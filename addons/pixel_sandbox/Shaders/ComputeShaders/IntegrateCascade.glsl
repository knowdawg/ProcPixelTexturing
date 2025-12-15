#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D cascade; //cascade that we are merging from. cascade N + 1
layout(set = 0, binding = 1, rgba32f) uniform writeonly image2D outputBuffer; //cascade that we are merging to. cascade N

layout(set = 0, binding = 2, std430) readonly buffer Params {
    int probeSize;
};

//1 thread per probe
void main(){
    ivec2 probeCoord = ivec2(gl_GlobalInvocationID.xy);
    
    //iteratate through each interval in the probe
    vec4 radiance = vec4(0.0, 0.0, 0.0, 1.0);
    for (int d = 0; d < probeSize; d++) {
        for (int b = 0; b < probeSize; b++) {
            ivec2 texel = (probeCoord * probeSize) + ivec2(d, b);

            radiance.rgb += imageLoad(cascade, texel).rgb;
        }
    }
    //average out the probe
    radiance.rgb /= probeSize * probeSize;

    imageStore(outputBuffer, probeCoord, radiance);
}