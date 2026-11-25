class_name BoardView
extends Control

const BoardLogic = preload("res://scripts/board/board_logic.gd")

signal swap_requested(p1: Vector2i, p2: Vector2i)

const CELL_SIZE := 70.0
const BOARD_SIZE := 560.0 # 8 * 70

# 7 Gem Color specifications from specs.yml
const GEM_COLORS: Array[Color] = [
	Color("#FF1E56"), # Ruby Crimson
	Color("#FFB800"), # Amber Gold
	Color("#00F5A0"), # Emerald Mint
	Color("#00D2FF"), # Sapphire Cyan
	Color("#A855F7"), # Amethyst Violet
	Color("#F8FAFC"), # Pearl White
	Color("#38BDF8"), # Obsidian Chrome (7th)
]

var board_bg: Panel
var board_border: ReferenceRect
var gem_nodes: Dictionary = {} # Vector2i -> ColorRect
var ice_nodes: Dictionary = {} # Vector2i -> ColorRect
var selected_cell: Vector2i = Vector2i(-1, -1)
var is_animating: bool = false
var hint_cell_a: Vector2i = Vector2i(-1, -1)
var hint_cell_b: Vector2i = Vector2i(-1, -1)
var hint_timer: float = 0.0

var gem_shader: Shader
var ice_shader: Shader

func _init() -> void:
	name = "BoardView"
	custom_minimum_size = Vector2(BOARD_SIZE, BOARD_SIZE)
	size = Vector2(BOARD_SIZE, BOARD_SIZE)
	gem_shader = preload("res://shaders/gem_sdf.gdshader")
	ice_shader = preload("res://shaders/chrono_ice.gdshader")
	_setup_board_frame()

func _ready() -> void:
	pass

func _setup_board_frame() -> void:
	# Translucent glass board panel
	board_bg = Panel.new()
	board_bg.size = size
	board_bg.mouse_filter = MOUSE_FILTER_IGNORE
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.02, 0.02, 0.05, 0.65)
	stylebox.set_corner_radius_all(14)
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.2, 0.6, 1.0, 0.5)
	board_bg.add_theme_stylebox_override("panel", stylebox)
	add_child(board_bg)

func sync_board(board_logic: BoardLogic) -> void:
	# Clear existing gem and ice nodes
	for node in gem_nodes.values():
		node.queue_free()
	gem_nodes.clear()
	
	for node in ice_nodes.values():
		node.queue_free()
	ice_nodes.clear()
	
	selected_cell = Vector2i(-1, -1)
	
	# Instantiate cells
	for y in range(BoardLogic.HEIGHT):
		for x in range(BoardLogic.WIDTH):
			var cell := board_logic.get_cell(x, y)
			if not cell or not cell.active:
				continue
			var pos := Vector2i(x, y)
			
			# Create gem if present
			if cell.color != -1 or cell.special == BoardLogic.SpecialType.HYPERCUBE:
				var gem := _create_gem_node(pos, cell.color, cell.special)
				add_child(gem)
				gem_nodes[pos] = gem
			
			# Create ice overlay if present
			if cell.ice_hp > 0:
				var ice := _create_ice_node(pos, cell.ice_hp)
				add_child(ice)
				ice_nodes[pos] = ice

func _create_gem_node(grid_pos: Vector2i, color_idx: int, special: int) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = Vector2(CELL_SIZE - 4.0, CELL_SIZE - 4.0)
	rect.position = Vector2(grid_pos.x * CELL_SIZE + 2.0, grid_pos.y * CELL_SIZE + 2.0)
	rect.pivot_offset = rect.size * 0.5
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	
	var mat := ShaderMaterial.new()
	mat.shader = gem_shader
	
	var cut := color_idx if color_idx >= 0 else 0
	var col := GEM_COLORS[color_idx] if (color_idx >= 0 and color_idx < GEM_COLORS.size()) else Color.WHITE
	
	mat.set_shader_parameter("cut_type", cut)
	mat.set_shader_parameter("gem_color", col)
	mat.set_shader_parameter("special_type", special)
	mat.set_shader_parameter("selected", 0.0)
	mat.set_shader_parameter("beat_pulse", 0.0)
	mat.set_shader_parameter("time_val", 0.0)
	
	rect.material = mat
	return rect

