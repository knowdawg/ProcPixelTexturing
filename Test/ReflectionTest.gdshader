shader_type canvas_item;

global uniform sampler2D PS_REFLECTION_BUFFER;
global uniform sampler2D PS_FLUENCE;

void fragment() {
	vec4 c = texture(PS_REFLECTION_BUFFER, UV);
	c.a = 1.0;
	
	COLOR = c;
}
