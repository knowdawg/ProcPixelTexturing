#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D c1;
layout(set = 0, binding = 1, rgba32f) uniform readonly image2D c0;

//L2 circular-harmonic coefficients. One texture per coefficient, holding its RGB:
//L0 = Direct Current, L1C/L1S = cos/sin, L2C/L2S = cos2/sin2.
layout(set = 0, binding = 2, rgba16f) uniform writeonly image2D CHC_L0;
layout(set = 0, binding = 3, rgba16f) uniform writeonly image2D CHC_L1C;
layout(set = 0, binding = 4, rgba16f) uniform writeonly image2D CHC_L1S;
layout(set = 0, binding = 5, rgba16f) uniform writeonly image2D CHC_L2C;
layout(set = 0, binding = 6, rgba16f) uniform writeonly image2D CHC_L2S;

layout(set = 0, binding = 7, std430) readonly buffer Params {
    int c0ProbeResolution; //512
    int c1RayCountPerProbe; //16
};

layout(constant_id = 0) const int c0ProbeSize = 2;
layout(constant_id = 1) const int c1ProbeSize = 4;

#define PI 3.141592

//Merge 2 rays with respect to their visibility. Alpha equals 0.0 means it hit something
vec4 mergeIntervals(vec4 near, vec4 far) {
    float nearOcluder = near.a; //will be 0 is near hit something
    float farOcluder = far.a; //will be 0 is far hit something
    //Far's radiance can be ocluded by near's radiance if near hit
    vec3 radiance = near.rgb + (far.rgb * nearOcluder);

    return vec4(radiance, (nearOcluder * farOcluder));
}

//Returns the bilinear wieghts for the 4 nearest n+1 probes.
//Ratio is the fractional part of n's probe position in n+1 probe space. So (0.0, 0.0) would be top left, (0.5, 0.5) would be in the center ect ect...
vec4 bilinearWeights(vec2 ratio) {
    return vec4(
        (1.0 - ratio.x) * (1.0 - ratio.y),
        ratio.x * (1.0 - ratio.y),
        (1.0 - ratio.x) * ratio.y,
        ratio.x * ratio.y
    );
}

void bilinearSamples(vec2 nProbePos, vec2 nextCascadeSize, out vec4 weights) {
    //position of n probe in n+1 probe space
    const vec2 baseCoord = (nProbePos / nextCascadeSize) - vec2(0.5, 0.5);

    const vec2 ratio = fract(baseCoord); //location in n+1 probe space relative to top left n+1 probe
    weights = bilinearWeights(ratio);
}

vec4 textureC0RayAtIndex(ivec2 c0ProbeCoord, int index){
    int xOffset = index % c0ProbeSize;
    int yOffset = index / c0ProbeSize;
    ivec2 coord = c0ProbeSize * c0ProbeCoord + ivec2(xOffset, yOffset);
    return imageLoad(c0, coord);
}

vec4 textureC1RayAtIndex(ivec2 c1ProbeCoord, int index){
    int xOffset = index % 4;
    int yOffset = index / 4;
    return imageLoad(c1, 4 * c1ProbeCoord + ivec2(xOffset, yOffset));
}

void main(){
    ivec2 probeCoord = ivec2(gl_GlobalInvocationID.xy);

    //L2 coefficients, one vec3 (rgb) per harmonic: DC, cos, sin, cos2, sin2.
    vec3 coefDC  = vec3(0.0);
    vec3 coefC1  = vec3(0.0);
    vec3 coefS1  = vec3(0.0);
    vec3 coefC2  = vec3(0.0);
    vec3 coefS2  = vec3(0.0);

    ivec2 topLeftC1Probe = (probeCoord - ivec2(1)) / 2;
    ivec2 nearestC1Probes[4] = {
        topLeftC1Probe,
        topLeftC1Probe + ivec2(1, 0),
        topLeftC1Probe + ivec2(0, 1),
        topLeftC1Probe + ivec2(1, 1)
    };

    //Bilinear Wieghts
    vec2 c0ProbeTexturePosition = vec2(probeCoord * 2) + vec2(1.0); //position of n probe in pixels
    vec2 c1ProbeSize = vec2(c1RayCountPerProbe >> 2); // size of n+1 probe
    vec4 weights;
    bilinearSamples(c0ProbeTexturePosition, c1ProbeSize, weights);

    //Pass 1: gather the merged (c0 + c1) radiance for every ray up front so they can be blended together
    vec4 rayRadiance[16]; //sized to c1RayCountPerProbe
    for(int i = 0; i < c1RayCountPerProbe; i++){
        vec4 weightedRayRadiance = vec4(0.0);
        for(int j = 0; j < 4; j++){
            ivec2 curC1Probe = nearestC1Probes[j];

            vec4 radiance = textureC1RayAtIndex(curC1Probe, i);
            weightedRayRadiance += radiance * weights[j];
        }

        vec4 c0Radiance = textureC0RayAtIndex(probeCoord, i / 4); //4x less rays
        rayRadiance[i] = mergeIntervals(c0Radiance, weightedRayRadiance);
    }

    //Pass 2: smooth the rays with eachother, then project onto the L2 basis (DC, cos, sin, cos2, sin2)
    float rayScalar = (2.0 * PI) / float(c1RayCountPerProbe);
    for(int i = 0; i < c1RayCountPerProbe; i++){
        float angle = (float(i) / float(c1RayCountPerProbe)) * 2.0 * PI;

        int prevRay = (i - 1 + c1RayCountPerProbe) % c1RayCountPerProbe;
        int nextRay = (i + 1) % c1RayCountPerProbe;
        vec3 rad = (0.33 * rayRadiance[prevRay] + 0.34 * rayRadiance[i] + 0.33 * rayRadiance[nextRay]).rgb;

        coefDC += rad * (1.0 * rayScalar);
        coefC1 += rad * (cos(angle) * rayScalar);
        coefS1 += rad * (sin(angle) * rayScalar);
        coefC2 += rad * (cos(2.0 * angle) * rayScalar);
        coefS2 += rad * (sin(2.0 * angle) * rayScalar);
    }

    imageStore(CHC_L0,  probeCoord, vec4(coefDC, 1.0));
    imageStore(CHC_L1C, probeCoord, vec4(coefC1, 1.0));
    imageStore(CHC_L1S, probeCoord, vec4(coefS1, 1.0));
    imageStore(CHC_L2C, probeCoord, vec4(coefC2, 1.0));
    imageStore(CHC_L2S, probeCoord, vec4(coefS2, 1.0));
}
