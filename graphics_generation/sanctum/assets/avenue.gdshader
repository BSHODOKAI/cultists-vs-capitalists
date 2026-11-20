shader_type spatial;
render_mode unshaded;
uniform sampler2D pavement : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 world_xz;
void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	float marking = smoothstep(0.22, 0.48, max(COLOR.r, max(COLOR.g, COLOR.b)));
	vec3 asphalt = texture(pavement, world_xz * 0.55).rgb * 1.15;
	ALBEDO = mix(asphalt, COLOR.rgb * 0.68, marking);
}
