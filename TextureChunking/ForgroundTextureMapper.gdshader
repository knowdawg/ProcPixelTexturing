shader_type canvas_item;

uniform vec2 RESOLUTION;
global uniform vec2 WORLD_POSITION;
uniform sampler2D TILE_ARRAY_TEXTURE : filter_nearest, repeat_disable;
global uniform sampler2D GLOBAL_ILLUMINATION : filter_nearest;

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
global uniform float WORLD_BRIGHTNESS;
uniform float falloff : hint_range(0.0, 0.1);

varying vec2 screenSize;
varying vec4 screen;

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

vec2 angleToVec2(float angle){
	float angRad = angle;
	if(angle < 0.5){
		angRad *= 2.0; //back to 0-1
		angRad -= 0.5; //back to -0.5-0.5
		angRad *= PI; //Final: -PI/2 to PI/2
	}else{
		angRad -= 0.5; //back to 0-0.5
		angRad *= 2.0; //back to 0-1
		angRad *= PI; //back to 0 to PI
		angRad += PI / 2.0; //PI/2 to 3PI/2
	}
	
	//angle * TAU;
	return(vec2(cos(angRad), sin(angRad)));
}

vec3 directionToNormal(vec2 direction) {
	vec2 inverted_direction = ((direction * vec2(1.0, -1.0)) + 1.0) * 0.5;
	float z = sqrt(1.0 - clamp(dot(inverted_direction, inverted_direction), 0.0, 1.0));
	
	return normalize(vec3(inverted_direction, z));
}

void fragment() {
	vec2 qUV = UV;//floor(UV * RESOLUTION) / RESOLUTION;
	
	vec4 self = texture(TILE_ARRAY_TEXTURE, qUV);
	int type = int(round((self.g) * 3.0)); //might have some floating point inacuracies here...
	
	
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
	
	screenSize = SCREEN_PIXEL_SIZE;
	screen = c;
	c.rgb *= WORLD_BRIGHTNESS;
	
	COLOR = c;
	
	float disToEdge = (self.a - 0.5) * 2.0;
	vec2 dir = angleToVec2(self.b);
	vec3 nVal = directionToNormal(dir);
	NORMAL_MAP = mix(nVal, NORMAL_MAP, disToEdge);
	
	//NORMAL_MAP = nVal;
	//COLOR.rg = NORMAL_MAP.xy;
	//COLOR.b = 1.0;
}


void light() {
	
	//Setup the variables for SDF Raymarching
	vec2 lightPosNormalized = LIGHT_POSITION.xy * screenSize;
	vec2 angleVector = normalize(lightPosNormalized - SCREEN_UV);
	float sdfVal = 0.0;
	float intensity = 1.0;
	float distanceNeededToTravel = length(lightPosNormalized - SCREEN_UV);
	float disTraveled = 0.0;

	float finished = 0.0;

	if(LIGHT_IS_DIRECTIONAL){
		angleVector = LIGHT_DIRECTION.xy;
		float sdfVal = texture_sdf(screen_uv_to_sdf(SCREEN_UV));
		sdfVal *= 0.02;
		
		intensity = texture(GLOBAL_ILLUMINATION, SCREEN_UV).r * 2.0;
		if(abs(sdfVal) < 0.05 && intensity > 0.6){
			intensity += 1.0;
		}
		intensity += sdfVal;
		intensity = clamp(intensity, 0.0, 1.0);
		
	}else{
		for(int i = 0; i < 20; i++){
			if(distanceNeededToTravel > 0.4){
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
			
			float moveAmount = length(screenSize * angleVector) * 5.0;
			disTraveled += moveAmount;//0.05;//0.001//Bump the distance traveled to speed up the algorithm and to prevent the raymarching from moving zero every loop.
			intensity += moveAmount * clamp(floor(sdfVal), -1.0, 0.0);
			
		}
		intensity *= finished;
		intensity = clamp(intensity, 0.0, 1.0);
	}
	
	//intensity = smoothstep(0.0, 0.8, intensity);
	
	float cNdotL = max(0.0, dot(NORMAL, LIGHT_DIRECTION));
	LIGHT = vec4(LIGHT_COLOR.rgb * screen.rgb * intensity * LIGHT_ENERGY * cNdotL, LIGHT_COLOR.a);
}
