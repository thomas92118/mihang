shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 field_color : source_color = vec4(0.08, 0.4, 1.0, 1.0);
uniform float opacity = 0.35;
varying vec3 sphere_position;

void vertex() {
	sphere_position = VERTEX;
}

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.4);
	float latitude = pow(0.5 + 0.5 * sin(sphere_position.y * 40.0), 24.0);
	float longitude = pow(0.5 + 0.5 * sin(atan(sphere_position.z, sphere_position.x) * 24.0), 24.0);
	ALBEDO = field_color.rgb;
	EMISSION = field_color.rgb * 1.5;
	ALPHA = opacity * clamp(rim * 0.85 + latitude * 0.25 + longitude * 0.18, 0.0, 1.0);
}
