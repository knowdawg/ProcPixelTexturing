#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D lightImage;
layout(set = 0, binding = 1, rgba16f) uniform writeonly image2D outputBuffer;

layout(set = 0, binding = 2, std430) readonly buffer Params {
    int c0ProbeSize; //how wide (and tall) the first cascade's raycasts take up on the output texture
    int c0RayLength;
    int cascadeIndex; //TODO: TURN INTO A PUSH CONSTANT
};

vec4 sampleLightImage(ivec2 fragCoord){
    vec2 uv = vec2(fragCoord) / vec2(imageSize(outputBuffer));

    vec4 radiance = texture(lightImage, uv);
    radiance.a = 1.0 - radiance.a;

    return radiance;
}

// Get the scale factor for a ray
float ray_scale(int cIndex) {
    if (cIndex <= 0) return 0.0;
    return float(1 << (2 * (cIndex - 1)));//Four times the ray length per cascade: first (0 -> 1), secound (1 -> 4), third (4 -> 16) ect
}

// Get the start & end offset for a ray. It will sample the light image based on these values
vec2 ray_interval() {
    return c0RayLength * vec2(ray_scale(cascadeIndex), ray_scale(cascadeIndex + 1));
}


//origin is in probe space
//interval is in probe space
vec4 ray_march(vec2 origin, vec2 dir, vec2 interval){
    vec4 radiance = vec4(0.0, 0.0, 0.0, 0.0); //0 in alpha is hit nothing, 1 is hit something
    float transmittance = 1.0;

    float dis = interval.x;
    for (int i = 0; i < 8; i++){
        if(dis >= interval.y){
            break;
        }
        
        if(transmittance < 0.01){
            transmittance = 0.0;
            break;
        }

        vec2 p = origin + (dis * dir);

        vec4 myPos = sampleLightImage(ivec2(p));

        radiance.rgb += myPos.rgb * transmittance * myPos.a;
        transmittance *= 1.0 - myPos.a;
        dis += (interval.y - interval.x) / 8.0;
        
    }
    radiance.a = transmittance;
    return radiance;
}

vec4 mergeIntervals(vec4 near, vec4 far) {
    float nearOcluder = near.a;
    float farOcluder = far.a;
    //Far's radiance can be ocluded by near's radiance if near hit
    vec3 radiance = near.rgb + (far.rgb * nearOcluder);

    return vec4(radiance, (nearOcluder * farOcluder));
}

void main(){
    const float PI = 3.1415926535;

    ivec2 rayCoord = ivec2(gl_GlobalInvocationID.xy);

    int numOfRays = (c0ProbeSize * c0ProbeSize) << (2 * cascadeIndex); //Number of rays TOTAL in each probe. 4 times more pre cascade
    int probeSize = c0ProbeSize << cascadeIndex; //The WIDTH (and hieght) of each probe. 2 times the width per cascade
    ivec2 probeCoord = ivec2(floor(vec2(rayCoord) / float(probeSize))); //the x, y position of the probe I am apart of
    ivec2 probePos = (probeCoord * probeSize) + ivec2(probeSize); //The probe position in probe space

    //get the direction of the ray based on rayCoord
    ivec2 localRayCoord = rayCoord % ivec2(probeSize); //get the x,y position of my ray in local_probe space
    int dirIndex = localRayCoord.x + (localRayCoord.y * probeSize); // get the index so I can be turned into an angle
    float angle = 2.0 * PI * ((float(dirIndex) + 0.5) / float(numOfRays));
    vec2 dir = vec2(cos(angle), sin(angle));


    vec4 radiance = vec4(0.0, 0.0, 0.0, 1.0);
    vec2 interval = ray_interval();
    int sampleCount = 1 + (cascadeIndex * 2);
    for(int i = 0; i < sampleCount; i++){
        float curInterval = mix(interval.x, interval.y, float(i) / float(sampleCount));
        vec4 curRadiance = sampleLightImage(probePos + ivec2(curInterval * dir));
        
        radiance = mergeIntervals(radiance, curRadiance);
    }

    // vec4 closeRadiance = sampleLightImage(probePos + ivec2(ray_interval().x * dir));
    // vec4 farRadiance = sampleLightImage(probePos + ivec2(ray_interval().y * dir));
    // vec4 radiance = closeRadiance;//mergeIntervals(closeRadiance, farRadiance);


    //March!
    //vec4 radiance = ray_march(vec2(probePos), dir, ray_interval());

    //vec2 uv = vec2(rayCoord) / vec2(imageSize(outputBuffer));

    //radiance = vec4(dir.x, dir.y, 0.0, 1.0);

    imageStore(outputBuffer, rayCoord, radiance);
}