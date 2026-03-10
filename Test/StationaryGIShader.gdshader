shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades


void fragment() {
	COLOR.rgb = pow(getRadiance(SCREEN_UV), vec3(1.0 / 2.2));
}
