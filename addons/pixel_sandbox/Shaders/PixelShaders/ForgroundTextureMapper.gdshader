shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/GeneralPostProcessing.gdshaderinc" //Exposure / Luminance

global uniform sampler2D PS_REFLECTION_BUFFER : filter_nearest;

uniform sampler2D backgroundTexture : filter_nearest; //For Reflections

void fragment() {
	float textureScalling = PS_RENDER_QUADRANT_SIZE.x / 512.0;
	
	//offset back the VU
	vec2 qUV = UV + PS_TILE_TEXTURE_SCROLL;
	qUV = fract(qUV);
	
	qUV = floor(qUV * PS_RENDER_QUADRANT_SIZE) / PS_RENDER_QUADRANT_SIZE;
	
	vec4 self = texture(TEXTURE, qUV);
	
	vec4 normalAndSpecular = texture(NORMAL_TEXTURE, qUV);
	vec3 norm = normalAndSpecular.rgb;
	
	vec4 custom = texture(SPECULAR_SHININESS_TEXTURE, qUV);
	float reflectiveness = custom.r;
	
	float spec = 1.0 - normalAndSpecular.a;
	float dirOffsetBlend = 1.0 - (spec * 0.5); //from 1.0 (no spec) to 0.5 (full spec)
	
	vec3 specularGI;
	vec4 radiance = getRadianceWithNormals(SCREEN_UV, norm, spec, 0.0, dirOffsetBlend, specularGI);
	radiance.rgb = brightnessExposureLuminance(radiance.rgb, 1.0, 1.0, 1.0); //brightness*exposure = gain, last arg = saturation
	radiance.rgb = pow(radiance.rgb, vec3(1.0 / 2.2));
	//Specular on top of the albedo with its own tonemap, so it isn't squashed by the diffuse correction
	vec3 specularDisplay = pow(tonemapHDR(specularGI, 1.0), vec3(1.0 / 2.2));
	
	//Calculating Reflection
	if(reflectiveness > 0.0){
		int maxDis = 16;
		int dis = maxDis;
		for(int i = 1; i < maxDis; i++){
			vec2 sampleUV = fract(UV + PS_TILE_TEXTURE_SCROLL) - vec2(0.0, float(i) * TEXTURE_PIXEL_SIZE.y);
			sampleUV = fract(sampleUV);
			if(texture(SPECULAR_SHININESS_TEXTURE, sampleUV).r != reflectiveness){ //not the same material
				dis = i;
				break;
			}
		}
		
		vec4 backgroundReflection = texture(backgroundTexture, qUV - vec2(0.0, float((dis) * 2) * TEXTURE_PIXEL_SIZE.y));
		vec4 foregroundReflection = texture(TEXTURE, vec2(qUV.x, qUV.y - float((dis) * 2) * TEXTURE_PIXEL_SIZE.y));
		vec4 tileReflection = mix(backgroundReflection, foregroundReflection, foregroundReflection.a); //prioritize foregorund reflection over backgorund
		//tileReflection.a *= clamp(ceil(tileReflection.r + tileReflection.g + tileReflection.b), 0.0, 1.0); //ignore black
		
		vec4 objectReflection = texture(PS_REFLECTION_BUFFER, getReflectionUV(UV - vec2(0.0, float((dis) * 2) / PS_RENDER_QUADRANT_SIZE.y)));
		vec4 finalReflection = mix(tileReflection, objectReflection, objectReflection.a); //prioritize object reflections over foreground / background reflection
		
		float mixMult = smoothstep(0.0, 0.75, float(maxDis - dis) / float(maxDis)); //1.0 when on edge, 0.0 when far away
		self = mix(self, finalReflection, reflectiveness * mixMult * finalReflection.a);
	}
	
	self = vec4(self.rgb * (radiance.rgb + specularDisplay), self.a);
	
	COLOR = self;
}
