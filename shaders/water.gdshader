shader_type spatial;

// A nonnegative override freezes only visual time for repeatable review.
uniform float review_time = -1.0;
render_mode cull_disabled, blend_mix, depth_draw_never, world_vertex_coords;

uniform sampler2D ripple_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 sun_direction = vec3(0.18, 0.93, 0.33);

varying vec3 world_pos;
varying vec2 swell_slope;
varying float wave_crest;

void vertex() {
	vec3 phase = vec3(dot(VERTEX.xz, vec2(0.16, 0.06)),
		dot(VERTEX.xz, vec2(-0.09, 0.24)), dot(VERTEX.xz, vec2(0.31, 0.19)))
		- (review_time >= 0.0 ? review_time : TIME) * vec3(0.72, 0.91, 1.17);
	VERTEX.y += dot(sin(phase), vec3(0.28, 0.16, 0.08));
	vec3 slope = cos(phase) * vec3(0.28, 0.16, 0.08);
	swell_slope = vec2(dot(slope, vec3(0.16, -0.09, 0.31)), dot(slope, vec3(0.06, 0.24, 0.19)));
	// A broad fourth swell gives the surface a calm, sculpted rhythm. The
	// Blender patch resolves these long arcs and the shorter ripples nearby.
	float long_phase = dot(VERTEX.xz, vec2(0.045, -0.025))
		- (review_time >= 0.0 ? review_time : TIME) * 0.42;
	VERTEX.y += sin(long_phase) * 0.36;
	swell_slope += cos(long_phase) * vec2(0.045, -0.025) * 0.36;
	wave_crest = dot(sin(phase), vec3(0.28, 0.16, 0.08));
	world_pos = VERTEX;
}

float scene_depth(vec2 uv, mat4 inverse_projection) {
	float depth = textureLod(depth_texture, uv, 0.0).r;
	// Compatibility uses OpenGL's [-1, 1] NDC depth range.
	vec4 position = inverse_projection * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	return -position.z / position.w;
}

