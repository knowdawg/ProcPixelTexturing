#[compute]
#version 450

// Invocations
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D sourceImage1;
layout(set = 0, binding = 1, rgba8) uniform readonly image2D sourceImage2; //Dynamic Image
layout(set = 0, binding = 2, rgba32f) uniform writeonly image2D outputImage;

layout(set = 0, binding = 3, std430) readonly buffer Params {
    int camPosX;
    int camPosY;
};

void main(){
    ivec2 size = imageSize(sourceImage2);
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

    vec4 sum = imageLoad(sourceImage1, uv);
    sum += imageLoad(sourceImage2, (uv - ivec2(camPosX, camPosY)) % size);

    imageStore(outputImage, uv, sum);
}