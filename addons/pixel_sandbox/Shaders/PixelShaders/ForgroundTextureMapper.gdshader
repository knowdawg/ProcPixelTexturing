shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/GeneralPostProcessing.gdshaderinc" //Exposure / Luminance

global uniform vec2 PS_TILE_TEXTURE_SCROLL;

void fragment() {
	float textureScalling = PS_RENDER_QUADRANT_SIZE.x / 512.0;
	
	//offset back the VU
	vec2 qUV = UV + PS_TILE_TEXTURE_SCROLL;
	qUV = fract(qUV);
	
	qUV = floor(qUV * PS_RENDER_QUADRANT_SIZE) / PS_RENDER_QUADRANT_SIZE;
	
	vec4 self = texture(TEXTURE, qUV);
	
	vec4 normalAndSpecular = texture(NORMAL_TEXTURE, qUV);
	vec3 norm = normalAndSpecular.rgb;
	
	float spec = 1.0 - normalAndSpecular.a;
	
	vec3 specularGI;
	vec4 radiance = getRadianceWithNormals(SCREEN_UV, norm, spec, 0.5, specularGI);
	radiance.rgb = brightnessExposureLuminance(radiance.rgb, 1.0, 1.0, 1.0); //brightness*exposure = gain, last arg = saturation
	radiance.rgb = pow(radiance.rgb, vec3(1.0 / 2.2));

	//Specular on top of the albedo with its own tonemap, so it isn't squashed by the diffuse correction
	vec3 specularDisplay = pow(tonemapHDR(specularGI, 1.0), vec3(1.0 / 2.2));

	COLOR = vec4(self.rgb * (radiance.rgb + specularDisplay), self.a);
}
