#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D cascade;
layout(set = 0, binding = 1, rgba32f) uniform writeonly image2D outputBuffer;

layout(set = 0, binding = 2, std430) readonly buffer Params {
    int probeSize;
};

/*
Maybye decouple the integrate cascade and caculate light direction logic into two compute shaders so i can get lighting direction on any cascade, not just the last one
I could write lighting direction to a seperate texture, perhaps even a lower resolution one.
*/


vec3 apply_exposure(vec3 color) {
    return 1.0 - exp(-color * 3.0);
}

vec3 boost_luminance(vec3 color) {
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    vec3 normalized = color / max(lum, 0.0001);
    return normalized * lum * 3.0;
}


//1 thread per probe
void main(){
    ivec2 probeCoord = ivec2(gl_GlobalInvocationID.xy);

    const float PI = 3.1415926535;

    //iteratate through each interval in the probe
    vec4 radiance = vec4(0.0, 0.0, 0.0, 1.0);
    for (int d = 0; d < probeSize; d++) {
        for (int b = 0; b < probeSize; b++) {
            ivec2 texel = (probeCoord * probeSize) + ivec2(d, b);
            vec3 radVal = imageLoad(cascade, texel).rgb;
            radiance.rgb += radVal;
        }
    }
    //average out the probe
    radiance.rgb /= probeSize * probeSize;

    // //amplify lighting
    // radiance.rgb *= 2.0;
    //radiance.rgb = apply_exposure(radiance.rgb);
    //radiance.rgb = boost_luminance(radiance.rgb);

    imageStore(outputBuffer, probeCoord, radiance);
   // imageStore(outputBuffer, probeCoord, imageLoad(cascade, probeCoord));
}