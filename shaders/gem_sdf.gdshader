shader_type canvas_item;

uniform int cut_type : hint_range(0, 6) = 0;
uniform vec4 gem_color : source_color = vec4(1.0, 0.12, 0.34, 1.0);
uniform int special_type : hint_range(0, 3) = 0; // 0=none, 1=flame, 2=star, 3=hypercube
uniform float selected : hint_range(0.0, 1.0) = 0.0;
uniform float beat_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float time_val = 0.0;

// Signed Distance Field primitives (centered around vec2(0.0))
float sd_circle(vec2 p, float r) {
	return length(p) - r;
}

float sd_box(vec2 p, vec2 b, float r) {
	vec2 d = abs(p) - b + vec2(r);
	return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

float sd_rhombus(vec2 p, vec2 b) {
	vec2 q = abs(p);
	float h = clamp((-2.0 * dot(q, b) + dot(b, b)) / dot(b, b), -1.0, 1.0);
	float d = length(q - 0.5 * b * vec2(1.0 - h, 1.0 + h));
	return d * sign(q.x * b.y + q.y * b.x - b.x * b.y);
}

float sd_hexagon(vec2 p, float r) {
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	p = abs(p);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y);
}

float sd_equilateral_triangle(vec2 p, float r) {
	const float k = sqrt(3.0);
	p.x = abs(p.x) - r;
	p.y = p.y + r / k;
	if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	p.x -= clamp(p.x, -2.0 * r, 0.0);
	return -length(p) * sign(p.y);
}

float sd_star6(vec2 p, float r) {
	vec2 p1 = p;
	float d1 = sd_equilateral_triangle(p1, r);
	vec2 p2 = vec2(p.x, -p.y);
	float d2 = sd_equilateral_triangle(p2, r);
	return min(d1, d2);
}

float sd_teardrop(vec2 p, float r) {
	p.y += 0.06;
	if (p.y > 0.0) {
		float h = p.y / 0.42;
		p.x = abs(p.x) - (1.0 - h) * r;
		return length(max(vec2(p.x, 0.0), 0.0)) + min(p.x, 0.0);
	}
	return length(p) - r;
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = time_val;
	
	// Base distance evaluation according to cut_type
	float d = 0.0;
	float inner_d = 0.0;
	
	switch (cut_type) {
		case 0: // Octahedron / Diamond (Rhombus)
			d = sd_rhombus(uv, vec2(0.85, 0.85));
			inner_d = sd_rhombus(uv, vec2(0.50, 0.50));
			break;
		case 1: // Hexagon
			d = sd_hexagon(uv, 0.78);
			inner_d = sd_hexagon(uv, 0.46);
			break;
		case 2: // Cushion Square
			d = sd_box(uv, vec2(0.68, 0.68), 0.22);
			inner_d = sd_box(uv, vec2(0.40, 0.40), 0.12);
			break;
		case 3: // Triangle / Trillion
			d = sd_equilateral_triangle(uv * vec2(1.0, -1.0) + vec2(0.0, -0.15), 0.78);
			inner_d = sd_equilateral_triangle(uv * vec2(1.0, -1.0) + vec2(0.0, -0.15), 0.42);
			break;
		case 4: // Circle / Cabochon
			d = sd_circle(uv, 0.75);
			inner_d = sd_circle(uv, 0.48);
			break;
		case 5: // Radiant Six-Point Star
			d = sd_star6(uv, 0.76);
			inner_d = sd_star6(uv, 0.42);
			break;
		case 6: // Teardrop / Briolette
			d = sd_teardrop(uv, 0.58);
			inner_d = sd_teardrop(uv, 0.34);
			break;
	}
	
	// Smooth anti-aliased edge
	float edge = 1.0 - smoothstep(-0.02, 0.01, d);
	if (edge <= 0.001) {
		discard;
	}
	
	// Determine color
	vec3 base_col = gem_color.rgb;
	if (special_type == 3) {
		// Hypercube rainbow chromatic cycle
		float hue = fract(t * 0.4 + length(uv) * 0.5);
		base_col = hsv2rgb(vec3(hue, 0.85, 1.0));
	}
	
	// Shading & Faceting
	float inner_mask = 1.0 - smoothstep(-0.02, 0.01, inner_d);
	float facet_shading = 0.85 + 0.35 * inner_mask;
	
	// Specular highlight at top-left
	vec2 spec_dir = normalize(vec2(-0.4, -0.6));
	float spec = pow(max(dot(normalize(uv), spec_dir), 0.0), 3.0) * inner_mask;
	
	// Bevel rim highlight
	float rim = smoothstep(-0.10, -0.01, d) * (1.0 - smoothstep(-0.02, 0.0, d));
	
	// Beat pulse boost
	float pulse_lum = beat_pulse * 0.3;
	
	vec3 final_rgb = base_col * facet_shading + vec3(spec * 0.7) + vec3(rim * 0.4) + vec3(pulse_lum);
	
	// Selection outline glow
	if (selected > 0.01) {
		float sel_ring = smoothstep(-0.06, -0.01, d) * (1.0 - smoothstep(-0.01, 0.01, d));
		final_rgb = mix(final_rgb, vec3(1.0, 1.0, 1.0), sel_ring * selected);
	}
	
	// Special Gem Visual Overlays
	if (special_type == 1) { // Flame Gem: Pulsing fiery solar flare
		float fire_ring = sin(length(uv) * 14.0 - t * 8.0) * 0.5 + 0.5;
		final_rgb += vec3(1.0, 0.45, 0.05) * fire_ring * 0.6;
	} else if (special_type == 2) { // Star Gem: Laser crosshair beams
		float beam_x = 1.0 - smoothstep(0.0, 0.08, abs(uv.y));
		float beam_y = 1.0 - smoothstep(0.0, 0.08, abs(uv.x));
		final_rgb += vec3(0.3, 0.8, 1.0) * (beam_x + beam_y) * 0.8;
	} else if (special_type == 3) { // Hypercube: Rotating energy arcs
		float angle = atan(uv.y, uv.x);
		float arc = sin(angle * 6.0 + t * 6.0) * 0.5 + 0.5;
		final_rgb += vec3(1.0) * arc * 0.4;
	}
	
	COLOR = vec4(final_rgb, edge);
}
