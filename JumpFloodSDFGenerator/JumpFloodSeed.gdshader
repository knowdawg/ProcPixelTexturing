shader_type canvas_item;

uniform sampler2D image : filter_nearest;

void fragment() {
	float texVal = ceil(texture(image, UV).a);
	COLOR = vec4(UV.x * texVal, UV.y * texVal, 0.0, 1.0);
}
