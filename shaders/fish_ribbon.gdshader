shader_type spatial;
render_mode cull_back;
uniform vec3 back_color : source_color = vec3(0.06, 0.35, 0.52);
uniform vec3 belly_color : source_color = vec3(0.92, 0.80, 0.44);
uniform float radius = 16.0;
// 0: broad ellipse, 1: crossing S stream, 2: crescent with a recessed return.
uniform int curve_mode = 0;
uniform vec2 path_stretch = vec2(1.0, 0.72);
uniform float path_yaw = 0.0;
uniform float swim_speed = 0.14;
uniform float review_time = -1.0;
varying vec3 body;
void vertex() {
	body = VERTEX;
	float clock = review_time >= 0.0 ? review_time : mod(TIME, 3600.0);
	float phase = INSTANCE_CUSTOM.x * 6.283185 + clock * swim_speed * (0.97 + INSTANCE_CUSTOM.w * 0.06);
	float tail = 1.0 - smoothstep(-0.55, -0.12, VERTEX.z);
	VERTEX.x += sin(clock * (4.6 + INSTANCE_CUSTOM.w) + INSTANCE_CUSTOM.z * 6.283185 + VERTEX.z * 4.0) * tail * 0.065;
	vec2 path = vec2(sin(phase), cos(phase));
	vec2 derivative = vec2(cos(phase), -sin(phase));
	if (curve_mode == 1) {
		path.y = sin(phase * 2.0) * 0.43;
		derivative.y = cos(phase * 2.0) * 0.86;
	} else if (curve_mode == 2) {
		path.y = cos(phase) * 0.76 + cos(phase * 2.0) * 0.16;
		derivative.y = -sin(phase) * 0.76 - sin(phase * 2.0) * 0.32;
	}
	path *= radius * path_stretch;
	derivative *= radius * path_stretch;
	mat2 turn = mat2(vec2(cos(path_yaw), -sin(path_yaw)), vec2(sin(path_yaw), cos(path_yaw)));
	path = turn * path;
	derivative = turn * derivative;
	float rise = sin(phase * 2.0) * 0.90;
	vec3 forward = normalize(vec3(derivative.x, cos(phase * 2.0) * 1.80, derivative.y));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
	vec3 up = cross(forward, right);
	mat3 frame = mat3(right, up, forward);
	vec3 lane = right * (INSTANCE_CUSTOM.y - 0.5) * 3.2;
	VERTEX = frame * VERTEX + vec3(path.x, rise + (INSTANCE_CUSTOM.z - 0.5) * 3.0, path.y) + lane;
	NORMAL = normalize(frame * NORMAL);
}
void fragment() {
	float back = smoothstep(-0.035, 0.10, body.y);
	ALBEDO = mix(belly_color, back_color, back);
	float lateral = 1.0 - smoothstep(0.012, 0.038, abs(body.y - 0.015));
	ALBEDO = mix(ALBEDO, mix(belly_color, vec3(0.80, 0.90, 0.84), 0.35), lateral * 0.26);
	vec3 eye_position = vec3(sign(body.x) * 0.072, 0.045, 0.365);
	float eye = 1.0 - smoothstep(0.016, 0.032, length(body - eye_position));
	ALBEDO = mix(ALBEDO, vec3(0.018, 0.035, 0.045), eye);
	ROUGHNESS = 0.74;
	SPECULAR = 0.22;
}
