shader_type canvas_item;
render_mode blend_premul_alpha;

uniform float energy  = 1.0;
uniform float density = 0.0;

group_uniforms emission_color_override;
uniform bool override = false;
uniform vec3  emission : source_color = vec3(1.0);


varying vec4 modulated_color;
void vertex() {
    modulated_color = COLOR;
}

void fragment(){
	vec4 tex = texture(TEXTURE, UV);
	float shape = tex.a;//silhouette
	
	
	
	vec3 emissionColor = modulated_color.rgb;
	if (override){
		emissionColor = emission;
	}
	
	COLOR = vec4(emissionColor * energy * shape, density * shape);
}