
global uniform vec2 PS_CAMERA_POSITION;
global uniform sampler2D PS_GLOBAL_ILLUMINATION : filter_linear, repeat_enable;
global uniform int PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE;
global uniform int PS_INITIAL_CASCADE_PROBE_SIZE;
global uniform ivec2 PS_TOP_LEFT_CHUNK_POSITION;
global uniform vec2 PS_RENDER_QUADRANT_SIZE;
global uniform vec2 PS_SCREEN_SIZE;

//L2 circular-harmonic coefficients. One texture per coefficient; rgb = that coefficient for r,g,b.
global uniform sampler2D PS_CH_L0  : filter_linear, repeat_enable; //direct current
global uniform sampler2D PS_CH_L1C : filter_linear, repeat_enable; //cos
global uniform sampler2D PS_CH_L1S : filter_linear, repeat_enable; //sin
global uniform sampler2D PS_CH_L2C : filter_linear, repeat_enable; //cos2
global uniform sampler2D PS_CH_L2S : filter_linear, repeat_enable; //sin2

//Sample the five L2 coefficients (each texture's rgb = that coefficient for r,g,b).
void getCoefficients(vec2 uv, out vec3 dc, out vec3 c1, out vec3 s1, out vec3 c2, out vec3 s2){
	dc = texture(PS_CH_L0,  uv).rgb;
	c1 = texture(PS_CH_L1C, uv).rgb;
	s1 = texture(PS_CH_L1S, uv).rgb;
	c2 = texture(PS_CH_L2C, uv).rgb;
	s2 = texture(PS_CH_L2S, uv).rgb;
}

const float SPEC_FALLOFF = 0.1;    //per-channel radiance at which the highlight reaches half strength
const float SPEC_SHININESS = 4.0;  //higher = tighter highlight
const float SPEC_STRENGTH = 5.0;   //spec=1 intensity (bounded now, safe to raise)
const float SPEC_RESPONSE = 2.0;   //spec map curve: higher = low spec stays subtle (wet), only high spec reflects

vec4 getRadianceWithNormals(vec2 sUV, vec3 normal, float specular, float lightHeight, out vec3 specularOut){
	int GIProbeSize = PS_INITIAL_CASCADE_PROBE_SIZE;
	vec2 screenSize = PS_SCREEN_SIZE;
	vec2 GITexSize = vec2(float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE));
	
	vec2 camPos = (PS_CAMERA_POSITION - (GITexSize / 2.0));
	
	vec2 sampleWorldPosition = ((sUV * screenSize) + camPos); //position of the given screen UV in world space
	
	vec2 GIOrigin = vec2(PS_TOP_LEFT_CHUNK_POSITION) - (GITexSize - screenSize) * 0.5;
	vec2 lightLocalPosition = sampleWorldPosition - GIOrigin; //local postion of the light that wants to be sampled
	
	vec2 uvScale = GITexSize / PS_RENDER_QUADRANT_SIZE.x;
	
	vec2 uv = (lightLocalPosition / GITexSize) * uvScale;
	
	vec3 adjustedNormal = normal * 2.0 - 1.0;
	adjustedNormal.y *= -1.0;
	
	float angle = atan(adjustedNormal.y, adjustedNormal.x);
	float directionalWeight = 1.0 / (1.0 + (lightHeight * lightHeight));
	
	
	vec3 dc, c1, s1, c2, s2;
	getCoefficients(uv, dc, c1, s1, c2, s2);

	float cos1 = cos(angle);
	float sin1 = sin(angle);
	float cos2 = cos(2.0 * angle);
	float sin2 = sin(2.0 * angle);

	//Clamped-cosine diffuse reconstruction kernel (relative band weights). directionalWeight
	//falls the directional bands off with light height so flat-lit normals read as ambient.
	float A0 = 1.0;
	float A1 = 1.570796 * directionalWeight; // pi/2
	float A2 = 0.666667 * directionalWeight; // 2/3

	vec3 diffuseGI = dc * A0
	               + (c1 * cos1 + s1 * sin1) * A1
	               + (c2 * cos2 + s2 * sin2) * A2;

	diffuseGI = max(vec3(0.0), diffuseGI);

	//Specular: bounded curve applied PER CHANNEL. Bounded so HDR brightness can't blow it out;
	//per channel so multiple (differently coloured) lights blend smoothly instead of one winning.
	vec3 specRad = max(vec3(0.0), (c1 * cos1 + s1 * sin1) + (c2 * cos2 + s2 * sin2));
	vec3 shape = pow(specRad / (specRad + SPEC_FALLOFF), vec3(SPEC_SHININESS)); //0..1 each channel
	specularOut = shape * SPEC_STRENGTH * pow(specular, SPEC_RESPONSE);

	return vec4(diffuseGI, 1.0);
}


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

	//Direct Current
	vec3 radiance = texture(PS_CH_L0, uv).rgb;

	return radiance;
	
}