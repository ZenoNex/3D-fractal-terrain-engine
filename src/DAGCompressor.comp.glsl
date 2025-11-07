// DAGCompressor.comp.glsl
#version 460
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(binding = 0) readonly buffer Mesh { vec4 vertices[]; uint indices[]; };
layout(binding = 1) writeonly buffer DAG { uint nodes[]; }; // 4-children + payload

// Simple 8-ary DAG: each node = (child0,child1,child2,child3,child4,child5,child6,child7,payload)
// payload = triangle start index | triangle count << 16
