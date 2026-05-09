shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/GeneralPostProcessing.gdshaderinc" //Exposure / Luminance

void fragment() {
	
	//vec3 c = getRadiance(SCREEN_UV);
	
	vec4 normalAndSpecular = texture(NORMAL_TEXTURE, UV);
	vec3 norm = normalAndSpecular.rgb;
	float spec = 1.0 - normalAndSpecular.a;
	
	vec3 radiance = getRadianceWithNormals(SCREEN_UV, norm, spec, 0.75).rgb;
	radiance.rgb = pow(radiance.rgb, vec3(1.0 / 2.2));
	radiance.rgb = brightnessExposureLuminance(radiance.rgb, 2.0, 2.0, 2.0);
	radiance.rgb = clamp(radiance.rgb, vec3(0.0), vec3(1.0));
	
	COLOR.rgb *= radiance;
}