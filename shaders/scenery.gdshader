shader_type spatial;

uniform vec3 pigment : source_color = vec3(0.3, 0.6, 0.65);
uniform vec3 top_pigment : source_color = vec3(0.84, 0.80, 0.68);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.0;

varying vec3 world_position;
varying vec3 local_position;
varying vec3 world_normal;

void vertex() {
	local_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float strata = sin(world_position.y * 1.42 + sin(world_position.x * 0.12 + world_position.z * 0.09) * 0.8);
	float bands = smoothstep(-0.85, 0.85, strata);
	float shelf = smoothstep(0.38, 0.88, world_normal.y);
	float grounded = mix(0.80, 1.0, smoothstep(-0.35, 0.25, local_position.y));
	vec3 base_col = mix(pigment, top_pigment, shelf * 0.40);
	ALBEDO = base_col * COLOR.rgb * (0.85 + bands * 0.15) * grounded * 0.56;
	EMISSION = pigment * COLOR.rgb * glow_strength;
	ROUGHNESS = 0.88;
	SPECULAR = 0.15;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float wrap = smoothstep(-0.28, 0.88, facing);
	float depth = max(0.0, -world_position.y);
	vec3 sun_trans = LIGHT_IS_DIRECTIONAL
		? exp(-vec3(0.016, 0.0042, 0.0008) * min(depth, 140.0))
		: vec3(1.65);
	vec3 tint = LIGHT_IS_DIRECTIONAL
		? mix(vec3(0.30, 0.59, 0.89), vec3(1.0, 0.96, 0.86), wrap)
		: mix(vec3(0.46, 0.68, 0.92), vec3(1.0, 0.98, 0.94), wrap);
	DIFFUSE_LIGHT += tint * LIGHT_COLOR * sun_trans * ATTENUATION * (0.14 + wrap * 0.86) / PI;
}
