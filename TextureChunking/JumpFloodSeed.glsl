#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D bitmap;

layout(set = 0, binding = 1, rgba32f) uniform writeonly image2D outputBuffer;


bool isBorder(ivec2 uv){
    float center = ceil(imageLoad(bitmap, uv).r);

	float left = ceil(imageLoad(bitmap, uv + ivec2(-1, 0)).r);
	float right = ceil(imageLoad(bitmap, uv + ivec2(1, 0)).r);
	float up = ceil(imageLoad(bitmap, uv + ivec2(0, -1)).r);
	float down = ceil(imageLoad(bitmap, uv + ivec2(0, 1)).r);

    

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