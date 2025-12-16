shader_type canvas_item;
//render_mode blend_mul;

uniform sampler2D screen : hint_screen_texture;

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	vec4 s = texture(screen, SCREEN_UV);
	
	float brightness = (c.r + c.g + c.b) / 3.0;
	brightness = clamp(0.0, 1.0, 1.0 - brightness);
	
	vec3 mulc = pow(c, vec3(0.5)) * 4.0;
	//mulc = smoothstep(0.1, 1.0, mulc);
	//mulc = smoothstep(0.3, 0.6, mulc);
	//s.rgb *= mulc;//smoothstep(0.0, 0.3, c);//c * 4.0;
	//s.rgb += c * 0.25;
	
	s.rgb += c;
	s.rgb *= clamp(vec3(0.0), vec3(1.0), mulc);
	
	
	COLOR = s;
	//COLOR.rgb = c;
	
}
