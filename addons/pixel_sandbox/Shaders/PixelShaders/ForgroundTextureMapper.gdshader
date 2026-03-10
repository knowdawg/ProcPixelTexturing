shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/GeneralPostProcessing.gdshaderinc" //Exposure / Luminance

global uniform vec2 PS_TILE_TEXTURE_SCROLL;

void fragment() {
	float textureScalling = PS_RENDER_QUADRANT_SIZE.x / 512.0;
	
	//offset back the VU
	vec2 qUV = UV + PS_TILE_TEXTURE_SCROLL - vec2(0.5, 0.5);
	qUV = fract(qUV);
	
	qUV = floor(qUV * PS_RENDER_QUADRANT_SIZE) / PS_RENDER_QUADRANT_SIZE;
	
	vec4 self = texture(TEXTURE, qUV);
	
	vec4 normalAndSpecular = texture(NORMAL_TEXTURE, qUV);
	vec3 norm = normalAndSpecular.rgb;
	float spec = 1.0 - normalAndSpecular.a;
	
	vec4 radiance = getRadianceWithNormals(SCREEN_UV, norm, spec);
	radiance.rgb = pow(radiance.rgb, vec3(1.0 / 6.0));
	//radiance.rgb = brightnessExposureLuminance(radiance.rgb, 1.0 + spec, 1.0 + spec, 1.0 + spec);
	//radiance.rgb = clamp(radiance.rgb, vec3(0.0), vec3(1.0 + spec));
	
	COLOR = self * radiance;
	//COLOR.rgb = norm.rgb;
	//COLOR.rgb += highlights * radiance.rgb;
	//COLOR.rgb = mix(COLOR.rgb, highlights, highlights);
}


//void light() {
	//vec2 screenCenter = vec2(0.5, 0.5);
	//vec2 unzoomedUV = screenCenter + (SCREEN_UV - screenCenter) / PS_CAMERA_ZOOM;
	//vec2 unzoomedLightPos = screenCenter + ((LIGHT_POSITION.xy * screenSize) - screenCenter) / PS_CAMERA_ZOOM;
	//
	////Setup the variables for SDF Raymarching
	//vec2 lightPosNormalized = unzoomedLightPos.xy;
	//vec2 angleVector = normalize(lightPosNormalized - unzoomedUV);
	//float sdfVal = 0.0;
	//float intensity = 1.0;
	//float distanceNeededToTravel = length(lightPosNormalized - unzoomedUV);
	//float disTraveled = 0.0;
//
	//float finished = 0.0;
	//
	//float textureScalling = PS_RENDER_QUADRANT_SIZE.x / 512.0;
//
	//if(LIGHT_IS_DIRECTIONAL){
		//vec2 lightMapTexturePos = (unzoomedUV / screenSize) + PS_WORLD_POSITION; //Get rid of world pos?
		//lightMapTexturePos /= PS_RENDER_QUADRANT_SIZE;
		//lightMapTexturePos -= PS_TILE_TEXTURE_SCROLL + vec2(0.5, 0.5);
		//lightMapTexturePos = fract(lightMapTexturePos);
		//
		//float lightVal = texture(PS_GLOBAL_ILLUMINATION, lightMapTexturePos).r;
		//
		////Highlights
		//vec2 sdfTexturePos = (unzoomedUV / screenSize) + PS_WORLD_POSITION;
		//sdfTexturePos /= PS_RENDER_QUADRANT_SIZE;
		//sdfTexturePos -= PS_TILE_TEXTURE_SCROLL + vec2(0.5, 0.5);
		//sdfTexturePos = fract(sdfTexturePos);
		//vec2 sdfVal = texture(PS_FOREGROUND_SDF, sdfTexturePos).rg;
		//sdfVal.r *= ((sdfVal.g - 0.5) * -2.0);
		//float subtract = min(sdfVal.r * textureScalling, 0.0) * 10.0;// * 10.0 + 1.0;
//
		////lightVal = clamp(lightVal * subtract, 0.0, 1.0);
		//lightVal = lightVal + subtract;
		//
		//intensity = lightVal;
		//
	//}else{
		//for(int i = 0; i < 80; i++){
			//if(distanceNeededToTravel > 0.6){
				//break;
			//}
			//if(disTraveled > distanceNeededToTravel){
				//finished = 1.0;
				//break;
			//}
			//if(intensity <= 0.0){
				//break;
			//}
			//vec2 curPos = unzoomedUV + (angleVector * disTraveled);
			//vec2 sdfTexturePos = (curPos / screenSize) + PS_WORLD_POSITION;
			//sdfTexturePos /= PS_RENDER_QUADRANT_SIZE;
			//sdfTexturePos -= PS_TILE_TEXTURE_SCROLL + vec2(0.5, 0.5);
			//sdfTexturePos = fract(sdfTexturePos);
			//vec2 sdfData = texture(PS_FOREGROUND_SDF, sdfTexturePos).rg;
			//sdfVal = sdfData.r;
			////if(sdfData.g > 0.5){
				////sdfVal *= -1.0;
			////}
			//intensity += falloff * min(sdfVal, 0.0); //If sdfVal in negative, it is subtracted. If it is positive, nothing happens because of the min function
			//disTraveled += abs(sdfVal) / PS_CAMERA_ZOOM.x;
			//
			//float moveAmount = length((1.0 / PS_RENDER_QUADRANT_SIZE) * angleVector);
			//disTraveled += moveAmount;
			//intensity += falloff * moveAmount * clamp(floor(sdfVal), -1.0, 0.0);
		//}
		//intensity *= finished;
		//intensity = clamp(intensity, 0.0, 1.0);
	//}
	//
	//intensity = clamp(intensity, 0.0, 100.0);
	//
	//float cNdotL = max(0.0, dot(NORMAL, LIGHT_DIRECTION));
	//cNdotL = (cNdotL / 2.0) + 0.5;//clamp(cNdotL + 0.5, 0.0, 1.0);
	//LIGHT = vec4(LIGHT_COLOR.rgb * screen.rgb * intensity * LIGHT_ENERGY * cNdotL, LIGHT_COLOR.a);
//}
