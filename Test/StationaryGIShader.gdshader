shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/GeneralPostProcessing.gdshaderinc" //Exposure / Luminance

void fragment() {
	vec4 radiance = vec4(1.0);
	radiance.rgb = getRadiance(SCREEN_UV);
	radiance.rgb = brightnessExposureLuminance(radiance.rgb, 1.0, 1.0, 1.0); //brightness*exposure = gain, last arg = saturation
	radiance.rgb = pow(radiance.rgb, vec3(1.0 / 2.2));
	
	COLOR.rgb = radiance.rgb;
	
}
