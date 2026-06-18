uniform sampler2D noise : filter_nearest, repeat_enable;
uniform vec2 resolution = vec2(6.0, 12.0);
uniform sampler2D colorRamp : filter_nearest;

uniform float speed : hint_range(0.0, 3.0) = 1.0;

float getTorchVal(vec2 uv){
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

