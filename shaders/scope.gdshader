shader_type canvas_item;

void fragment() {
	vec2 p = SCREEN_UV - vec2(0.5);
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float distance_to_center = length(p);

	vec3 ink_col = vec3(0.0627, 0.1529, 0.2078);
	vec3 ink_deep = vec3(0.035, 0.085, 0.120);
	vec3 cyan_col = vec3(0.5020, 0.7765, 0.7686);
	vec3 amber_col = vec3(0.8745, 0.7059, 0.4275);

	float housing_mask = smoothstep(0.363, 0.370, distance_to_center);
	float lens_vignette = smoothstep(0.295, 0.365, distance_to_center) * 0.24;
	float outer_rim = 1.0 - smoothstep(0.0009, 0.0024, abs(distance_to_center - 0.362));
	float range_ring = (1.0 - smoothstep(0.0006, 0.0018, abs(distance_to_center - 0.180))) * 0.32;

	float horizontal = (1.0 - smoothstep(0.00045, 0.0011, abs(p.y))) * smoothstep(0.015, 0.019, abs(p.x)) * (1.0 - smoothstep(0.312, 0.320, abs(p.x)));
	float vertical = (1.0 - smoothstep(0.00045, 0.0011, abs(p.x))) * smoothstep(0.015, 0.019, abs(p.y)) * (1.0 - smoothstep(0.312, 0.320, abs(p.y)));

	float cell_x = abs(mod(abs(p.x) + 0.0225, 0.045) - 0.0225);
	float major_x = step(0.065, mod(abs(p.x) + 0.002, 0.090));
	float tick_h_x = mix(0.0055, 0.0095, major_x);
	float ticks_x = (1.0 - smoothstep(0.00045, 0.0011, cell_x)) * (1.0 - smoothstep(tick_h_x - 0.001, tick_h_x, abs(p.y))) * step(0.032, abs(p.x)) * (1.0 - step(0.295, abs(p.x)));

	float cell_y = abs(mod(abs(p.y) + 0.0225, 0.045) - 0.0225);
	float major_y = step(0.065, mod(abs(p.y) + 0.002, 0.090));
	float tick_w_y = mix(0.0055, 0.0095, major_y);
	float ticks_y = (1.0 - smoothstep(0.00045, 0.0011, cell_y)) * (1.0 - smoothstep(tick_w_y - 0.001, tick_w_y, abs(p.x))) * step(0.032, abs(p.y)) * (1.0 - step(0.295, abs(p.y)));

	float center_pip = 1.0 - smoothstep(0.0015, 0.0030, distance_to_center);
	float center_collar = (1.0 - smoothstep(0.0006, 0.0016, abs(distance_to_center - 0.0085))) * 0.48;

	float cyan_marks = clamp((horizontal + vertical) * 0.68 + (ticks_x + ticks_y) * 0.78 + outer_rim * 0.72 + range_ring, 0.0, 1.0);
	float amber_marks = clamp(center_pip + center_collar, 0.0, 1.0);
	float reticle = clamp(cyan_marks + amber_marks, 0.0, 1.0);

	vec3 bg_col = mix(ink_col, ink_deep, smoothstep(0.36, 0.62, distance_to_center));
	vec3 reticle_col = mix(cyan_col, amber_col, clamp(amber_marks / max(reticle, 0.001), 0.0, 1.0));
	float bg_alpha = clamp(housing_mask * 0.94 + lens_vignette * (1.0 - housing_mask), 0.0, 0.95);
	float mark_alpha = max(cyan_marks * 0.76, amber_marks * 0.94);
	COLOR = vec4(mix(bg_col, reticle_col, reticle), max(bg_alpha, mark_alpha));
}
