#[compute]
#version 450

// Invocations
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;


//Set 0: Constant Textures
layout(set = 0, binding = 0) uniform sampler2DArray tex2dArrayForeground;
layout(set = 0, binding = 1) uniform sampler2DArray normal2dArrayForeground;
layout(set = 0, binding = 2) uniform sampler2DArray gradient2dArrayForeground;
layout(set = 0, binding = 3) uniform sampler2DArray borderGradient2dArrayForeground;
layout(set = 0, binding = 4) uniform sampler2D borderColorsForeground;
layout(set = 0, binding = 5) uniform sampler2D emissionColorsForeground;

layout(set = 0, binding = 6) uniform sampler2DArray tex2dArrayBackground;
layout(set = 0, binding = 7) uniform sampler2DArray normal2dArrayBackground;
layout(set = 0, binding = 8) uniform sampler2DArray gradient2dArrayBackground;
layout(set = 0, binding = 9) uniform sampler2DArray borderGradient2dArrayBackground;
layout(set = 0, binding = 10) uniform sampler2D borderColorsBackground;
layout(set = 0, binding = 11) uniform sampler2D emissionColorsBackground;

//Set 1: Constant Storage Buffers
layout(set = 1, binding = 0, std430) readonly buffer BorderParamsForeground { vec2 borderParamsForeground[]; };
layout(set = 1, binding = 1, std430) readonly buffer BorderParamsBackground { vec2 borderParamsBackground[]; }; //Curently Does Nothing, The shader curently only used the foreground border params. Need to change this
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


int getDistanceToNearestEdge(ivec2 uv, int radiusSize, bool foreground, out vec2 dir, out float density) {
	int returnRadius = radiusSize + 1;
	vec2 dirSum = vec2(0.0);
	int numOfDirAdds = 0;
	int tileArea = 0;
	// Search in expanding rings around center
	for (int radius = 0; radius <= radiusSize; radius++){
		for (int x = -radius; x <= radius; x++){
			for (int y = -radius; y <= radius; y++){
				// Only check the outer ring at each radius
				if (abs(x) == radius || abs(y) == radius){
					tileArea++;

					ivec2 offset = ivec2(x, y);
					ivec2 sampleUV = uv + ivec2(offset);
					float sampleValue;
					if(foreground){
						sampleValue = imageLoad(TileImage, sampleUV).r;
					}else{
						sampleValue = imageLoad(TileImage, sampleUV).g;
					}
					
					if (sampleValue > 0.0) {
						continue;
					}

					dirSum += normalize(vec2(offset));
					numOfDirAdds += 1;
					if(radius < returnRadius){
						returnRadius = radius;
					}
				}
			}
		}
	}
	dir = dirSum / float(max(numOfDirAdds, 1)); //Do not normalize, does not need to be
	density = float(numOfDirAdds) / float(tileArea);
	density = 1.0 - smoothstep(0.0, 0.65, density);
	return returnRadius;
}


vec4 getNormal(ivec2 uv, float self, in sampler2DArray normalTextures){
	//UV stuff
	vec2 normalizedUV = fract(vec2(uv) / 256.0); //from 0-1
	int tileIndex = getTileIndex(self);
	vec3 arrayUV = vec3(normalizedUV, tileIndex);

	vec4 n = texture(normalTextures, arrayUV);

	return n;
}

vec4 modifyNormalBasedOnEdgeDirection(vec4 normal, int disToEdge, float maxDisToEdge, vec2 dirToEdge, float disToEdgeRatio, float density){
	vec4 newNormal = normal;
	if(disToEdge <= int(maxDisToEdge.x)){ //if you are near a border
		newNormal.rgb = mix(vec3(dirToEdge.x * 0.5 + 0.5, -dirToEdge.y * 0.5 + 0.5, normal.b), normal.rgb, clamp(disToEdgeRatio - 0.25, 0.0, 1.0));
		newNormal.rgb = mix(vec3(0.5, 0.5, newNormal.b), newNormal.rgb, density);
	}
	return newNormal;
}

