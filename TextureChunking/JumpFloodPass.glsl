#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;


layout(set = 0, binding = 0, std430) readonly buffer Data {
    int offset;
};

layout(set = 0, binding = 1, rgba32f) uniform readonly image2D inputBuffer;

layout(set = 0, binding = 2, rgba32f) uniform writeonly image2D outputBuffer;


void main(){
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    float closestDist = 9999999.9;
    vec2 closestPos = vec2(0.0);
    ivec2 texSize = imageSize(outputBuffer);

    for(float x = -1.0; x <= 1.0; x += 1.0){
        for(float y = -1.0; y <= 1.0; y += 1.0){
            ivec2 voffset = uv;
            voffset += ivec2(x, y) * offset;

            if (voffset.x < 0 || voffset.x > texSize.x - 1) {
                continue;
            }
            if (voffset.y < 0 || voffset.y > texSize.y - 1) {
                continue;
            }
            vec2 pos = imageLoad(inputBuffer, voffset).xy * float(texSize);
            float dist = distance(pos.xy, vec2(uv));

            if(pos.x != 0.0 && pos.y != 0.0 && dist < closestDist){
                closestDist = dist;
                closestPos = pos / float(texSize);
            }
        }
    }

    vec4 color = vec4(closestPos, 0.0, 1.0);
    imageStore(outputBuffer, uv, color);
   
}