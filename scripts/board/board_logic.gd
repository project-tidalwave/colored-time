class_name BoardLogic
extends RefCounted

const WIDTH := 8
const HEIGHT := 8

enum SpecialType {
	NONE = 0,
	FLAME = 1,      # 4-in-a-row: 3x3 blast
	STAR = 2,       # T or L shape: row and column laser clear
	HYPERCUBE = 3   # 5-in-a-row line: clears all gems of swapped color
}

class Cell:
	var active: bool = true
	var color: int = -1
	var special: int = SpecialType.NONE
	var ice_hp: int = 0
	
	func duplicate() -> Cell:
		var c := Cell.new()
		c.active = active
		c.color = color
		c.special = special
		c.ice_hp = ice_hp
		return c

var grid: Array = [] # 2D array [y][x]
var num_colors: int = 6
var rng := RandomNumberGenerator.new()

func _init() -> void:
	_init_empty_grid()

func _init_empty_grid() -> void:
	grid.clear()
	for y in range(HEIGHT):
		var row: Array[Cell] = []
		for x in range(WIDTH):
			row.append(Cell.new())
		grid.append(row)

func get_cell(x: int, y: int) -> Cell:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return null
	return grid[y][x]

func init_for_track(track_data: Dictionary) -> void:
	var track_id: int = track_data.get("id", 1)
	var style: String = track_data.get("style", "bird_blues")
	num_colors = track_data.get("gem_color_count", 6)
	
	rng.seed = track_id * 10007 + 42
	_init_empty_grid()
	_apply_board_mask(style)
	_apply_chrono_ice(track_data)
	
	# Populate initial gems without matches and ensuring valid moves
	var attempts := 0
	while attempts < 100:
		attempts += 1
		for y in range(HEIGHT):
			for x in range(WIDTH):
				var cell := get_cell(x, y)
				if cell.active:
					cell.color = _pick_color_no_immediate_match(x, y)
					cell.special = SpecialType.NONE
		
		# Ensure at least 1 valid swap exists
		if not find_all_valid_moves().is_empty():
			break

func _apply_board_mask(style: String) -> void:
	match style:
		"medium_swing":
			# Symmetric 1-cell corner cutouts
			get_cell(0, 0).active = false
			get_cell(WIDTH - 1, 0).active = false
			get_cell(0, HEIGHT - 1).active = false
			get_cell(WIDTH - 1, HEIGHT - 1).active = false
		"burning_swing":
			# Octagonal cuts (corners of 2 cells)
			get_cell(0, 0).active = false
			get_cell(1, 0).active = false
			get_cell(0, 1).active = false
			get_cell(WIDTH - 1, 0).active = false
			get_cell(WIDTH - 2, 0).active = false
			get_cell(WIDTH - 1, 1).active = false
			get_cell(0, HEIGHT - 1).active = false
			get_cell(1, HEIGHT - 1).active = false
			get_cell(0, HEIGHT - 2).active = false
			get_cell(WIDTH - 1, HEIGHT - 1).active = false
			get_cell(WIDTH - 2, HEIGHT - 1).active = false
			get_cell(WIDTH - 1, HEIGHT - 2).active = false
		"spiced_blues":
			# Syncopated jazz channels (top and bottom asymmetric notches)
			get_cell(3, 0).active = false
			get_cell(4, HEIGHT - 1).active = false
		_:
			# bird_blues, slow_ballad, minor_blues use full 8x8
			pass

