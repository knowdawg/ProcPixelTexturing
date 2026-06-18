#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba16f) uniform readonly image2D c1;
layout(set = 0, binding = 1, rgba16f) uniform readonly image2D c0;

//Output: the merged (bilinear c1 + c0) radiance per ray. One array layer per ray. Stored in a
//texture (not a local array) so the convolution pass can re-read it cheaply from cache.
layout(set = 0, binding = 2, rgba16f) uniform writeonly image2DArray mergedRays;

//Omnidirectional ambient (old L2 DC). Separate from the array for simplicity.
layout(set = 0, binding = 3, rgba16f) uniform writeonly image2D fluenceBuffer;

layout(constant_id = 0) const int c0ProbeSize = 2;
layout(constant_id = 1) const int c1ProbeSize = 4;
layout(constant_id = 3) const int c1RayCountPerProbe = 16;

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

    ivec2 topLeftC1Probe = (probeCoord - ivec2(1)) / 2;
    ivec2 nearestC1Probes[4] = {
        topLeftC1Probe,
        topLeftC1Probe + ivec2(1, 0),
        topLeftC1Probe + ivec2(0, 1),
        topLeftC1Probe + ivec2(1, 1)
    };

    //Bilinear Wieghts
    vec2 c0ProbeTexturePosition = vec2(probeCoord * 2) + vec2(1.0); //position of n probe in pixels
    vec2 c1ProbeSizePx = vec2(c1ProbeSize); // size of n+1 probe
    vec4 weights;
    bilinearSamples(c0ProbeTexturePosition, c1ProbeSizePx, weights);

    //Merge each ray (bilinear c1 + c0) and store it. Accumulate fluence as well.
    float rayScalar = (2.0 * PI) / float(c1RayCountPerProbe);
    vec3 fluence = vec3(0.0);
    for(int i = 0; i < c1RayCountPerProbe; i++){
        vec4 c1Ray = vec4(0.0);
        for(int j = 0; j < 4; j++)
            c1Ray += textureC1RayAtIndex(nearestC1Probes[j], i) * weights[j];

        vec4 merged = mergeIntervals(textureC0RayAtIndex(probeCoord, i / 4), c1Ray);
        imageStore(mergedRays, ivec3(probeCoord, i), merged);
        fluence += merged.rgb;
    }
    fluence *= rayScalar;
    imageStore(fluenceBuffer, probeCoord, vec4(fluence, 1.0));
}
