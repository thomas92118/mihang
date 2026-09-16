shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float edge = pow(max(0.0, sin(UV.x * 3.14159)), 2.0);
	ALBEDO = vec3(0.28, 0.66, 0.61);
	ALPHA = edge * (1.0 - UV.y) * 0.048;
}
