shader_type canvas_item;

global uniform vec2 PS_RENDER_QUADRANT_SIZE;
global uniform  int PS_UNIQUE_TILES;
global uniform vec2 PS_WORLD_POSITION;
global uniform vec2 PS_CAMERA_ZOOM;
global uniform sampler2D PS_GLOBAL_ILLUMINATION : filter_nearest, repeat_enable;
global uniform sampler2D PS_FOREGROUND_SDF : filter_nearest, repeat_enable;
global uniform vec2 PS_TILE_TEXTURE_SCROLL;

global uniform sampler2DArray PS_BACKGROUND_TEXTURES : filter_nearest, repeat_enable;
global uniform sampler2DArray PS_BACKGROUND_NORMALS : filter_nearest, repeat_enable;
global uniform sampler2DArray PS_BACKGROUND_GRADIENTS : filter_nearest;
global uniform sampler2D PS_BACKGROUND_BORDER_COLORS : filter_nearest;


group_uniforms lighting;
uniform float brightness : hint_range(0.0, 1.0) = 0.5;

uniform float warp : hint_range(-1.0, 1.0) = 0.03;

varying vec2 screenSize;
varying vec4 screen;



vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz),
                 vec4(c.gb, K.xy),
                 step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r),
                 vec4(c.r, p.yzx),
                 step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)),
                d / (q.x + e),
                q.x);
}
vec3 hsv2rgb(vec3 c) {
    vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0, 4, 2),
                             6.0) - 3.0) - 1.0,
                     0.0,
                     1.0);
    return c.z * mix(vec3(1.0), rgb, c.y);
}
vec3 darkenHSV(vec3 color, float factor) {
    vec3 hsv = rgb2hsv(color);
    hsv.z *= factor;  // Reduce brightness
    return hsv2rgb(hsv);
}

vec4 getColor(int type, vec2 uv, vec4 self, inout vec3 normal){
	vec4 c = vec4(1.0);
	vec2 offsetUV = uv * (PS_RENDER_QUADRANT_SIZE / vec2(256.0, 256.0));
	float tileIndex = self.r * float(PS_UNIQUE_TILES);
	tileIndex -= 1.0; //-1 because self.r at 0 is empty but the arrays start at 0
	
	vec3 arrayUV = vec3(offsetUV, tileIndex);
	
	vec4 border = texture(PS_BACKGROUND_BORDER_COLORS, vec2(self.r - (1.0 / float(PS_UNIQUE_TILES)), 0.0));
	vec4 tVal = texture(PS_BACKGROUND_TEXTURES, arrayUV);
	vec4 nVal = texture(PS_BACKGROUND_NORMALS, arrayUV);
	
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
			c = texture(PS_BACKGROUND_GRADIENTS, vec3(vec2(tVal.r), tileIndex));
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
	float textureScalling = PS_RENDER_QUADRANT_SIZE.x / 512.0;
	vec2 qUV = UV + PS_TILE_TEXTURE_SCROLL - vec2(0.5, 0.5);
	qUV = fract(qUV);
	qUV = floor(qUV * PS_RENDER_QUADRANT_SIZE) / PS_RENDER_QUADRANT_SIZE;
	
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
	screen = vec4(darkenHSV(c.rgb, brightness), c.a);
	
	COLOR = screen;
	
	vec3 nVal = directionToNormal(dir);
	nVal = clamp(nVal, vec3(0.0), vec3(1.0));
	
	disToEdge += 0.2;
	disToEdge = clamp(disToEdge, 0.0, 1.0);
	NORMAL_MAP.xy = mix(nVal.xy, NORMAL_MAP.xy, disToEdge);
}


void light() {
	vec2 screenCenter = vec2(0.5, 0.5);
	vec2 unzoomedUV = screenCenter + (SCREEN_UV - screenCenter) / PS_CAMERA_ZOOM;
	
	vec2 unzoomedLightPos = screenCenter + ((LIGHT_POSITION.xy * screenSize) - screenCenter) / PS_CAMERA_ZOOM;
	
	//Setup the variables for SDF Raymarching
	vec2 lightPosNormalized = unzoomedLightPos.xy;
	vec2 angleVector = normalize(lightPosNormalized - unzoomedUV);
	
	float sdfVal = 0.0;
	float intensity = 1.0;
	float distanceNeededToTravel = length(lightPosNormalized - unzoomedUV);
	float disTraveled = 0.0;

	float finished = 0.0;
	
	float closestSdfVal = 1.0;
	
	float textureScalling = PS_RENDER_QUADRANT_SIZE.x / 512.0;

	if(LIGHT_IS_DIRECTIONAL){
		vec2 lightMapTexturePos = (unzoomedUV / screenSize) + PS_WORLD_POSITION;
		lightMapTexturePos /= PS_RENDER_QUADRANT_SIZE;
		lightMapTexturePos -= PS_TILE_TEXTURE_SCROLL + vec2(0.5, 0.5);
		
		vec4 lightVal = texture(PS_GLOBAL_ILLUMINATION, lightMapTexturePos) * 2.0;
		intensity = lightVal.r;
		finished = 1.0;
	}else{
		float threshold = (1.0 / PS_RENDER_QUADRANT_SIZE.x);
		for(int i = 0; i < 80; i++){
			if(distanceNeededToTravel > 0.6){
				finished = 0.0;
				break;
			}
			
			vec2 curPos = unzoomedUV + (angleVector * disTraveled);
			vec2 sdfTexturePos = (curPos / screenSize) + PS_WORLD_POSITION;
			sdfTexturePos /= PS_RENDER_QUADRANT_SIZE;
			sdfTexturePos -= PS_TILE_TEXTURE_SCROLL + vec2(0.5, 0.5);
			vec2 sdfData = texture(PS_FOREGROUND_SDF, sdfTexturePos).rg;
			sdfVal = sdfData.r;
			disTraveled += abs(sdfVal) / PS_CAMERA_ZOOM.x;
			
			closestSdfVal = min(sdfVal * 200.0 * textureScalling, closestSdfVal);
			
			if(sdfVal <= threshold){
				finished = 0.3;
				break;
			}
			if(disTraveled > distanceNeededToTravel){
				finished = closestSdfVal;
				break;
			}
		}
	}
	finished = clamp(finished, 0.0, 1.0);
	
	vec3 finalCol = COLOR.rgb * LIGHT_COLOR.rgb * LIGHT_ENERGY;
	float cNdotL = max(0.0, dot(NORMAL, LIGHT_DIRECTION));
	LIGHT = vec4(finalCol * finished * cNdotL * intensity, LIGHT_COLOR.a);
}