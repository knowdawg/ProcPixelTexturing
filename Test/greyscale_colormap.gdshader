shader_type canvas_item;

uniform sampler2D tex : filter_linear;
uniform float blackPoint : hint_range(0.0, 1.0) = 0.0;
uniform float whitePoint : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint : source_color = vec4(1.0);

//linear color space greyscale
float toGrey(vec3 baseColor){
	float grey = (0.2126 * baseColor.r) + (0.7152 * baseColor.g) + (0.0722 * baseColor.b);
	
	return grey;
}

void fragment() {
	float grey = toGrey(texture(tex, UV).rgb);
	
	float slope = 1.0 / (whitePoint - blackPoint);
	grey -= blackPoint;
	grey *= slope;
	grey = clamp(grey, 0.0, 1.0);
	
	
	COLOR.rgb = vec3(grey) * tint.rgb;
}
