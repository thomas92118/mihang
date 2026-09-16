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

uniform float sway_strength : hint_range(0.0, 2.0) = 0.35;
uniform float sway_frequency : hint_range(0.0, 5.0) = 1.25;
uniform float phase_offset : hint_range(0.0, 6.283) = 0.0;
uniform float retract_progress : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float h = max(0.0, VERTEX.y);
	vec3 world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Procedural phase from world position enables sharing a single material instance across all plants
	float auto_phase = dot(MODEL_MATRIX[3].xz, vec2(1.73, 2.41));
	float t = TIME * sway_frequency + phase_offset + auto_phase;
	float wave1 = sin(t + world_p.x * 0.18 + world_p.z * 0.14);
	float wave2 = cos(t * 0.72 + world_p.z * 0.16);

	float sway = h * h * 0.045 * sway_strength;
	VERTEX.x += (wave1 * 0.75 + wave2 * 0.25) * sway;
	VERTEX.z += (wave2 * 0.75 + wave1 * 0.25) * sway;

	if (retract_progress > 0.0 && h > 0.4) {
		VERTEX.y -= (h - 0.4) * retract_progress * 0.70;
	}
}

void fragment() {
	vec2 material_uv = UV * uv_scale.xy + uv_offset.xy;
	ALBEDO = albedo.rgb * texture(albedo_texture, material_uv).rgb;
	vec3 orm = texture(orm_texture, material_uv).rgb;
	AO = orm.r;
	ROUGHNESS = roughness * orm.g;
	METALLIC = metallic * orm.b;
	NORMAL_MAP = texture(normal_texture, material_uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	if (emission_energy > 0.0) {
		float auto_phase = dot(MODEL_MATRIX[3].xz, vec2(1.73, 2.41));
		float pulse = 0.85 + sin(TIME * 2.5 + phase_offset + auto_phase) * 0.25;
		EMISSION = emission * texture(emission_texture, material_uv).rgb * (emission_energy * pulse);
	}
}
