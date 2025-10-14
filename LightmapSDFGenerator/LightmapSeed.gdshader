shader_type canvas_item;

global uniform vec2 WORLD_POSITION; //world position for checking underground
global uniform sampler2D TILE_ARRAY_TEXTURE : filter_nearest;
global uniform sampler2D TILE_ARRAY_TEXTURE_BACKGROUND : filter_nearest, repeat_disable;


void fragment() {
	float texVal = ceil(texture(TILE_ARRAY_TEXTURE, UV).a);
	texVal += ceil(texture(TILE_ARRAY_TEXTURE_BACKGROUND, UV).a);
	texVal = clamp(texVal, 0.0, 1.0);
	texVal = 1.0 - texVal;
	COLOR = vec4(UV.x * texVal, UV.y * texVal, 0.0, 1.0);
	//COLOR.rg = UV * ceil(sin(UV.x + PI / 1.1));
}
