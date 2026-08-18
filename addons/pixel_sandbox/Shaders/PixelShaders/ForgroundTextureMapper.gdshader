shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/GeneralPostProcessing.gdshaderinc" //Exposure / Luminance

global uniform vec2 PS_TILE_TEXTURE_SCROLL;
uniform sampler2D SCREEN : hint_screen_texture;

void fragment() {
	float textureScalling = PS_RENDER_QUADRANT_SIZE.x / 512.0;
	
	//offset back the VU
	vec2 qUV = UV + PS_TILE_TEXTURE_SCROLL;
	qUV = fract(qUV);
	
	qUV = floor(qUV * PS_RENDER_QUADRANT_SIZE) / PS_RENDER_QUADRANT_SIZE;
	
	vec4 self = texture(TEXTURE, qUV);
	
	vec4 normalAndSpecular = texture(NORMAL_TEXTURE, qUV);
	vec3 norm = normalAndSpecular.rgb;
	
	vec4 custom = texture(SPECULAR_SHININESS_TEXTURE, qUV);
	float reflectiveness = custom.r;
	
	float spec = 1.0 - normalAndSpecular.a;
	float dirOffsetBlend = 1.0 - (spec * 0.5); //from 1.0 (no spec) to 0.5 (full spec)
	
	vec3 specularGI;
	vec4 radiance = getRadianceWithNormals(SCREEN_UV, norm, spec, 0.0, dirOffsetBlend, specularGI);
	radiance.rgb = brightnessExposureLuminance(radiance.rgb, 1.0, 1.0, 1.0); //brightness*exposure = gain, last arg = saturation
	radiance.rgb = pow(radiance.rgb, vec3(1.0 / 2.2));
	//Specular on top of the albedo with its own tonemap, so it isn't squashed by the diffuse correction
	vec3 specularDisplay = pow(tonemapHDR(specularGI, 1.0), vec3(1.0 / 2.2));
	
	if(reflectiveness > 0.0){
		int maxDis = 16;
		int dis = maxDis;
		for(int i = 1; i < maxDis; i++){
			vec2 sampleUV = fract(UV + PS_TILE_TEXTURE_SCROLL) - vec2(0.0, float(i) * TEXTURE_PIXEL_SIZE.y);
			sampleUV = fract(sampleUV);
			if(texture(TEXTURE, sampleUV).a < 0.1){ //check for empty space
				dis = i;
				break;
			}
		}
		
		vec4 screenTexure = texture(SCREEN, vec2(SCREEN_UV.x, SCREEN_UV.y - float((dis - 1) * 2) / PS_SCREEN_SIZE.y));
		float mixMult = smoothstep(0.0, 0.5, float(maxDis - dis) / float(maxDis));
		self = mix(self, screenTexure, reflectiveness * mixMult);
	}
	
	self = vec4(self.rgb * (radiance.rgb + specularDisplay), self.a);
	
	COLOR = self;
}
