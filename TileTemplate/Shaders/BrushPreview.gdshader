shader_type canvas_item;

uniform vec4 color : source_color;

bool isBorder(sampler2D tex, vec2 uv, vec2 texSize){
	float center = texture(tex, uv).a;
	float left = texture(tex, uv + vec2(-1.0, 0.0) * texSize).a;
	float right = texture(tex, uv + vec2(1.0, 0.0) * texSize).a;
	float up = texture(tex, uv + vec2(0.0, -1.0) * texSize).a;
	float down = texture(tex, uv + vec2(0.0, 1.0) * texSize).a;
	
	float border = left * right * up * down;
	
	if(uv.x < texSize.x || uv.y < texSize.y || uv.x > 1.0 - texSize.x || uv.y > 1.0 - texSize.y){
		border = 0.0;
	}
	
	if(border < 0.001 && center > 0.0){
		return true;
	}
	return false;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 c = color;
	
	float alpha = (abs(sin(TIME * 2.0)) + 2.0) / 4.0;
	c.a = tex.a * alpha;
	
	if(isBorder(TEXTURE, UV, TEXTURE_PIXEL_SIZE * 0.5)){
		c = vec4(1.0, 1.0, 1.0, 1.0);
	}
	
	COLOR = c;
}
