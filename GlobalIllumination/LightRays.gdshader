shader_type canvas_item;

uniform sampler2D lightSDF : filter_nearest;
uniform sampler2D envirementalSDF : filter_nearest;
global uniform float SUN_DIRECTION;
//uniform float SUN_DIRECTION : hint_range(0.0, 10.0);

void fragment() {
	//Setup the variables for SDF Raymarching
	vec2 angleVector = vec2(cos(SUN_DIRECTION), sin(SUN_DIRECTION));
	float envirementSDFVal = 0.0;
	float lightSDFVal = 0.0;
	float intensity = 1.0;
	float disTraveled = 0.0;

	float finished = 0.0;

	for(int i = 0; i < 40; i++){
		vec2 curPos = SCREEN_UV + (angleVector * disTraveled);
		envirementSDFVal = texture(envirementalSDF, curPos).r;
		lightSDFVal = texture(lightSDF, curPos).r;
		float combinedSDF = min(envirementSDFVal, lightSDFVal);
		
		if(combinedSDF > 0.007){
			disTraveled += abs(combinedSDF);
			//intensity -= abs(combinedSDF) * 0.1;//If sdfVal in negative, it is subtracted. If it is positive, nothing happens because of the min function
		}else{
			float moveAmount = length(SCREEN_PIXEL_SIZE * angleVector);
			disTraveled += moveAmount;//Bump the distance traveled to speed up the algorithm and to prevent the raymarching from moving zero every loop.
			intensity -= moveAmount * 10.0;
		}
		
		
		
		if(lightSDFVal < 0.01){
			finished = 1.0;
			break;
		}
		if(intensity <= 0.0){
			finished = 1.0;
			break;
		}
	}
	float lightVal = texture(lightSDF, SCREEN_UV).r;
	lightVal = 1.0 - smoothstep(0.0, 0.05, lightVal);
	//lightVal = step(0.3, lightVal);
	//intensity = max(intensity * 1.0, lightVal);
	
	intensity *= finished;
	//intensity = step(0.1, intensity);
	intensity = clamp(intensity, 0.0, 1.0);
	//intensity = smoothstep(0.0, 1.0, intensity);
	
	COLOR = vec4(vec3(intensity), intensity);
	
	//float v = texture(envirementalSDF, UV).r;
	//v = step(0.01, v);
	//COLOR.rgb = vec3(v);
}

