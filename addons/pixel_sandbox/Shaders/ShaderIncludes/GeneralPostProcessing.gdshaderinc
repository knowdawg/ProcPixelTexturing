
float ppLuminance(vec3 c){
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

//Manual slider: the input luminance that maps to (near) full white. Lower = highlights roll
//off to white sooner; higher = colours stay coloured further up the range before whitening.
const float TONEMAP_WHITE = 12.0;

//HDR tonemap for unbounded (0..inf) input, with an explicit saturation control.
//  saturation = 0 -> per-channel (filmic): bright colours wash toward white. Natural, duller.
//             = 1 -> luminance-only (chroma preserved): bright colours keep their hue. Vibrant.
//Blend between the two to taste; ~0.8 keeps colour without going neon.
vec3 tonemapHDR(vec3 color, float saturation){
	float w2 = TONEMAP_WHITE * TONEMAP_WHITE;

	//Per-channel extended Reinhard: each channel compressed on its own, so the brighter a
	//channel gets the more the others "catch up" -> highlights desaturate toward white.
	vec3 filmic = color * (1.0 + color / w2) / (1.0 + color);

	//Luminance-only extended Reinhard with the original chroma re-applied: the ratio between
	//channels is untouched, so the colour keeps its full saturation as it brightens.
	float l = ppLuminance(color);
	float lOut = l * (1.0 + l / w2) / (1.0 + l);
	vec3 vibrant = color * (lOut / max(l, 1e-5));

	return max(vec3(0.0), mix(filmic, vibrant, saturation));
}

//brightness * exposure = overall HDR exposure. With true 0..inf emitters this should be SMALL
//(start near 1, not the old 10x3) - the tonemap above does the highlight rolloff, not the gain.
//saturation = 0 (natural) .. 1 (vibrant). The tonemap runs LAST so the result lands in [0,1].
vec3 brightnessExposureLuminance(vec3 color, float brightness, float exposure, float saturation){
	color = color * (brightness * exposure);
	return tonemapHDR(color, saturation);
}
