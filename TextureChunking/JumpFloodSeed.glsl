#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D bitmap;

layout(set = 0, binding = 1, rgba32f) uniform writeonly image2D outputBuffer;

layout(set = 0, binding = 2, std430) readonly buffer OffsetData {
    int bitmapOffsetX;
    int bitmapOffsetY;

    int sined;
    int inverted;
};


float sampleBitmap(ivec2 uv){
    ivec2 size = imageSize(bitmap);
    ivec2 bitmapUV = uv + ivec2(bitmapOffsetX, bitmapOffsetY) + (size / 2);
    bitmapUV = bitmapUV % ivec2(size);
    float val = ceil(imageLoad(bitmap, bitmapUV).r);

    if(inverted == 1){
        val = 1.0 - val;
    }

    return val;
}

bool isBorder(ivec2 uv){
    float center = sampleBitmap(uv);

	float left = sampleBitmap(uv + ivec2(-1, 0));//ceil(imageLoad(bitmap, uv + ivec2(-1, 0)).r);
	float right = sampleBitmap(uv + ivec2(1, 0));//ceil(imageLoad(bitmap, uv + ivec2(1, 0)).r);
	float up = sampleBitmap(uv + ivec2(0, -1));//ceil(imageLoad(bitmap, uv + ivec2(0, -1)).r);
	float down = sampleBitmap(uv + ivec2(0, 1));//ceil(imageLoad(bitmap, uv + ivec2(0, 1)).r);

    
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
    if(sined == 1){
        if(isBorder(uv)){
            color.rg = UV;
        }
    }else{
        if(sampleBitmap(uv) > 0.5){
            color.rg = UV;
        }
    }

    imageStore(outputBuffer, uv, color);
}