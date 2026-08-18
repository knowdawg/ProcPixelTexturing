shader_type canvas_item;
render_mode blend_premul_alpha;

#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/EmissiveMaterial.gdshaderinc"

uniform sampler2D noiseTex : repeat_enable, filter_nearest;
uniform sampler2D colorGrad;
uniform vec2 resolution = vec2(64.0, 64.0);

group_uniforms scalars;
uniform float flameSpeed : hint_range(0.0, 3.0, 0.1) = 1.0;
uniform float flameIntensity : hint_range(-0.5, 2.0, 0.1) = 0.5;

void fragment() {
	vec2 qUV = floor(UV * resolution) / resolution;
	
	float n = texture(noiseTex, qUV + vec2(TIME * flameSpeed * 0.1, TIME * flameSpeed)).r;
	
	n += flameIntensity;
	n *= smoothstep(0.0, 1.0, 1.0 - (distance(0.5, qUV.y) * 2.0));
	n *= smoothstep(0.0, 1.0, 1.0 - (distance(0.5, qUV.x) * 2.0));
	
	n = smoothstep(0.4, 1.0, n);
	
	vec4 c = texture(colorGrad, vec2(1.0 - n, 0.0));
	c = EmissiveTransform(c);
	
	COLOR = c;
}