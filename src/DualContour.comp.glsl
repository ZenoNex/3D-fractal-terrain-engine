// DualContour.comp.glsl
#version 460
#extension GL_EXT_scalar_block_layout : enable
#extension GL_NV_mesh_shader : enable   // optional; fallback to compute+SSBO

layout(local_size_x = 1) in;   // one workgroup per cell
layout(std430, binding = 0) readonly buffer Field { float f[512]; };
layout(std430, binding = 1) buffer Vertices { vec4 v[]; };   // pos + normal
layout(std430, binding = 2) buffer Indices  { uint  i[]; };
layout(std430, binding = 3) buffer Counter  { uint  vertCnt; uint triCnt; };

uniform vec3 chunkOrigin;
uniform float cellSize;

// Hermite data per edge (12 edges)
struct EdgeHermite {
    vec3 pos;
    vec3 normal;
    bool valid;
};

EdgeHermite hermite[12];

void computeHermite(uint edge) {
    // edge index → two voxel indices (i0,i1)
    uint i0 = edgeTable[edge*2], i1 = edgeTable[edge*2+1];
    float f0 = f[i0], f1 = f[i1];
    if (sign(f0) == sign(f1)) { hermite[edge].valid = false; return; }
    float t = f0 / (f0 - f1);
    vec3 p0 = voxelPos(i0), p1 = voxelPos(i1);
    vec3 pos = mix(p0, p1, t);
    vec3 n0 = gradient(i0), n1 = gradient(i1);
    vec3 normal = normalize(mix(n0, n1, t));
    hermite[edge].pos = pos; hermite[edge].normal = normal;
    hermite[edge].valid = true;
}

// Dual Contouring QEF solver (closed-form for 3×3)
vec3 solveQEF(vec3 points[12], vec3 normals[12], uint count) {
    mat3 A = mat3(0); vec3 b = vec3(0);
    for (uint i = 0; i < count; ++i) {
        vec3 n = normals[i];
        A += outerProduct(n,n);
        b += n * dot(n, points[i]);
    }
    // Pseudo-inverse via SVD would be overkill; use simple regularized solve
    mat3 reg = mat3(1e-4);
    vec3 x = inverse(A + reg) * b;
    return x;
}

void main() {
    // 1. evaluate 512 field values (already filled by FieldEvaluator)
    // 2. compute Hermite data for each of 12 edges
    for (uint e = 0; e < 12; ++e) computeHermite(e);

    // 3. collect valid edge points
    vec3 pts[12]; vec3 nrm[12]; uint cnt = 0;
    for (uint e = 0; e < 12; ++e) if (hermite[e].valid) {
        pts[cnt] = hermite[e].pos; nrm[cnt] = hermite[e].normal; ++cnt;
    }
    if (cnt == 0) return;

    // 4. QEF → optimal vertex
    vec3 vert = solveQEF(pts, nrm, cnt);
    uint vertIdx = atomicAdd(vertCnt, 1);
    vertices[vertIdx] = vec4(vert, packSnorm4x8(vec4(normalize(averageNormal(nrm,cnt)), 0)));

    // 5. emit quads (dual graph)
    //    (lookup table for sign-config → quad list)
    uint config = signConfig(); // 8-bit from corner signs
    uint* quadList = dualTable[config];
    for (uint q = 0; quadList[q] != 0xFF; ++q) {
        uint e0 = quadList[q*4+0], e1 = quadList[q*4+1],
             e2 = quadList[q*4+2], e3 = quadList[q*4+3];
        if (!hermite[e0].valid || !hermite[e1].valid || 
            !hermite[e2].valid || !hermite[e3].valid) continue;
        uint base = atomicAdd(triCnt, 2); // two triangles per quad
        uint v0 = edgeVertexIndex(e0), v1 = edgeVertexIndex(e1),
             v2 = edgeVertexIndex(e2), v3 = edgeVertexIndex(e3);
        indices[base*3+0] = v0; indices[base*3+1] = v1; indices[base*3+2] = v2;
        indices[base*3+3] = v2; indices[base*3+4] = v3; indices[base*3+5] = v0;
    }
}
