shader_type spatial;

uniform vec3 pigment : source_color = vec3(0.3, 0.6, 0.65);
uniform vec3 top_pigment : source_color = vec3(0.84, 0.80, 0.68);
uniform vec3 shadow_pigment : source_color = vec3(0.07, 0.23, 0.40);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.0;

varying vec3 world_position;
varying vec3 local_position;
varying vec3 world_normal;

void vertex() {
	local_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n_world = normalize(world_normal);
	float strata = sin(world_position.y * 1.48 + sin(world_position.x * 0.11 + world_position.z * 0.09) * 0.84);
	float bands = smoothstep(-0.76, 0.76, strata);
	float shelf = smoothstep(0.42, 0.84, n_world.y);
	float overhang = smoothstep(0.16, -0.46, n_world.y);
	float grounded = mix(0.74, 1.0, smoothstep(-0.18, 0.46, local_position.y));
	vec3 shadowed_rock = mix(pigment, shadow_pigment, overhang * 0.44);
	vec3 base_col = mix(shadowed_rock, top_pigment, shelf * 0.42);
	ALBEDO = base_col * COLOR.rgb * (0.87 + bands * 0.13) * grounded * 0.57;
	EMISSION = pigment * COLOR.rgb * glow_strength;
	ROUGHNESS = 0.89;
	SPECULAR = 0.13;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float lambert = clamp(facing, 0.0, 1.0);
	float facet = smoothstep(-0.08, 0.58, facing);
	float plane_light = mix(lambert, facet, 0.55);
	float depth = max(0.0, -world_position.y);
	vec3 sun_trans = LIGHT_IS_DIRECTIONAL
		? exp(-vec3(0.016, 0.0042, 0.0008) * min(depth, 140.0))
		: vec3(1.58);
	vec3 tint = LIGHT_IS_DIRECTIONAL
		? mix(vec3(0.22, 0.46, 0.69), vec3(1.0, 0.96, 0.84), plane_light)
		: mix(vec3(0.42, 0.66, 0.90), vec3(1.0, 0.98, 0.93), plane_light);
	DIFFUSE_LIGHT += tint * LIGHT_COLOR * sun_trans * ATTENUATION * (0.06 + plane_light * 0.94) / PI;
}
