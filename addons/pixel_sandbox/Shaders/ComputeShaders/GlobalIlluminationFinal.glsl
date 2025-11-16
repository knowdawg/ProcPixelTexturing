#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;


layout(set = 0, binding = 0, rgba32f) uniform readonly image2D lightmap;

layout(set = 0, binding = 1, rgba32f) uniform readonly image2D lightSDF;

layout(set = 0, binding = 2, rgba32f) uniform writeonly image2D outputBuffer;

float sampleDistanceField(ivec2 uv){
    vec2 sam = imageLoad(lightSDF, uv).rg;
    if(sam.g < 0.5){
        return sam.r;
    }
    return 0.0;
}

void main(){
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

    float imSize = float(imageSize(outputBuffer).x);
    float textureScalling = (imSize / 512.0);

    float lightVal = sampleDistanceField(uv);
    lightVal = 1.0 - smoothstep(0.0, 0.1 / textureScalling, lightVal);

    float lightRay = imageLoad(lightmap, uv).r;

    lightVal = max(lightRay, lightVal * 0.5);

    vec4 color = vec4(vec3(lightVal), 1.0);

    imageStore(outputBuffer, uv, color);
}