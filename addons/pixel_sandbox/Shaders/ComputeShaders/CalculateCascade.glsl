#[compute]
#version 450

//Note, cascades should be in no way dependant on the render section size of the terrain. This method currently is and assumes that the size of a cascade is the size of the render section size
//This is because is samples from the lightmap and light image based on gl_GlobalInvocationID which will only line up if everything is the same resoltion

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D lightSDF;
layout(set = 0, binding = 1, rgba32f) uniform readonly image2D lightImage;
layout(set = 0, binding = 2, rgba32f) uniform writeonly image2D outputBuffer;

layout(set = 0, binding = 3, std430) readonly buffer Params {
    int c0ProbeSize; //how wide (and tall) the first cascade's raycasts take up on the output texture
    int c0RayLength;
    int cascadeIndex; //TODO: TURN INTO A PUSH CONSTANT
    int scrollOffsetX;
    int scrollOffsetY;
};

vec4 sampleLightImage(ivec2 uv){
    ivec2 size = imageSize(lightImage);
    ivec2 offsetUV = uv + ivec2(scrollOffsetX, scrollOffsetY) - (size / 2);
    offsetUV = ivec2(
        (offsetUV.x % size.x + size.x) % size.x,
        (offsetUV.y % size.y + size.y) % size.y
    );

    return imageLoad(lightImage, offsetUV);
}

// Get the scale factor for a ray
float ray_scale(int cIndex) {
    if (cIndex <= 0) return 0.0;
    return float(1 << (2 * cIndex)); //Four times the ray length per cascade
}

// Get the start & end offset for a ray (it will start and finish this far away from its probe)
vec2 ray_interval() {
    return c0RayLength * vec2(ray_scale(cascadeIndex), ray_scale(cascadeIndex + 1));
}


vec4 ray_march(vec2 origin, vec2 dir, vec2 interval){
    vec2 size = vec2(imageSize(outputBuffer));
    vec4 hit = vec4(0.0, 0.0, 0.0, 0.0); //0 in alpha is hit nothing, 1 is hit something

    float dis = interval.x;
    for (int i = 0; i < 32; i++){
        dis = clamp(dis, interval.x, interval.y);
        vec2 p = origin + (dir * dis);

        if(p.x < 0 || p.y < 0 || p.x >= size.x || p.y >= size.y) break;

        vec4 sdfVal = imageLoad(lightSDF, ivec2(p));
        if(sdfVal.r < 0.001 || dis == interval.y){
            hit = sampleLightImage(ivec2(p));
            break;
        }
        dis += sdfVal.r * size.x;
    }
    return hit;
}

void main(){
    const float PI = 3.1415926535;

    ivec2 rayCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(outputBuffer);

    if(rayCoord.x < 0 || rayCoord.y < 0 || rayCoord.x > size.x || rayCoord.y > size.y) return; //Out of bounds

    int numOfRays = (c0ProbeSize * c0ProbeSize) << (2 * cascadeIndex); //Number of rays TOTAL in each probe. 4 times move pre cascade
    int probeSize = c0ProbeSize << cascadeIndex; //The WIDTH (and hieght) of each probe. 2 times the width per cascade
    ivec2 probeCoord = ivec2(floor(vec2(rayCoord) / float(probeSize)));
    ivec2 probePos = (probeCoord * probeSize) + ivec2(probeSize >> 1);

    //get the direction of the ray based on rayCoord
    ivec2 localRayCoord = rayCoord % ivec2(probeSize); //get the local rayCoord in my probe
    int dirIndex = localRayCoord.x + (localRayCoord.y * probeSize); // get the index so I can be turned into an angle
    float angle = 2.0 * PI * ((float(dirIndex) + 0.5) / float(numOfRays));
    vec2 dir = vec2(cos(angle), sin(angle));

    //March!
    vec4 radiance = ray_march(vec2(probePos), dir, ray_interval());

    imageStore(outputBuffer, rayCoord, radiance);
}