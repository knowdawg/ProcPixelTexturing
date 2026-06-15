#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba16f) uniform readonly image2D source;
layout(set = 0, binding = 1, rgba16f) uniform writeonly image2D outputBuffer;

const float occlusionGain = 1.0;

void main(){
    ivec2 fragCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 base = fragCoord * 2;

    const float w[4] = float[4](1.0, 3.0, 3.0, 1.0); //per-axis weights, sum 8
    vec4 sum = vec4(0.0);
    for(int y = 0; y < 4; y++){
        for(int x = 0; x < 4; x++){
            sum += imageLoad(source, base + ivec2(x - 1, y - 1)) * (w[x] * w[y]);
        }
    }

    vec4 val;
    val.rgb = sum.rgb / 64.0;                                 //energy-preserving tent (total weight 8 * 8 = 64)
    val.a = clamp((sum.a / 64.0) * occlusionGain, 0.0, 1.0);  //averaged occlusion density, amplified per mip

    imageStore(outputBuffer, fragCoord, val);
}