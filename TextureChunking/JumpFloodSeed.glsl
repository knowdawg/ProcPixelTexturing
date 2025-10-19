#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D bitmap;

layout(set = 0, binding = 1, rgba32f) uniform writeonly image2D outputBuffer;

layout(set = 0, binding = 2, std430) readonly buffer OffsetData {
    int bitmapOffsetX;
    int bitmapOffsetY;
};


bool isBorder(ivec2 uv){
    ivec2 size = imageSize(bitmap);
    ivec2 bitmapUV = uv + ivec2(bitmapOffsetX, bitmapOffsetY) + (size / 2);
    bitmapUV = bitmapUV % ivec2(size);

    float center = ceil(imageLoad(bitmap, bitmapUV).r);

	float left = ceil(imageLoad(bitmap, bitmapUV + ivec2(-1, 0)).r);
	float right = ceil(imageLoad(bitmap, bitmapUV + ivec2(1, 0)).r);
	float up = ceil(imageLoad(bitmap, bitmapUV + ivec2(0, -1)).r);
	float down = ceil(imageLoad(bitmap, bitmapUV + ivec2(0, 1)).r);

    

    if(center > 0.5 && left * right * up * down < 0.5){
        return true;
    }
    return false;
}

void main(){
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(bitmap);
    vec2 UV = vec2(uv) / vec2(size);

    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
    if(isBorder(uv)){
        color.rg = UV;
    }

    imageStore(outputBuffer, uv, color);
}