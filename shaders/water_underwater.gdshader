shader_type spatial;

// A nonnegative override freezes only visual time for repeatable review.
uniform float review_time = -1.0;
render_mode cull_disabled, blend_mix, depth_draw_never, world_vertex_coords;

uniform sampler2D ripple_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 sun_direction = vec3(0.18, 0.93, 0.33);

varying vec3 world_pos;
varying vec2 swell_slope;

void vertex() {
	float anim_time = review_time >= 0.0 ? review_time : mod(TIME, 3600.0);
	vec3 phase = vec3(dot(VERTEX.xz, vec2(0.16, 0.06)),
		dot(VERTEX.xz, vec2(-0.09, 0.24)), dot(VERTEX.xz, vec2(0.31, 0.19)))
		- anim_time * vec3(0.72, 0.91, 1.17);
	VERTEX.y += dot(sin(phase), vec3(0.28, 0.16, 0.08));
	vec3 slope = cos(phase) * vec3(0.28, 0.16, 0.08);
	swell_slope = vec2(dot(slope, vec3(0.16, -0.09, 0.31)), dot(slope, vec3(0.06, 0.24, 0.19)));
	// Keep the same authored swell above and below the air-water interface.
	float long_phase = dot(VERTEX.xz, vec2(0.045, -0.025))
		- anim_time * 0.42;
	VERTEX.y += sin(long_phase) * 0.36;
	swell_slope += cos(long_phase) * vec2(0.045, -0.025) * 0.36;
	world_pos = VERTEX;
}

void fragment() {
	float anim_time = review_time >= 0.0 ? review_time : mod(TIME, 3600.0);
	vec2 drift = anim_time * vec2(0.014, -0.009);
	vec2 broad = texture(ripple_normal, world_pos.xz * 0.035 + drift).rg * 2.0 - 1.0;
	vec2 fine = texture(ripple_normal, world_pos.zx * 0.083 - drift * 1.31).gr * 2.0 - 1.0;
	float distance_to_camera = length(CAMERA_POSITION_WORLD - world_pos);
	float detail_fade = 1.0 - smoothstep(25.0, 120.0, distance_to_camera);
	vec2 slope = -swell_slope + broad * mix(0.05, 0.20, detail_fade) + fine * (0.05 * detail_fade);
	vec3 water_normal = normalize(vec3(slope.x, 1.0, slope.y));
	vec3 facing_normal = -water_normal;
	NORMAL = normalize((VIEW_MATRIX * vec4(facing_normal, 0.0)).xyz);
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - world_pos);
	float facing = clamp(dot(facing_normal, to_camera), 0.0, 1.0);
	float fresnel = 0.0204 + 0.9796 * pow(1.0 - facing, 5.0);
	ROUGHNESS = mix(0.26, 0.44, 1.0 - detail_fade);
	METALLIC = 0.0;
	SPECULAR = 0.16;

	// Snell's window closes into total internal reflection at grazing angles.
	float window = smoothstep(0.58, 0.73, facing);
	vec3 sky_ray = refract(-to_camera, facing_normal, 1.333);
	float sun_glow = smoothstep(0.94, 0.993, max(dot(sky_ray, sun_direction), 0.0));
	vec3 skylight = mix(vec3(0.16, 0.58, 0.74), vec3(0.74, 0.94, 0.92), max(sky_ray.y, 0.0));
	vec3 transmission = exp(-vec3(0.045, 0.018, 0.009) * distance_to_camera);
	vec3 reflection_ray = reflect(-to_camera, facing_normal);
	vec3 reflected_water = mix(vec3(0.018, 0.19, 0.32), vec3(0.08, 0.46, 0.56), pow(1.0 - abs(reflection_ray.y), 2.2));
	float crest_rim = smoothstep(0.14, 0.32, length(slope)) * (1.0 - window) * detail_fade;
	float camera_depth = max(-CAMERA_POSITION_WORLD.y, 0.0);
	// A surface window can illuminate the shelf, but it cannot remain a
	// luminous blue ceiling above a 600 m trench. Extinguish scattered light
	// first, then fade the distant transparent surface into the water column.
	float skylight_visibility = 1.0 - smoothstep(95.0, 240.0, camera_depth);
	ALBEDO = vec3(0.04, 0.17, 0.24) * skylight_visibility;
	EMISSION = (mix(reflected_water, skylight + vec3(1.0, 0.96, 0.82) * sun_glow * 1.65,
		window * (1.0 - fresnel)) + vec3(0.28, 0.72, 0.76) * crest_rim * 0.18) * transmission * skylight_visibility;
	// The far grazing surface hands over to the same water atmosphere. A fully
	// opaque, infinitely dark reflection here creates a ruler-straight horizon.
	float grazing_fade = smoothstep(0.015, 0.24, facing);
	float horizon_fade = (1.0 - smoothstep(55.0, 190.0, distance_to_camera)) * grazing_fade;
	ALPHA = (1.0 - smoothstep(180.0, 300.0, camera_depth)) * horizon_fade;
}
