shader_type canvas_item;

varying vec2 screenSize;

uniform vec2 RESOLUTION;
global uniform vec2 WORLD_POSITION;
global uniform sampler2D TILE_ARRAY_TEXTURE_BACKGROUND : filter_nearest, repeat_disable;
global uniform sampler2D SDF_LIGHT_TEXTURE : filter_nearest;

group_uniforms dirt;
uniform sampler2D DIRT_TEX : filter_nearest, repeat_enable;
uniform sampler2D DIRT_NORMAL : filter_nearest, repeat_enable;
uniform sampler2D DIRT_GRAD;
uniform vec4 DIRT_BORDER_COLOR : source_color;

group_uniforms stone;
uniform sampler2D STONE_TEX : filter_nearest, repeat_enable;
uniform sampler2D STONE_NORMAL : filter_nearest, repeat_enable;
uniform sampler2D STONE_GRAD;
uniform vec4 STONE_BORDER_COLOR : source_color;

group_uniforms grass;
uniform sampler2D GRASS_TEX : filter_nearest, repeat_enable;
uniform sampler2D GRASS_NORMAL : filter_nearest, repeat_enable;
uniform sampler2D GRASS_GRAD;
uniform vec4 GRASS_BORDER_COLOR : source_color;

group_uniforms wood;
uniform sampler2D WOOD_TEX : filter_nearest, repeat_enable;
uniform sampler2D WOOD_NORMAL : filter_nearest, repeat_enable;
uniform sampler2D WOOD_GRAD;
uniform vec4 WOOD_BORDER_COLOR : source_color;

group_uniforms lighting;
uniform float falloff : hint_range(0.0, 0.1) = 0.03;

int getPixelType(sampler2D tex, vec2 uv, vec2 stepAmount){
	vec4 center = texture(TILE_ARRAY_TEXTURE_BACKGROUND, uv);
	
	vec4 left = texture(TILE_ARRAY_TEXTURE_BACKGROUND, uv + vec2(-stepAmount.x * 1.0, 0.0));
	vec4 right = texture(TILE_ARRAY_TEXTURE_BACKGROUND, uv + vec2(stepAmount.x * 1.0, 0.0));
	vec4 up = texture(TILE_ARRAY_TEXTURE_BACKGROUND, uv + vec2(0.0, -stepAmount.y * 1.0));
	vec4 down = texture(TILE_ARRAY_TEXTURE_BACKGROUND, uv + vec2(0.0, stepAmount.y * 1.0));
	
	bool hasNonPopulatedNieghbor = left.r * right.r * up.r * down.r == 0.0;
	bool hasPopulatedNieghbor = left.r + right.r + up.r + down.r > 0.0;
	bool isCenterPopulated = center.r != 0.0;
	
	if(!hasNonPopulatedNieghbor && isCenterPopulated){return 3;}
	if(hasNonPopulatedNieghbor && isCenterPopulated){return 2;}
	if(hasPopulatedNieghbor && !isCenterPopulated){return 1;}
	if(!isCenterPopulated){return 0;}
	
	
	return 0;
}

vec4 getColor(int type, vec2 uv, sampler2D tex, sampler2D normalMap, sampler2D grad, vec4 border, inout vec3 normal){
	vec4 c = vec4(1.0);
	vec2 offsetUV = uv + vec2(floor(WORLD_POSITION) / RESOLUTION);
	switch(type){
		case 0:
			c.a = 0.0;
			break;
		case 1:
			c = vec4(0.0, 0.0, 0.0, 1.0);
			break;
		case 2:
			c = border;
			normal = texture(normalMap, offsetUV * (RESOLUTION / vec2(256.0, 256.0))).rgb;
			break;
		case 3:
			vec4 tVal = texture(tex, offsetUV * (RESOLUTION / vec2(256.0, 256.0)));
			normal = texture(normalMap, offsetUV * (RESOLUTION / vec2(256.0, 256.0))).rgb;
			c = texture(grad, vec2(tVal.r, 0.0));
			break;
		default:
			c.a = 0.0;
			break;
	}
	
	
	return c;
}

