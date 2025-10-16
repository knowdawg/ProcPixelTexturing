shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec2 texSize;
uniform sampler2D tileArrayTex : filter_nearest;

vec4 sampleTileTex(vec2 uv, vec2 uvRatio){
	vec2 centerUV = uv + vec2((uvRatio - 1.0) / 2.0);
	return texture(tileArrayTex, centerUV / uvRatio);
}

int getPixelType(vec2 uv, vec2 stepAmount, vec2 uvRatio){
	vec4 center = sampleTileTex(uv, uvRatio);
	
	vec4 left = sampleTileTex(uv + vec2(-stepAmount.x * 1.0, 0.0), uvRatio);
	vec4 right = sampleTileTex(uv + vec2(stepAmount.x * 1.0, 0.0), uvRatio);
	vec4 up = sampleTileTex(uv + vec2(0.0, -stepAmount.y * 1.0), uvRatio);
	vec4 down = sampleTileTex(uv + vec2(0.0, stepAmount.y * 1.0), uvRatio);
	
	bool hasNonPopulatedNieghbor = left.r * right.r * up.r * down.r == 0.0;
	bool hasPopulatedNieghbor = left.r + right.r + up.r + down.r > 0.0;
	bool isCenterPopulated = center.r != 0.0;
	
	if(!hasNonPopulatedNieghbor && isCenterPopulated){return 3;} //Center
	if(hasNonPopulatedNieghbor && isCenterPopulated){return 2;} //Border
	if(hasPopulatedNieghbor && !isCenterPopulated){return 1;} //Outline
	if(!isCenterPopulated){return 0;} //Nothing
	
	
	return 0;
}

vec2 getNearestEdgeAngle(vec2 uv, vec2 stepAmount, vec2 uvRatio, int radiusSize, inout float dis) {
	// Search in expanding rings around center
	for (int radius = 0; radius <= radiusSize; radius++) {
		for (int x = -radius; x <= radius; x++) {
			for (int y = -radius; y <= radius; y++) {
				// Only check the outer ring at each radius
				if (abs(x) == radius || abs(y) == radius) {
					ivec2 offset = ivec2(x, y);
					vec2 sample_uv = uv + vec2(offset) * stepAmount;
					float sample_value = sampleTileTex(sample_uv, uvRatio).r;
					
					if (sample_value < 0.01) { //This will suport about 100 difrent tiles
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


void fragment() {
	vec2 texPixelSize = 1.0 / texSize;
	vec2 UVRatio = SCREEN_PIXEL_SIZE / texPixelSize;
	vec4 tileTex = sampleTileTex(UV, UVRatio);
	
	int pixelType = getPixelType(UV, SCREEN_PIXEL_SIZE, UVRatio);
	
	float disToEdge;
	vec2 vecToEdge = getNearestEdgeAngle(UV, SCREEN_PIXEL_SIZE, UVRatio, 5, disToEdge);
	float angleToEdge = atan(vecToEdge.y / vecToEdge.x) / (2.0 * PI);
	angleToEdge += 1.0;
	angleToEdge *= 0.5;
	
	//COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	COLOR.r = sampleTileTex(UV, UVRatio).r;
	COLOR.g = float(pixelType) / 3.0;
	COLOR.b = angleToEdge;
	COLOR.a = (disToEdge * 0.5) + 0.5;
}
