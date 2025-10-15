shader_type canvas_item;

global uniform sampler2D TILE_ARRAY_TEXTURE : filter_nearest;

void fragment() {
	float texVal = ceil(texture(TILE_ARRAY_TEXTURE, UV).a);
	COLOR = vec4(UV.x * texVal, UV.y * texVal, 0.0, 1.0);
}

