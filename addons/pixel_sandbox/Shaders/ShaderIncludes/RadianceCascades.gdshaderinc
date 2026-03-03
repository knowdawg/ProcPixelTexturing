
global uniform vec2 PS_CAMERA_POSITION;
global uniform sampler2D PS_GLOBAL_ILLUMINATION : filter_linear, repeat_enable;
global uniform int PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE;
global uniform sampler2D PS_GLOBAL_ILLUMINATION_DIRECTIONAL_DATA : filter_nearest, repeat_enable;
global uniform int PS_INITIAL_CASCADE_PROBE_SIZE;
global uniform ivec2 PS_TOP_LEFT_CHUNK_POSITION;
global uniform vec2 PS_RENDER_QUADRANT_SIZE;
global uniform vec2 PS_SCREEN_SIZE;


vec3 sample_probe(vec2 base_uv, int probeSize, float dirGITexSize, vec3 normal, float specular) {
	vec3 result = vec3(0.0);
	vec2 scalledUV = base_uv;
	scalledUV *= float(dirGITexSize) / PS_RENDER_QUADRANT_SIZE.x;
	scalledUV = floor(scalledUV * float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE)) / float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE);
	
	for (int d = 0; d < probeSize; d++) {
		for (int b = 0; b < probeSize; b++) {
			vec2 texel = scalledUV + (vec2(float(d), float(b)) / dirGITexSize);
			
			vec3 radVal = texture(PS_GLOBAL_ILLUMINATION_DIRECTIONAL_DATA, texel).rgb;
			
			ivec2 localRayCoord = ivec2(d, b);
			int dirIndex = localRayCoord.x + (localRayCoord.y * probeSize);
			float angle = 2.0 * PI * ((float(dirIndex) + 0.5) / float(probeSize * probeSize));
			vec3 lightDir = normalize(vec3(cos(angle), -sin(angle), 0.75));
			
			vec3 viewVector = vec3(0.0, 0.0, 1.0);//Front on camera view
			vec3 H = normalize(lightDir + viewVector); //the halfway vector
			float spec = pow(max(dot(normal, H), 0.0), 16.0); //8.0 is the shininess
			spec = clamp(spec, 0.0, 1.0);
			//result += radVal * spec;
			
			float cNdotL = max(0.0, dot(normal, lightDir));
			//cNdotL *= (1.0 - specular); //reduces normal lighting based on how specular it is
			result += radVal * cNdotL + radVal * spec * specular * 8.0;
		}
	}

	return result / float(probeSize * probeSize);
}

vec4 getRadianceWithNormals(vec2 sUV, vec3 normal, float specular){
	vec3 adjustedNormal = normal * 2.0 - 1.0;
	
	int probeSize = PS_INITIAL_CASCADE_PROBE_SIZE;
	vec2 screenSize = PS_SCREEN_SIZE;
	vec2 GITexSize = vec2(float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE));
	float dirGITexSize = float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE * probeSize);
	
	vec2 camPos = (PS_CAMERA_POSITION - (GITexSize / 2.0));
	vec2 sampleWorldPosition = (sUV * screenSize) + camPos;
	
	vec2 GIOrigin = vec2(PS_TOP_LEFT_CHUNK_POSITION) - (GITexSize - screenSize) * 0.5;
	vec2 lightLocalPosition = sampleWorldPosition - GIOrigin;
	
	//Convert to probe space
	vec2 probe_pos = lightLocalPosition / float(probeSize);
	vec2 base = floor(probe_pos);
	vec2 f = fract(probe_pos);
	
	//Convert probe coords → UV
	vec2 uv00 = (base) / GITexSize;
	vec2 uv10 = (base + vec2(1.0, 0.0)) / GITexSize;
	vec2 uv01 = (base + vec2(0.0, 1.0)) / GITexSize;
	vec2 uv11 = (base + vec2(1.0, 1.0)) / GITexSize;
	
	//Sample 4 probes
	vec3 r00 = sample_probe(uv00, probeSize, dirGITexSize, adjustedNormal, specular);
	vec3 r10 = sample_probe(uv10, probeSize, dirGITexSize, adjustedNormal, specular);
	vec3 r01 = sample_probe(uv01, probeSize, dirGITexSize, adjustedNormal, specular);
	vec3 r11 = sample_probe(uv11, probeSize, dirGITexSize, adjustedNormal, specular);
	
	//Bilinear blend
	vec3 rx0 = mix(r00, r10, f.x);
	vec3 rx1 = mix(r01, r11, f.x);
	vec3 finalRadiance = mix(rx0, rx1, f.y);
	
	return vec4(finalRadiance, 1.0);
}

