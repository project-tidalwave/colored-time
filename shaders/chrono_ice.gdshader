shader_type canvas_item;

uniform int ice_hp : hint_range(0, 2) = 1;
uniform float time_val = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	if (ice_hp <= 0) {
		discard;
	}
	
	vec2 uv = UV * 2.0 - 1.0;
	float dist_box = max(abs(uv.x), abs(uv.y));
	if (dist_box > 0.95) {
		discard;
	}
	
	// Frosted cyan crystal glass base
	vec3 ice_color = vec3(0.5, 0.85, 1.0);
	float n = noise(uv * 8.0 + vec2(time_val * 0.1));
	float alpha = 0.45 + n * 0.25;
	
	// Crack lines (more visible when hp == 1)
	float crack = abs(sin(uv.x * 12.0 + n * 4.0) * cos(uv.y * 12.0));
	if (ice_hp == 1) {
		float crack_line = smoothstep(0.02, 0.0, crack);
		ice_color += vec3(crack_line * 0.6);
		alpha += crack_line * 0.3;
	} else if (ice_hp == 2) {
		// Reinforced cage bars
		float bar_h = 1.0 - smoothstep(0.0, 0.12, abs(uv.y));
		float bar_v = 1.0 - smoothstep(0.0, 0.12, abs(uv.x));
		float border = smoothstep(0.80, 0.92, dist_box);
		float cage = max(max(bar_h, bar_v), border);
		ice_color = mix(ice_color, vec3(0.15, 0.25, 0.45), cage * 0.7);
		alpha = mix(alpha, 0.85, cage * 0.6);
	}
	
	COLOR = vec4(ice_color, clamp(alpha, 0.0, 0.9));
}
