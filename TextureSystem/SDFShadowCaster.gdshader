shader_type canvas_item;
//NOT CURRENTLY USED

uniform sampler2D screen : hint_screen_texture;
global uniform float WORLD_BRIGHTNESS;

varying vec2 screenSize;
varying vec4 screenVal;

void fragment(){
	screenSize = SCREEN_PIXEL_SIZE;
	vec4 c = texture(screen, SCREEN_UV);
	screenVal = c;
	c.rgb *= WORLD_BRIGHTNESS;
	COLOR = c;
}

//Called for each light for each pixel
void light() {
	//Setup the variables for SDF Raymarching
	vec2 lightPosNormalized = LIGHT_POSITION.xy * screenSize;
	vec2 angleVector = normalize(lightPosNormalized - SCREEN_UV);
	float sdfVal = 0.0;
	float finished = 0.0;
	float distanceNeededToTravel = length(lightPosNormalized - SCREEN_UV);
	float disTraveled = 0.0;
	
	float closestSdfVal = 1.0;

	//Marching Algorithm
	for(int i = 0; i < 40; i++){
		vec2 curPos = SCREEN_UV + (angleVector * disTraveled);
		sdfVal = texture_sdf(screen_uv_to_sdf(curPos));
		disTraveled += screenSize.x * abs(sdfVal);
		
		//disTraveled += 0.005;
		closestSdfVal = min(closestSdfVal, sdfVal);
		if(sdfVal <= 0.0){
			break;
		}
		if(disTraveled > distanceNeededToTravel){
			finished = 1.0 * closestSdfVal;
			break;
		}
	}
	
	finished = clamp(finished, 0.0, 1.0);
	
	LIGHT = vec4(LIGHT_COLOR.rgb * screenVal.rgb * finished * LIGHT_ENERGY, LIGHT_COLOR.a);
}
