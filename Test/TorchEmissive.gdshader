shader_type canvas_item;
render_mode blend_premul_alpha;

#include "uid://bbiwd2ntuy4pg" //Torch Shader

group_uniforms emission_params;
uniform float energy  = 1.0;
uniform float density = 0.0;

void fragment() {
	vec2 qUV = floor(vec2(UV.y, 1.0 - UV.x) * resolution) / resolution;
	
	float val = getTorchVal(qUV);

	vec4 color = texture(colorRamp, vec2(val, 0.0));
	
	float shape = smoothstep(0.0, 0.3, val);
	COLOR = vec4(color.rgb * shape * energy, density * shape);
}
