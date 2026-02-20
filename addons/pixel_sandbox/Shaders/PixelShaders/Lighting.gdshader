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
	
	COLOR.rgb = c * s.rgb;
	COLOR.a = 1.0;
	
	//COLOR.rgb = vec3(1.0);
	//COLOR.a = texture(TEXTURE, UV).a;
}
