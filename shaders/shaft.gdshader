shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

varying vec3 world_v;

void vertex() {
	world_v = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = max(0.0, sin(UV.x * 3.14159));
	float edge = pow(s, 2.0);
	float streak_a = 0.5 + 0.5 * sin(UV.x * 18.0 + TIME * 0.65 + world_v.x * 0.15);
	float streak_b = 0.5 + 0.5 * cos(UV.x * 31.0 - TIME * 0.48 + world_v.z * 0.12);
	float rays = mix(0.65, 1.35, streak_a * 0.6 + streak_b * 0.4);
	float vertical_fade = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.35) * smoothstep(0.0, 0.12, UV.y);
	float depth = max(-world_v.y, 0.0);
	vec3 transmission = exp(-vec3(0.055, 0.024, 0.014) * depth);
	ALBEDO = vec3(0.78, 0.86, 0.82) * transmission;
	float depth_fade = 1.0 - smoothstep(30.0, 120.0, depth);
	float camera_depth = max(-CAMERA_POSITION_WORLD.y, 0.0);
	float column_visibility = 1.0 - smoothstep(85.0, 190.0, camera_depth);
	ALPHA = edge * rays * vertical_fade * depth_fade * column_visibility * 0.046;
}
