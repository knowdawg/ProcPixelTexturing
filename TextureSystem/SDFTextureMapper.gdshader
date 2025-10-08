shader_type canvas_item;

uniform vec2 RESOLUTION;
global uniform vec2 WORLD_POSITION;
global uniform sampler2D TILE_ARRAY_TEXTURE : filter_nearest, repeat_disable;

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
uniform float brightness : hint_range(0.0, 1.0);
uniform float falloff : hint_range(0.0, 0.1);

varying vec2 screenSize;
varying vec4 screen;

int getPixelType(sampler2D tex, vec2 uv, vec2 stepAmount){
	vec4 center = texture(TILE_ARRAY_TEXTURE, uv);
	
	vec4 left = texture(TILE_ARRAY_TEXTURE, uv + vec2(-stepAmount.x * 1.0, 0.0));
	vec4 right = texture(TILE_ARRAY_TEXTURE, uv + vec2(stepAmount.x * 1.0, 0.0));
	vec4 up = texture(TILE_ARRAY_TEXTURE, uv + vec2(0.0, -stepAmount.y * 1.0));
	vec4 down = texture(TILE_ARRAY_TEXTURE, uv + vec2(0.0, stepAmount.y * 1.0));
	
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
	
	vec4 self = texture(TILE_ARRAY_TEXTURE, qUV);
	int type = getPixelType(TILE_ARRAY_TEXTURE, qUV, 1.0 / RESOLUTION);
	
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
	
	//COLOR.rgb *= sdfVal;
	
	if(type == 1){
		c = vec4(0.0, 0.0, 0.0, 1.0);
	}
	
	screenSize = SCREEN_PIXEL_SIZE;
	screen = c;
	c.rgb *= brightness;
	
	COLOR = c;
}


void light() {
	//Setup the variables for SDF Raymarching
	vec2 lightPosNormalized = LIGHT_POSITION.xy * screenSize;
	vec2 angleVector = normalize(lightPosNormalized - SCREEN_UV);
	float sdfVal = 0.0;
	float intensity = 1.0;
	float distanceNeededToTravel = length(lightPosNormalized - SCREEN_UV);
	float disTraveled = 0.0;
	//float falloff = 0.01; //0.01

	float finished = 0.0;

	//Marching Algorithm
	for(int i = 0; i < 80; i++){
		if(distanceNeededToTravel > 0.7){
			break;
		}
		if(disTraveled > distanceNeededToTravel){
			finished = 1.0;
			break;
		}
		if(intensity <= 0.0){
			break;
		}
		vec2 curPos = SCREEN_UV + (angleVector * disTraveled);
		sdfVal = texture_sdf(screen_uv_to_sdf(curPos));
		intensity += falloff * min(sdfVal, 0.0); //If sdfVal in negative, it is subtracted. If it is positive, nothing happens because of the min function
		disTraveled += abs(sdfVal) * screenSize.x;

		disTraveled += 0.001;//0.001//Bump the distance traveled to speed up the algorithm and to prevent the raymarching from moving zero every loop.
		//intensity += 0.005;
		
		//if(sdfVal <= 0.0){
			//intensity = 0.0;
			//break;
		//}
	}
	intensity *= finished;

	intensity = clamp(intensity, 0.0, 1.0);

	//intensity = smoothstep(0.0, 1.0, intensity);
	
	float cNdotL = max(0.0, dot(NORMAL, LIGHT_DIRECTION));
	LIGHT = vec4(LIGHT_COLOR.rgb * screen.rgb * intensity * LIGHT_ENERGY * cNdotL, LIGHT_COLOR.a);
}
