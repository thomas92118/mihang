shader_type spatial;

uniform sampler2D sediment_noise : repeat_enable, filter_linear_mipmap_anisotropic;
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

void fragment() {
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= dot(weights, vec3(1.0));
	float distance_to_camera = length(VERTEX);
	float grain_fade = 1.0 - smoothstep(2.0, 14.0, distance_to_camera);
	float patch = sediment(world_pos * 0.004, weights);
	float detail = sediment(world_pos * 0.07, weights);
	float gravel = sediment(world_pos * 0.45, weights);
	// Skip high-frequency grain sampling beyond its fade distance (14m)
	float grain = grain_fade > 0.005 ? sediment(world_pos * 6.0, weights) : 0.5;
	float depth = max(-world_pos.y, 0.0);
	float deep = smoothstep(22.0, 72.0, depth + (patch - 0.5) * 12.0);
	float steep = smoothstep(0.12, 0.46, 1.0 - abs(world_normal.y));
	float sand = (1.0 - steep) * (1.0 - deep * 0.8);
	float stones = smoothstep(0.55, 0.8, gravel)
		* smoothstep(0.45, 0.68, patch + steep * 0.18 + deep * 0.1);

	// Half-meter sand ridges stay fixed on the seabed; only the light moves.
	float phase = dot(world_pos.xz, vec2(0.92, 0.39)) * 12.0 + patch * 6.0 + detail * 1.4;
	float ripple_fade = (1.0 - smoothstep(18.0, 65.0, distance_to_camera))
		* (1.0 - smoothstep(0.4, 2.0, fwidth(phase))) * sand;
	float ridge = pow(0.5 + 0.5 * sin(phase), 2.0);
	float height = ridge * 0.014 * ripple_fade + detail * mix(0.018, 0.065, steep)
		+ stones * 0.003 + grain * 0.0003 * grain_fade;

	// Surface-gradient bump mapping needs no mesh UVs or extra collision geometry.
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float determinant = dot(dpdx, r1);
	NORMAL = normalize(abs(determinant) * NORMAL
		- sign(determinant) * (dFdx(height) * r1 + dFdy(height) * r2));

	vec3 shallow_sand = mix(vec3(0.54, 0.38, 0.3), vec3(0.78, 0.6, 0.46), patch);
	vec3 deep_silt = mix(vec3(0.075, 0.1, 0.12), vec3(0.16, 0.18, 0.18), patch);
	vec3 rock = mix(vec3(0.12, 0.16, 0.17), vec3(0.27, 0.29, 0.26), detail) * (1.0 - deep * 0.35);
	vec3 base_color = mix(mix(shallow_sand, deep_silt, deep), rock, steep);
	base_color *= 0.86 + detail * 0.22 + (grain - 0.5) * 0.16 * grain_fade;
	base_color = mix(base_color, base_color * 0.82, stones);
	base_color *= 1.0 - (1.0 - ridge) * 0.07 * ripple_fade;

	float a = sin(world_pos.x * 2.3 + sin(world_pos.z * 1.7 + TIME * 0.5) + patch * 2.0 + TIME * 0.4);
	float b = sin(world_pos.z * 2.6 - sin(world_pos.x * 1.4 - TIME * 0.4) + patch * 1.7);
	float caustic = 1.0 - smoothstep(0.025, 0.055 + fwidth(a + b), abs(a + b));
	float caustic_fade = (1.0 - smoothstep(8.0, 28.0, depth)) * max(world_normal.y, 0.0);
	ALBEDO = base_color * (1.0 + caustic * caustic_fade * 0.22);
	ROUGHNESS = clamp(0.94 - stones * 0.12 + (grain - 0.5) * 0.05 * grain_fade, 0.8, 1.0);
	SPECULAR = 0.2;
	AO = 1.0 - (1.0 - ridge) * 0.12 * ripple_fade - stones * 0.1;
}
