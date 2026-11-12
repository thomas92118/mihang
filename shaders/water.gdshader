shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never, world_vertex_coords;

uniform sampler2D ripple_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
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

float scene_depth(vec2 uv, mat4 inverse_projection) {
	float depth = textureLod(depth_texture, uv, 0.0).r;
	// Compatibility uses OpenGL's [-1, 1] NDC depth range.
	vec4 position = inverse_projection * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	return -position.z / position.w;
}

void fragment() {
	vec2 drift = TIME * vec2(0.014, -0.009);
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
		vec2 refraction_uv = SCREEN_UV + NORMAL.xy * 0.018 * edge.x * edge.y * smoothstep(0.0, 2.0, water_depth);
		// Reject distortion across foreground silhouettes.
		if (scene_depth(refraction_uv, INV_PROJECTION_MATRIX) < -VERTEX.z) {
			refraction_uv = SCREEN_UV;
		}
		float crest_foam = smoothstep(0.24, 0.36, length(slope)) * detail_fade;
		vec3 transmission = exp(-vec3(0.09, 0.028, 0.014) * water_depth);
		ALBEDO = mix(vec3(0.024, 0.22, 0.28) * (1.0 - transmission), vec3(0.88, 0.93, 0.87), crest_foam * 0.26);
		EMISSION = textureLod(screen_texture, refraction_uv, 0.0).rgb * transmission * (1.0 - fresnel) + vec3(0.69, 0.79, 0.78) * crest_foam * 0.12;
	} else {
		// Snell's window closes into total internal reflection at grazing angles.
		float window = smoothstep(0.64, 0.72, facing);
		vec3 sky_ray = refract(-to_camera, facing_normal, 1.333);
		float sun_glow = smoothstep(0.96, 0.992, max(dot(sky_ray, sun_direction), 0.0));
		vec3 skylight = mix(vec3(0.27, 0.50, 0.62), vec3(0.79, 0.87, 0.84), max(sky_ray.y, 0.0));
		vec3 transmission = exp(-vec3(0.045, 0.018, 0.009) * distance_to_camera);
		vec3 reflection_ray = reflect(-to_camera, facing_normal);
		// An inexpensive water-colour gradient keeps off-screen reflections stable.
		vec3 reflected_water = mix(vec3(0.025, 0.12, 0.20), vec3(0.09, 0.33, 0.39), pow(1.0 - abs(reflection_ray.y), 2.5));
		float camera_depth = max(-CAMERA_POSITION_WORLD.y, 0.0);
		// A surface window can illuminate the shelf, but it cannot remain a
		// luminous blue ceiling above a 600 m trench. Extinguish scattered light
		// first, then fade the distant transparent surface into the water column.
		float skylight_visibility = 1.0 - smoothstep(95.0, 240.0, camera_depth);
		ALBEDO = vec3(0.035, 0.13, 0.18) * skylight_visibility;
		EMISSION = mix(reflected_water, skylight + vec3(1.0, 0.95, 0.82) * sun_glow * 1.4,
			window * (1.0 - fresnel)) * transmission * skylight_visibility;
		surface_opacity = 1.0 - smoothstep(180.0, 300.0, camera_depth);
	}
	ALPHA = surface_opacity;
}
