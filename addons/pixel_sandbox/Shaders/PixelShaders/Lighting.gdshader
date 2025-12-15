shader_type canvas_item;
render_mode blend_mul;

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	
	c = pow(c, vec3(1.0));
	
	COLOR.rgb = c;
	
}
