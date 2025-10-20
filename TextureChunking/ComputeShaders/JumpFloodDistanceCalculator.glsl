#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D bitmap;

layout(set = 0, binding = 1, rgba32f) uniform readonly image2D inputBuffer;

layout(set = 0, binding = 2, rgba32f) uniform writeonly image2D outputBuffer;

layout(set = 0, binding = 3, std430) readonly buffer OffsetData {
    int bitmapOffsetX;
    int bitmapOffsetY;

    int sined;
};

layout(set = 0, binding = 4, std430) readonly buffer Threshold {
    float threshold;
};

void main(){
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy); //big
    ivec2 size = imageSize(inputBuffer);
    if(uv.x >= size.x || uv.y >= size.y){
        return;
    }


    vec2 UV = vec2(uv) / size; //small
    ivec2 bitmapUV = uv + ivec2(bitmapOffsetX, bitmapOffsetY) + (size / 2);
    bitmapUV = ivec2(
        (bitmapUV.x % size.x + size.x) % size.x,
        (bitmapUV.y % size.y + size.y) % size.y
    );

    //Check if safe here
    if(bitmapUV.x < 0 || bitmapUV.y < 0 || bitmapUV.x > size.x - 1 || bitmapUV.y > size.y - 1){
        return;
    }

	vec2 offsetUV = imageLoad(inputBuffer, uv).xy; //small

	float SDFVal = distance(UV, offsetUV); //distance between small and small
    SDFVal = clamp(SDFVal, 0.0, 1.0);

	
	vec4 color = vec4(SDFVal, 0.0, 0.0, 1.0);
    float bitmapVal = ceil(imageLoad(bitmap, bitmapUV).r - threshold);
    bitmapVal = clamp(bitmapVal, 0.0, 1.0);

    if(bitmapVal > 0.5 && sined == 1){
        color.g = 1.0;
    }
    imageStore(outputBuffer, uv, color);
}