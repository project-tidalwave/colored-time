class_name ProceduralBackground3D
extends Node3D

var world_env: WorldEnvironment
var camera: Camera3D
var dir_light: DirectionalLight3D
var omni_light: OmniLight3D

var primary_mmi: MultiMeshInstance3D
var secondary_mmi: MultiMeshInstance3D
var shader_material: ShaderMaterial

var current_style: String = "bird_blues"
var current_key_hue: float = 0.0
var shockwave_intensity: float = 0.0

const PRIMARY_INSTANCE_COUNT := 96
const SECONDARY_INSTANCE_COUNT := 64

# Rotational states
var global_rotation_phase: float = 0.0
var secondary_rotation_phase: float = 0.0

func _init() -> void:
	name = "ProceduralBackground3D"
	_setup_environment_and_camera()
	_setup_multimeshes()

func _ready() -> void:
	pass

func _setup_environment_and_camera() -> void:
	# WorldEnvironment with Glow & ACES Tonemap
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#05030a")
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_env.environment = env
	add_child(world_env)
	
	# Camera3D
	camera = Camera3D.new()
	camera.position = Vector3(0, 0, 14)
	camera.fov = 72.0
	camera.current = true
	add_child(camera)
	
	# Lighting
	dir_light = DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-45, 30, 0)
	dir_light.light_energy = 0.8
	add_child(dir_light)
	
	omni_light = OmniLight3D.new()
	omni_light.position = Vector3(0, 0, 6)
	omni_light.omni_range = 30.0
	omni_light.light_energy = 1.2
	add_child(omni_light)

func _setup_multimeshes() -> void:
	shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://shaders/background_geo.gdshader")
	
	# Primary MultiMesh
	primary_mmi = MultiMeshInstance3D.new()
	var p_mm := MultiMesh.new()
	p_mm.transform_format = MultiMesh.TRANSFORM_3D
	p_mm.use_custom_data = true
	p_mm.instance_count = PRIMARY_INSTANCE_COUNT
	primary_mmi.multimesh = p_mm
	primary_mmi.material_override = shader_material
	add_child(primary_mmi)
	
	# Secondary MultiMesh
	secondary_mmi = MultiMeshInstance3D.new()
	var s_mm := MultiMesh.new()
	s_mm.transform_format = MultiMesh.TRANSFORM_3D
	s_mm.use_custom_data = true
	s_mm.instance_count = SECONDARY_INSTANCE_COUNT
	secondary_mmi.multimesh = s_mm
	secondary_mmi.material_override = shader_material
	add_child(secondary_mmi)
	
	set_track_style("bird_blues", 0.0)

func set_track_style(style: String, key_hue: float) -> void:
	current_style = style
	current_key_hue = key_hue
	
	# Compute palette colors based on key_hue
	var primary_color := Color.from_hsv(current_key_hue, 0.75, 1.0)
	var secondary_color := Color.from_hsv(fposmod(current_key_hue + 0.35, 1.0), 0.85, 0.95)
	
	if shader_material:
		shader_material.set_shader_parameter("u_primary_color", primary_color)
		shader_material.set_shader_parameter("u_secondary_color", secondary_color)
	
	if omni_light:
		omni_light.light_color = primary_color
	if dir_light:
		dir_light.light_color = secondary_color
	
	# Select appropriate 3D meshes per style
	var p_mesh: Mesh
	var s_mesh: Mesh
	
	match style:
		"bird_blues":
			# Angular Prism Tunnel
			var prism := PrismMesh.new()
			prism.size = Vector3(0.8, 1.2, 0.8)
			p_mesh = prism
			var box := BoxMesh.new()
			box.size = Vector3(0.4, 0.4, 0.4)
			s_mesh = box
		"medium_swing":
			# Gyroscopic Torus Rings & Cylinders
			var torus := TorusMesh.new()
			torus.inner_radius = 0.7
			torus.outer_radius = 1.0
			p_mesh = torus
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.2
			cyl.bottom_radius = 0.2
			cyl.height = 1.5
			s_mesh = cyl
		"slow_ballad":
			# Floating Monoliths & Crystals
			var box := BoxMesh.new()
			box.size = Vector3(0.5, 3.2, 0.5)
			p_mesh = box
			var prism := PrismMesh.new()
			prism.size = Vector3(0.7, 0.7, 0.7)
			s_mesh = prism
		"minor_blues":
			# Hexagonal Lattice Pillars
			var hex := CylinderMesh.new()
			hex.radial_segments = 6
			hex.top_radius = 0.6
			hex.bottom_radius = 0.6
			hex.height = 2.4
			p_mesh = hex
			var box := BoxMesh.new()
			box.size = Vector3(0.5, 0.5, 0.5)
			s_mesh = box
		"burning_swing":
			# Kinetic Polyhedral Vortex
			var prism := PrismMesh.new()
			prism.size = Vector3(0.9, 1.8, 0.5)
			p_mesh = prism
			var torus := TorusMesh.new()
			torus.inner_radius = 0.4
			torus.outer_radius = 0.6
			s_mesh = torus
		"spiced_blues":
			# Torus Knots & Kaleidoscopic Mandala Shards
			var torus := TorusMesh.new()
			torus.inner_radius = 0.6
			torus.outer_radius = 1.1
			p_mesh = torus
			var prism := PrismMesh.new()
			prism.size = Vector3(0.6, 1.0, 0.6)
			s_mesh = prism
		_:
			var box := BoxMesh.new()
			box.size = Vector3(0.8, 0.8, 0.8)
			p_mesh = box
			s_mesh = box
	
	primary_mmi.multimesh.mesh = p_mesh
	secondary_mmi.multimesh.mesh = s_mesh
	
	_rebuild_initial_instances()

