shader_type spatial;
render_mode cull_disabled;

// 0: silverside, 1: lanternfish, 2: squid, 3: jellyfish, 4: abyssal jelly.
uniform int creature_kind = 0;
uniform float review_time = -1.0;
varying vec3 body_position;
varying float world_depth;

void vertex() {
	body_position = VERTEX;
	float clock = review_time >= 0.0 ? review_time : TIME;
	float phase_offset = INSTANCE_CUSTOM.x * 6.283185;
	if (creature_kind <= 2) {
		float speed = creature_kind == 2 ? 0.13 : (creature_kind == 1 ? 0.22 : 0.32);
		float phase = phase_offset + clock * speed * (0.94 + INSTANCE_CUSTOM.y * 0.12);
		float tail = 1.0 - smoothstep(-0.60, -0.12, VERTEX.z);
		float undulation = creature_kind == 2 ? 0.10 : 0.075;
		VERTEX.x += sin(clock * (creature_kind == 2 ? 2.2 : 5.8 + INSTANCE_CUSTOM.z) + phase_offset + VERTEX.z * 3.0) * tail * undulation;
		if (creature_kind == 2) {
			VERTEX.xy *= 0.97 + sin(clock * 1.9 + phase_offset) * 0.035;
		}
		float travel = creature_kind == 2 ? 3.0 : 2.4;
		float vertical_phase = phase * 2.0 + INSTANCE_CUSTOM.z * 2.0;
		vec3 forward = normalize(vec3(cos(phase) * travel, cos(vertical_phase) * 0.32, -sin(phase) * travel * 0.62));
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
		mat3 frame = mat3(right, cross(forward, right), forward);
		VERTEX = frame * VERTEX + vec3(sin(phase) * travel, sin(vertical_phase) * 0.16, cos(phase) * travel * 0.62);
		NORMAL = normalize(frame * NORMAL);
	} else {
		float pulse = sin(clock * 1.15 + phase_offset);
		float tentacle = smoothstep(0.0, 1.25, -VERTEX.y);
		VERTEX.xz *= 0.96 + pulse * 0.065;
		VERTEX.x += sin(clock * 0.8 + phase_offset - VERTEX.y * 2.8) * tentacle * 0.16;
		VERTEX.z += cos(clock * 0.65 + phase_offset - VERTEX.y * 2.1) * tentacle * 0.12;
		VERTEX.xz += vec2(sin(clock * 0.09 + phase_offset), cos(clock * 0.08 + phase_offset)) * 1.2;
		VERTEX.y += pulse * 0.30;
	}
	world_depth = max(-(MODEL_MATRIX * vec4(VERTEX, 1.0)).y, 0.0);
}

void fragment() {
	float back = smoothstep(-0.08, 0.12, body_position.y);
	if (creature_kind == 0) {
		ALBEDO = mix(vec3(0.80, 0.83, 0.71), vec3(0.12, 0.35, 0.40), back);
		float stripe = (1.0 - smoothstep(0.018, 0.05, abs(body_position.y + 0.005)))
			* smoothstep(-0.5, -0.20, body_position.z);
		ALBEDO = mix(ALBEDO, vec3(0.77, 0.61, 0.30), stripe * 0.55);
		ROUGHNESS = 0.56;
		METALLIC = 0.08;
	} else if (creature_kind == 1) {
		ALBEDO = mix(vec3(0.45, 0.42, 0.43), vec3(0.13, 0.19, 0.29), back);
		float spots = pow(max(sin(body_position.z * 54.0), 0.0), 14.0);
		float belly = (1.0 - smoothstep(0.025, 0.065, abs(body_position.y + 0.12)))
			* (1.0 - smoothstep(0.30, 0.41, abs(body_position.z)));
		EMISSION = vec3(0.22, 0.55, 0.48) * spots * belly * 0.12;
		ROUGHNESS = 0.58;
	} else if (creature_kind == 2) {
		ALBEDO = mix(vec3(0.67, 0.49, 0.46), vec3(0.37, 0.21, 0.28), back);
		ROUGHNESS = 0.57;
	} else {
		ALBEDO = mix(vec3(0.58, 0.67, 0.67), vec3(0.30, 0.44, 0.57), back);
		float edge = (1.0 - smoothstep(0.04, 0.11, abs(body_position.y)))
			* smoothstep(0.25, 0.44, length(body_position.xz));
		float filaments = smoothstep(0.30, 0.75, -body_position.y)
			* pow(max(sin(body_position.y * 24.0), 0.0), 8.0);
		EMISSION = vec3(0.22, 0.49, 0.52) * (edge + filaments * 0.25)
			* (creature_kind == 4 ? 0.12 : 0.045);
		ROUGHNESS = 0.68;
	}
	ALBEDO *= COLOR.rgb;
	if (creature_kind <= 1) {
		vec3 eye_position = vec3(sign(body_position.x) * 0.077, 0.06, 0.285);
		float eye = 1.0 - smoothstep(0.018, 0.035, length(body_position - eye_position));
		ALBEDO = mix(ALBEDO, vec3(0.018, 0.035, 0.042), eye);
	}
	SPECULAR = 0.30;
}

void light() {
	float ndotl = max(dot(NORMAL, LIGHT), 0.0);
	vec3 attenuation = vec3(1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		float camera_depth = max(-INV_VIEW_MATRIX[3].y, 0.0);
		float depth_correction = exp(clamp((camera_depth - world_depth) * 0.012, -5.0, 2.5));
		attenuation = exp(-vec3(0.022, 0.0055, 0.0) * world_depth) * depth_correction;
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * attenuation * ndotl / PI;
	vec3 half_dir = normalize(LIGHT + VIEW);
	float specular = pow(max(dot(NORMAL, half_dir), 0.0), 34.0) * 0.10;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * attenuation * specular;
}
