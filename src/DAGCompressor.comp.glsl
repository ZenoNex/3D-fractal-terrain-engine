// DAGCompressor.comp.glsl
#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

struct Triangle {
    uvec3 indices;   // vertex indices (0-based inside chunk)
    uint  _pad;
};

layout(std430, binding = 0) readonly buffer Mesh {
    vec4  vertices[];   // .xyz = pos, .w = packed normal (unused here)
    uint  indices[];    // flat triangle list (3 uint per tri)
};
layout(std430, binding = 1) writeonly buffer DAG {
    // Node layout: 8 child offsets (uint) + payload (uint)
    // payload = (triangleStart << 16) | triangleCount
    uint nodes[];
};

uniform uint vertexCount;
uniform uint indexCount;      // must be multiple of 3
uniform vec3 chunkOrigin;
uniform float chunkSize;      // world-space edge length

// ------------------------------------------------------------------
// Helper: Morton order for a voxel (8x8x8 grid inside the chunk)
uint morton3(uint x, uint y, uint z) {
    uint mort = 0;
    for (uint i = 0; i < 8; ++i) {
        mort |= ((x >> i) & 1u) << (3u*i + 0u);
        mort |= ((y >> i) & 1u) << (3u*i + 1u);
        mort |= ((z >> i) & 1u) << (3u*i + 2u);
    }
    return mort;
}

// ------------------------------------------------------------------
// Atomic counter for node allocation
shared uint nodeAlloc;
void allocNode(out uint offset) {
    if (gl_LocalInvocationID.x == 0u && gl_LocalInvocationID.y == 0u && gl_LocalInvocationID.z == 0u)
        nodeAlloc = atomicAdd(nodes[0], 9u); // 9 uints per node
    barrier();
    offset = nodeAlloc;
}

// ------------------------------------------------------------------
// Build leaf nodes (one per voxel that contains triangles)
void main() {
    // ------------------------------------------------------------------
    // 1. Determine which voxel this invocation belongs to
    uvec3 voxel = gl_GlobalInvocationID;               // 0..7
    uint mort = morton3(voxel.x, voxel.y, voxel.z);   // 0..511

    // ------------------------------------------------------------------
    // 2. Scan the index buffer for triangles intersecting this voxel
    const uint triCount = indexCount / 3u;
    uint localTriStart = 0xFFFFFFFFu;
    uint localTriCnt   = 0u;

    // Simple AABB test per triangle
    for (uint t = 0u; t < triCount; ++t) {
        uint i0 = indices[t*3u+0u];
        uint i1 = indices[t*3u+1u];
        uint i2 = indices[t*3u+2u];

        // early out if any vertex index is out of range
        if (i0 >= vertexCount || i1 >= vertexCount || i2 >= vertexCount) continue;

        vec3 p0 = vertices[i0].xyz;
        vec3 p1 = vertices[i1].xyz;
        vec3 p2 = vertices[i2].xyz;

        // transform to local voxel space (0..7)
        vec3 local0 = (p0 - chunkOrigin) * (8.0 / chunkSize);
        vec3 local1 = (p1 - chunkOrigin) * (8.0 / chunkSize);
        vec3 local2 = (p2 - chunkOrigin) * (8.0 / chunkSize);

        // axis-aligned bounding box of the triangle
        vec3 bbMin = min(local0, min(local1, local2));
        vec3 bbMax = max(local0, max(local1, local2));

        // does it intersect our voxel?
        bvec3 leq = lessThanEqual(bbMin, vec3(voxel) + vec3(1.0));
        bvec3 geq = greaterThanEqual(bbMax, vec3(voxel));
        if (all(bvec3(leq.x && geq.x, leq.y && geq.y, leq.z && geq.z))) {
            if (localTriCnt == 0u) localTriStart = t;
            ++localTriCnt;
        }
    }

    // ------------------------------------------------------------------
    // 3. If the voxel contains triangles → allocate a leaf node
    if (localTriCnt == 0u) return;

    uint nodeOffset;
    allocNode(nodeOffset);

    // leaf nodes have no children → child pointers = 0
    for (uint c = 0u; c < 8u; ++c)
        nodes[nodeOffset + c] = 0u;

    // payload = (triangleStart << 16) | triangleCount
    nodes[nodeOffset + 8u] = (localTriStart << 16u) | localTriCnt;

    // ------------------------------------------------------------------
    // 4. Write the morton index into a shared "leaf list" for the next pass
    //     (the merge pass will run as a separate compute dispatch)
    //     For brevity we store leaf offsets in a global buffer:
    //     layout(binding=2) buffer LeafList { uint leafOffsets[]; };
    //     (omitted here – host will read back and merge hierarchically)
}
