#[compute]
#version 450

// Invocations
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;


//Set 0: Constant Textures
layout(set = 0, binding = 0) uniform sampler2DArray tex2dArrayForeground;
layout(set = 0, binding = 1) uniform sampler2DArray normal2dArrayForeground;
layout(set = 0, binding = 2) uniform sampler2DArray gradient2dArrayForeground;
layout(set = 0, binding = 3) uniform sampler2D borderColorsForeground;
layout(set = 0, binding = 4) uniform sampler2D emissionColorsForeground;

layout(set = 0, binding = 5) uniform sampler2DArray tex2dArrayBackground;
layout(set = 0, binding = 6) uniform sampler2DArray normal2dArrayBackground;
layout(set = 0, binding = 7) uniform sampler2DArray gradient2dArrayBackground;
layout(set = 0, binding = 8) uniform sampler2D borderColorsBackground;
layout(set = 0, binding = 9) uniform sampler2D emissionColorsBackground;

//Set 1: Constant Storage Buffers
layout(set = 1, binding = 0, std430) readonly buffer BorderParamsForeground { vec2 borderParamsForeground[]; };
layout(set = 1, binding = 1, std430) readonly buffer BorderParamsBackground { vec2 borderParamsBackground[]; };
layout(set = 1, binding = 2, std430) readonly buffer SolidBuffer { uint solids[]; }; //Only for foreground. Background will assume the same solidity as thier foreground counterpart

//Set 2: Variable Uniforms
layout(set = 2, binding = 0, std430) readonly buffer ChunkData {
    int chunkCoordX;
    int chunkCoordY;
    int chunkSize;
    int outlineBufferSize;
}
chunkData;
layout(set = 2, binding = 1, rgba8) uniform readonly image2D TileImage;
layout(set = 2, binding = 2, rgba8) uniform writeonly image2D OutputBufferForeground;
layout(set = 2, binding = 3, rgba8) uniform writeonly image2D OutputBufferBackground;
layout(set = 2, binding = 4, rgba32f) uniform writeonly image2D LightMap;
layout(set = 2, binding = 5, rgba8) uniform writeonly image2D OutputBufferForegroundNormal;
layout(set = 2, binding = 6, rgba8) uniform writeonly image2D OutputBufferBackgroundNormal;



int getTileIndex(float floatIndex){
	return int((floatIndex * 255.0) + 0.5);
}

vec4 getColor(int type, ivec2 uv, float self, in sampler2DArray textures, in sampler2DArray gradients, in sampler2D borders){
	vec4 c = vec4(1.0);

	//UV stuff
	vec2 normalizedUV = fract(vec2(uv) / 256.0); //from 0-1
	int tileIndex = getTileIndex(self);
	vec3 arrayUV = vec3(normalizedUV, tileIndex);
	
	//sampling
	vec4 tVal = texture(textures, arrayUV);
	
	switch(type){
		case 0:
			c.a = 0.0;
			break;
		case 1:
			c = vec4(0.0, 0.0, 0.0, 1.0);
			break;
		case 2:
			vec4 border = texture(borders, vec2(self, 0.0));
			c = border;
			break;
		case 3:
			//tVal.r = (tVal.r * 0.75) + (1.0 - step((0.5 + tVal.r) * (5.0 / PS_RENDER_QUADRANT_SIZE.x), disToEdge)) * 0.25;
			c = texture(gradients, vec3(vec2(tVal.r), tileIndex));
			break;
		default:
			c.a = 0.0;
			break;
	}
	
	return c;
}

vec4 getNormal(ivec2 uv, float self, in sampler2DArray normalTextures){
	//UV stuff
	vec2 normalizedUV = fract(vec2(uv) / 256.0); //from 0-1
	int tileIndex = getTileIndex(self);
	vec3 arrayUV = vec3(normalizedUV, tileIndex);

	vec4 n = texture(normalTextures, arrayUV);

	return n;
}

