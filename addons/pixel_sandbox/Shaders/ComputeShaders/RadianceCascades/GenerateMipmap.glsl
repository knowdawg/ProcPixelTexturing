#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba16f) uniform readonly image2D source;
layout(set = 0, binding = 1, rgba16f) uniform writeonly image2D outputBuffer;

void main(){
    ivec2 fragCoord = ivec2(gl_GlobalInvocationID.xy);

    vec4 val = 
        imageLoad(source, fragCoord * 2) * 2.0 +
        imageLoad(source, fragCoord * 2 + ivec2(1, 0)) +
        imageLoad(source, fragCoord * 2 + ivec2(0, 1)) +
        imageLoad(source, fragCoord * 2 + ivec2(-1, 0)) +
        imageLoad(source, fragCoord * 2 + ivec2(0, -1)) +
        imageLoad(source, fragCoord * 2 + ivec2(1, 1)) * 0.5 +
        imageLoad(source, fragCoord * 2 + ivec2(1, -1)) * 0.5 +
        imageLoad(source, fragCoord * 2 + ivec2(-1, 1)) * 0.5 +
        imageLoad(source, fragCoord * 2 + ivec2(-1, -1)) * 0.5;
    val /= 8.0;

    imageStore(outputBuffer, fragCoord, val);
}