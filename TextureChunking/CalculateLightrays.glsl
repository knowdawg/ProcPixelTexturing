#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;


layout(set = 0, binding = 0, rgba32f) uniform readonly image2D foregroundSDF;

layout(set = 0, binding = 1, rgba32f) uniform readonly image2D backgroundSDF;

layout(set = 0, binding = 2, rgba32f) uniform writeonly image2D outputBuffer;

layout(set = 0, binding = 3, std430) readonly buffer SunDirection {
    float sunDir;
};


float sampleDistanceFields(ivec2 uv){
    vec2 sam1 = imageLoad(foregroundSDF, uv).xy;
    vec2 sam2 = imageLoad(backgroundSDF, uv).xy;
    float sam1Pos = (sam1.g - 0.5) * -2.0; //1 if outside, -1 if inside
    float sam2Pos = (sam2.g - 0.5) * -2.0; //1 if outside, -1 if inside

    //float posNeg = (max(sam1.r, sam2.r) - 0.5) * -2.0;

    float finalSam = min(sam1.r * sam1Pos, sam2.r * sam2Pos);
    
    return finalSam;
}

float sampleDistanceFieldsSafe(ivec2 uv){
    vec2 sam1 = imageLoad(foregroundSDF, uv).xy;
    vec2 sam2 = imageLoad(backgroundSDF, uv).xy;

    float finalSam = min(sam1.r, sam2.r);
    
    return finalSam;
}


float sampleForegroundDistanceField(ivec2 uv){
    vec2 sam = imageLoad(foregroundSDF, uv).rg;
    float samPos = (floor(sam.g) - 0.5) * -2.0; //1 if outside, -1 if inside

    return sam.r * samPos;
}


void main(){
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	//Setup the variables for SDF Raymarching
	vec2 angleVector = vec2(cos(sunDir), sin(sunDir));
	float sdfVal = 0.0;
    float foregroundSdfVal = 0.0;
	float intensity = 1.0;
	float disTraveled = 0.0;

    float finished = 0.0;
    float imSize = float(imageSize(outputBuffer).x);
    float threshold = (1.0 / imSize) + 0.00001;

	for(int i = 0; i < 80; i++){
		vec2 curPos = vec2(uv) + (angleVector * disTraveled);
		sdfVal = sampleDistanceFields(ivec2(curPos));
        foregroundSdfVal = sampleForegroundDistanceField(ivec2(curPos));


        float moveAmount;
        if(sdfVal > 0.0){
            moveAmount = max(sdfVal, threshold) * imSize;
            disTraveled += moveAmount;
        }else{
            float v = sampleDistanceFieldsSafe(ivec2(curPos));
            moveAmount = max(v, threshold) * imSize;
            disTraveled += moveAmount;
        }

		
		
		if(sdfVal > -threshold / 3.0){ //If niether is here
			finished = 1.0;
			break;
		}
        if(foregroundSdfVal < threshold){
            //intensity -= (moveAmount / imSize) * 80.0;
            break;
        }
		if(intensity <= 0.0){
			break;
		}
	}

    intensity *= finished;
    vec4 color = vec4(vec3(intensity), 1.0);
    imageStore(outputBuffer, uv, color);
}

// void fragment() {
// 	//Setup the variables for SDF Raymarching
// 	vec2 angleVector = vec2(cos(SUN_DIRECTION), sin(SUN_DIRECTION));
// 	float envirementSDFVal = 0.0;
// 	float lightSDFVal = 0.0;
// 	float intensity = 1.0;
// 	float disTraveled = 0.0;

// 	float finished = 0.0;

// 	for(int i = 0; i < 40; i++){
// 		vec2 curPos = SCREEN_UV + (angleVector * disTraveled);
// 		envirementSDFVal = texture(envirementalSDF, curPos).r;
// 		lightSDFVal = texture(lightSDF, curPos).r;
// 		float combinedSDF = min(envirementSDFVal, lightSDFVal);
		
// 		if(combinedSDF > 0.007){
// 			disTraveled += abs(combinedSDF);
// 			//intensity -= abs(combinedSDF) * 0.1;//If sdfVal in negative, it is subtracted. If it is positive, nothing happens because of the min function
// 		}else{
// 			float moveAmount = length(SCREEN_PIXEL_SIZE * angleVector);
// 			disTraveled += moveAmount;//Bump the distance traveled to speed up the algorithm and to prevent the raymarching from moving zero every loop.
// 			intensity -= moveAmount * 10.0;
// 		}
		
		
// 		if(lightSDFVal < 0.007){
// 			finished = 1.0;
// 			break;
// 		}
// 		if(intensity <= 0.0){
// 			break;
// 		}
// 	}
// 	float lightVal = texture(lightSDF, SCREEN_UV).r;
// 	lightVal = 1.0 - smoothstep(0.0, 0.05, lightVal);
// 	//lightVal = step(0.3, lightVal);
// 	//intensity = max(intensity * 1.0, lightVal);
	
// 	intensity *= finished;
// 	//intensity = step(0.1, intensity);
// 	intensity = clamp(intensity, 0.0, 1.0);
// 	//intensity = smoothstep(0.0, 1.0, intensity);
	
// 	COLOR = vec4(vec3(intensity), intensity);
	
// 	//float v = texture(envirementalSDF, UV).r;
// 	//v = step(0.01, v);
// 	//COLOR.rgb = vec3(v);
// }