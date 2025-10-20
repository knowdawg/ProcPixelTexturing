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
    vec2 size = min(imageSize(foregroundSDF), imageSize(backgroundSDF));
    if(uv.x < 0 || uv.y < 0 || uv.x > size.x - 1 || uv.y > size.y - 1){
        return 0;
    }

    vec2 sam1 = imageLoad(foregroundSDF, uv).xy;
    vec2 sam2 = imageLoad(backgroundSDF, uv).xy;
    float sam1Pos = (sam1.g - 0.5) * -2.0; //1 if outside, -1 if inside
    float sam2Pos = (sam2.g - 0.5) * -2.0; //1 if outside, -1 if inside

    //float posNeg = (max(sam1.r, sam2.r) - 0.5) * -2.0;

    float finalSam = min(sam1.r * sam1Pos, sam2.r * sam2Pos);
    
    return finalSam;
}

float sampleDistanceFieldsSafe(ivec2 uv){
    vec2 size = min(imageSize(foregroundSDF), imageSize(backgroundSDF));
    if(uv.x < 0 || uv.y < 0 || uv.x > size.x - 1 || uv.y > size.y - 1){
        return 0;
    }

    vec2 sam1 = imageLoad(foregroundSDF, uv).xy;
    vec2 sam2 = imageLoad(backgroundSDF, uv).xy;

    float finalSam = min(sam1.r, sam2.r);
    
    return finalSam;
}


float sampleForegroundDistanceField(ivec2 uv){
    vec2 size = min(imageSize(foregroundSDF), imageSize(backgroundSDF));
    if(uv.x < 0 || uv.y < 0 || uv.x > size.x - 1 || uv.y > size.y - 1){
        return 0;
    }

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

    vec2 size = min(imageSize(foregroundSDF), imageSize(backgroundSDF));

    bool isBackgroundTile = sampleForegroundDistanceField(uv) > 0.0;

    float textureScalling = (imSize / 512.0);

	for(int i = 0; i < 80; i++){
		vec2 curPos = vec2(uv) + (angleVector * disTraveled);

        if(curPos.x < 0 || curPos.y < 0 || curPos.x > size.x - 1 || curPos.y > size.y - 1){ //If you leave the screen, you failed
            break;
        }

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

        if(isBackgroundTile){ // IF im a background tile, slowly fade out the light ray
            intensity -= (moveAmount / imSize) * 2.0 * textureScalling;
        }

		
		
		if(sdfVal > -threshold / 3.0){ //If niether is here
			finished = 1.0;
			break;
		}
        if(foregroundSdfVal < threshold){
            intensity -= (moveAmount / imSize) * 40.0 * textureScalling;
            //break;
        }
		if(intensity <= 0.0){
			break;
		}
	}

    if(isBackgroundTile){ //If I am a background Tile, then smoothstep for more visible light rays
        intensity = smoothstep(0.0, 0.5 / textureScalling, intensity);
    }

    intensity *= finished;
    vec4 color = vec4(vec3(intensity), 1.0);
    imageStore(outputBuffer, uv, color);
}
