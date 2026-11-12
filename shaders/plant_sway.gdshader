shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(0.2, 0.6, 0.3, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy : hint_range(0.0, 10.0) = 0.0;
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform sampler2D orm_texture : hint_default_white, filter_linear_mipmap;
uniform sampler2D emission_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform float normal_scale = 1.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);

// Optional pigment remapping for stylized source assets. Luminance retains
// pores, weathering and contrasting coral tips while replacing neon hues.
uniform bool natural_palette = false;
uniform vec3 palette_dark : source_color = vec3(0.22, 0.20, 0.15);
uniform vec3 palette_light : source_color = vec3(0.64, 0.59, 0.45);
uniform float palette_strength : hint_range(0.0, 1.0) = 0.0;

uniform float sway_strength : hint_range(0.0, 2.0) = 0.35;
uniform float sway_frequency : hint_range(0.0, 5.0) = 1.25;
uniform float phase_offset : hint_range(0.0, 6.283) = 0.0;
uniform float retract_progress : hint_range(0.0, 1.0) = 0.0;
varying float v_world_depth;

void vertex() {
	float h = max(0.0, VERTEX.y);
	vec3 world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_depth = max(-world_p.y, 0.0);
	if (sway_strength > 0.001) {
		// Procedural phase from world position enables sharing a single material instance across all plants
		float auto_phase = dot(MODEL_MATRIX[3].xz, vec2(1.73, 2.41));
		float t = TIME * sway_frequency + phase_offset + auto_phase;
		float wave1 = sin(t + world_p.x * 0.18 + world_p.z * 0.14);
		float wave2 = cos(t * 0.72 + world_p.z * 0.16);
		float sway = h * h * 0.045 * sway_strength;
		VERTEX.x += (wave1 * 0.75 + wave2 * 0.25) * sway;
		VERTEX.z += (wave2 * 0.75 + wave1 * 0.25) * sway;
	}

	if (retract_progress > 0.0 && h > 0.4) {
		VERTEX.y -= (h - 0.4) * retract_progress * 0.70;
	}
}

void fragment() {
	vec2 material_uv = UV * uv_scale.xy + uv_offset.xy;
	vec3 raw_albedo = albedo.rgb * texture(albedo_texture, material_uv).rgb * COLOR.rgb;
	float luma = dot(raw_albedo, vec3(0.299, 0.587, 0.114));
	// Preserve the imported pigments without the old saturation boost. Absorption
	// belongs to incident sunlight, not albedo: a nearby lamp restores warm hues.
	ALBEDO = clamp(raw_albedo * 0.76, vec3(0.0), vec3(1.0));
	if (natural_palette) {
		// Texture samples are linear. Lift their dark range smoothly rather than
		// flattening it into bands or preserving the source's artificial colours.
		float pigment_value = clamp(sqrt(max(luma, 0.0)), 0.0, 1.0);
		vec3 pigment = mix(palette_dark, palette_light, pigment_value);
		ALBEDO = mix(ALBEDO, pigment, palette_strength);
	}
	if (dot(VERTEX, VERTEX) < 900.0) {
		vec3 orm = texture(orm_texture, material_uv).rgb;
		AO = orm.r;
		ROUGHNESS = clamp(roughness * mix(0.72, 1.0, orm.g), 0.18, 1.0);
		METALLIC = metallic * orm.b;
		NORMAL_MAP = texture(normal_texture, material_uv).rgb;
		NORMAL_MAP_DEPTH = normal_scale * 0.55;
	} else {
		ROUGHNESS = clamp(roughness, 0.18, 1.0);
		METALLIC = metallic;
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
		NORMAL_MAP_DEPTH = 0.0;
	}
	if (emission_energy > 0.0) {
		float auto_phase = dot(MODEL_MATRIX[3].xz, vec2(1.73, 2.41));
		float pulse = 0.92 + sin(TIME * 0.8 + phase_offset + auto_phase) * 0.08;
		EMISSION = emission * texture(emission_texture, material_uv).rgb * (emission_energy * pulse);
	} else {
		EMISSION = vec3(0.0);
	}
}

void light() {
	float camera_depth = max(-INV_VIEW_MATRIX[3].y, 0.0);
	float depth_correction = exp(clamp((camera_depth - v_world_depth) * 0.012, -8.0, 7.2));
	vec3 transmission = LIGHT_IS_DIRECTIONAL
		? exp(-vec3(0.022, 0.0055, 0.0) * v_world_depth) * depth_correction : vec3(1.0);
	float ndotl = max(dot(NORMAL, LIGHT), 0.0);
	// A little transmitted light softens thin leaves without luminous outlines.
	float foliage_diffuse = max((dot(NORMAL, LIGHT) + 0.10) / 1.10, 0.0);
	DIFFUSE_LIGHT += foliage_diffuse * LIGHT_COLOR * transmission * ATTENUATION / PI;
	vec3 half_dir = normalize(LIGHT + VIEW);
	float exponent = mix(64.0, 8.0, ROUGHNESS);
	float spec = pow(max(dot(NORMAL, half_dir), 0.0), exponent) * ndotl;
	SPECULAR_LIGHT += LIGHT_COLOR * transmission * ATTENUATION * spec * (1.0 - ROUGHNESS) * 0.07;
}
