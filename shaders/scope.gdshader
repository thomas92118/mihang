shader_type canvas_item;

void fragment() {
	vec2 p = SCREEN_UV - vec2(0.5);
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float distance_to_center = length(p);
	float mask = smoothstep(0.365, 0.37, distance_to_center);
	float rim = 1.0 - smoothstep(0.001, 0.003, abs(distance_to_center - 0.362));
	float horizontal = (1.0 - step(0.0008, abs(p.y))) * step(0.015, abs(p.x)) * (1.0 - step(0.31, abs(p.x)));
	float vertical = (1.0 - step(0.0008, abs(p.x))) * step(0.015, abs(p.y)) * (1.0 - step(0.31, abs(p.y)));
	float ticks_x = (1.0 - step(0.001, abs(mod(p.x + 0.025, 0.05) - 0.025))) * (1.0 - step(0.009, abs(p.y))) * (1.0 - step(0.29, abs(p.x)));
	float ticks_y = (1.0 - step(0.001, abs(mod(p.y + 0.025, 0.05) - 0.025))) * (1.0 - step(0.009, abs(p.x))) * (1.0 - step(0.29, abs(p.y)));
	float center_dot = 1.0 - smoothstep(0.001, 0.0025, distance_to_center);
	float reticle = clamp(horizontal + vertical + ticks_x + ticks_y + center_dot + rim, 0.0, 1.0);
	COLOR = vec4(mix(vec3(0.002, 0.008, 0.018), vec3(0.12, 0.58, 1.0), reticle), max(mask * 0.94, reticle * 0.8));
}
