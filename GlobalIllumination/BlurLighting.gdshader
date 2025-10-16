shader_type canvas_item;

uniform sampler2D light : filter_linear;

void fragment() {
	float c = 0.0;//texture(light, UV).r;

	float dis = 1.0;

	for(int i = 0; i < 3; i++){
		vec2 spin = vec2(cos(float(i)), sin(float(i)));
		float up = texture(light, UV + vec2(1.0, -1.0) * SCREEN_PIXEL_SIZE.y * dis * spin).r;
		float down = texture(light, UV + vec2(-1.0, 1.0) * SCREEN_PIXEL_SIZE.y * dis * spin).r;
		float left = texture(light, UV + vec2(-1.0, -1.0) * SCREEN_PIXEL_SIZE.x * dis * spin).r;
		float right = texture(light, UV + vec2(1.0, 1.0) * SCREEN_PIXEL_SIZE.x * dis * spin).r;
		c += (up + down + left + right) * 0.25;//(1.0 / float(i + 1));
		dis = float(i + 2) * 1.0;
	}

	c /= 3.0;
	c = max(c, texture(light, UV).r);
	
	if(c > 0.8){
		c *= 2.0;
	}
	c /= 2.0;
	
	//c *= 2.0;
	//c = smoothstep(0.0, 0.7, c);
	
	//c = texture(light, UV).r;
	
	COLOR = vec4(vec3(c), 1.0);
}
