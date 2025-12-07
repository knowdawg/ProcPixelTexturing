shader_type canvas_item;

uniform sampler2D SCREEN : hint_screen_texture;

uniform float intensity : hint_range(-5, 5);

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float disFromCenter = distance(center, UV);
	disFromCenter = smoothstep(0.0, 0.1, 0.5 - disFromCenter);
	vec2 vecFromCenter = UV - center;
	vecFromCenter = vecFromCenter * disFromCenter * intensity * 1000.0 * SCREEN_PIXEL_SIZE;
	
	
	vec4 screen = texture(SCREEN, SCREEN_UV - vecFromCenter);
	COLOR = screen;
}

