shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/GeneralPostProcessing.gdshaderinc" //Exposure / Luminance

void fragment() {
	
	//vec3 c = getRadiance(SCREEN_UV);
	
	vec4 normalAndSpecular = texture(NORMAL_TEXTURE, UV);
	vec3 norm = normalAndSpecular.rgb;
	float spec = 1.0 - normalAndSpecular.a;
	
	vec3 c = getRadianceWithNormals(SCREEN_UV, norm, spec).rgb;
	c = brightnessExposureLuminance(c, 3.0, 3.0, 3.0);
	c = pow(c, vec3(1.0 / 2.2));
	
	COLOR.rgb *= c;
}