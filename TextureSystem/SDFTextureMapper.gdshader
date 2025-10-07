shader_type canvas_item;

uniform vec2 RESOLUTION;
global uniform sampler2D TILE_ARRAY_TEXTURE : filter_nearest, repeat_disable;
//uniform sampler2D tileArrayTex : filter_nearest, repeat_disable;
group_uniforms dirt;
uniform sampler2D DIRT_TEX : filter_nearest, repeat_enable;
uniform sampler2D DIRT_GRAD;
uniform vec4 DIRT_BORDER_COLOR : source_color;

group_uniforms stone;
uniform sampler2D STONE_TEX : filter_nearest, repeat_enable;
uniform sampler2D STONE_GRAD;
uniform vec4 STONE_BORDER_COLOR : source_color;

group_uniforms grass;
uniform sampler2D GRASS_TEX : filter_nearest, repeat_enable;
uniform sampler2D GRASS_GRAD;
uniform vec4 GRASS_BORDER_COLOR : source_color;

int getPixelType(sampler2D tex, vec2 uv, vec2 stepAmount){
	
	vec4 center = texture(TILE_ARRAY_TEXTURE, uv);
	
	vec4 left = texture(TILE_ARRAY_TEXTURE, uv - stepAmount.x + vec2(0.001, 0.005));
	vec4 right = texture(TILE_ARRAY_TEXTURE, uv + stepAmount.x - vec2(0.0, 0.003));
	vec4 up = texture(TILE_ARRAY_TEXTURE, uv - stepAmount.y + vec2(0.006, 0.001));
	vec4 down = texture(TILE_ARRAY_TEXTURE, uv + stepAmount.y - vec2(0.005, 0.0));
	
	bool hasNonPopulatedNieghbor = left.r * right.r * up.r * down.r == 0.0;
	bool hasPopulatedNieghbor = left.r + right.r + up.r + down.r > 0.0;
	bool isCenterPopulated = center.r != 0.0;
	
	if(!hasNonPopulatedNieghbor && isCenterPopulated){return 3;}
	if(hasNonPopulatedNieghbor && isCenterPopulated){return 2;}
	if(hasPopulatedNieghbor && !isCenterPopulated){return 1;}
	if(!isCenterPopulated){return 0;}
	
	
	return 0;
}

vec4 getColor(int type, vec2 uv, sampler2D tex, sampler2D grad, vec4 border, float valBoost){
	vec4 c = vec4(1.0);
	switch(type){
		case 0:
			c.a = 0.0;
			break;
		case 1:
			c = vec4(0.0, 0.0, 0.0, 1.0);
			break;
		case 2:
			c = border;
			break;
		case 3:
			vec4 tVal = texture(tex, uv * (RESOLUTION / vec2(256.0, 256.0)));
			c = texture(grad, vec2(tVal.r, 0.0));
			c.rgb *= valBoost;
			break;
		default:
			c.a = 0.0;
			break;
	}
	
	
	return c;
}

void fragment() {
	vec2 qUV = floor(UV * RESOLUTION) / RESOLUTION;
	
	vec4 self = texture(TILE_ARRAY_TEXTURE, qUV);
	int type = getPixelType(TILE_ARRAY_TEXTURE, qUV, 1.0 / RESOLUTION);
	
	float sdfVal = texture_sdf(screen_uv_to_sdf(SCREEN_UV));
	sdfVal = abs(sdfVal);
	sdfVal /= 10.0;
	sdfVal *= 0.5;
	sdfVal = clamp(sdfVal, 0.0, 1.0);
	sdfVal = 1.0 - sdfVal;
	
	if(self.r < 0.05){
		COLOR.a = 0.0;
	}else if(self.r < 0.15){
		COLOR = getColor(type, qUV, STONE_TEX, STONE_GRAD, STONE_BORDER_COLOR, sdfVal);
	}else if(self.r < 0.25){
		COLOR = getColor(type, qUV, GRASS_TEX, GRASS_GRAD, GRASS_BORDER_COLOR, sdfVal);
	}else if(self.r < 0.35){
		COLOR = getColor(type, qUV, DIRT_TEX, DIRT_GRAD, DIRT_BORDER_COLOR, sdfVal);
	}
	
	
	if(type == 1){
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
	
}