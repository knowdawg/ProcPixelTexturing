
global uniform vec2 PS_CAMERA_POSITION;
global uniform sampler2D PS_GLOBAL_ILLUMINATION : filter_nearest, repeat_enable;
global uniform int PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE;
global uniform ivec2 PS_TOP_LEFT_CHUNK_POSITION;
global uniform vec2 PS_RENDER_QUADRANT_SIZE;
global uniform vec2 PS_SCREEN_SIZE;
global uniform int PS_INITIAL_CASCADE_PROBE_SIZE;

vec4 getRadianceWithNormals(vec2 sUV, vec3 normal){
	vec3 adjustedNormal = normal * 2.0 - 1.0;
	
	int GIProbeSize = PS_INITIAL_CASCADE_PROBE_SIZE;
	vec2 screenSize = PS_SCREEN_SIZE;
	vec2 GITexSize = vec2(float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE / GIProbeSize), float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE / GIProbeSize));
	vec2 camPos = (PS_CAMERA_POSITION - (GITexSize / 2.0)); //Figure out why this is the value
	
	vec2 sampleWorldPosition = floor((sUV * screenSize) + camPos); //position of the given screen UV in world space
	
	vec2 GIOrigin = vec2(PS_TOP_LEFT_CHUNK_POSITION) - (GITexSize - screenSize) * 0.5;
	vec2 lightLocalPosition = sampleWorldPosition - GIOrigin; //local postion of the light that wants to be sampled
	
	vec2 uv = lightLocalPosition / float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE);
	uv *= float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE) / PS_RENDER_QUADRANT_SIZE.x;
	float GIProbeCount = float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE) / float(PS_INITIAL_CASCADE_PROBE_SIZE);
	uv = floor(uv * GIProbeCount) / GIProbeCount;
	
	//----Global Ilumination Lighting----\\
	vec4 radiance = vec4(0.0, 0.0, 0.0, 1.0);
	int probeSize = GIProbeSize;
	//iteratate through each interval in the probe
	for (int d = 0; d < probeSize; d++) {
		for (int b = 0; b < probeSize; b++) {
			//get the ray based on the loop
			vec2 texel = uv + (vec2(float(d), float(b)) / float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE));
			vec3 radVal = texture(PS_GLOBAL_ILLUMINATION, texel).rgb;
			
			//Light Direction Calculations
			ivec2 localRayCoord = ivec2(d, b); //get the local rayCoord in my probe
			int dirIndex = localRayCoord.x + (localRayCoord.y * probeSize); // get the index so I can be turned into an angle
			float angle = 2.0 * PI * ((float(dirIndex) + 0.5) / float(probeSize * probeSize));
			vec3 lightDir = vec3(cos(angle), -sin(angle), 1.0);
			
			float cNdotL = max(0.0, dot(adjustedNormal, lightDir));
			radiance.rgb += radVal * cNdotL;
		}
	}
	//Average out the radiance
	radiance.rgb /= float(probeSize) * float(probeSize);
	
	return radiance;
}

vec4 getRadiance(vec2 sUV){
	int GIProbeSize = PS_INITIAL_CASCADE_PROBE_SIZE;
	vec2 screenSize = PS_SCREEN_SIZE;
	vec2 GITexSize = vec2(float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE / GIProbeSize), float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE / GIProbeSize));
	vec2 camPos = (PS_CAMERA_POSITION - (GITexSize / 2.0)); //Figure out why this is the value
	
	vec2 sampleWorldPosition = floor((sUV * screenSize) + camPos); //position of the given screen UV in world space
	
	vec2 GIOrigin = vec2(PS_TOP_LEFT_CHUNK_POSITION) - (GITexSize - screenSize) * 0.5;
	vec2 lightLocalPosition = sampleWorldPosition - GIOrigin; //local postion of the light that wants to be sampled
	
	vec2 uv = lightLocalPosition / float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE);
	uv *= float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE) / PS_RENDER_QUADRANT_SIZE.x;
	float GIProbeCount = float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE) / float(PS_INITIAL_CASCADE_PROBE_SIZE);
	uv = floor(uv * GIProbeCount) / GIProbeCount;
	
	//----Global Ilumination Lighting----\\
	vec4 radiance = vec4(0.0, 0.0, 0.0, 1.0);
	int probeSize = GIProbeSize;
	//iteratate through each interval in the probe
	for (int d = 0; d < probeSize; d++) {
		for (int b = 0; b < probeSize; b++) {
			//get the ray based on the loop
			vec2 texel = uv + (vec2(float(d), float(b)) / float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE));
			vec3 radVal = texture(PS_GLOBAL_ILLUMINATION, texel).rgb;
			
			radiance.rgb += radVal;
		}
	}
	//Average out the radiance
	radiance.rgb /= float(probeSize) * float(probeSize);
	
	return radiance;
}