shader_type canvas_item;

uniform sampler2D lightSDF : filter_nearest;
uniform sampler2D lightRaySDF : filter_nearest;

void fragment() {

	float lightVal = texture(lightSDF, SCREEN_UV).r;
	lightVal = 1.0 - smoothstep(0.0, 0.1, lightVal);
	//lightVal = step(0.3, lightVal);
	
	float lightRayVal = texture(lightRaySDF, SCREEN_UV).r;
	
	lightVal = max(lightRayVal, lightVal * 0.5);
	
	//lightVal = mix(lightVal, lightVal * lightVal, 0.8);
	
	COLOR = vec4(vec3(lightVal), 1.0);
	
}

