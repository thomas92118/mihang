shader_type spatial;

// A nonnegative override freezes only visual time for repeatable review.
uniform float review_time = -1.0;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled, world_vertex_coords;

varying vec3 particle_world_pos;

void vertex() {
	// Each MultiMesh instance has its own world origin. World-space phases keep
	// the slow suspension independent of camera rotation and camera movement.
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = dot(origin, vec3(0.71, 1.37, 0.93));
	VERTEX += vec3(
		sin((review_time >= 0.0 ? review_time : TIME) * 0.16 + phase) * 0.24,
		sin((review_time >= 0.0 ? review_time : TIME) * 0.085 + phase * 1.23) * 0.30,
		cos((review_time >= 0.0 ? review_time : TIME) * 0.13 + phase * 0.79) * 0.18
	);
	particle_world_pos = VERTEX;
}

void fragment() {
	float distance_to_camera = length(particle_world_pos - CAMERA_POSITION_WORLD);
	float near_fade = smoothstep(0.8, 2.8, distance_to_camera);
	float far_fade = 1.0 - smoothstep(22.0, 44.0, distance_to_camera);
	float depth = max(-particle_world_pos.y, 0.0);
	// A little more falling detritus becomes visible in a lamp over the basin
	// and trench. Opacity stays low; darkness must not create glowing particles.
	float basin = smoothstep(180.0, 260.0, depth);
	float hadal = smoothstep(350.0, 470.0, depth);
	float density = 0.065 + smoothstep(30.0, 95.0, depth) * 0.015 + basin * 0.02 + hadal * 0.015;
	// Muted detritus scatters available light; it has no emission or glowing rim.
	ALBEDO = mix(vec3(0.58, 0.65, 0.58), vec3(0.49, 0.53, 0.52), basin);
	ROUGHNESS = 0.96;
	SPECULAR = 0.08;
	EMISSION = vec3(0.0);
	ALPHA = density * near_fade * far_fade;
}
