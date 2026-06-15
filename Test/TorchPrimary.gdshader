shader_type canvas_item;

#include "uid://bbiwd2ntuy4pg"


uniform vec3 outlineColor : source_color;

void fragment() {
	vec2 qUV = floor(vec2(UV.y, 1.0 - UV.x) * resolution) / resolution;
	
	float val = getTorchVal(qUV);
	
	vec2 inverseRes = 1.0 / resolution;
	float leftVal = getTorchVal(qUV + vec2(-inverseRes.x, 0));
	float rightVal = getTorchVal(qUV + vec2(inverseRes.x, 0));
	float upVal = getTorchVal(qUV + vec2(0, -inverseRes.y));
	float downVal = getTorchVal(qUV + vec2(0, inverseRes.y));

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

