// TerrainVertex.vert.glsl
#version 460
layout(location=0) in vec4 inPosNorm; // .xyz pos, .w packed normal
out vec3 vWorldPos;
out mat3 vTBN;

void main() {
    vec3 pos = inPosNorm.xyz;
    vec3 N   = unpackSnorm4x8(uint(inPosNorm.w)).xyz;
    // build cheap TBN from partial derivatives (or pass from dual contour)
    vec3 T   = normalize(cross(N, vec3(0,0,1)));
    vec3 B   = cross(N, T);
    vTBN = mat3(T, B, N);
    vWorldPos = pos;
    gl_Position = ubo.proj * ubo.view * vec4(pos,1);
}
