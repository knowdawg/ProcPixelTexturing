shader_type canvas_item;

uniform sampler2D image : filter_nearest;
uniform float threshold = 0.0001;

void fragment() {
	float texVal = step(threshold, texture(image, UV).a);//ceil(texture(image, UV).a);
	COLOR = vec4(UV.x * texVal, UV.y * texVal, 0.0, 1.0);
}
