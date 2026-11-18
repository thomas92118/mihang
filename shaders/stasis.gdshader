shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

uniform vec4 field_color : source_color = vec4(0.502, 0.776, 0.769, 1.0);
uniform float opacity = 0.32;
varying vec3 sphere_position;

void vertex() {
	sphere_position = VERTEX;
}

void fragment() {
	float fresnel = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float boundary = smoothstep(0.36, 0.80, fresnel) * 0.58 + smoothstep(0.78, 0.97, fresnel) * 0.54;
	float y_norm = clamp(sphere_position.y, -1.0, 1.0);
	float clock = mod(TIME, 3600.0);
	float wave = 0.5 + 0.5 * cos((y_norm * 5.0 - clock * 0.32) * 6.2831853);
	float harmonic_rings = smoothstep(0.86, 0.992, wave) * (1.0 - abs(y_norm) * 0.35);
	float equator = 1.0 - smoothstep(0.004, 0.022, abs(y_norm));
	vec3 paper_col = vec3(0.929, 0.906, 0.847);
	ALBEDO = mix(field_color.rgb, paper_col, smoothstep(0.72, 0.98, fresnel) * 0.36 + equator * 0.22);
	ALPHA = clamp(opacity * (0.14 + boundary * 0.88 + harmonic_rings * 0.28 + equator * 0.22), 0.0, 0.78);
}
