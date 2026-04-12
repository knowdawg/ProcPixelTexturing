shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/GeneralPostProcessing.gdshaderinc" //Exposure / Luminance

void fragment() {
	COLOR.rgb = getRadiance(SCREEN_UV);
	//COLOR.rgb = brightnessExposureLuminance(COLOR.rgb, 3.0, 3.0, 3.0);
	//COLOR.rgb *= 10.0;
	COLOR.rgb = pow(COLOR.rgb, vec3(1.0 / 2.2));
	
}
