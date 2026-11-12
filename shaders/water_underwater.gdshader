shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never, world_vertex_coords;

uniform sampler2D ripple_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 sun_direction = vec3(0.18, 0.93, 0.33);

varying vec3 world_pos;
varying vec2 swell_slope;

void vertex() {
	vec3 phase = vec3(dot(VERTEX.xz, vec2(0.16, 0.06)),
		dot(VERTEX.xz, vec2(-0.09, 0.24)), dot(VERTEX.xz, vec2(0.31, 0.19)))
		- TIME * vec3(0.72, 0.91, 1.17);
	VERTEX.y += dot(sin(phase), vec3(0.28, 0.16, 0.08));
	vec3 slope = cos(phase) * vec3(0.28, 0.16, 0.08);
	swell_slope = vec2(dot(slope, vec3(0.16, -0.09, 0.31)), dot(slope, vec3(0.06, 0.24, 0.19)));
	world_pos = VERTEX;
}

void fragment() {
	vec2 drift = TIME * vec2(0.014, -0.009);
	vec2 broad = texture(ripple_normal, world_pos.xz * 0.035 + drift).rg * 2.0 - 1.0;
	vec2 fine = texture(ripple_normal, world_pos.zx * 0.083 - drift * 1.31).gr * 2.0 - 1.0;
	float distance_to_camera = length(CAMERA_POSITION_WORLD - world_pos);
	float detail_fade = 1.0 - smoothstep(25.0, 120.0, distance_to_camera);
	vec2 slope = -swell_slope + broad * mix(0.04, 0.16, detail_fade) + fine * (0.03 * detail_fade);
	vec3 water_normal = normalize(vec3(slope.x, 1.0, slope.y));
	vec3 facing_normal = -water_normal;
	NORMAL = normalize((VIEW_MATRIX * vec4(facing_normal, 0.0)).xyz);
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - world_pos);
	float facing = clamp(dot(facing_normal, to_camera), 0.0, 1.0);
	float fresnel = 0.0204 + 0.9796 * pow(1.0 - facing, 5.0);
	ROUGHNESS = mix(0.35, 0.5, 1.0 - detail_fade);
	METALLIC = 0.0;
	SPECULAR = 0.10;

	// Snell's window closes into total internal reflection at grazing angles.
	float window = smoothstep(0.64, 0.72, facing);
	vec3 sky_ray = refract(-to_camera, facing_normal, 1.333);
	float sun_glow = smoothstep(0.96, 0.992, max(dot(sky_ray, sun_direction), 0.0));
	vec3 skylight = mix(vec3(0.13, 0.48, 0.66), vec3(0.60, 0.86, 0.87), max(sky_ray.y, 0.0));
	vec3 transmission = exp(-vec3(0.045, 0.018, 0.009) * distance_to_camera);
	vec3 reflection_ray = reflect(-to_camera, facing_normal);
	vec3 reflected_water = mix(vec3(0.015, 0.15, 0.28), vec3(0.04, 0.32, 0.44), pow(1.0 - abs(reflection_ray.y), 2.5));
	float camera_depth = max(-CAMERA_POSITION_WORLD.y, 0.0);
	// A surface window can illuminate the shelf, but it cannot remain a
	// luminous blue ceiling above a 600 m trench. Extinguish scattered light
	// first, then fade the distant transparent surface into the water column.
	float skylight_visibility = 1.0 - smoothstep(95.0, 240.0, camera_depth);
	ALBEDO = vec3(0.035, 0.13, 0.18) * skylight_visibility;
	EMISSION = mix(reflected_water, skylight + vec3(1.0, 0.95, 0.82) * sun_glow * 1.4,
		window * (1.0 - fresnel)) * transmission * skylight_visibility;
	ALPHA = 1.0 - smoothstep(180.0, 300.0, camera_depth);
}
