shader_type canvas_item;

uniform sampler2D noise : filter_nearest, repeat_enable;
uniform vec2 resolution = vec2(6.0, 12.0);
uniform sampler2D colorRamp : filter_nearest;

uniform float speed : hint_range(0.0, 3.0) = 1.0;

uniform vec3 outlineColor : source_color;

//void vertex(){
	//VERTEX.x += ((UV.x - 0.5) * 2.0) * (1.0 - UV.y) * sin(TIME * 3.0);
//}

float getVal(vec2 uv){
	vec4 n = texture(noise, uv + vec2(sin(TIME * speed * 1.0) * 0.3, TIME * speed));
	float topDis =  0.9 - uv.y;
	
	float centerDis = -abs(0.5 - uv.x + sin(TIME * speed * 6.0) * topDis * 0.3);
	float val = n.r + centerDis - topDis;
	
	float dis = 0.5 - distance(vec2(uv.x, (1.0 - uv.y) * (resolution.y / resolution.x)), vec2(0.4, 0.5));
	val += max(dis, 0.0);
	
	val = n.r;
	val += centerDis * 1.5;
	val -= smoothstep(0.2, 1.0, topDis);
	val -= smoothstep(0.8, 1.0, uv.y);
	val += max(dis, 0.0) * 4.0;
	
	return max(val, 0.0);
}

void fragment() {
	vec2 qUV = floor(vec2(UV.y, 1.0 - UV.x) * resolution) / resolution;
	
	float val = getVal(qUV);
	
	vec2 inverseRes = 1.0 / resolution;
	float leftVal = getVal(qUV + vec2(-inverseRes.x, 0));
	float rightVal = getVal(qUV + vec2(inverseRes.x, 0));
	float upVal = getVal(qUV + vec2(0, -inverseRes.y));
	float downVal = getVal(qUV + vec2(0, inverseRes.y));

	float alpha = max(leftVal + rightVal, upVal + downVal);

	vec4 color = texture(colorRamp, vec2(val, 0.0));
	
	COLOR.a = smoothstep(0.0, 0.3, val);
	COLOR.rgb = color.rgb;
	
	if(alpha > 0.0 && val < 0.1){ //Your an outline
		COLOR = vec4(outlineColor.rgb, smoothstep(0.0, 0.3, alpha));
	}
	
	if(qUV.x < inverseRes.x && val > 0.1){
		COLOR = vec4(outlineColor.rgb, smoothstep(0.0, 0.3, alpha));
	}
	
	if(qUV.x > 0.99 - inverseRes.x && val > 0.1){
		COLOR = vec4(outlineColor.rgb, smoothstep(0.0, 0.3, alpha));
	}
}

