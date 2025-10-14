shader_type canvas_item;

uniform sampler2D image : filter_nearest;

void fragment() {
	vec2 offsetUV = texture(image, UV).xy;
	float SDFVal = distance(UV, offsetUV);
	SDFVal = clamp(SDFVal, 0.0, 1.0);
	
	COLOR = vec4(vec3(SDFVal), 1.0);
}