func _create_ice_node(grid_pos: Vector2i, hp: int) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = Vector2(CELL_SIZE - 2.0, CELL_SIZE - 2.0)
	rect.position = Vector2(grid_pos.x * CELL_SIZE + 1.0, grid_pos.y * CELL_SIZE + 1.0)
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	
	var mat := ShaderMaterial.new()
	mat.shader = ice_shader
	mat.set_shader_parameter("ice_hp", hp)
	mat.set_shader_parameter("time_val", 0.0)
	
	rect.material = mat
	return rect

func _gui_input(event: InputEvent) -> void:
	if not visible or is_animating:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos: Vector2 = event.position
		var gx := int(local_pos.x / CELL_SIZE)
		var gy := int(local_pos.y / CELL_SIZE)
		_handle_cell_click(Vector2i(gx, gy))
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_animating:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var rect := Rect2(global_position, size)
		if rect.has_point(event.global_position):
			var local_pos: Vector2 = event.global_position - global_position
			var gx := int(local_pos.x / CELL_SIZE)
			var gy := int(local_pos.y / CELL_SIZE)
			_handle_cell_click(Vector2i(gx, gy))
			var vp := get_viewport()
			if vp:
				vp.set_input_as_handled()

func _handle_cell_click(clicked: Vector2i) -> void:
	if clicked.x < 0 or clicked.x >= BoardLogic.WIDTH or clicked.y < 0 or clicked.y >= BoardLogic.HEIGHT:
		return
	
	if not gem_nodes.has(clicked):
		selected_cell = Vector2i(-1, -1)
		_update_selection_visuals()
		return
	
	if selected_cell == Vector2i(-1, -1):
		# First selection
		selected_cell = clicked
		_update_selection_visuals()
	elif selected_cell == clicked:
		# Deselect
		selected_cell = Vector2i(-1, -1)
		_update_selection_visuals()
	else:
		# Attempt swap
		var p1 := selected_cell
		var p2 := clicked
		selected_cell = Vector2i(-1, -1)
		_update_selection_visuals()
		swap_requested.emit(p1, p2)

func _update_selection_visuals() -> void:
	for pos in gem_nodes.keys():
		var node: ColorRect = gem_nodes[pos]
		if node and node.material:
			var is_sel: bool = (pos == selected_cell)
			node.material.set_shader_parameter("selected", 1.0 if is_sel else 0.0)
			if is_sel:
				var t := create_tween()
				t.tween_property(node, "scale", Vector2(1.15, 1.15), 0.1)
			else:
				var t := create_tween()
				t.tween_property(node, "scale", Vector2.ONE, 0.1)

func update_beat_visuals(beat_phase: float, bass: float) -> void:
	var pulse := (1.0 - beat_phase) * (0.6 + bass * 0.4)
	for node in gem_nodes.values():
		if node and node.material:
			node.material.set_shader_parameter("beat_pulse", pulse)
			node.material.set_shader_parameter("time_val", Time.get_ticks_msec() / 1000.0)
	
	# Pulse board border neon glow
	if board_bg:
		var sb := board_bg.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			var border_alpha := 0.35 + pulse * 0.55
			sb.border_color = Color(0.2, 0.7, 1.0, border_alpha)

