shader_type spatial;
render_mode cull_disabled;

// 0: silverside, 1: lanternfish, 2: squid, 3: jellyfish, 4: abyssal jelly.
uniform int creature_kind = 0;
varying vec3 body_position;
varying float world_depth;

void vertex() {
	body_position = VERTEX;
	float phase_offset = INSTANCE_CUSTOM.x * 6.283185;
	if (creature_kind <= 2) {
		float speed = creature_kind == 2 ? 0.13 : (creature_kind == 1 ? 0.22 : 0.32);
		float phase = phase_offset + TIME * speed;
		float tail = 1.0 - smoothstep(-0.60, -0.12, VERTEX.z);
		float undulation = creature_kind == 2 ? 0.10 : 0.075;
		VERTEX.x += sin(TIME * (creature_kind == 2 ? 2.2 : 6.5) + phase_offset + VERTEX.z * 3.0) * tail * undulation;
		if (creature_kind == 2) {
			VERTEX.xy *= 0.97 + sin(TIME * 1.9 + phase_offset) * 0.035;
		}
		float heading = phase + 1.570796;
		float c = cos(heading);
		float s = sin(heading);
		VERTEX.xz = vec2(VERTEX.x * c + VERTEX.z * s, -VERTEX.x * s + VERTEX.z * c);
		NORMAL.xz = vec2(NORMAL.x * c + NORMAL.z * s, -NORMAL.x * s + NORMAL.z * c);
		VERTEX.xz += vec2(sin(phase), cos(phase)) * (creature_kind == 2 ? 3.0 : 2.4);
		VERTEX.y += sin(phase * 2.0 + INSTANCE_CUSTOM.z * 2.0) * 0.16;
	} else {
		float pulse = sin(TIME * 1.15 + phase_offset);
		float tentacle = smoothstep(0.0, 1.25, -VERTEX.y);
		VERTEX.xz *= 0.96 + pulse * 0.065;
		VERTEX.x += sin(TIME * 0.8 + phase_offset - VERTEX.y * 2.8) * tentacle * 0.16;
		VERTEX.z += cos(TIME * 0.65 + phase_offset - VERTEX.y * 2.1) * tentacle * 0.12;
		VERTEX.xz += vec2(sin(TIME * 0.09 + phase_offset), cos(TIME * 0.08 + phase_offset)) * 1.2;
		VERTEX.y += pulse * 0.30;
	}
	world_depth = max(-(MODEL_MATRIX * vec4(VERTEX, 1.0)).y, 0.0);
}

void fragment() {
	float back = smoothstep(-0.08, 0.12, body_position.y);
	if (creature_kind == 0) {
		ALBEDO = mix(vec3(0.62, 0.65, 0.62), vec3(0.22, 0.30, 0.31), back);
		ROUGHNESS = 0.42;
		METALLIC = 0.08;
	} else if (creature_kind == 1) {
		ALBEDO = mix(vec3(0.27, 0.24, 0.20), vec3(0.11, 0.15, 0.15), back);
		float spots = pow(max(sin(body_position.z * 54.0), 0.0), 14.0);
		float belly = (1.0 - smoothstep(0.025, 0.065, abs(body_position.y + 0.12)))
			* (1.0 - smoothstep(0.30, 0.41, abs(body_position.z)));
		EMISSION = vec3(0.22, 0.55, 0.48) * spots * belly * 0.12;
		ROUGHNESS = 0.58;
	} else if (creature_kind == 2) {
		ALBEDO = mix(vec3(0.42, 0.34, 0.30), vec3(0.29, 0.24, 0.23), back);
		ROUGHNESS = 0.57;
	} else {
		ALBEDO = mix(vec3(0.43, 0.51, 0.50), vec3(0.29, 0.38, 0.41), back);
		float edge = (1.0 - smoothstep(0.04, 0.11, abs(body_position.y)))
			* smoothstep(0.25, 0.44, length(body_position.xz));
		float filaments = smoothstep(0.30, 0.75, -body_position.y)
			* pow(max(sin(body_position.y * 24.0), 0.0), 8.0);
		EMISSION = vec3(0.22, 0.49, 0.52) * (edge + filaments * 0.25)
			* (creature_kind == 4 ? 0.12 : 0.045);
		ROUGHNESS = 0.68;
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
