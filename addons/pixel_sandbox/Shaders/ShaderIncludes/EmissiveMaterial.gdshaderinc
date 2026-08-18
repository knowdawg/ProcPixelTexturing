
group_uniforms emission_params;
uniform bool isEmissive = false;
uniform float energy  = 1.0;
uniform float density = 0.0;

//Must use a Pre-Mult blend mode, always pass in color, even when not emmisive
vec4 EmissiveTransform(vec4 c) {
	if(!isEmissive){
		return vec4(c.rgb * c.a, c.a);;
	}
	
	c.rgb *= c.a; //Premultiply Alpha
	return vec4(c.rgb * energy, density * c.a);
}