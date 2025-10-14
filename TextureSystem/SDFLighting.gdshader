shader_type canvas_item;

varying vec2 screenSize;
global uniform sampler2D SDF_LIGHT_TEXTURE;

void fragment(){
	screenSize = SCREEN_PIXEL_SIZE;
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
		for(int i = 0; i < 40; i++){
			vec2 curPos = SCREEN_UV + (angleVector * disTraveled);
			sdfVal = texture_sdf(screen_uv_to_sdf(curPos)) * screenSize.x;
			float lightSdf = texture(SDF_LIGHT_TEXTURE, curPos).r;
			float combinedSDF = min(sdfVal, lightSdf);
			
			disTraveled += abs(combinedSDF);
			if(combinedSDF <= 0.0){
				intensity -= abs(combinedSDF) * 30.0;//If sdfVal in negative, it is subtracted. If it is positive, nothing happens because of the min function
			
			}
			//disTraveled += lightSdf;
			
			float moveAmount = length(screenSize * angleVector) * 1.0;
			disTraveled += moveAmount;//Bump the distance traveled to speed up the algorithm and to prevent the raymarching from moving zero every loop.
			if(combinedSDF <= 0.0){
				intensity -= moveAmount;
			}
			
			
			if(lightSdf < 0.01){
				//finished = 1.0;
				break;
			}
			if(intensity <= 0.0){
				//finished = 0.0;
				break;
			}
			if(i == 39){
				intensity = 0.0;
				break;
			}
		}
		finished = 1.0;
		float lightVal = texture(SDF_LIGHT_TEXTURE, SCREEN_UV).r;
		lightVal = 1.0 - smoothstep(0.0, 0.25, lightVal);
		lightVal *= 0.5;
		intensity = max(intensity, lightVal);
		
	}else{
		for(int i = 0; i < 40; i++){
			if(distanceNeededToTravel > 0.5){
				finished = 0.0;
				break;
			}
			
			vec2 curPos = SCREEN_UV + (angleVector * disTraveled);
			sdfVal = texture_sdf(screen_uv_to_sdf(curPos));
			disTraveled += screenSize.x * abs(sdfVal);
			
			closestSdfVal = min(sdfVal, closestSdfVal);
			
			if(sdfVal <= 0.0){
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