void fragment() {
	vec2 qUV = UV;//floor(UV * RESOLUTION) / RESOLUTION;
	
	vec4 self = texture(TILE_ARRAY_TEXTURE_BACKGROUND, qUV);
	int type = getPixelType(TILE_ARRAY_TEXTURE_BACKGROUND, qUV, 1.0 / RESOLUTION);
	
	float sdfVal = texture_sdf(screen_uv_to_sdf(SCREEN_UV));
	sdfVal = abs(sdfVal);
	sdfVal /= 10.0;
	sdfVal *= 0.5;
	sdfVal = clamp(sdfVal, 0.0, 1.0);
	sdfVal = 1.0 - sdfVal;
	
	
	vec4 c = vec4(1.0);
	if(self.r < 0.05){
		c.a = 0.0;
	}else if(self.r < 0.15){
		c = getColor(type, qUV, STONE_TEX, STONE_NORMAL, STONE_GRAD, STONE_BORDER_COLOR, NORMAL_MAP);
	}else if(self.r < 0.25){
		c = getColor(type, qUV, GRASS_TEX, GRASS_NORMAL, GRASS_GRAD, GRASS_BORDER_COLOR, NORMAL_MAP);
	}else if(self.r < 0.35){
		c = getColor(type, qUV, DIRT_TEX, DIRT_NORMAL, DIRT_GRAD, DIRT_BORDER_COLOR, NORMAL_MAP);
	}else if(self.r < 0.45){
		c = getColor(type, qUV, WOOD_TEX, WOOD_NORMAL, WOOD_GRAD, WOOD_BORDER_COLOR, NORMAL_MAP);
	}
	
	if(type == 1){
		c = vec4(0.0, 0.0, 0.0, 1.0);
	}
	
	COLOR = c;
	
	screenSize = SCREEN_PIXEL_SIZE;
	
	//vec4 backgroundVal = textureLod(TILE_ARRAY_TEXTURE_BACKGROUND, UV, 2.0);
	//COLOR = backgroundVal;
}

//Called for each light for each pixel
void light() {
	//Setup the variables for SDF Raymarching
	vec2 lightPosNormalized = LIGHT_POSITION.xy * screenSize;
	vec2 angleVector = normalize(lightPosNormalized - SCREEN_UV);
	float sdfVal = 0.0;
	float finished = 0.0;
	float distanceNeededToTravel = length(lightPosNormalized - SCREEN_UV);
	float disTraveled = 0.0;
	float intensity = 1.0;
	
	float closestSdfVal = 1.0;
		
		
	if(LIGHT_IS_DIRECTIONAL){
		angleVector = LIGHT_DIRECTION.xy;
		for(int i = 0; i < 40; i++){
			vec2 curPos = SCREEN_UV + (angleVector * disTraveled);
			sdfVal = texture_sdf(screen_uv_to_sdf(curPos)) * screenSize.x;
			float lightSdf = texture(SDF_LIGHT_TEXTURE, curPos).r;
			float combinedSDF = min(sdfVal, lightSdf);
			
			disTraveled += abs(combinedSDF);
			if(combinedSDF <= 0.0){
				intensity -= abs(combinedSDF) * 30.0;//If sdfVal in negative, it is subtracted. If it is positive, nothing happens because of the min function
			
			}
			//disTraveled += lightSdf;
			
			float moveAmount = length(screenSize * angleVector) * 1.0;
			disTraveled += moveAmount;//Bump the distance traveled to speed up the algorithm and to prevent the raymarching from moving zero every loop.
			if(combinedSDF <= 0.0){
				intensity -= moveAmount;
			}
			
			
			if(lightSdf < 0.01){
				//finished = 1.0;
				break;
			}
			if(intensity <= 0.0){
				//finished = 0.0;
				break;
			}
			if(i == 39){
				intensity = 0.0;
				break;
			}
		}
		finished = 1.0;
		float lightVal = texture(SDF_LIGHT_TEXTURE, SCREEN_UV).r;
		lightVal = 1.0 - smoothstep(0.0, 0.25, lightVal);
		lightVal *= 0.5;
		intensity = max(intensity * 1.0, lightVal);
		
	}else{
		for(int i = 0; i < 40; i++){
			if(distanceNeededToTravel > 0.5){
				finished = 0.0;
				break;
			}
			
			vec2 curPos = SCREEN_UV + (angleVector * disTraveled);
			sdfVal = texture_sdf(screen_uv_to_sdf(curPos));
			disTraveled += screenSize.x * abs(sdfVal);
			
			closestSdfVal = min(sdfVal, closestSdfVal);
			
			if(sdfVal <= 0.0){
				finished = 0.0;
				break;
			}
			if(disTraveled > distanceNeededToTravel){
				finished = closestSdfVal;//10.0 / (float(i));
				break;
			}
			//if(i == 10){
				//finished = 1.0 - (disTraveled / distanceNeededToTravel);
				//break;
			//}
		}
		
	}
	
	
	finished = clamp(finished, 0.0, 1.0);
	
	vec3 finalCol = COLOR.rgb * LIGHT_COLOR.rgb * LIGHT_ENERGY;
	float cNdotL = max(0.0, dot(NORMAL, LIGHT_DIRECTION));
	LIGHT = vec4(((finalCol * finished * cNdotL * 0.8) + finalCol * 0.2) * intensity, LIGHT_COLOR.a);
}