void fragment() {
	vec2 drift = (review_time >= 0.0 ? review_time : TIME) * vec2(0.014, -0.009);
	vec2 broad = texture(ripple_normal, world_pos.xz * 0.035 + drift).rg * 2.0 - 1.0;
	vec2 fine = texture(ripple_normal, world_pos.zx * 0.083 - drift * 1.31).gr * 2.0 - 1.0;
	float distance_to_camera = length(CAMERA_POSITION_WORLD - world_pos);
	float detail_fade = 1.0 - smoothstep(25.0, 120.0, distance_to_camera);
	vec2 slope = -swell_slope + broad * mix(0.08, 0.32, detail_fade) + fine * (0.1 * detail_fade);
	vec3 water_normal = normalize(vec3(slope.x, 1.0, slope.y));
	vec3 facing_normal = FRONT_FACING ? water_normal : -water_normal;
	NORMAL = normalize((VIEW_MATRIX * vec4(facing_normal, 0.0)).xyz);
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - world_pos);
	float facing = clamp(dot(facing_normal, to_camera), 0.0, 1.0);
	float fresnel = 0.0204 + 0.9796 * pow(1.0 - facing, 5.0);
	ROUGHNESS = mix(0.21, 0.34, 1.0 - detail_fade);
	METALLIC = 0.0;
	SPECULAR = 0.25;
	float surface_opacity = 1.0;

	if (FRONT_FACING) {
		float water_depth = max(scene_depth(SCREEN_UV, INV_PROJECTION_MATRIX) + VERTEX.z, 0.0);
		vec2 edge = smoothstep(vec2(0.0), vec2(0.06), SCREEN_UV)
			* smoothstep(vec2(0.0), vec2(0.06), 1.0 - SCREEN_UV);
		vec2 refraction_uv = SCREEN_UV + NORMAL.xy * 0.022 * edge.x * edge.y * smoothstep(0.0, 2.0, water_depth);
		// Reject distortion across foreground silhouettes.
		if (scene_depth(refraction_uv, INV_PROJECTION_MATRIX) < -VERTEX.z) {
			refraction_uv = SCREEN_UV;
		}
		// A few pearl lines at coherent crests, rather than foam on every ripple.
		float crest_thin = smoothstep(0.12, 0.44, wave_crest);
		float foam_lace = 0.5 + 0.5 * sin(world_pos.x * 3.4 + fine.x * 5.0 + world_pos.z * 2.7);
		float crest_foam = smoothstep(0.28, 0.45, wave_crest)
			* smoothstep(0.10, 0.26, length(slope)) * mix(0.65, 1.0, foam_lace) * detail_fade;
		vec3 transmission = exp(-vec3(0.078, 0.022, 0.010) * water_depth);
		vec3 body_teal = mix(vec3(0.022, 0.24, 0.34), vec3(0.09, 0.58, 0.62), crest_thin * 0.58);
		vec3 sss_glow = vec3(0.14, 0.72, 0.72) * crest_thin * pow(1.0 - facing, 2.0) * 0.24;
		vec3 refl_dir = reflect(-to_camera, facing_normal);
		vec3 sky_refl = mix(vec3(0.14, 0.46, 0.62), vec3(0.76, 0.90, 0.96), clamp(refl_dir.y * 1.4 + 0.2, 0.0, 1.0));
		float sun_spec = pow(max(dot(refl_dir, normalize(sun_direction)), 0.0), 96.0);
		ALBEDO = mix(body_teal * (1.0 - transmission), vec3(0.93, 0.96, 0.92), crest_foam * 0.42);
		EMISSION = textureLod(screen_texture, refraction_uv, 0.0).rgb * transmission * (1.0 - fresnel)
			+ sky_refl * fresnel * 0.68 + vec3(1.0, 0.94, 0.78) * sun_spec * 1.35
			+ sss_glow + vec3(0.78, 0.88, 0.86) * crest_foam * 0.20;
	} else {
		// Snell's window closes into total internal reflection at grazing angles.
		float window = smoothstep(0.60, 0.74, facing);
		vec3 sky_ray = refract(-to_camera, facing_normal, 1.333);
		float sun_glow = smoothstep(0.945, 0.994, max(dot(sky_ray, sun_direction), 0.0));
		vec3 skylight = mix(vec3(0.22, 0.58, 0.72), vec3(0.84, 0.93, 0.90), max(sky_ray.y, 0.0));
		vec3 transmission = exp(-vec3(0.045, 0.018, 0.009) * distance_to_camera);
		vec3 reflection_ray = reflect(-to_camera, facing_normal);
		// An inexpensive water-colour gradient keeps off-screen reflections stable.
		vec3 reflected_water = mix(vec3(0.022, 0.16, 0.28), vec3(0.11, 0.46, 0.54), pow(1.0 - abs(reflection_ray.y), 2.2));
		float camera_depth = max(-CAMERA_POSITION_WORLD.y, 0.0);
		// A surface window can illuminate the shelf, but it cannot remain a
		// luminous blue ceiling above a 600 m trench. Extinguish scattered light
		// first, then fade the distant transparent surface into the water column.
		float skylight_visibility = 1.0 - smoothstep(95.0, 240.0, camera_depth);
		ALBEDO = vec3(0.04, 0.18, 0.25) * skylight_visibility;
		EMISSION = mix(reflected_water, skylight + vec3(1.0, 0.95, 0.80) * sun_glow * 1.65,
			window * (1.0 - fresnel)) * transmission * skylight_visibility;
		float grazing_fade = smoothstep(0.015, 0.24, facing);
		float horizon_fade = (1.0 - smoothstep(55.0, 190.0, distance_to_camera)) * grazing_fade;
		surface_opacity = (1.0 - smoothstep(180.0, 300.0, camera_depth)) * horizon_fade;
	}
	ALPHA = surface_opacity;
}