func _rebuild_initial_instances() -> void:
	var p_mm := primary_mmi.multimesh
	for i in range(PRIMARY_INSTANCE_COUNT):
		var frac := float(i) / float(PRIMARY_INSTANCE_COUNT)
		var custom_data := Color(frac, 0.5 + frac * 0.5, 1.0, 0.0)
		p_mm.set_instance_custom_data(i, custom_data)
	
	var s_mm := secondary_mmi.multimesh
	for i in range(SECONDARY_INSTANCE_COUNT):
		var frac := float(i) / float(SECONDARY_INSTANCE_COUNT)
		var custom_data := Color(frac, 1.0 + frac, 0.8, 0.0)
		s_mm.set_instance_custom_data(i, custom_data)

func trigger_beat_shockwave(intensity: float = 1.0, _color: Color = Color.WHITE) -> void:
	shockwave_intensity = clampf(intensity, 0.5, 2.5)

func update_audio_reaction(delta: float, bass: float, mid: float, treble: float, beat_phase: float) -> void:
	# Decay shockwave
	shockwave_intensity = lerpf(shockwave_intensity, 0.0, delta * 6.0)
	
	# Camera bass kick
	if camera:
		var target_fov := 72.0 + bass * 5.0 + shockwave_intensity * 6.0
		camera.fov = lerpf(camera.fov, target_fov, delta * 12.0)
	
	# Pass uniforms to 3D background shader
	if shader_material:
		shader_material.set_shader_parameter("u_bass", bass)
		shader_material.set_shader_parameter("u_mid", mid)
		shader_material.set_shader_parameter("u_treble", treble)
		shader_material.set_shader_parameter("u_beat_phase", beat_phase)
		shader_material.set_shader_parameter("u_shockwave", shockwave_intensity)
	
	# Rotate phases based on tempo and mid frequency
	var speed := 0.4 + mid * 0.6
	global_rotation_phase += delta * speed
	secondary_rotation_phase += delta * (speed * 1.5)
	
	_update_archetype_transforms(delta, bass, mid, treble)

