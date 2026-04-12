#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D bigCascade; //cascade that we are merging from. cascade N + 1
layout(set = 0, binding = 1, rgba32f) uniform image2D mergeToCascade; //cascade that we are merging to. cascade N

layout(set = 0, binding = 2, std430) readonly buffer Params {
    int mergeProbeSize; //TODO: TURN INTO A PUSH CONSTANT
};

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

//outs the 
void bilinearSamples(vec2 nProbePos, vec2 nextCascadeSize, out vec4 weights, out ivec2 baseIndex) {
    //position of n probe in n+1 probe space
    const vec2 baseCoord = (nProbePos / nextCascadeSize) - vec2(0.5, 0.5);

    const vec2 ratio = fract(baseCoord); //location in n+1 probe space relative to top left n+1 probe
    weights = bilinearWeights(ratio);
    baseIndex = ivec2(floor(baseCoord)); //Top-left n+1 probe coord
}


//trasnforms offsetIndex into a offset for each bilinear probe
ivec2 bilinearOffset(int offsetIndex) {
    const ivec2 offsets[4] = { ivec2(0, 0), ivec2(1, 0), ivec2(0, 1), ivec2(1, 1) };
    return offsets[offsetIndex];
}

void main(){
    ivec2 rayCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 probeCoord = ivec2(floor(vec2(rayCoord) / float(mergeProbeSize)));

    vec2 mergeProbePos = vec2(probeCoord * mergeProbeSize) + vec2(mergeProbeSize >> 1); //position of n probe in pixels
    vec2 bigCascadeSize = vec2(mergeProbeSize << 1); // size of n+1 probe
    vec4 weights;
    ivec2 baseIndex;
    bilinearSamples(mergeProbePos, bigCascadeSize, weights, baseIndex);

    //get the direction index of the current n ray (the index relative to its probe)
    ivec2 localRayCoord = rayCoord % ivec2(mergeProbeSize);
    const int dirIndex = localRayCoord.x + (localRayCoord.y * mergeProbeSize);
    const vec4 nearInterval = imageLoad(mergeToCascade, rayCoord);
    //base index for n+1 cascade. times 4 because there are 4 more rays so it takes 4 times as long to get to the same angle
    const int baseBigDirIndex = dirIndex * 4;

    vec4 combinedRadiance = vec4(0.0);
    //for each of the four rays
    for (int d = 0; d < 4; d++) {
        vec4 radiance = vec4(0.0);
        //for each of the 4 n+1 probes
        for (int b = 0; b < 4; b++) {
            //get the coord of the current n+1 probe
            const ivec2 baseOffset = bilinearOffset(b);
            const ivec2 bilinearCoord = baseIndex + baseOffset;

            const int bilinearDirIndex = baseBigDirIndex + d;
            //Convert the directional index to a local texel coordinate in n+1
            const ivec2 bilinearDirCoord = ivec2(
                bilinearDirIndex % int(bigCascadeSize.x),
                bilinearDirIndex / int(bigCascadeSize.x)
            );
            //Get the texel coordinate to merge with in cascade n+1
            const ivec2 bilinearTexel = (bilinearCoord * ivec2(bigCascadeSize)) + bilinearDirCoord;
            //Fetch the bilinear interval from the n+1 cascade
            const vec4 bilinearInterval = imageLoad(bigCascade, bilinearTexel);

            //Merge the two intervals
            radiance += mergeIntervals(nearInterval, bilinearInterval) * weights[b];
        }
        combinedRadiance += radiance / 4.0; //gunna be adding radiance 4 times and we want the average of each of the 4 n+1 probes
    }
    
    //combinedRadiance.rgb = pow(combinedRadiance.rgb, vec3(1.0 / 2.2));

    imageStore(mergeToCascade, rayCoord, combinedRadiance);
}