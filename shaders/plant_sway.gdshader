shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

uniform vec3 base_color : source_color = vec3(0.12, 0.48, 0.28);
uniform float roughness : hint_range(0.0, 1.0) = 0.72;
uniform float sway_strength : hint_range(0.0, 1.0) = 0.22;
uniform float sway_frequency : hint_range(0.0, 5.0) = 1.25;
uniform float emission_energy : hint_range(0.0, 5.0) = 0.0;

void vertex() {
	float height = max(0.0, VERTEX.y - MODEL_MATRIX[3].y);
	float wave = sin(TIME * sway_frequency + VERTEX.x * 0.35 + VERTEX.z * 0.25);
	float wave_cross = cos(TIME * (sway_frequency * 0.75) + VERTEX.x * 0.22);
	VERTEX.x += (wave * 0.7 + wave_cross * 0.3) * height * sway_strength * 0.14;
	VERTEX.z += (wave_cross * 0.7 + wave * 0.3) * height * sway_strength * 0.12;
}

void fragment() {
	ALBEDO = base_color;
	ROUGHNESS = roughness;
	if (emission_energy > 0.0) {
		EMISSION = base_color * emission_energy;
	}
}