func _update_archetype_transforms(delta: float, bass: float, mid: float, treble: float) -> void:
	var p_mm := primary_mmi.multimesh
	var s_mm := secondary_mmi.multimesh
	
	match current_style:
		"bird_blues":
			# Tunnel layout: rings along Z axis
			var rings := 12
			var per_ring := PRIMARY_INSTANCE_COUNT / rings
			for i in range(PRIMARY_INSTANCE_COUNT):
				var ring_idx := i / per_ring
				var angle := (float(i % per_ring) / float(per_ring)) * TAU + global_rotation_phase * 0.5
				var radius := 5.5 + sin(ring_idx * 0.8 + global_rotation_phase) * 1.2
				var z_pos := -20.0 + ring_idx * 3.5 + fposmod(global_rotation_phase * 4.0, 3.5)
				var pos := Vector3(cos(angle) * radius, sin(angle) * radius, z_pos)
				var basis := Basis().rotated(Vector3(0, 0, 1), angle + PI * 0.5)
				basis = basis.scaled(Vector3.ONE * (0.8 + bass * 0.5))
				p_mm.set_instance_transform(i, Transform3D(basis, pos))
			
			for i in range(SECONDARY_INSTANCE_COUNT):
				var angle := (float(i) / float(SECONDARY_INSTANCE_COUNT)) * TAU * 2.0 + secondary_rotation_phase
				var r := 3.2 + sin(float(i) + secondary_rotation_phase) * 0.8
				var pos := Vector3(cos(angle) * r, sin(angle) * r, -5.0 + sin(angle * 3.0) * 4.0)
				var basis := Basis().rotated(Vector3(1, 1, 0).normalized(), secondary_rotation_phase * 2.0)
				basis = basis.scaled(Vector3.ONE * (0.5 + treble * 0.6))
				s_mm.set_instance_transform(i, Transform3D(basis, pos))

		"medium_swing":
			# Concentric gyroscopic rings
			for i in range(PRIMARY_INSTANCE_COUNT):
				var ring_idx := i % 4
				var angle := (float(i) / float(PRIMARY_INSTANCE_COUNT)) * TAU * 3.0 + global_rotation_phase
				var radius := 3.5 + float(ring_idx) * 2.0 + sin(global_rotation_phase * 2.0 + float(ring_idx)) * 0.5
				var axis := Vector3(sin(float(ring_idx)), cos(float(ring_idx)), 0.5).normalized()
				var pos := Basis(axis, angle) * Vector3(radius, 0, -2.0)
				var basis := Basis(axis, angle + global_rotation_phase).scaled(Vector3.ONE * (0.9 + bass * 0.4))
				p_mm.set_instance_transform(i, Transform3D(basis, pos))
			
			for i in range(SECONDARY_INSTANCE_COUNT):
				var frac := float(i) / float(SECONDARY_INSTANCE_COUNT)
				var angle := frac * TAU * 4.0 - secondary_rotation_phase
				var pos := Vector3(sin(angle) * 7.5, cos(angle) * 5.0, -8.0 + sin(angle * 2.0) * 3.0)
				var basis := Basis().rotated(Vector3.FORWARD, angle).scaled(Vector3.ONE * (0.6 + mid * 0.5))
				s_mm.set_instance_transform(i, Transform3D(basis, pos))

		"slow_ballad":
			# Serene monolithic circle with undulating sine motion
			for i in range(PRIMARY_INSTANCE_COUNT):
				var angle := (float(i) / float(PRIMARY_INSTANCE_COUNT)) * TAU
				var r := 7.0 + sin(angle * 3.0 + global_rotation_phase * 0.5) * 1.5
				var y_pos := sin(angle * 4.0 + global_rotation_phase) * 1.8
				var pos := Vector3(cos(angle) * r, y_pos, -6.0 + sin(angle) * 2.0)
				var basis := Basis().rotated(Vector3(0, 1, 0), angle + PI * 0.5)
				basis = basis.scaled(Vector3(1.0, 1.0 + bass * 0.8, 1.0) * 0.9)
				p_mm.set_instance_transform(i, Transform3D(basis, pos))
			
			for i in range(SECONDARY_INSTANCE_COUNT):
				var frac := float(i) / float(SECONDARY_INSTANCE_COUNT)
				var angle := frac * TAU * 2.0 + secondary_rotation_phase * 0.5
				var pos := Vector3(cos(angle) * 4.5, sin(angle * 2.0) * 3.5, -4.0 + cos(angle) * 2.5)
				var basis := Basis().rotated(Vector3(1, 0, 1).normalized(), secondary_rotation_phase)
				basis = basis.scaled(Vector3.ONE * (0.4 + mid * 0.3))
				s_mm.set_instance_transform(i, Transform3D(basis, pos))

		"minor_blues":
			# Hexagonal pillar lattice
			var cols := 12
			var rows := PRIMARY_INSTANCE_COUNT / cols
			for i in range(PRIMARY_INSTANCE_COUNT):
				var c := i % cols
				var r := i / cols
				var x := (float(c) - float(cols) * 0.5) * 1.8
				var y := (float(r) - float(rows) * 0.5) * 2.2
				var h := 1.0 + sin(x * 0.5 + y * 0.5 + global_rotation_phase * 2.0) * 0.8 + bass * 1.2
				var pos := Vector3(x, y, -10.0 + sin(float(i) + global_rotation_phase) * 1.0)
				var basis := Basis().rotated(Vector3(0, 0, 1), PI / 6.0)
				basis = basis.scaled(Vector3(1.0, 1.0, h) * 0.75)
				p_mm.set_instance_transform(i, Transform3D(basis, pos))
			
			for i in range(SECONDARY_INSTANCE_COUNT):
				var angle := (float(i) / float(SECONDARY_INSTANCE_COUNT)) * TAU + secondary_rotation_phase
				var pos := Vector3(cos(angle) * 6.0, sin(angle) * 6.0, -5.0 + sin(angle * 3.0) * 2.0)
				var basis := Basis().rotated(Vector3(0, 1, 0), angle).scaled(Vector3.ONE * (0.5 + treble * 0.4))
				s_mm.set_instance_transform(i, Transform3D(basis, pos))

		"burning_swing":
			# Kinetic double-helix vortex spinning along Z
			for i in range(PRIMARY_INSTANCE_COUNT):
				var frac := float(i) / float(PRIMARY_INSTANCE_COUNT)
				var angle := frac * TAU * 6.0 + global_rotation_phase * 3.0
				var r := 2.5 + frac * 6.0 + bass * 2.0
				var z := -18.0 + frac * 20.0
				var pos := Vector3(cos(angle) * r, sin(angle) * r, z)
				var basis := Basis().rotated(Vector3(0, 0, 1), angle + global_rotation_phase * 4.0)
				basis = basis.scaled(Vector3.ONE * (0.8 + bass * 0.7))
				p_mm.set_instance_transform(i, Transform3D(basis, pos))
			
			for i in range(SECONDARY_INSTANCE_COUNT):
				var frac := float(i) / float(SECONDARY_INSTANCE_COUNT)
				var angle := -frac * TAU * 4.0 - secondary_rotation_phase * 2.0
				var r := 4.0 + sin(frac * TAU + global_rotation_phase) * 2.0
				var pos := Vector3(cos(angle) * r, sin(angle) * r, -8.0 + frac * 12.0)
				var basis := Basis().rotated(Vector3(1, 1, 1).normalized(), secondary_rotation_phase * 3.0)
				basis = basis.scaled(Vector3.ONE * (0.6 + treble * 0.8))
				s_mm.set_instance_transform(i, Transform3D(basis, pos))

		"spiced_blues":
			# Torus-knot mandala (p=3, q=4)
			var p := 3.0
			var q := 4.0
			for i in range(PRIMARY_INSTANCE_COUNT):
				var phi := (float(i) / float(PRIMARY_INSTANCE_COUNT)) * TAU + global_rotation_phase * 0.8
				var r_knot := 4.5 + cos(q * phi) * 1.5 + bass * 1.5
				var x := r_knot * cos(p * phi)
				var y := r_knot * sin(p * phi)
				var z := -7.0 + sin(q * phi) * 3.0
				var pos := Vector3(x, y, z)
				var basis := Basis().rotated(Vector3(cos(phi), sin(phi), 0).normalized(), phi * 2.0)
				basis = basis.scaled(Vector3.ONE * (0.85 + mid * 0.6))
				p_mm.set_instance_transform(i, Transform3D(basis, pos))
			
			for i in range(SECONDARY_INSTANCE_COUNT):
				var angle := (float(i) / float(SECONDARY_INSTANCE_COUNT)) * TAU - secondary_rotation_phase
				var pos := Vector3(cos(angle) * 7.0, sin(angle) * 7.0, -10.0 + sin(angle * 5.0) * 2.0)
				var basis := Basis().rotated(Vector3(0, 0, 1), angle * 3.0).scaled(Vector3.ONE * (0.5 + treble * 0.5))
				s_mm.set_instance_transform(i, Transform3D(basis, pos))
