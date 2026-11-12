shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 field_color : source_color = vec4(0.08, 0.4, 1.0, 1.0);
uniform float opacity = 0.35;
varying vec3 sphere_position;

void vertex() {
	sphere_position = VERTEX;
}

void fragment() {
	float fresnel = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = smoothstep(0.42, 0.68, fresnel) * 0.65 + smoothstep(0.78, 0.88, fresnel) * 0.45;
	float latitude = step(0.92, 0.5 + 0.5 * sin(sphere_position.y * 28.0));
	float longitude = step(0.92, 0.5 + 0.5 * sin(atan(sphere_position.z, sphere_position.x) * 18.0));
	ALBEDO = field_color.rgb;
	EMISSION = mix(field_color.rgb, vec3(0.55, 0.98, 1.0), 0.35) * 1.85;
	ALPHA = opacity * clamp(rim * 0.9 + latitude * 0.32 + longitude * 0.24, 0.0, 1.0);
}