//returns a ivec2 where the x value is the pixel type for the forground and y value is the pixel type for the background
//0 means that you a blank space / empty. No color will be writen to the output
//1 means you are an outline. Black will be written to the output
//2 means you are a border. The coresponding border color will be writen to the output
//3 means you are a center. The coresponding texture value for your uv will be written to the output
ivec2 getPixelType(ivec2 uv, vec2 tileTexVal){
	ivec2 pixelType = ivec2(0, 0);
	vec2 center = tileTexVal;
	//get the tile index of both the foreground and background
	vec2 left = imageLoad(TileImage, uv + ivec2(-1, 0)).rg;
	vec2 right = imageLoad(TileImage, uv + ivec2(1, 0)).rg;
	vec2 up = imageLoad(TileImage, uv + ivec2(0, -1)).rg;
	vec2 down = imageLoad(TileImage, uv + ivec2(0, 1)).rg;

	//Foreground
	bool centerSolid = solids[getTileIndex(center.r)] == 1;
	bool leftSolid = solids[getTileIndex(left.r)] == 1;
	bool rightSolid = solids[getTileIndex(right.r)] == 1;
	bool upSolid = solids[getTileIndex(up.r)] == 1;
	bool downSolid = solids[getTileIndex(down.r)] == 1;

	bool hasSolidNieghbor = leftSolid || rightSolid || upSolid || downSolid;
	bool hasMissingNieghbor = !(leftSolid && rightSolid && upSolid && downSolid);

	if(!centerSolid && hasSolidNieghbor){
		pixelType.x = 1;
	}else if(!centerSolid){
		pixelType.x = 0;
	}else if(centerSolid && hasMissingNieghbor){
		pixelType.x = 2;
	}else if(centerSolid && !hasMissingNieghbor){
		pixelType.x = 3;
	}

	//Background
	centerSolid = solids[getTileIndex(center.g)] == 1;
	leftSolid = solids[getTileIndex(left.g)] == 1;
	rightSolid = solids[getTileIndex(right.g)] == 1;
	upSolid = solids[getTileIndex(up.g)] == 1;
	downSolid = solids[getTileIndex(down.g)] == 1;

	hasSolidNieghbor = leftSolid || rightSolid || upSolid || downSolid;
	hasMissingNieghbor = !(leftSolid && rightSolid && upSolid && downSolid);

	if(!centerSolid && hasSolidNieghbor){
		pixelType.y = 1;
	}else if(!centerSolid){
		pixelType.y = 0;
	}else if(centerSolid && hasMissingNieghbor){
		pixelType.y = 2;
	}else if(centerSolid && !hasMissingNieghbor){
		pixelType.y = 3;
	}
	
	
	return pixelType;
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
    ivec2 UV = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(OutputBufferForeground);

	if(UV.x < 0 || UV.y < 0 || UV.x > size.x - 1 || UV.y > size.y - 1){ //If you leave the screen, you failed
		return;
	}

    float TAU = 6.28318;
	//Alternate UV
    ivec2 TILE_IMAGE_UV = UV + ivec2(chunkData.outlineBufferSize);
    ivec2 chunkOffsetUV = (ivec2(chunkData.chunkCoordX, chunkData.chunkCoordY) * chunkData.chunkSize) + UV;

	vec4 tileData = imageLoad(TileImage, TILE_IMAGE_UV);
	
	ivec2 pixelType = getPixelType(TILE_IMAGE_UV, tileData.rg);
	
	vec4 foregroundColor = getColor(pixelType.x, chunkOffsetUV, tileData.r, tex2dArrayForeground, gradient2dArrayForeground, borderColorsForeground);
	vec4 backgroundColor = getColor(pixelType.y, chunkOffsetUV, tileData.g, tex2dArrayBackground, gradient2dArrayBackground, borderColorsBackground);
	vec4 foregroundNormal = getNormal(chunkOffsetUV, tileData.r, normal2dArrayForeground);
	vec4 backgroundNormal = getNormal(chunkOffsetUV, tileData.g, normal2dArrayBackground);


	vec4 emissionColor = vec4(0.0);
	emissionColor += texture(emissionColorsForeground, vec2(tileData.r, 0.0)); // foreground light
	emissionColor += texture(emissionColorsBackground, vec2(tileData.g, 0.0)) * (1.0 - emissionColor.a); //background light
	if(solids[getTileIndex(tileData.r)] == 0 && solids[getTileIndex(tileData.g)] == 0){
		emissionColor += vec4(1.0) * (1.0 - emissionColor.a); //sunlight
	}
	emissionColor = clamp(emissionColor, vec4(0.0), vec4(1.0));

	//wrap the texture on itself
    chunkOffsetUV = chunkOffsetUV % size;
	imageStore(LightMap, chunkOffsetUV, emissionColor);

    imageStore(OutputBufferForeground, chunkOffsetUV, foregroundColor);
	imageStore(OutputBufferBackground, chunkOffsetUV, backgroundColor);

	imageStore(OutputBufferForegroundNormal, chunkOffsetUV, foregroundNormal);
	imageStore(OutputBufferBackgroundNormal, chunkOffsetUV, backgroundNormal);
}