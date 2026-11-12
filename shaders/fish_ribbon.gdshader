shader_type spatial;
render_mode cull_disabled;
uniform vec3 back_color : source_color = vec3(0.06, 0.35, 0.52);
uniform vec3 belly_color : source_color = vec3(0.92, 0.80, 0.44);
uniform float radius = 16.0;
varying vec3 body;
void vertex() {
	body = VERTEX;
	float phase = INSTANCE_CUSTOM.x * 6.283185 + TIME * 0.12;
	float tail = 1.0 - smoothstep(-0.55, -0.12, VERTEX.z);
	VERTEX.x += sin(TIME * 5.5 + phase * 3.0 + VERTEX.z * 4.0) * tail * 0.07;
	float heading = phase + 1.570796;
	mat2 turn = mat2(vec2(cos(heading), -sin(heading)), vec2(sin(heading), cos(heading)));
	VERTEX.xz = turn * VERTEX.xz;
	NORMAL.xz = turn * NORMAL.xz;
	float r = radius + INSTANCE_CUSTOM.y * 2.4;
	VERTEX.xz += vec2(sin(phase), cos(phase)) * r;
	VERTEX.y += sin(phase * 2.0) * 1.4 + (INSTANCE_CUSTOM.z - 0.5) * 3.8;
}
void fragment() {
	float back = smoothstep(-0.035, 0.10, body.y);
	ALBEDO = mix(belly_color, back_color, back);
	ROUGHNESS = 0.67;
	EMISSION = ALBEDO * 0.055;
}
