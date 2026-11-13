shader_type sky;

// Background scattering only: geometry continues to use the shared depth fog.
// No screen reads, volumetric buffers, sun simulation or animated cubemap work.
uniform vec3 water_color : source_color = vec3(0.025, 0.40, 0.62);
uniform float water_energy : hint_range(0.0, 2.0) = 0.8;
uniform float sunlit_amount : hint_range(0.0, 1.0) = 1.0;

void sky() {
	// Compatibility also draws the visible background from this cubemap, so
	// keep the scattering gradient in both passes rather than baking a flat sky.
	float rise = smoothstep(-0.68, 0.80, EYEDIR.y);
	float overhead = smoothstep(0.12, 0.97, EYEDIR.y);
	vec3 lower = water_color * vec3(0.35, 0.47, 0.66);
	vec3 upper = water_color * vec3(0.86, 1.16, 1.25);
	vec3 water = mix(lower, upper, rise);
	water += water_color * overhead * sunlit_amount * 0.13;
	COLOR = water * water_energy;
}
