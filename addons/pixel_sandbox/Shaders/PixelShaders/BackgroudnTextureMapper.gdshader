shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/GeneralPostProcessing.gdshaderinc" //Exposure / Luminance

//filter_linear: since background reflections are jagged, linear filtering helps smooth them out. Since uv is still quantized, keeps pixel perfect apearance
global uniform sampler2D PS_REFLECTION_BUFFER : filter_linear;

uniform sampler2D foregroundTexture : filter_linear_mipmap; //For Reflections

void fragment() {
	float textureScalling = PS_RENDER_QUADRANT_SIZE.x / 512.0;
	vec2 qUV = UV + PS_TILE_TEXTURE_SCROLL;
	qUV = fract(qUV);
	qUV = floor(qUV * PS_RENDER_QUADRANT_SIZE) / PS_RENDER_QUADRANT_SIZE;
	
	vec4 self = texture(TEXTURE, qUV);
	
	vec4 normalAndSpecular = texture(NORMAL_TEXTURE, qUV);
	vec3 norm = normalAndSpecular.rgb;
	float spec = 1.0 - normalAndSpecular.a;
	
	vec4 custom = texture(SPECULAR_SHININESS_TEXTURE, qUV);
	float reflectiveness = custom.r;
	
	vec3 specularGI;
	vec4 radiance = getRadianceWithNormals(SCREEN_UV, norm, spec, 1.0, 0.5, specularGI);
	radiance.rgb = brightnessExposureLuminance(radiance.rgb, 1.0, 1.0, 1.0); //brightness*exposure = gain, last arg = saturation
	radiance.rgb = pow(radiance.rgb, vec3(1.0 / 2.2));

	//Specular on top of the albedo with its own tonemap, so it isn't squashed by the diffuse correction
	vec3 specularDisplay = pow(tonemapHDR(specularGI, 1.0), vec3(1.0 / 2.2));
	
	if(reflectiveness > 0.0){
		vec3 adjustedNormal = norm.rgb * 2.0 - 1.0;
		adjustedNormal.y *= -1.0;
		vec2 dir = vec2(adjustedNormal.x, adjustedNormal.y); //normalize? more intense on softer normals, * 50 is too much
		vec2 sampleOffset = (dir * 50.0) / PS_RENDER_QUADRANT_SIZE;
		
		vec4 foregroundReflection = texture(foregroundTexture, qUV + sampleOffset * 3.0);
		foregroundReflection.rgb = mix(foregroundReflection.rgb, self.rgb, 0.5);
		
		vec4 objectReflection = texture(PS_REFLECTION_BUFFER, getReflectionUV(UV) + sampleOffset);
		vec4 finalReflection = mix(foregroundReflection, objectReflection, objectReflection.a); //prioritize object reflections over tile reflection
		
		self.rgb = mix(self.rgb, finalReflection.rgb, reflectiveness * finalReflection.a);
	}
	
	self = vec4(self.rgb * (radiance.rgb + specularDisplay), self.a);
	
	COLOR = self;
}