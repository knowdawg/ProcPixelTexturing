shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/GeneralPostProcessing.gdshaderinc" //Exposure / Luminance

void fragment() {
	
	//vec3 c = getRadiance(SCREEN_UV);
	
	vec4 normalAndSpecular = texture(NORMAL_TEXTURE, UV);
	vec3 norm = normalAndSpecular.rgb;
	float spec = 1.0 - normalAndSpecular.a;
	
	vec3 specHighlights = vec3(0.0);
	vec4 radiance = vec4(1.0);
	radiance = getRadianceWithNormals(SCREEN_UV, norm, spec, 0.5, specHighlights);
	radiance.rgb = brightnessExposureLuminance(radiance.rgb, 1.0, 1.0, 0.5); //brightness*exposure = gain, last arg = saturation
	radiance.rgb = pow(radiance.rgb, vec3(1.0 / 2.2));
	
	COLOR.rgb *= radiance.rgb;
}