shader_type canvas_item;
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/RadianceCascades.gdshaderinc" //Radiance Cascades
#include "res://addons/pixel_sandbox/Shaders/ShaderIncludes/GeneralPostProcessing.gdshaderinc" //Exposure / Luminance

global uniform vec2 PS_TILE_TEXTURE_SCROLL;

void fragment() {
	float textureScalling = PS_RENDER_QUADRANT_SIZE.x / 512.0;
	
	//offset back the VU
	vec2 qUV = UV + PS_TILE_TEXTURE_SCROLL - vec2(0.5, 0.5);
	qUV = fract(qUV);
	
	qUV = floor(qUV * PS_RENDER_QUADRANT_SIZE) / PS_RENDER_QUADRANT_SIZE;
	
	vec4 self = texture(TEXTURE, qUV);
	
	vec4 normalAndSpecular = texture(NORMAL_TEXTURE, qUV);
	vec3 norm = normalAndSpecular.rgb;
	float spec = 1.0 - normalAndSpecular.a;
	
	vec4 radiance = getRadianceWithNormals(SCREEN_UV, norm, spec);
	radiance.rgb = pow(radiance.rgb, vec3(1.0 / 2.2));
	radiance.rgb = brightnessExposureLuminance(radiance.rgb, 2.0, 2.0, 2.0);
	//radiance.rgb = brightnessExposureLuminance(radiance.rgb, 2.0 + spec, 2.0 + spec, 2.0 + spec);
	radiance.rgb = clamp(radiance.rgb, vec3(0.0), vec3(1.0 + spec));
	
	COLOR = self * radiance;
	//COLOR.rgb = norm.rgb;
	//COLOR.rgb += highlights * radiance.rgb;
	//COLOR.rgb = mix(COLOR.rgb, highlights, highlights);
}
