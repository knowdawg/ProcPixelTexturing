shader_type canvas_item;

global uniform vec2 RENDER_QUADRANT_SIZE;
global uniform vec2 WORLD_POSITION;
global uniform vec2 CAMERA_ZOOM;
global uniform sampler2D GLOBAL_ILLUMINATION : filter_nearest, repeat_enable;
global uniform sampler2D FOREGROUND_SDF : filter_nearest, repeat_enable;
global uniform vec2 TILE_TEXTURE_SCROLL;

global uniform sampler2DArray FOREGROUND_TEXTURES_SAMPLER_2D_ARRAY : filter_nearest, repeat_enable;
global uniform sampler2DArray FOREGROUND_NORMALS_SAMPLER_2D_ARRAY : filter_nearest, repeat_enable;
global uniform sampler2DArray FOREGROUND_GRADIENTS_SAMPLER_2D_ARRAY : filter_nearest;
global uniform sampler2D FOREGROUND_BORDER_COLORS : filter_nearest;

group_uniforms lighting;
uniform float falloff : hint_range(0.0, 100.0);
uniform vec4 modulate : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float warp : hint_range(-1.0, 1.0) = -0.03;
uniform int numOfUniqueTiles = 128;

varying vec2 screenSize;
varying vec4 screen;

vec4 getColor(int type, vec2 uv, vec4 self, inout vec3 normal){
	vec4 c = vec4(1.0);
	vec2 offsetUV = uv * (RENDER_QUADRANT_SIZE / vec2(256.0, 256.0));
	float tileIndex = self.r * float(numOfUniqueTiles);
	tileIndex -= 1.0; //-1 because self.r at 0 is empty but the arrays start at 0
	
	vec3 arrayUV = vec3(offsetUV, tileIndex);
	
	vec4 border = texture(FOREGROUND_BORDER_COLORS, vec2(self.r - (1.0 / float(numOfUniqueTiles)), 0.0));
	vec4 tVal = texture(FOREGROUND_TEXTURES_SAMPLER_2D_ARRAY, arrayUV);
	vec4 nVal = texture(FOREGROUND_NORMALS_SAMPLER_2D_ARRAY, arrayUV);
	
	switch(type){
		case 0:
			c.a = 0.0;
			break;
		case 1:
			c = vec4(0.0, 0.0, 0.0, 1.0);
			break;
		case 2:
			c = border;
			normal = nVal.rgb;
			break;
		case 3:
			normal = nVal.rgb;
			c = texture(FOREGROUND_GRADIENTS_SAMPLER_2D_ARRAY, vec3(vec2(tVal.r), tileIndex));
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
	float textureScalling = RENDER_QUADRANT_SIZE.x / 512.0;
	vec2 qUV = UV + TILE_TEXTURE_SCROLL - vec2(0.5, 0.5);
	qUV = fract(qUV);
	qUV = floor(qUV * RENDER_QUADRANT_SIZE) / RENDER_QUADRANT_SIZE;
	
	vec4 self = texture(TEXTURE, qUV);
	int type = int(round((self.g) * 3.0)); //might have some floating point inacuracies here...
	
	float disToEdge = (self.a - 0.5) * 2.0;
	disToEdge = clamp(disToEdge, 0.0, 1.0);
	disToEdge += 0.1;
	vec2 dir = angleToVec2(self.b);
	
	if(disToEdge < 1.0){
		qUV += (dir * clamp(1.0 - disToEdge, 0.0, 1.0)) * warp * textureScalling;
	}
	
	vec4 c = vec4(1.0);
	c = getColor(type, qUV, self, NORMAL_MAP);
	
	if(type == 1){
		c = vec4(0.0, 0.0, 0.0, 1.0);
	}
	
	screenSize = SCREEN_PIXEL_SIZE;
	screen = c * modulate;
	
	COLOR = c * modulate;
	
	vec3 nVal = directionToNormal(dir);
	nVal = clamp(nVal, vec3(0.0), vec3(1.0));
	
	disToEdge += 0.2;
	disToEdge = clamp(disToEdge, 0.0, 1.0);
	NORMAL_MAP.xy = mix(nVal.xy, NORMAL_MAP.xy, disToEdge);
	
	//NORMAL_MAP = nVal;
	//COLOR.rg = NORMAL_MAP.xy;
	//COLOR.b = 1.0;
	
	//COLOR = vec4(self.r, 0.0, 0.0, 1.0);
}


void light() {
	vec2 screenCenter = vec2(0.5, 0.5);
	vec2 unzoomedUV = screenCenter + (SCREEN_UV - screenCenter) / CAMERA_ZOOM;
	vec2 unzoomedLightPos = screenCenter + ((LIGHT_POSITION.xy * screenSize) - screenCenter) / CAMERA_ZOOM;
	
	//Setup the variables for SDF Raymarching
	vec2 lightPosNormalized = unzoomedLightPos.xy;
	vec2 angleVector = normalize(lightPosNormalized - unzoomedUV);
	float sdfVal = 0.0;
	float intensity = 1.0;
	float distanceNeededToTravel = length(lightPosNormalized - unzoomedUV);
	float disTraveled = 0.0;

	float finished = 0.0;
	
	float textureScalling = RENDER_QUADRANT_SIZE.x / 512.0;

	if(LIGHT_IS_DIRECTIONAL){
		vec2 lightMapTexturePos = (unzoomedUV / screenSize) + WORLD_POSITION; //Get rid of world pos?
		lightMapTexturePos /= RENDER_QUADRANT_SIZE;
		lightMapTexturePos -= TILE_TEXTURE_SCROLL + vec2(0.5, 0.5);
		lightMapTexturePos = fract(lightMapTexturePos);
		
		float lightVal = texture(GLOBAL_ILLUMINATION, lightMapTexturePos).r;
		//lightVal *= 2.0;
		
		//Highlights
		vec2 sdfTexturePos = (unzoomedUV / screenSize) + WORLD_POSITION;
		sdfTexturePos /= RENDER_QUADRANT_SIZE;
		sdfTexturePos -= TILE_TEXTURE_SCROLL + vec2(0.5, 0.5);
		sdfTexturePos = fract(sdfTexturePos);
		vec2 sdfVal = texture(FOREGROUND_SDF, sdfTexturePos).rg;
		sdfVal.r *= ((sdfVal.g - 0.5) * -2.0);
		float subtract = min(sdfVal.r * 10.0 * textureScalling, 0.0);
		float bonus = 0.0;
		if(lightVal > 0.75){
			bonus = (lightVal + subtract * 10.0);
		}
		subtract = smoothstep(0.0, 0.5, lightVal + subtract);
		lightVal = subtract + bonus;
		
		intensity = lightVal;
		
	}else{
		for(int i = 0; i < 80; i++){
			if(distanceNeededToTravel > 0.6){
				break;
			}
			if(disTraveled > distanceNeededToTravel){
				finished = 1.0;
				break;
			}
			if(intensity <= 0.0){
				break;
			}
			vec2 curPos = unzoomedUV + (angleVector * disTraveled);
			vec2 sdfTexturePos = (curPos / screenSize) + WORLD_POSITION;
			sdfTexturePos /= RENDER_QUADRANT_SIZE;
			sdfTexturePos -= TILE_TEXTURE_SCROLL + vec2(0.5, 0.5);
			sdfTexturePos = fract(sdfTexturePos);
			vec2 sdfData = texture(FOREGROUND_SDF, sdfTexturePos).rg;
			sdfVal = sdfData.r;
			if(sdfData.g > 0.5){
				sdfVal *= -1.0;
			}
			intensity += falloff * min(sdfVal, 0.0); //If sdfVal in negative, it is subtracted. If it is positive, nothing happens because of the min function
			disTraveled += abs(sdfVal) / CAMERA_ZOOM.x;
			
			float moveAmount = length((1.0 / RENDER_QUADRANT_SIZE) * angleVector);
			disTraveled += moveAmount;
			intensity += falloff * moveAmount * clamp(floor(sdfVal), -1.0, 0.0);
		}
		intensity *= finished;
		intensity = clamp(intensity, 0.0, 1.0);
	}
	
	intensity = clamp(intensity, 0.0, 100.0);
	
	float cNdotL = max(0.0, dot(NORMAL, LIGHT_DIRECTION));
	LIGHT = vec4(LIGHT_COLOR.rgb * screen.rgb * intensity * LIGHT_ENERGY * cNdotL, LIGHT_COLOR.a);
}
