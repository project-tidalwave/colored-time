shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float u_bass = 0.0;
uniform float u_mid = 0.0;
uniform float u_treble = 0.0;
uniform float u_beat_phase = 0.0;
uniform float u_shockwave = 0.0;
uniform vec4 u_primary_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 u_secondary_color : source_color = vec4(1.0, 0.4, 0.8, 1.0);

varying vec4 v_custom;

void vertex() {
	// Instance custom data contains: (phase_offset, speed_mult, amplitude, style_id)
	vec4 custom = INSTANCE_CUSTOM;
	v_custom = custom;
	float phase = custom.x + TIME * (0.5 + custom.y * 0.5) + u_beat_phase * 0.2;
	
	// Dynamic vertex displacement influenced by Bass and shockwave
	float disp = sin(phase * 4.0 + VERTEX.y * 2.0) * (0.05 + u_bass * 0.15 + u_shockwave * 0.2);
	VERTEX += NORMAL * disp;
}

void fragment() {
	vec4 custom = v_custom;
	float instance_id_norm = fract(custom.x * 3.14159);
	
	// Blend primary and secondary colors according to instance and mid-frequencies
	vec3 base_color = mix(u_primary_color.rgb, u_secondary_color.rgb, instance_id_norm);
	
	// Fresnel rim highlight
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	
	// Emissive glow driven by beat phase, treble sparkles, and shockwaves
	float pulse = (1.0 - u_beat_phase) * u_bass * 1.5;
	float sparkle = u_treble * step(0.7, fract(custom.x * 17.0 + TIME * 3.0));
	float emit_strength = 0.2 + pulse * 0.8 + sparkle * 1.2 + u_shockwave * 2.5;
	
	ALBEDO = base_color * 0.4;
	METALLIC = 0.85;
	ROUGHNESS = 0.18;
	EMISSION = (base_color + vec3(fresnel * 0.8)) * emit_strength;
}