func _apply_chrono_ice(track_data: Dictionary) -> void:
	var style: String = track_data.get("style", "bird_blues")
	var ice_count: int = track_data.get("ice_count", 8)
	var track_id: int = track_data.get("id", 1)
	
	var candidates: Array[Vector2i] = []
	for y in range(HEIGHT):
		for x in range(WIDTH):
			if get_cell(x, y).active:
				candidates.append(Vector2i(x, y))
	
	match style:
		"bird_blues":
			# Edge focus
			candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				var dist_a := mini(mini(a.x, WIDTH - 1 - a.x), mini(a.y, HEIGHT - 1 - a.y))
				var dist_b := mini(mini(b.x, WIDTH - 1 - b.x), mini(b.y, HEIGHT - 1 - b.y))
				return dist_a < dist_b
			)
		"minor_blues":
			# Reinforced center & cross
			candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				var center_dist_a := absi(a.x - 3) + absi(a.y - 3)
				var center_dist_b := absi(b.x - 3) + absi(b.y - 3)
				return center_dist_a < center_dist_b
			)
		_:
			# Pseudo-random shuffle seeded
			for i in range(candidates.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var temp = candidates[i]
				candidates[i] = candidates[j]
				candidates[j] = temp
	
	var placed := 0
	for pos in candidates:
		if placed >= ice_count:
			break
		var cell := get_cell(pos.x, pos.y)
		if cell and cell.active:
			cell.ice_hp = 2 if (style in ["minor_blues", "spiced_blues"] and placed % 2 == 0) else 1
			placed += 1

func _pick_color_no_immediate_match(x: int, y: int) -> int:
	var invalid_colors := {}
	# Check horizontal
	if x >= 2:
		var c1 := get_cell(x - 1, y).color
		var c2 := get_cell(x - 2, y).color
		if c1 != -1 and c1 == c2:
			invalid_colors[c1] = true
	# Check vertical
	if y >= 2:
		var c1 := get_cell(x, y - 1).color
		var c2 := get_cell(x, y - 2).color
		if c1 != -1 and c1 == c2:
			invalid_colors[c1] = true
	
	var valid_pool: Array[int] = []
	for c in range(num_colors):
		if not invalid_colors.has(c):
			valid_pool.append(c)
	
	if valid_pool.is_empty():
		return rng.randi_range(0, num_colors - 1)
	return valid_pool[rng.randi_range(0, valid_pool.size() - 1)]

func can_swap(p1: Vector2i, p2: Vector2i) -> bool:
	var c1 := get_cell(p1.x, p1.y)
	var c2 := get_cell(p2.x, p2.y)
	if not c1 or not c2 or not c1.active or not c2.active:
		return false
	# Must be orthogonally adjacent
	var dist := absi(p1.x - p2.x) + absi(p1.y - p2.y)
	if dist != 1:
		return false
	
	# Hypercube swap with any gem is always valid
	if c1.special == SpecialType.HYPERCUBE or c2.special == SpecialType.HYPERCUBE:
		return true
	
	# Hypothetically swap and test for matches
	_swap_cells(p1, p2)
	var matches := _detect_raw_matches()
	_swap_cells(p1, p2) # Undo
	return not matches.is_empty()

func execute_swap(p1: Vector2i, p2: Vector2i) -> void:
	_swap_cells(p1, p2)

func _swap_cells(p1: Vector2i, p2: Vector2i) -> void:
	var c1 := get_cell(p1.x, p1.y)
	var c2 := get_cell(p2.x, p2.y)
	var temp_color := c1.color
	var temp_special := c1.special
	c1.color = c2.color
	c1.special = c2.special
	c2.color = temp_color
	c2.special = temp_special

func _detect_raw_matches() -> Array[Dictionary]:
	# Returns array of match dictionaries: {"type": "h"/"v", "cells": [Vector2i, ...], "color": int}
	var results: Array[Dictionary] = []
	
	# Horizontal runs
	for y in range(HEIGHT):
		var match_len := 1
		for x in range(1, WIDTH):
			var cur := get_cell(x, y)
			var prev := get_cell(x - 1, y)
			if cur.active and prev.active and cur.color != -1 and cur.color == prev.color:
				match_len += 1
			else:
				if match_len >= 3:
					var cells: Array[Vector2i] = []
					for k in range(match_len):
						cells.append(Vector2i(x - 1 - k, y))
					results.append({"type": "h", "cells": cells, "color": prev.color})
				match_len = 1
		if match_len >= 3:
			var cells: Array[Vector2i] = []
			for k in range(match_len):
				cells.append(Vector2i(WIDTH - 1 - k, y))
			results.append({"type": "h", "cells": cells, "color": get_cell(WIDTH - 1, y).color})
	
	# Vertical runs
	for x in range(WIDTH):
		var match_len := 1
		for y in range(1, HEIGHT):
			var cur := get_cell(x, y)
			var prev := get_cell(x, y - 1)
			if cur.active and prev.active and cur.color != -1 and cur.color == prev.color:
				match_len += 1
			else:
				if match_len >= 3:
					var cells: Array[Vector2i] = []
					for k in range(match_len):
						cells.append(Vector2i(x, y - 1 - k))
					results.append({"type": "v", "cells": cells, "color": prev.color})
				match_len = 1
		if match_len >= 3:
			var cells: Array[Vector2i] = []
			for k in range(match_len):
				cells.append(Vector2i(x, HEIGHT - 1 - k))
			results.append({"type": "v", "cells": cells, "color": get_cell(x, HEIGHT - 1).color})
	
	return results

func resolve_matches_and_specials(last_swap_pos: Vector2i = Vector2i(-1, -1), swap_pos_alt: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	# Returns:
	# {
	#   "cleared_cells": [Vector2i, ...],
	#   "special_spawns": {Vector2i: SpecialType},
	#   "ice_damaged": [Vector2i, ...],
	#   "ice_shattered": [Vector2i, ...],
	#   "score_delta": int,
	#   "special_events": [String, ...]
	# }
	var raw_matches := _detect_raw_matches()
	var cleared_dict: Dictionary = {} # Vector2i -> bool
	var special_spawns: Dictionary = {} # Vector2i -> SpecialType
	var ice_damaged: Array[Vector2i] = []
	var ice_shattered: Array[Vector2i] = []
	var special_events: Array[String] = []
	var score_delta := 0
	
	for m in raw_matches:
		var cells: Array = m["cells"]
		for cell_pos in cells:
			cleared_dict[cell_pos] = true
	
	score_delta += cleared_dict.size() * 100
	
	# Detect Star Gems (T/L shape intersections between H and V runs of the same color)
	var consumed_matches: Dictionary = {}
	for i in range(raw_matches.size()):
		var m1: Dictionary = raw_matches[i]
		if m1["type"] != "h":
			continue
		for j in range(raw_matches.size()):
			var m2: Dictionary = raw_matches[j]
			if m2["type"] != "v" or m1["color"] != m2["color"]:
				continue
			for p1: Vector2i in m1["cells"]:
				if m2["cells"].has(p1):
					special_spawns[p1] = SpecialType.STAR
					special_events.append("STAR_CREATED")
					score_delta += 500
					consumed_matches[i] = true
					consumed_matches[j] = true
					break
	
	# Detect Line Specials (5-in-a-row Hypercube, 4-in-a-row Flame Gem)
	for i in range(raw_matches.size()):
		if consumed_matches.has(i):
			continue
		var m: Dictionary = raw_matches[i]
		var cells: Array = m["cells"]
		var count: int = cells.size()
		
		if count >= 5:
			var spawn_pos: Vector2i = Vector2i(-1, -1)
			if cells.has(last_swap_pos):
				spawn_pos = last_swap_pos
			elif cells.has(swap_pos_alt):
				spawn_pos = swap_pos_alt
			else:
				spawn_pos = cells[count / 2]
			special_spawns[spawn_pos] = SpecialType.HYPERCUBE
			special_events.append("HYPERCUBE_CREATED")
			score_delta += 1000
		elif count == 4:
			var spawn_pos: Vector2i = Vector2i(-1, -1)
			if cells.has(last_swap_pos):
				spawn_pos = last_swap_pos
			elif cells.has(swap_pos_alt):
				spawn_pos = swap_pos_alt
			else:
				spawn_pos = cells[count / 2]
			special_spawns[spawn_pos] = SpecialType.FLAME
			special_events.append("FLAME_CREATED")
			score_delta += 250
	# Trigger Special Gem Detonations for matched specials
	var specials_to_detonate: Array[Vector2i] = []
	for pos in cleared_dict.keys():
		var c := get_cell(pos.x, pos.y)
		if c and c.special != SpecialType.NONE and not special_spawns.has(pos):
			specials_to_detonate.append(pos)
	
	# Recursive detonation queue
	var detonated_specials := {}
	while not specials_to_detonate.is_empty():
		var pos: Vector2i = specials_to_detonate.pop_front()
		if detonated_specials.has(pos):
			continue
		detonated_specials[pos] = true
		
		var c := get_cell(pos.x, pos.y)
		if not c:
			continue
		
		match c.special:
			SpecialType.FLAME:
				special_events.append("FLAME_BLAST")
				score_delta += 400
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var target_pos := Vector2i(pos.x + dx, pos.y + dy)
						var tc := get_cell(target_pos.x, target_pos.y)
						if tc and tc.active:
							cleared_dict[target_pos] = true
							if tc.special != SpecialType.NONE and not detonated_specials.has(target_pos):
								specials_to_detonate.append(target_pos)
			SpecialType.STAR:
				special_events.append("STAR_LASER")
				score_delta += 600
				# Entire row and column
				for x in range(WIDTH):
					var target_pos := Vector2i(x, pos.y)
					var tc := get_cell(target_pos.x, target_pos.y)
					if tc and tc.active:
						cleared_dict[target_pos] = true
						if tc.special != SpecialType.NONE and not detonated_specials.has(target_pos):
							specials_to_detonate.append(target_pos)
				for y in range(HEIGHT):
					var target_pos := Vector2i(pos.x, y)
					var tc := get_cell(target_pos.x, target_pos.y)
					if tc and tc.active:
						cleared_dict[target_pos] = true
						if tc.special != SpecialType.NONE and not detonated_specials.has(target_pos):
							specials_to_detonate.append(target_pos)
			SpecialType.HYPERCUBE:
				special_events.append("HYPERCUBE_WIPE")
				score_delta += 1500
				var target_color := c.color if c.color != -1 else rng.randi_range(0, num_colors - 1)
				for y in range(HEIGHT):
					for x in range(WIDTH):
						var tc := get_cell(x, y)
						if tc and tc.active and tc.color == target_color:
							cleared_dict[Vector2i(x, y)] = true
							if tc.special != SpecialType.NONE and not detonated_specials.has(Vector2i(x, y)):
								specials_to_detonate.append(Vector2i(x, y))
	
	# Chrono Ice Damage Check (damaged if cell is cleared OR orthogonally adjacent to cleared cell)
	var ice_damage_candidates := {}
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for pos in cleared_dict.keys():
		ice_damage_candidates[pos] = true
		for offset: Vector2i in offsets:
			var adj: Vector2i = pos + offset
			var ac := get_cell(adj.x, adj.y)
			if ac and ac.active and ac.ice_hp > 0:
				ice_damage_candidates[adj] = true
	
	for pos in ice_damage_candidates.keys():
		var cell := get_cell(pos.x, pos.y)
		if cell and cell.ice_hp > 0:
			cell.ice_hp -= 1
			ice_damaged.append(pos)
			if cell.ice_hp == 0:
				ice_shattered.append(pos)
				score_delta += 300
	
	# Apply clearing and special placement on logic grid
	for pos in cleared_dict.keys():
		var cell := get_cell(pos.x, pos.y)
		if cell:
			if special_spawns.has(pos):
				cell.special = special_spawns[pos]
				# Retain color for flame and star, hypercube is prismatic (-1)
				if cell.special == SpecialType.HYPERCUBE:
					cell.color = -1
			else:
				cell.color = -1
				cell.special = SpecialType.NONE
	
	return {
		"cleared_cells": cleared_dict.keys(),
		"special_spawns": special_spawns,
		"ice_damaged": ice_damaged,
		"ice_shattered": ice_shattered,
		"score_delta": score_delta,
		"special_events": special_events
	}

func resolve_hypercube_swap(hyper_pos: Vector2i, target_pos: Vector2i) -> Dictionary:
	var hc := get_cell(hyper_pos.x, hyper_pos.y)
	var tc := get_cell(target_pos.x, target_pos.y)
	var cleared_cells: Array[Vector2i] = [hyper_pos]
	var score_delta := 1500
	
	if tc.special == SpecialType.HYPERCUBE:
		# Double Hypercube swap: Clears entire active board!
		for y in range(HEIGHT):
			for x in range(WIDTH):
				var cell := get_cell(x, y)
				if cell.active:
					cleared_cells.append(Vector2i(x, y))
					cell.color = -1
					cell.special = SpecialType.NONE
		score_delta = 5000
	else:
		var target_color := tc.color
		for y in range(HEIGHT):
			for x in range(WIDTH):
				var cell := get_cell(x, y)
				if cell.active and cell.color == target_color:
					cleared_cells.append(Vector2i(x, y))
					cell.color = -1
					cell.special = SpecialType.NONE
		hc.color = -1
		hc.special = SpecialType.NONE
	
	# Damage ice on cleared cells
	var ice_damaged: Array[Vector2i] = []
	var ice_shattered: Array[Vector2i] = []
	for pos in cleared_cells:
		var cell := get_cell(pos.x, pos.y)
		if cell and cell.ice_hp > 0:
			cell.ice_hp -= 1
			ice_damaged.append(pos)
			if cell.ice_hp == 0:
				ice_shattered.append(pos)
				score_delta += 300
	
	return {
		"cleared_cells": cleared_cells,
		"special_spawns": {},
		"ice_damaged": ice_damaged,
		"ice_shattered": ice_shattered,
		"score_delta": score_delta,
		"special_events": ["HYPERCUBE_WIPE"]
	}

func apply_gravity_and_refill() -> Dictionary:
	# Returns:
	# {
	#   "movements": [{"from": Vector2i, "to": Vector2i, "color": int, "special": int}],
	#   "spawns": [{"pos": Vector2i, "color": int, "special": int}]
	# }
	var movements: Array[Dictionary] = []
	var spawns: Array[Dictionary] = []
	
	for x in range(WIDTH):
		# Process column from bottom to top
		for y in range(HEIGHT - 1, -1, -1):
			var cell := get_cell(x, y)
			if not cell.active or cell.color != -1:
				continue
			
			# Find lowest cell above this that has a gem
			var found_source := false
			for source_y in range(y - 1, -1, -1):
				var source_cell := get_cell(x, source_y)
				if source_cell.active and source_cell.color != -1:
					cell.color = source_cell.color
					cell.special = source_cell.special
					source_cell.color = -1
					source_cell.special = SpecialType.NONE
					movements.append({
						"from": Vector2i(x, source_y),
						"to": Vector2i(x, y),
						"color": cell.color,
						"special": cell.special
					})
					found_source = true
					break
			
			# If no gem above, spawn a new one from the top
			if not found_source and cell.active:
				cell.color = rng.randi_range(0, num_colors - 1)
				cell.special = SpecialType.NONE
				spawns.append({
					"pos": Vector2i(x, y),
					"color": cell.color,
					"special": cell.special
				})
	
	return {"movements": movements, "spawns": spawns}

func find_all_valid_moves() -> Array[Dictionary]:
	var valid_moves: Array[Dictionary] = []
	
	# Horizontal swaps
	for y in range(HEIGHT):
		for x in range(WIDTH - 1):
			var p1 := Vector2i(x, y)
			var p2 := Vector2i(x + 1, y)
			if can_swap(p1, p2):
				valid_moves.append({"p1": p1, "p2": p2})
	
	# Vertical swaps
	for x in range(WIDTH):
		for y in range(HEIGHT - 1):
			var p1 := Vector2i(x, y)
			var p2 := Vector2i(x, y + 1)
			if can_swap(p1, p2):
				valid_moves.append({"p1": p1, "p2": p2})
	
	return valid_moves

func reshuffle_board() -> void:
	var gems: Array[Dictionary] = []
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell := get_cell(x, y)
			if cell.active and cell.color != -1:
				gems.append({"color": cell.color, "special": cell.special})
	
	var attempts := 0
	while attempts < 50:
		attempts += 1
		# Shuffle gems
		for i in range(gems.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var temp = gems[i]
			gems[i] = gems[j]
			gems[j] = temp
		
		# Place back
		var idx := 0
		for y in range(HEIGHT):
			for x in range(WIDTH):
				var cell := get_cell(x, y)
				if cell.active and idx < gems.size():
					cell.color = gems[idx]["color"]
					cell.special = gems[idx]["special"]
					idx += 1
		
		# Verify no immediate match and at least 1 valid move
		if _detect_raw_matches().is_empty() and not find_all_valid_moves().is_empty():
			break

func count_remaining_ice() -> int:
	var count := 0
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell := get_cell(x, y)
			if cell and cell.active and cell.ice_hp > 0:
				count += 1
	return count
