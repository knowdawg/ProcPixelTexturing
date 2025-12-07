shader_type canvas_item;

global uniform sampler2DArray PS_FOREGROUND_TEXTURES : filter_nearest, repeat_enable;
global uniform sampler2DArray PS_FOREGROUND_GRADIENTS : filter_nearest;
global uniform sampler2D PS_FOREGROUND_BORDER_COLORS : filter_nearest;

global uniform sampler2DArray PS_BACKGROUND_TEXTURES : filter_nearest, repeat_enable;
global uniform sampler2DArray PS_BACKGROUND_GRADIENTS : filter_nearest;
global uniform sampler2D PS_BACKGROUND_BORDER_COLORS : filter_nearest;

global uniform int PS_UNIQUE_TILES;

uniform bool isForeground = true;
group_uniforms lighting;
uniform float falloff : hint_range(0.0, 100.0);
uniform float warp : hint_range(-1.0, 1.0) = -0.03;


varying vec2 size;

vec4 getColor(int type, vec2 uv, vec4 self){
	vec4 c = vec4(1.0);
	vec2 offsetUV = uv * (size / vec2(256.0, 256.0));
	float tileIndex = self.r * float(PS_UNIQUE_TILES);
	tileIndex -= 1.0; //-1 because self.r at 0 is empty but the arrays start at 0
	
	vec3 arrayUV = vec3(offsetUV, tileIndex);
	
	vec4 border;
	vec4 tVal;
	
	if(isForeground){
		border = texture(PS_FOREGROUND_BORDER_COLORS, vec2(self.r - (1.0 / float(PS_UNIQUE_TILES)), 0.0));
		tVal = texture(PS_FOREGROUND_TEXTURES, arrayUV);
	}else{
		border = texture(PS_BACKGROUND_BORDER_COLORS, vec2(self.r - (1.0 / float(PS_UNIQUE_TILES)), 0.0));
		tVal = texture(PS_BACKGROUND_TEXTURES, arrayUV);
	}
	
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
			if(isForeground){
				c = texture(PS_FOREGROUND_GRADIENTS, vec3(vec2(tVal.r), tileIndex));
			}else{
				c = texture(PS_BACKGROUND_GRADIENTS, vec3(vec2(tVal.r), tileIndex));
			}
			break;
		default:
			c.a = 0.0;
			break;
	}
	
	
	return c;
}

vec2 angleToVec2(float angle){
	float angRad = angle;
	if(angle < 0.5){
		angRad *= 2.0; //back to 0-1
		angRad -= 0.5; //back to -0.5-0.5
		angRad *= PI; //Final: -PI/2 to PI/2
	}else{
		angRad -= 0.5; //back to 0-0.5
		angRad *= 2.0; //back to 0-1
		angRad *= PI; //back to 0 to PI
		angRad += PI / 2.0; //PI/2 to 3PI/2
	}
	
	//angle * TAU;
	return(vec2(cos(angRad), sin(angRad)));
}

void fragment() {
	size = 1.0 / TEXTURE_PIXEL_SIZE;
	
	float textureScalling = size.x / 512.0;
	vec2 qUV = UV;
	qUV = fract(qUV);
	qUV = floor(qUV * size) / size;
	
	vec4 self = texture(TEXTURE, qUV);
	int type = int(round((self.g) * 3.0)); //might have some floating point inacuracies here...
	
	float disToEdge = (self.a - 0.5) * 2.0;
	disToEdge = clamp(disToEdge, 0.0, 1.0);
	disToEdge += 0.1;
	vec2 dir = angleToVec2(self.b);
	
	if(disToEdge < 1.0){
		qUV += (dir * clamp(1.0 - disToEdge, 0.0, 1.0)) * warp * textureScalling;
	}
	
	vec4 c = vec4(1.0);
	c = getColor(type, qUV, self);
	
	if(type == 1){
		c = vec4(0.0, 0.0, 0.0, 1.0);
	}
	
	COLOR.rgb = c.rgb;
	COLOR.a *= c.a;
	
	//NORMAL_MAP = nVal;
	//COLOR.rg = NORMAL_MAP.xy;
	//COLOR.b = 1.0;
	
	//COLOR = vec4(self.r, 0.0, 0.0, 1.0);
}