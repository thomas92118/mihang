shader_type spatial;

uniform sampler2D sediment_noise : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D region_palette : source_color, filter_nearest, repeat_disable;
uniform bool use_region_palette = false;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float sediment(vec3 position, vec3 weights) {
	// Project onto all three axes so cliff faces retain the same texture scale.
	// For predominantly horizontal seabed (>94% vertical normal), sample XZ directly to save 66% texture bandwidth.
	if (weights.y > 0.94) {
		return texture(sediment_noise, position.xz).r;
	}
	return texture(sediment_noise, position.yz).r * weights.x
		+ texture(sediment_noise, position.xz).r * weights.y
		+ texture(sediment_noise, position.xy).r * weights.z;
}

void blend_region(vec2 center, float radius, float column, inout vec3 sand_color, inout vec3 rock_color, inout float total) {
	float weight = 1.0 - smoothstep(radius * 0.30, radius, length(world_pos.xz - center));
	if (weight > 0.0) {
		sand_color += texture(region_palette, vec2((column + 0.5) / 9.0, 0.25)).rgb * weight;
		rock_color += texture(region_palette, vec2((column + 0.5) / 9.0, 0.75)).rgb * weight;
		total += weight;
	}
}

void fragment() {
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= dot(weights, vec3(1.0));
	float distance_to_camera = length(VERTEX);
	float grain_fade = 1.0 - smoothstep(1.5, 9.0, distance_to_camera);
	float patch = sediment(world_pos * 0.004, weights);
	float meso = sediment(world_pos * 0.018, weights);
	float detail = sediment(world_pos * 0.07, weights);
	float gravel = sediment(world_pos * 0.45, weights);
	// Skip high-frequency grain sampling beyond its fade distance (14m)
	float grain = grain_fade > 0.005 ? sediment(world_pos * 6.0, weights) : 0.5;
	float depth = max(-world_pos.y, 0.0);
	// Geological transitions use actual seabed depth, not the diver's depth.
	// A little patch variation avoids ruler-straight boundaries at each contour.
	float substrate_depth = depth + (patch - 0.5) * 10.0;
	float shelf = smoothstep(28.0, 44.0, substrate_depth);
	float slope = smoothstep(78.0, 104.0, substrate_depth);
	float basin = smoothstep(184.0, 224.0, substrate_depth);
	float hadal = smoothstep(340.0, 390.0, substrate_depth);
	float shelf_band = shelf * (1.0 - slope);
	float slope_band = slope * (1.0 - basin);
	float steep = smoothstep(0.12, 0.46, 1.0 - abs(world_normal.y));
	float sand = (1.0 - steep) * (1.0 - shelf * 0.32) * (1.0 - slope * 0.94);
	float stones = smoothstep(0.55, 0.8, gravel)
		* smoothstep(0.42, 0.68, patch + steep * 0.18 + shelf_band * 0.18);
	stones *= 1.0 - basin * 0.65;

	// Rounded manganese nodules occur in patches on the deepest soft sediments.
	// Warp cell coordinates with organic sediment noise so nodules never align to a grid.
	vec2 nodule_warp = vec2(meso - 0.5, patch - 0.5) * 2.8 + vec2(detail - 0.5, gravel - 0.5) * 0.85;
	vec2 nodule_grid = world_pos.xz * 1.45 + nodule_warp;
	vec2 nodule_cell = floor(nodule_grid);
	vec2 nodule_seed = fract(sin(vec2(dot(nodule_cell, vec2(127.1, 311.7)),
		dot(nodule_cell, vec2(269.5, 183.3)))) * 43758.5453);
	vec2 nodule_offset = fract(nodule_grid) - mix(vec2(0.16), vec2(0.84), nodule_seed);
	float nodule_radius = mix(0.10, 0.22, nodule_seed.x);
	float nodule_shape = max(1.0 - dot(nodule_offset, nodule_offset) / (nodule_radius * nodule_radius), 0.0);
	float nodule_patch = hadal * (1.0 - steep) * step(0.68, nodule_seed.y)
		* smoothstep(0.42, 0.72, meso) * (1.0 - smoothstep(20.0, 52.0, distance_to_camera));
	float nodules = smoothstep(0.0, 0.16 + fwidth(nodule_shape), nodule_shape) * nodule_patch;

	// Weathered sedimentary layers follow elevation, including on cliff faces.
	float strata_wave = sin(world_pos.y * 0.95 + patch * 3.0 + meso * 1.7) * 0.65
		+ cos(world_pos.y * 0.35 - detail * 1.2) * 0.35;
	float strata_band = smoothstep(-0.35, 0.45, strata_wave);
	float terrace_line = 1.0 - smoothstep(0.0, 0.16, abs(fract(world_pos.y * 0.38 + patch * 0.4) - 0.5));

	// Half-meter sand ridges stay fixed on the seabed; only the light moves.
	float phase = dot(world_pos.xz, vec2(0.92, 0.39)) * 8.0 + patch * 5.0 + detail * 0.9;
	float ripple_fade = (1.0 - smoothstep(18.0, 65.0, distance_to_camera))
		* (1.0 - smoothstep(0.4, 2.0, fwidth(phase))) * sand;
	float ridge = pow(0.5 + 0.5 * sin(phase), 2.0);
	float exposed_rock = max(steep, slope_band * smoothstep(0.28, 0.64, meso));
	float height = ridge * 0.011 * ripple_fade + detail * mix(0.008, 0.040, exposed_rock)
		+ strata_band * 0.022 * exposed_rock
		+ stones * mix(0.002, 0.008, shelf_band) + grain * 0.00018 * grain_fade
		+ pow(nodule_shape, 1.5) * nodule_patch * 0.018;

	// Surface-gradient bump mapping needs no mesh UVs or extra collision geometry.
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float determinant = dot(dpdx, r1);
	NORMAL = normalize(abs(determinant) * NORMAL
		- sign(determinant) * (dFdx(height) * r1 + dFdy(height) * r2));

	// Keep the sediment's actual pigment neutral. Blue-green water comes from
	// light absorption, so a diver's lamp can reveal the original warm colour.
	float sediment_mix = smoothstep(0.24, 0.78, patch * 0.65 + meso * 0.35);
	vec3 shallow_sand = mix(vec3(0.35, 0.29, 0.19), vec3(0.50, 0.43, 0.30), sediment_mix);
	float algae_mask = smoothstep(0.57, 0.82, meso + detail * 0.24)
		* (1.0 - smoothstep(20.0, 52.0, depth));
	float coralline_mask = smoothstep(0.63, 0.90, (1.0 - meso) + patch * 0.18)
		* (1.0 - smoothstep(28.0, 58.0, depth));
	vec3 shelf_gravel = mix(vec3(0.28, 0.31, 0.25), vec3(0.45, 0.47, 0.36), sediment_mix);
	shelf_gravel = mix(shelf_gravel, vec3(0.30, 0.29, 0.25), stones * 0.42);
	vec3 slope_scree = mix(vec3(0.26, 0.28, 0.26), vec3(0.47, 0.46, 0.39), sediment_mix);
	vec3 basin_silt = mix(vec3(0.23, 0.21, 0.18), vec3(0.43, 0.39, 0.32), sediment_mix);
	vec3 hadal_clay = mix(vec3(0.19, 0.19, 0.17), vec3(0.35, 0.33, 0.28), sediment_mix);
	vec3 seabed_palette = mix(shallow_sand, shelf_gravel, shelf);
	seabed_palette = mix(seabed_palette, slope_scree, slope);
	seabed_palette = mix(seabed_palette, basin_silt, basin);
	seabed_palette = mix(seabed_palette, hadal_clay, hadal);
	seabed_palette = mix(seabed_palette, vec3(0.26, 0.30, 0.18), algae_mask * 0.24);

	vec3 cliff_dark = vec3(0.22, 0.30, 0.29);
	vec3 cliff_light = vec3(0.50, 0.57, 0.50);
	vec3 rock = mix(cliff_dark, cliff_light, detail * 0.64 + strata_band * 0.36);
	if (use_region_palette) {
		vec3 regional_sand = vec3(0.0);
		vec3 regional_rock = vec3(0.0);
		float total = 0.0;
		blend_region(vec2(40.0, 340.0), 255.0, 1.0, regional_sand, regional_rock, total);
		blend_region(vec2(-260.0, 280.0), 200.0, 2.0, regional_sand, regional_rock, total);
		blend_region(vec2(380.0, 290.0), 220.0, 3.0, regional_sand, regional_rock, total);
		blend_region(vec2(460.0, -60.0), 245.0, 4.0, regional_sand, regional_rock, total);
		blend_region(vec2(420.0, -380.0), 235.0, 5.0, regional_sand, regional_rock, total);
		blend_region(vec2(-480.0, -90.0), 250.0, 6.0, regional_sand, regional_rock, total);
		blend_region(vec2(-440.0, -420.0), 240.0, 7.0, regional_sand, regional_rock, total);
		blend_region(vec2(60.0, -640.0), 300.0, 8.0, regional_sand, regional_rock, total);
		float core_weight = max(1.0 - total, 0.0);
		regional_sand = (regional_sand + texture(region_palette, vec2(0.5 / 9.0, 0.25)).rgb * core_weight) / max(total, 1.0);
		regional_rock = (regional_rock + texture(region_palette, vec2(0.5 / 9.0, 0.75)).rgb * core_weight) / max(total, 1.0);
		seabed_palette = mix(seabed_palette, regional_sand * (0.58 + sediment_mix * 0.14), 0.42);
		rock = mix(rock, regional_rock * (0.58 + strata_band * 0.26 + detail * 0.12), 0.55);
	}
	rock = mix(rock, rock * vec3(0.83, 0.87, 0.89), basin * 0.6);
	rock = mix(rock, vec3(0.39, 0.29, 0.30), coralline_mask * 0.18);
	rock *= 1.0 - terrace_line * 0.12;
	vec3 base_color = mix(seabed_palette, rock, exposed_rock);
	base_color = mix(base_color, mix(vec3(0.065, 0.062, 0.052), vec3(0.15, 0.13, 0.10), detail), nodules);
	// Volcanic ash is local to the caldera instead of tinting every deep zone.
	float caldera = 1.0 - smoothstep(100.0, 220.0, length(world_pos.xz - vec2(-440.0, -420.0)));
	base_color = mix(base_color, mix(vec3(0.14, 0.15, 0.14), vec3(0.29, 0.27, 0.23), detail), caldera * 0.84);
	base_color *= 0.96 + detail * 0.08 + (grain - 0.5) * 0.045 * grain_fade;
	base_color *= 1.0 - stones * 0.09;
	base_color *= 1.0 - (1.0 - ridge) * 0.045 * ripple_fade;

	float fw_xz = length(fwidth(world_pos.xz));
	float caustic_lit = 0.0;
	if (depth < 46.0 && world_normal.y > 0.0) {
		float a = sin(world_pos.x * 2.3 + sin(world_pos.z * 1.7 + TIME * 0.5) + patch * 2.0 + TIME * 0.4);
		float b = sin(world_pos.z * 2.6 - sin(world_pos.x * 1.4 - TIME * 0.4) + patch * 1.7);
		float caustic = 1.0 - smoothstep(0.04, 0.08 + fw_xz * 3.4713, abs(a + b));
		float a2 = sin(world_pos.x * 4.1 - cos(world_pos.z * 3.2 - TIME * 0.65) + meso * 3.0);
		float b2 = cos(world_pos.z * 3.8 + sin(world_pos.x * 2.9 + TIME * 0.55) - patch * 2.2);
		float caustic_fine = (1.0 - smoothstep(0.05, 0.12 + fw_xz * 5.5902, abs(a2 + b2))) * 0.52;
		float caustic_fade = exp(-depth * 0.075) * (1.0 - smoothstep(22.0, 46.0, depth))
			* world_normal.y;
		caustic_lit = (caustic + caustic_fine * 0.55) * caustic_fade * 0.15;
	}
	ALBEDO = base_color * (1.0 + caustic_lit);
	EMISSION = vec3(0.0);
	ROUGHNESS = clamp(0.86 + basin * 0.06 - stones * 0.10 - nodules * 0.24, 0.64, 0.96);
	SPECULAR = 0.22;
	AO = 1.0 - (1.0 - ridge) * 0.10 * ripple_fade - stones * 0.08
		- terrace_line * exposed_rock * 0.12 - nodules * 0.08;
}

void light() {
	float depth = max(-world_pos.y, 0.0);
	// The environment sets sunlight energy at camera depth. Correct for the
	// actual seabed depth, then absorb red/green relative to blue. This avoids
	// dimming sunlight twice and keeps a deep floor dark from a shallow camera.
	float camera_depth = max(-INV_VIEW_MATRIX[3].y, 0.0);
	float depth_correction = exp(clamp((camera_depth - depth) * 0.012, -8.0, 7.2));
	vec3 transmission = LIGHT_IS_DIRECTIONAL
		? exp(-vec3(0.022, 0.0055, 0.0) * depth) * depth_correction : vec3(1.0);
	DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * LIGHT_COLOR * transmission * ATTENUATION / PI;
}
