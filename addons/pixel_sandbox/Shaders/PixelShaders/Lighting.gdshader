shader_type canvas_item;
//render_mode blend_mul;

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	
	//c = pow(c, vec3(1.0));
	
	//c.rgb = smoothstep(0.0, 0.3, c.rgb);
	
	COLOR.rgb = c;
	
}