func animate_swap(p1: Vector2i, p2: Vector2i, on_complete: Callable) -> void:
	is_animating = true
	var n1: ColorRect = gem_nodes.get(p1)
	var n2: ColorRect = gem_nodes.get(p2)
	
	var target_pos1 := Vector2(p2.x * CELL_SIZE + 2.0, p2.y * CELL_SIZE + 2.0)
	var target_pos2 := Vector2(p1.x * CELL_SIZE + 2.0, p1.y * CELL_SIZE + 2.0)
	
	var tween := create_tween().set_parallel(true)
	if n1:
		tween.tween_property(n1, "position", target_pos1, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if n2:
		tween.tween_property(n2, "position", target_pos2, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		# Update keys in dictionary
		gem_nodes.erase(p1)
		gem_nodes.erase(p2)
		if n1:
			gem_nodes[p2] = n1
		if n2:
			gem_nodes[p1] = n2
		is_animating = false
		on_complete.call()
	)

func animate_invalid_swap(p1: Vector2i, p2: Vector2i) -> void:
	is_animating = true
	var n1: ColorRect = gem_nodes.get(p1)
	var n2: ColorRect = gem_nodes.get(p2)
	
	var orig1 := Vector2(p1.x * CELL_SIZE + 2.0, p1.y * CELL_SIZE + 2.0)
	var orig2 := Vector2(p2.x * CELL_SIZE + 2.0, p2.y * CELL_SIZE + 2.0)
	
	var mid1 := orig1 + (orig2 - orig1) * 0.4
	var mid2 := orig2 + (orig1 - orig2) * 0.4
	
	var tween := create_tween().set_parallel(true)
	if n1:
		tween.tween_property(n1, "position", mid1, 0.1)
		tween.tween_property(n1, "position", orig1, 0.1).set_delay(0.1)
	if n2:
		tween.tween_property(n2, "position", mid2, 0.1)
		tween.tween_property(n2, "position", orig2, 0.1).set_delay(0.1)
	
	tween.chain().tween_callback(func():
		is_animating = false
	)

func animate_clears_and_specials(
	cleared: Array,
	special_spawns: Dictionary,
	ice_damaged: Array,
	ice_shattered: Array,
	on_complete: Callable
) -> void:
	is_animating = true
	var tween := create_tween().set_parallel(true)
	
	# Shrink and fade cleared gems
	for pos in cleared:
		if gem_nodes.has(pos):
			var node: ColorRect = gem_nodes[pos]
			if special_spawns.has(pos):
				# It transforms into a special gem!
				var new_special: int = special_spawns[pos]
				var mat: ShaderMaterial = node.material
				mat.set_shader_parameter("special_type", new_special)
				tween.tween_property(node, "scale", Vector2(1.3, 1.3), 0.15)
				tween.tween_property(node, "scale", Vector2.ONE, 0.15).set_delay(0.15)
			else:
				tween.tween_property(node, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tween.tween_property(node, "modulate:a", 0.0, 0.2)
	
	# Update Ice visuals
	for pos in ice_damaged:
		if ice_nodes.has(pos):
			var ice: ColorRect = ice_nodes[pos]
			var mat: ShaderMaterial = ice.material
			mat.set_shader_parameter("ice_hp", 1)
			# Brief white flash
			tween.tween_property(ice, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.08)
			tween.tween_property(ice, "modulate", Color.WHITE, 0.12).set_delay(0.08)
	
	for pos in ice_shattered:
		if ice_nodes.has(pos):
			var ice: ColorRect = ice_nodes[pos]
			tween.tween_property(ice, "scale", Vector2(1.4, 1.4), 0.18)
			tween.tween_property(ice, "modulate:a", 0.0, 0.18)
	
	tween.chain().tween_callback(func():
		for pos in cleared:
			if not special_spawns.has(pos) and gem_nodes.has(pos):
				gem_nodes[pos].queue_free()
				gem_nodes.erase(pos)
		
		for pos in ice_shattered:
			if ice_nodes.has(pos):
				ice_nodes[pos].queue_free()
				ice_nodes.erase(pos)
		
		is_animating = false
		on_complete.call()
	)

func animate_gravity_and_spawns(movements: Array, spawns: Array, on_complete: Callable) -> void:
	is_animating = true
	var tween := create_tween().set_parallel(true)
	
	# Move falling gems
	for move in movements:
		var from_pos: Vector2i = move["from"]
		var to_pos: Vector2i = move["to"]
		if gem_nodes.has(from_pos):
			var node: ColorRect = gem_nodes[from_pos]
			gem_nodes.erase(from_pos)
			gem_nodes[to_pos] = node
			var target_px := Vector2(to_pos.x * CELL_SIZE + 2.0, to_pos.y * CELL_SIZE + 2.0)
			tween.tween_property(node, "position", target_px, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Spawn new gems from top
	for sp in spawns:
		var pos: Vector2i = sp["pos"]
		var color_idx: int = sp["color"]
		var special: int = sp["special"]
		var node := _create_gem_node(pos, color_idx, special)
		var target_px := Vector2(pos.x * CELL_SIZE + 2.0, pos.y * CELL_SIZE + 2.0)
		var start_px := Vector2(pos.x * CELL_SIZE + 2.0, -CELL_SIZE)
		node.position = start_px
		add_child(node)
		gem_nodes[pos] = node
		tween.tween_property(node, "position", target_px, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		is_animating = false
		on_complete.call()
	)

func show_floating_text(text: String, grid_pos: Vector2i, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(grid_pos.x * CELL_SIZE, grid_pos.y * CELL_SIZE - 10.0)
	label.size = Vector2(CELL_SIZE, 30.0)
	label.modulate = color
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 35.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)
