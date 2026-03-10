shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/GeneralPostProcessing.gdshaderinc" //Exposure / Luminance

global uniform vec2 PS_TILE_TEXTURE_SCROLL;

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

void fragment() {
	float textureScalling = PS_RENDER_QUADRANT_SIZE.x / 512.0;
	vec2 qUV = UV + PS_TILE_TEXTURE_SCROLL - vec2(0.5, 0.5);
	qUV = fract(qUV);
	qUV = floor(qUV * PS_RENDER_QUADRANT_SIZE) / PS_RENDER_QUADRANT_SIZE;
	
	vec4 self = texture(TEXTURE, qUV);
	self.rgb = darkenHSV(self.rgb, 0.5);
	
	vec4 normalAndSpecular = texture(NORMAL_TEXTURE, qUV);
	vec3 norm = normalAndSpecular.rgb;
	float spec = 1.0 - normalAndSpecular.a;
	
	vec4 radiance = getRadianceWithNormals(SCREEN_UV, norm, spec);
	radiance.rgb = pow(radiance.rgb, vec3(1.0 / 2.2));
	radiance.rgb = brightnessExposureLuminance(radiance.rgb, 1.0 + spec, 2.0 + spec, 2.0 + spec);
	//radiance.rgb = clamp(radiance.rgb, vec3(0.0), vec3(1.0 + spec));
	
	COLOR = self * radiance;
}


//void light() {
	//vec2 screenCenter = vec2(0.5, 0.5);
	//vec2 unzoomedUV = screenCenter + (SCREEN_UV - screenCenter) / PS_CAMERA_ZOOM;
	//
	//vec2 unzoomedLightPos = screenCenter + ((LIGHT_POSITION.xy * screenSize) - screenCenter) / PS_CAMERA_ZOOM;
	//
	////Setup the variables for SDF Raymarching
	//vec2 lightPosNormalized = unzoomedLightPos.xy;
	//vec2 angleVector = normalize(lightPosNormalized - unzoomedUV);
	//
	//float sdfVal = 0.0;
	//float intensity = 1.0;
	//float distanceNeededToTravel = length(lightPosNormalized - unzoomedUV);
	//float disTraveled = 0.0;
//
	//float finished = 0.0;
	//
	//float closestSdfVal = 1.0;
	//
	//float textureScalling = PS_RENDER_QUADRANT_SIZE.x / 512.0;
//
	//if(LIGHT_IS_DIRECTIONAL){
		//vec2 lightMapTexturePos = (unzoomedUV / screenSize) + PS_WORLD_POSITION;
		//lightMapTexturePos /= PS_RENDER_QUADRANT_SIZE;
		//lightMapTexturePos -= PS_TILE_TEXTURE_SCROLL + vec2(0.5, 0.5);
		//
		//vec4 lightVal = texture(PS_GLOBAL_ILLUMINATION, lightMapTexturePos);// * 2.0;
		//intensity = lightVal.r;
		//finished = 1.0;
	//}else{
		//float threshold = (1.0 / PS_RENDER_QUADRANT_SIZE.x);
		//for(int i = 0; i < 80; i++){
			//if(distanceNeededToTravel > 0.6){
				//finished = 0.0;
				//break;
			//}
			//
			//vec2 curPos = unzoomedUV + (angleVector * disTraveled);
			//vec2 sdfTexturePos = (curPos / screenSize) + PS_WORLD_POSITION;
			//sdfTexturePos /= PS_RENDER_QUADRANT_SIZE;
			//sdfTexturePos -= PS_TILE_TEXTURE_SCROLL + vec2(0.5, 0.5);
			//vec2 sdfData = texture(PS_FOREGROUND_SDF, sdfTexturePos).rg;
			//sdfVal = sdfData.r;
			//disTraveled += abs(sdfVal) / PS_CAMERA_ZOOM.x;
			//
			//closestSdfVal = min(sdfVal * 200.0 * textureScalling, closestSdfVal);
			//
			//if(sdfVal <= threshold){
				//finished = 0.0;
				//break;
			//}
			//if(disTraveled > distanceNeededToTravel){
				//finished = closestSdfVal;
				//break;
			//}
		//}
	//}
	//finished = clamp(finished, 0.0, 1.0);
	//
	//vec3 finalCol = COLOR.rgb * LIGHT_COLOR.rgb * LIGHT_ENERGY;
	//float cNdotL = max(0.0, dot(NORMAL, LIGHT_DIRECTION));
	//LIGHT = vec4(finalCol * finished * cNdotL * intensity, LIGHT_COLOR.a);
//}