shader_type canvas_item;

uniform vec2 RESOLUTION;
uniform sampler2D tileArrayTex : filter_nearest, repeat_disable;

uniform sampler2D noise : filter_nearest, repeat_enable;

int getPixelType(sampler2D tex, vec2 uv, vec2 stepAmount){
	
	vec4 center = texture(tileArrayTex, uv);
	
	vec4 left = texture(tileArrayTex, uv - stepAmount.x + vec2(0.001, 0.005));
	vec4 right = texture(tileArrayTex, uv + stepAmount.x - vec2(0.0, 0.003));
	vec4 up = texture(tileArrayTex, uv - stepAmount.y + vec2(0.006, 0.001));
	vec4 down = texture(tileArrayTex, uv + stepAmount.y - vec2(0.005, 0.0));
	
	bool hasNonPopulatedNieghbor = left.r * right.r * up.r * down.r == 0.0;
	bool hasPopulatedNieghbor = left.r + right.r + up.r + down.r > 0.0;
	bool isCenterPopulated = center.r != 0.0;
	
	if(!hasNonPopulatedNieghbor && isCenterPopulated){return 3;}
	if(hasNonPopulatedNieghbor && isCenterPopulated){return 2;}
	if(hasPopulatedNieghbor && !isCenterPopulated){return 1;}
	if(!isCenterPopulated){return 0;}
	
	
	return 0;
}

void fragment() {
	vec2 qUV = floor(UV * RESOLUTION) / RESOLUTION;
	
	vec4 self = texture(tileArrayTex, qUV);
	int type = getPixelType(tileArrayTex, qUV, 1.0 / RESOLUTION);
	
	float sdfVal = texture_sdf(screen_uv_to_sdf(SCREEN_UV));
	sdfVal = abs(sdfVal);
	sdfVal /= 10.0;
	sdfVal = clamp(sdfVal, 0.0, 1.0);
	sdfVal = 1.0 - sdfVal;
	//sdfVal = round(sdfVal * 4.0) / 4.0;
	//sdfVal *= 0.5;
	
	
	switch(type){
		case 0:
			COLOR.a = 0.0;
			break;
		case 1:
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
			break;
		case 2:
			COLOR = vec4(1.0, 1.0, 1.0, 1.0);
			break;
		case 3:
			COLOR = vec4(0.5, 0.5, 0.5, 1.0);
			COLOR.rgb += vec3(sdfVal);
			COLOR *= texture(noise, qUV * (RESOLUTION / vec2(256.0, 256.0)));
			break;
		default:
			COLOR.a = 0.0;
			break;
	}
	
	
	if(self.r < 0.15){
		COLOR.rgb *= vec3(0.4, 0.4, 0.4);
	}else if(self.r < 0.25){
		COLOR.rgb *= vec3(0.4, 0.7, 0.2);
	}else if(self.r < 0.35){
		COLOR.rgb *= vec3(0.5, 0.3, 0.25);
	}
	
}