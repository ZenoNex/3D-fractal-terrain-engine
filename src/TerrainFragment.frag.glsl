// TerrainFragment.frag.glsl
#version 460
in vec3 vWorldPos;
in mat3 vTBN;
layout(location=0) out vec4 outColor;

uniform sampler2D rock, grass, snow;

vec3 triplanar(sampler2D tex, vec3 p, vec3 n) {
    vec3 blend = abs(n); blend = pow(blend, vec3(4.0)); blend /= dot(blend,vec3(1));
    vec3 c = texture(tex, p.yz).rgb * blend.x +
             texture(tex, p.xz).rgb * blend.y +
             texture(tex, p.xy).rgb * blend.z;
    return c;
}

void main() {
    float h = vWorldPos.y;
    vec3 rockCol  = triplanar(rock,  vWorldPos*0.1, vTBN[2]);
    vec3 grassCol = triplanar(grass, vWorldPos*0.2, vTBN[2]);
    vec3 snowCol  = triplanar(snow,  vWorldPos*0.05, vTBN[2]);

    float slope = 1.0 - vTBN[2].y;
    vec3 albedo = mix(rockCol, grassCol, smoothstep(0.3,0.7, h));
    albedo = mix(albedo, snowCol, smoothstep(0.8,1.2, h));

    outColor = vec4(albedo, 1.0);
}
