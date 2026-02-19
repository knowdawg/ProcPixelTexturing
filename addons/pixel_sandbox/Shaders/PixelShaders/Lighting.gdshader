shader_type canvas_item;
//render_mode blend_mul;

uniform sampler2D screen : hint_screen_texture;

uniform float intensity = 2.0;
uniform float exposure = 3.0;
uniform float luminance = 3.0;


vec3 apply_exposure(vec3 color) {
    return 1.0 - exp(-color * exposure);
}

vec3 boost_luminance(vec3 color) {
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    vec3 normalized = color / max(lum, 0.0001);
    return normalized * lum * luminance;
}



void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	
	c *= intensity;
	c = apply_exposure(c);
	c = boost_luminance(c);
	vec4 s = texture(screen, SCREEN_UV);
	
	//c = pow(c, vec3(0.25));
	//COLOR.rgb = smoothstep(0.1, 0.5, pow(c, vec3(0.5)) * 2.0);//pow(c * 4.0, vec3(0.5));
	
	COLOR.rgb = c * s.rgb;
	
	//
	//vec3 mulc = pow(c, vec3(0.5)) * 4.0;
	//
	//s.rgb += c;
	//s.rgb *= clamp(vec3(0.0), vec3(1.0), mulc);
	
	//if(c == vec3(1.0, 1.0, 1.0)){ //key out the sky somehow
		//s.a = 0.0;
	//}
	
	
	//COLOR = s;
	
	
	//c *= 5.0;
	//COLOR.rgb = linearTosRGB(c.rgb);
}
