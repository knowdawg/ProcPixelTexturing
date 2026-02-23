shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades


void fragment() {
	COLOR = getRadiance(SCREEN_UV) * 5.0;
}
