#[compute]
#version 450

// Invocations
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;


layout(set = 0, binding = 0, std430) readonly buffer ChunkData {
    int chunkCoordX;
    int chunkCoordY;
    int chunkSize;
    int outlineBufferSize;
}
chunkData;

layout(set = 0, binding = 1, rgba32f) uniform readonly image2D TileImage;

layout(set = 0, binding = 2, rgba32f) uniform writeonly image2D OutputBuffer;


int getPixelType(ivec2 uv, float tileTexVal){
	float center = tileTexVal;

	float left = imageLoad(TileImage, uv + ivec2(-1, 0)).r;
	float right = imageLoad(TileImage, uv + ivec2(1, 0)).r;
	float up = imageLoad(TileImage, uv + ivec2(0, -1)).r;
	float down = imageLoad(TileImage, uv + ivec2(0, 1)).r;
	
	bool hasNonPopulatedNieghbor = left * right * up * down == 0.0;
	bool hasPopulatedNieghbor = left + right + up + down > 0.0;
	bool isCenterPopulated = center != 0.0;
	
	if(!hasNonPopulatedNieghbor && isCenterPopulated){return 3;} //Center
	if(hasNonPopulatedNieghbor && isCenterPopulated){return 2;} //Border
	if(hasPopulatedNieghbor && !isCenterPopulated){return 1;} //Outline
	if(!isCenterPopulated){return 0;} //Nothing
	
	
	return 0;
}


vec2 getNearestEdgeAngle(ivec2 uv, int radiusSize, inout float dis) {
	// Search in expanding rings around center
	for (int radius = 0; radius <= radiusSize; radius++) {
		for (int x = -radius; x <= radius; x++) {
			for (int y = -radius; y <= radius; y++) {
				// Only check the outer ring at each radius
				if (abs(x) == radius || abs(y) == radius) {
					ivec2 offset = ivec2(x, y);
					ivec2 sampleUV = uv + ivec2(offset);
					float sampleValue = imageLoad(TileImage, sampleUV).r;
					
					if (sampleValue < 0.01) { //This will suport about 100 difrent tiles
						dis = length(vec2(offset)) / float(radiusSize);
						return normalize(vec2(offset));
					}
				}
			}
		}
	}
	dis = 1.0;
	return vec2(0.0);
}


void main() {
    float TAU = 6.28318;

    ivec2 outputSize = imageSize(OutputBuffer);

    ivec2 UV = ivec2(gl_GlobalInvocationID.xy);
    ivec2 TILE_IMAGE_UV = UV + ivec2(chunkData.outlineBufferSize);
	float tileTexVal = imageLoad(TileImage, TILE_IMAGE_UV).r;
	
	int pixelType = getPixelType(TILE_IMAGE_UV, tileTexVal);
	
	float disToEdge;
	vec2 vecToEdge = getNearestEdgeAngle(TILE_IMAGE_UV, 5, disToEdge);
	float angleToEdge = atan(vecToEdge.y / vecToEdge.x) / TAU;
	angleToEdge += 0.5; //now in 0-1 range
	angleToEdge *= 0.5;//range: 0-0.5
	if(vecToEdge.x < 0.0){
		angleToEdge += 0.5;//range: 0.5-1
	}
	
	vec4 COLOR = vec4(0.0);
	COLOR.r = tileTexVal;
	COLOR.g = float(pixelType) / 3.0;
	COLOR.b = angleToEdge;
	COLOR.a = (disToEdge * 0.5) + 0.5;

    ivec2 chunkOffsetUV = ivec2(chunkData.chunkCoordX, chunkData.chunkCoordY) * chunkData.chunkSize;
    chunkOffsetUV += UV;

    if(chunkOffsetUV.x < outputSize.x && chunkOffsetUV.y < outputSize.y){
        imageStore(OutputBuffer, chunkOffsetUV, COLOR);
    }
}