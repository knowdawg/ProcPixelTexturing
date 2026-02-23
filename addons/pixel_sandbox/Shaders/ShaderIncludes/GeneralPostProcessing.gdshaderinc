
vec3 applyExposure(vec3 color, float exposure) {
    return 1.0 - exp(-color * exposure);
}

vec3 boostLuminance(vec3 color, float luminance) {
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    vec3 normalized = color / max(lum, 0.0001);
    return normalized * lum * luminance;
}

vec3 brightnessExposureLuminance(vec3 color, float brightness, float exposure, float luminance){
	return boostLuminance(applyExposure(color * brightness, exposure), luminance);
}