shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades


void fragment() {
	COLOR.rgb = getRadiance(SCREEN_UV);
}
