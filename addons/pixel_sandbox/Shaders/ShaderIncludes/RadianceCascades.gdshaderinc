
global uniform vec2 PS_CAMERA_POSITION;
global uniform int PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE;
global uniform ivec2 PS_TOP_LEFT_CHUNK_POSITION;
global uniform vec2 PS_RENDER_QUADRANT_SIZE;
global uniform vec2 PS_SCREEN_SIZE;

//Cosine-convolved directional diffuse: one layer per facing direction
//rgb = diffuse, a = raw ray luminance (for specular)
global uniform sampler2DArray PS_DIFFUSE_DIRECTIONS : filter_linear, repeat_enable;
global uniform sampler2D PS_FLUENCE : filter_linear, repeat_enable;

const float TWO_PI = 6.28318530718;

const float SPEC_STRENGTH = 10.0;  //overall specular intensity
const float SPEC_RESPONSE = 5.0;  //spec map curve: higher = low spec stays subtle (wet), only high spec reflects

//Maps a screen UV to the radiance-cascade texture UV (shared by the diffuse array and fluence).
vec2 getRadianceUV(vec2 sUV){
	vec2 screenSize = PS_SCREEN_SIZE;
	vec2 GITexSize = vec2(float(PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE));

	vec2 camPos = (PS_CAMERA_POSITION - (GITexSize / 2.0));
	vec2 sampleWorldPosition = ((sUV * screenSize) + camPos); //position of the given screen UV in world space

	vec2 GIOrigin = vec2(PS_TOP_LEFT_CHUNK_POSITION) - (GITexSize - screenSize) * 0.5;
	vec2 lightLocalPosition = sampleWorldPosition - GIOrigin; //local postion of the light that wants to be sampled

	vec2 uvScale = GITexSize / PS_RENDER_QUADRANT_SIZE.x;
	return (lightLocalPosition / GITexSize) * uvScale;
}

vec4 getRadianceWithNormals(vec2 sUV, vec3 normal, float specular, float lightHeight, out vec3 specularOut){
	vec2 uv = getRadianceUV(sUV);

	vec3 adjustedNormal = normal * 2.0 - 1.0;
	adjustedNormal.y *= -1.0;

	float angle = atan(adjustedNormal.y, adjustedNormal.x);
	if(angle < 0.0) angle += TWO_PI;

	//Angular position between the two bracketing direction layers
	int dirCount = textureSize(PS_DIFFUSE_DIRECTIONS, 0).z;
	float fLayer = (angle / TWO_PI) * float(dirCount);
	int layer0 = int(floor(fLayer)) % dirCount;
	int layer1 = (layer0 + 1) % dirCount;
	//float t = smoothstep(0.0, 1.0, fract(fLayer)); //ease: zero slope at each layer boundary rounds off the crease

	//smooth out creases
	float f = fract(fLayer);
	float t = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

	//Hardware bilinear handles the spatial probe blend; we lerp the 2 layers angularly
	vec4 dir0 = texture(PS_DIFFUSE_DIRECTIONS, vec3(uv, float(layer0)));
	vec4 dir1 = texture(PS_DIFFUSE_DIRECTIONS, vec3(uv, float(layer1)));
	vec4 dir = mix(dir0, dir1, t); //rgb = directional diffuse, a = sharp raw luminance

	vec3 fluence = texture(PS_FLUENCE, uv).rgb;

	//normal.z blends light towards fluence
	//lightHeight softens directionality for taller lights.
	float directionalWeight = 1.0 / (1.0 + lightHeight * lightHeight);
	float dirAmount = clamp(adjustedNormal.z * directionalWeight, 0.0, 1.0);
	vec3 diffuse = max(vec3(0.0), mix(fluence, dir.rgb, dirAmount));
	
	//Specular: raw-luminance alpha shaped by a response curve (SPEC_FALLOFF = half-strength knee),
	//tinted by the directional hue. Scalar intensity, so lights blend instead of fighting.
	float maxC = max(dir.r, max(dir.g, dir.b));
	vec3 specHue = dir.rgb / max(maxC, 0.0001);
	
	//physically acurate:
	//specularOut = dir.a * specHue * SPEC_STRENGTH * pow(specular, SPEC_RESPONSE);
	//artistic overide (for more control for subtle and extreme surfaces):
	specularOut = dir.a * specHue * SPEC_STRENGTH * specular * pow(specular, SPEC_RESPONSE - (specular * 4.0));

	return vec4(diffuse, 1.0);
}


vec3 getRadiance(vec2 sUV){
	vec2 uv = getRadianceUV(sUV);
	return texture(PS_FLUENCE, uv).rgb;
}