//vec4 getRadianceWithNormals(vec2 sUV, vec3 normal){
	//vec3 adjustedNormal = normal * 2.0 - 1.0;
	//
	//int GIProbeSize = PS_INITIAL_CASCADE_PROBE_SIZE;
	//vec2 screenSize = PS_SCREEN_SIZE;
	//vec2 GITexSize = vec2(float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE), float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE));
	//float dirGITexSize = float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE * GIProbeSize);
	//vec2 camPos = (PS_CAMERA_POSITION - (GITexSize / 2.0));
	//
	//vec2 sampleWorldPosition = (sUV * screenSize) + camPos; //position of the given screen UV in world space
	//
	//vec2 GIOrigin = vec2(PS_TOP_LEFT_CHUNK_POSITION) - (GITexSize - screenSize) * 0.5;
	//vec2 lightLocalPosition = sampleWorldPosition - GIOrigin; //local postion of the light that wants to be sampled
	//
	//vec2 uv = lightLocalPosition / float(dirGITexSize);
	//uv *= float(dirGITexSize) / PS_RENDER_QUADRANT_SIZE.x;
	//float GIProbeCount = float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE);
	//uv = floor(uv * GIProbeCount) / GIProbeCount;
	//
	////----Global Ilumination Lighting----\\
	//vec4 radiance = vec4(0.0, 0.0, 0.0, 1.0);
	//int probeSize = GIProbeSize;
	////iteratate through each interval in the probe
	//for (int d = 0; d < probeSize; d++) {
		//for (int b = 0; b < probeSize; b++) {
			////get the ray based on the loop
			//vec2 texel = uv + (vec2(float(d), float(b)) / dirGITexSize);
			//
			////Bilinear Wieght This Value
			//vec3 radVal = texture(PS_GLOBAL_ILLUMINATION_DIRECTIONAL_DATA, texel).rgb;
			//
			////Light Direction Calculations
			//ivec2 localRayCoord = ivec2(d, b); //get the local rayCoord in my probe
			//int dirIndex = localRayCoord.x + (localRayCoord.y * probeSize); // get the index so I can be turned into an angle
			//float angle = 2.0 * PI * ((float(dirIndex) + 0.5) / float(probeSize * probeSize));
			//vec3 lightDir = vec3(cos(angle), -sin(angle), 1.0);
			//
			//float cNdotL = max(0.0, dot(adjustedNormal, lightDir));
			//radiance.rgb += radVal * cNdotL;
		//}
	//}
	////Average out the radiance
	//radiance.rgb /= float(probeSize) * float(probeSize);
	//
	//return radiance;
//}

vec3 getRadiance(vec2 sUV){
	int GIProbeSize = PS_INITIAL_CASCADE_PROBE_SIZE;
	vec2 screenSize = PS_SCREEN_SIZE;
	vec2 GITexSize = vec2(float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE));
	
	vec2 camPos = (PS_CAMERA_POSITION - (GITexSize / 2.0));
	
	vec2 sampleWorldPosition = ((sUV * screenSize) + camPos); //position of the given screen UV in world space
	
	vec2 GIOrigin = vec2(PS_TOP_LEFT_CHUNK_POSITION) - (GITexSize - screenSize) * 0.5;
	vec2 lightLocalPosition = sampleWorldPosition - GIOrigin; //local postion of the light that wants to be sampled
	
	vec2 uv = lightLocalPosition / GITexSize;
	uv *= GITexSize / PS_RENDER_QUADRANT_SIZE.x;
	uv /= float(GIProbeSize);
	
	vec3 radiance = texture(PS_GLOBAL_ILLUMINATION, uv).rgb;
	
	return radiance;
}