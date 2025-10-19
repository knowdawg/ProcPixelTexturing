shader_type canvas_item;

varying vec2 screenSize;
global uniform sampler2D GLOBAL_ILLUMINATION : filter_linear;
global uniform sampler2D FOREGROUND_SDF : filter_nearest;
global uniform vec2 WORLD_POSITION;
uniform vec2 SDFTextureSize = vec2(512.0, 512.0);

void fragment(){
	screenSize = SCREEN_PIXEL_SIZE;
	
	//COLOR = texture(FOREGROUND_SDF, UV);
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
	float intensity = 1.0;

	float closestSdfVal = 1.0;
	
	
	if(LIGHT_IS_DIRECTIONAL){
		
		angleVector = LIGHT_DIRECTION.xy;
		finished = 1.0;
		intensity = texture(GLOBAL_ILLUMINATION, SCREEN_UV).r;
		
	}else{
		for(int i = 0; i < 40; i++){
			if(distanceNeededToTravel > 0.5){
				finished = 0.0;
				break;
			}
			
			vec2 curPos = SCREEN_UV + (angleVector * disTraveled);
			vec2 sdfTexturePos = (curPos / screenSize) + WORLD_POSITION;
			sdfTexturePos /= SDFTextureSize;
			sdfVal = texture(FOREGROUND_SDF, sdfTexturePos).r;
			disTraveled += abs(sdfVal);
			
			closestSdfVal = min(sdfVal * 200.0, closestSdfVal);
			
			if(sdfVal <= 0.00196){ //1/512 roudned slightly up
				finished = 0.0;
				break;
			}
			if(disTraveled > distanceNeededToTravel){
				finished = closestSdfVal;
				break;
			}
		}
		
	}
	
	finished = clamp(finished, 0.0, 1.0);
	
	vec3 finalCol = COLOR.rgb * LIGHT_COLOR.rgb * LIGHT_ENERGY;
	float cNdotL = max(0.0, dot(NORMAL, LIGHT_DIRECTION));
	LIGHT = vec4(finalCol * finished * cNdotL * intensity, LIGHT_COLOR.a);
}
