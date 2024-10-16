shader_type spatial;

uniform sampler2D albedo: filter_nearest;

void vertex() {
}

void fragment() {
	ALBEDO = texture(albedo, UV).rgb;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
