shader_type spatial;

// A nonnegative override freezes only visual time for repeatable review.
uniform float review_time = -1.0;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

varying vec3 world_v;
varying vec3 world_n;

void vertex() {
	world_v = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float clock = review_time >= 0.0 ? review_time : TIME;
	float s = max(0.0, sin(UV.x * 3.14159265));
	float edge = pow(s, 1.68);
	float slant = UV.x + (UV.y - 0.32) * 0.16;
	float band_a = 0.5 + 0.5 * sin(slant * 6.0 + clock * 0.36 + world_v.x * 0.10);
	float band_b = 0.5 + 0.5 * cos(slant * 10.2 - clock * 0.25 + world_v.z * 0.08);
	float band_c = pow(0.5 + 0.5 * sin(slant * 17.5 + clock * 0.52 - world_v.x * 0.06), 2.0);
	float rays = mix(0.72, 1.28, band_a * 0.48 + band_b * 0.28 + band_c * 0.24);
	float vertical_fade = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.55) * smoothstep(0.0, 0.20, UV.y);
	float depth = max(-world_v.y, 0.0);
	vec3 transmission = exp(-vec3(0.042, 0.017, 0.009) * depth);
	vec3 warm_top = mix(vec3(0.68, 0.94, 0.98), vec3(0.98, 0.97, 0.86), 1.0 - smoothstep(0.0, 22.0, depth));
	ALBEDO = warm_top * transmission;
	float depth_fade = 1.0 - smoothstep(30.0, 120.0, depth);
	float camera_depth = max(-CAMERA_POSITION_WORLD.y, 0.0);
	float column_visibility = 1.0 - smoothstep(85.0, 190.0, camera_depth);
	vec3 to_camera = CAMERA_POSITION_WORLD - world_v;
	float camera_distance = length(to_camera);
	vec3 view_dir = to_camera / max(camera_distance, 0.001);
	float facing_fade = smoothstep(0.18, 0.56, abs(dot(normalize(world_n), view_dir)));
	float close_fade = smoothstep(0.9, 4.5, camera_distance);
	ALPHA = edge * rays * vertical_fade * depth_fade * column_visibility * facing_fade * close_fade * 0.064;
}
