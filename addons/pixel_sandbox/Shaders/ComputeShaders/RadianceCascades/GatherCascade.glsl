#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D lightImage;
layout(set = 0, binding = 1, rgba16f) uniform writeonly image2D outputBuffer;

layout(set = 0, binding = 2, std430) readonly buffer Params {
    int c0ProbeSize; //how wide (and tall) the first cascade's raycasts take up on the output texture
    int c0RayLength;
    int cascadeIndex;
    int probeResolution; //c0 probes per axis (initialCascadeResolution)
    int renderQuadrantSize; //Render quadrant size in texels
};

// Get the scale factor for a ray in probe space
float ray_scale(int cIndex) {
    if(cIndex < 0){
        return 0;
    }
    return float(1 << (2 * cIndex));//Four times the ray length per cascade: first (0 -> 1), secound (1 -> 4), third (4 -> 16) ect
    return float((1 << (2 * (cIndex + 1))) - 1) / 3.0;//Cumulative ray length: (4^c - 1) / 3, giving 0, 1, 5, 21, 85 ect
}

// Get the start & end offset for a ray in probe space.
vec2 ray_interval() {
    return c0RayLength * vec2(ray_scale(cascadeIndex - 1), ray_scale(cascadeIndex));
}

//Beer-Lambert extinction scale, tuned at REFERENCE_RESOLUTION. resScale (below) compensates for other resolutions.
const float extinction = 1.0;

//Returns the medium at a point: rgb = emitted radiance, a = occluder/medium density in [0,1].
//No longer inverted to transmittance - the march integrates density via Beer-Lambert below.
vec4 sampleLightImage(vec2 fragCoord){
    vec2 uv = fragCoord / vec2(imageSize(outputBuffer));
    return texture(lightImage, uv);
}

void main(){
    const float PI = 3.1415926535;

    ivec2 rayCoord = ivec2(gl_GlobalInvocationID.xy);

    int numOfRays = (c0ProbeSize * c0ProbeSize) << (2 * cascadeIndex); //Number of rays TOTAL in each probe. 4 times more pre cascade
    int probeSize = c0ProbeSize << cascadeIndex; //The WIDTH (and hieght) of each probe. 2 times the width per cascade
    ivec2 probeCoord = ivec2(floor(vec2(rayCoord) / float(probeSize))); //the x, y position of the probe I am apart of
    ivec2 probePos = (probeCoord * probeSize) + ivec2(probeSize / 2); //The probe position in texture space

    //get the direction of the ray based on rayCoord
    ivec2 localRayCoord = rayCoord % ivec2(probeSize); //get the x,y position of my ray in local_probe space
    int dirIndex = localRayCoord.x + (localRayCoord.y * probeSize); // get the index so I can be turned into an angle
    float angle = 2.0 * PI * ((float(dirIndex) + 0.5) / float(numOfRays));
    vec2 dir = vec2(cos(angle), sin(angle));

    vec3 radiance = vec3(0.0);
    float transmittance = 1.0; //1 = fully clear; decays via Beer-Lambert as the ray crosses density

    //Convert probe-space interval to cascade-texture texels while keeping the WORLD reach constant across
    float worldScale = float(c0ProbeSize) * float(probeResolution) / float(renderQuadrantSize);

    vec2 interval = ray_interval();
    float mipTexels = (interval.y - interval.x) / float(1 << cascadeIndex);
    int sampleCount = max(2, int(ceil(mipTexels))) * c0RayLength;
    float stepSize = (interval.y - interval.x) / float(sampleCount); //step length, cascade-texel units


    //start at -1 at cascade 4 to prevent leaking. Note, this will intensify ringing, thus it is limmtied to only cascade 4+
    for(int i = cascadeIndex > 3 ? -1 : 0; i < sampleCount; i++){
        //sample at the centre of each step segment
        float curInterval = mix(interval.x, interval.y, (float(i) + 0.5) / float(sampleCount)) * worldScale; //probe space to texture space, resolution-consistent
        vec4 s = sampleLightImage(vec2(probePos) + curInterval * dir); //rgb = emission, a = density

        //Gather light emitted here, attenuated by everything already in front of it.
        radiance += s.rgb * transmittance;

        //Beer-Lambert: transmittance across this step = exp(-opticalDepth).
        transmittance *= exp(-s.a * extinction * stepSize);
        if (transmittance < 0.001) break;
    }

    //Output accumulated radiance + transmittance left at the interval's end.
    imageStore(outputBuffer, rayCoord, vec4(radiance, transmittance));
}