void calculateColorAndNormal(out vec4 color, out vec4 normal, int type, ivec2 uv, ivec2 tileUV, float self, in sampler2DArray textures, in sampler2DArray gradients, in sampler2DArray borderGradients, in sampler2D borders, in sampler2DArray normalTextures, bool foreground){
	vec4 c = vec4(1.0);
	vec4 n = getNormal(uv, self, normalTextures);

	//UV stuff
	vec2 normalizedUV = fract(vec2(uv) / 256.0); //from 0-1
	int tileIndex = getTileIndex(self);
	vec3 arrayUV = vec3(normalizedUV, tileIndex);
	
	//Edge Information
	vec2 dirToEdge = vec2(0.0);
	float density = 0.0;
	vec2 borderParams = borderParamsForeground[tileIndex]; //x is max distance, y is border wieght
	int disToEdge = getDistanceToNearestEdge(tileUV, int(borderParams.x), foreground, dirToEdge, density);
	float distanceToEdgeRatio = clamp(float(disToEdge) / borderParams.x, 0.0, 1.0);

	//quantize dirToEdge to 8 Directions
	float a = atan(dirToEdge.y, dirToEdge.x);
	float qSize = 2.0 * 3.1415926535 / 8.0;
	a = floor(a / qSize + 0.5) * qSize;
	dirToEdge = vec2(cos(a), sin(a));

	//sampling
	vec4 tVal = texture(textures, arrayUV);
	
	switch(type){
		case 0:
			c.a = 0.0;
			break;
		case 1:
			c = vec4(0.0, 0.0, 0.0, 1.0);
			n = vec4(0.5, 0.5, 1.0, 1.0);
			break;
		case 2:
			vec4 border = texture(borders, vec2(self, 0.0));
			c = border;
			n = modifyNormalBasedOnEdgeDirection(n, disToEdge, borderParams.x, dirToEdge, distanceToEdgeRatio, density);
			break;
		case 3:
			n = modifyNormalBasedOnEdgeDirection(n, disToEdge, borderParams.x, dirToEdge, distanceToEdgeRatio, density);

			//If I am close to the edge, use the border gradients
			tVal.r = clamp(tVal.r, 0.0, 0.99);
			c = texture(gradients, vec3(vec2(tVal.r), tileIndex));

			float borderThreshold = mix(tVal.r - 0.5, 1.0 - float(disToEdge) / borderParams.x, borderParams.y);
			if(borderThreshold > 0.0 && disToEdge <= int(borderParams.x)){
				c = texture(borderGradients, vec3(vec2(tVal.r), tileIndex));
			}

			break;
		default:
			c.a = 0.0;
			break;
	}
	
	color = c;
	normal = n;
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
		pixelType.x = 1; //Black Border Pixel
	}else if(!centerSolid){
		pixelType.x = 0; //Empty Pixel
	}else if(centerSolid && hasMissingNieghbor){
		pixelType.x = 2; //Border Pixel
	}else if(centerSolid && !hasMissingNieghbor){
		bool leftSame = getTileIndex(left.r) == getTileIndex(center.r);
		bool rightSame = getTileIndex(right.r) == getTileIndex(center.r);
		bool upSame = getTileIndex(up.r) == getTileIndex(center.r);
		bool downSame = getTileIndex(down.r) == getTileIndex(center.r);

		//maybye only draw the borders if the border colors are difrent enough??
		//mabye if there is a difrent tile new to me I get the border weight instead of being a border tile??
		//Perhpas I can have blend groups and if two materials share a blend group they will blend together.
		if(leftSame && rightSame && upSame && downSame){
			pixelType.x = 3;
		}else{
			pixelType.x = 2;
		}
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
		bool leftSame = getTileIndex(left.g) == getTileIndex(center.g);
		bool rightSame = getTileIndex(right.g) == getTileIndex(center.g);
		bool upSame = getTileIndex(up.g) == getTileIndex(center.g);
		bool downSame = getTileIndex(down.g) == getTileIndex(center.g);

		//maybye only draw the borders if the border colors are difrent enough??
		//mabye if there is a difrent tile new to me I get the border weight instead of being a border tile??
		if(leftSame && rightSame && upSame && downSame){
			pixelType.y = 3;
		}else{
			pixelType.y = 2;
		}
		pixelType.y = 3;
	}
	
	
	return pixelType;
}


//This only runs equal to the size of the chunk. That way, lots of terrain information can be passed into this shader and it will only calcuate the pixels for the desired chunk... as long as TILE_IMAGE_UV and chunkOffsetUV is calculated corectly
void main() {
    ivec2 UV = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(OutputBufferForeground);

	if(UV.x < 0 || UV.y < 0 || UV.x > size.x - 1 || UV.y > size.y - 1){ //If you leave the screen, you failed
		return;
	}

    float TAU = 6.28318;
	//Alternate UV
    ivec2 TILE_IMAGE_UV = UV + ivec2(chunkData.outlineBufferSize); //Start at the actual chunk
    ivec2 chunkOffsetUV = (ivec2(chunkData.chunkCoordX, chunkData.chunkCoordY) * chunkData.chunkSize) + UV;

	vec4 tileData = imageLoad(TileImage, TILE_IMAGE_UV);
	
	ivec2 pixelType = getPixelType(TILE_IMAGE_UV, tileData.rg);
	
	vec4 foregroundColor;
	vec4 backgroundColor;
	vec4 foregroundNormal;
	vec4 backgroundNormal;
	calculateColorAndNormal(foregroundColor, foregroundNormal, pixelType.x, chunkOffsetUV, TILE_IMAGE_UV, tileData.r, tex2dArrayForeground, gradient2dArrayForeground, borderGradient2dArrayForeground, borderColorsForeground, normal2dArrayForeground, true); //foreground
	calculateColorAndNormal(backgroundColor, backgroundNormal, pixelType.y, chunkOffsetUV, TILE_IMAGE_UV, tileData.g, tex2dArrayBackground, gradient2dArrayBackground, borderGradient2dArrayBackground, borderColorsBackground, normal2dArrayBackground, false); //background

	vec4 emissionColor = vec4(0.0);
	emissionColor += texture(emissionColorsForeground, vec2(tileData.r, 0.0)); // foreground light
	emissionColor += texture(emissionColorsBackground, vec2(tileData.g, 0.0)) * (1.0 - emissionColor.a); //background light
	if(solids[getTileIndex(tileData.r)] == 0 && solids[getTileIndex(tileData.g)] == 0){
		emissionColor = vec4(1.0, 1.0, 1.0, 0.0);//sunlight
	}
	emissionColor = max(emissionColor, vec4(0.0));

	//wrap the texture on itself
    chunkOffsetUV = chunkOffsetUV % size;
	imageStore(LightMap, chunkOffsetUV, emissionColor);

    imageStore(OutputBufferForeground, chunkOffsetUV, foregroundColor);
	imageStore(OutputBufferBackground, chunkOffsetUV, backgroundColor);

	imageStore(OutputBufferForegroundNormal, chunkOffsetUV, foregroundNormal);
	imageStore(OutputBufferBackgroundNormal, chunkOffsetUV, backgroundNormal);
}