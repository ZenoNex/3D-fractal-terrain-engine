// FieldEvaluator.comp.glsl
#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

struct GeodesicSeed {
    vec3 pos;
    float weight;
};

layout(std430, binding = 0) readonly buffer Seeds { GeodesicSeed seeds[]; };
layout(std430, binding = 1) buffer Output { float field[]; };

uniform uint seedCount;
uniform vec3 chunkOrigin;   // world-space corner of this 8³ block
uniform float cellSize;
uniform float a, b, c;      // polynomial, perlin, hyperbolic weights

// ---------- Chebyshev T3 ----------
float T3(float x) { return 4.0*x*x*x - 3.0*x; }
// ---------- Legendre L2 ----------
float L2(float z) { return 1.5*z*z - 0.5; }

// ---------- 3-D Perlin (classic) ----------
float fade(float t) { return t*t*t*(t*(t*6.0-15.0)+10.0); }
float grad(int hash, vec3 p) {
    int h = hash & 15;
    float u = h<8 ? p.x : p.y, v = h<4 ? p.y : (h==12||h==14 ? p.x : p.z);
    return ((h&1)==0 ? u : -u) + ((h&2)==0 ? v : -v);
}
float perlin(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    int A = int(i.x) & 255, B = int(i.x+1.0) & 255;
    int C = int(i.y) & 255, D = int(i.y+1.0) & 255;
    int E = int(i.z) & 255, F = int(i.z+1.0) & 255;
    // (full permutation table omitted for brevity – use a 256-entry array)
    // ... hash lookup ...
    float u = fade(f.x), v = fade(f.y), w = fade(f.z);
    float res = mix(mix(mix(grad(pTable[A+C*256+E*65536], f),
                            grad(pTable[B+C*256+E*65536], f-vec3(1,0,0)), u),
                        mix(grad(pTable[A+D*256+E*65536], f-vec3(0,1,0)),
                            grad(pTable[B+D*256+E*65536], f-vec3(1,1,0)), u), v),
                    mix(mix(grad(pTable[A+C*256+F*65536], f-vec3(0,0,1)),
                            grad(pTable[B+C*256+F*65536], f-vec3(1,0,1)), u),
                        mix(grad(pTable[A+D*256+F*65536], f-vec3(0,1,1)),
                            grad(pTable[B+D*256+F*65536], f-vec3(1,1,1)), u), v), w);
    return res;
}

// ---------- Multifractal ----------
float multifractal(vec3 p, int octaves) {
    float value = 0.0, amp = 1.0, freq = 1.0;
    for (int i = 0; i < octaves; ++i) {
        value += amp * perlin(p * freq);
        freq *= 2.0; amp *= 0.5;
    }
    return value;
}

// ---------- Main ----------
void main() {
    uvec3 id = gl_GlobalInvocationID;
    vec3 local = vec3(id) * cellSize;
    vec3 world = chunkOrigin + local;

    // Geodesic term
    float geo = 0.0;
    for (uint i = 0; i < seedCount; ++i) {
        vec3 d = world - seeds[i].pos;
        geo += seeds[i].weight / (dot(d,d) + 1e-6);
    }

    // Polynomial term
    float poly = a * T3(world.x) * T3(world.y) * L2(world.z);

    // Fractal term
    float frac = b * multifractal(world, 5);

    // Hyperbolic modulator
    float hyp = c * sinh(dot(world,world));

    float F = geo + poly + frac + hyp;

    uint idx = id.x + id.y*8 + id.z*64;
    field[idx] = F;
}
