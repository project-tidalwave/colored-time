class_name Main
extends Node

const TrackCatalog = preload("res://scripts/core/track_catalog.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")
const AudioManager = preload("res://scripts/core/audio_manager.gd")
const ProceduralSFX = preload("res://scripts/core/procedural_sfx.gd")
const BoardLogic = preload("res://scripts/board/board_logic.gd")
const ProceduralBackground3D = preload("res://scripts/visuals/procedural_background_3d.gd")
const BoardView = preload("res://scripts/ui/board_view.gd")
const ArcadeHUD = preload("res://scripts/ui/arcade_hud.gd")

enum GameMode {
	NONE,
	CAMPAIGN,
	ENDLESS
}

var current_mode: GameMode = GameMode.NONE
var current_track_data: Dictionary = {}
var current_track_id: int = 1

var board_logic: BoardLogic
var audio_manager: AudioManager
var sfx: ProceduralSFX
var bg_3d: ProceduralBackground3D

var canvas_layer: CanvasLayer
var hud: ArcadeHUD
var board_view: BoardView

# In-game stats
var score: int = 0
var target_score: int = 5000
var cascade_count: int = 0
var max_cascade: int = 0
var on_beat_matches: int = 0
var total_matches: int = 0
var level_cleared: bool = false
var is_resolving_turn: bool = false

func _init() -> void:
	name = "Main"

func _ready() -> void:
	_setup_core_nodes()
	_setup_ui()
	_connect_signals()
	
	# Start in carousel preview mode
	hud.show_carousel()

func _setup_core_nodes() -> void:
	# 3D Background
	bg_3d = ProceduralBackground3D.new()
	add_child(bg_3d)
	
	# Audio Manager
	audio_manager = AudioManager.new()
	add_child(audio_manager)
	
	# Procedural SFX
	sfx = ProceduralSFX.new()
	add_child(sfx)
	
	# Board Engine
	board_logic = BoardLogic.new()

func _setup_ui() -> void:
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	# Board View (centered)
	board_view = BoardView.new()
	# Center board horizontally, positioned comfortably below top HUD
	board_view.position = Vector2(360, 130)
	canvas_layer.add_child(board_view)
	board_view.visible = false
	
	# Arcade HUD
	hud = ArcadeHUD.new()
	canvas_layer.add_child(hud)

func _connect_signals() -> void:
	hud.play_campaign_requested.connect(_on_play_campaign)
	hud.play_endless_requested.connect(_on_play_endless)
	hud.track_selected_for_preview.connect(_on_track_preview)
	hud.pause_toggled.connect(_on_pause_toggled)
	hud.next_level_requested.connect(_on_next_level)
	hud.replay_requested.connect(_on_replay_level)
	hud.return_to_carousel_requested.connect(_on_return_to_carousel)
	
	board_view.swap_requested.connect(_on_board_swap_requested)
	audio_manager.track_finished.connect(_on_track_finished)

func _on_track_preview(track_id: int) -> void:
	current_track_id = track_id
	var t := TrackCatalog.get_track_by_id(track_id)
	if t.is_empty():
		return
	current_track_data = t
	
	# Update 3D visual archetype and color palette
	bg_3d.set_track_style(t["style"], t["key_hue"])
	sfx.set_track_tuning(t["root_freq"], t["style"])
	
	# Play music preview
	var stream := load(t["file_path"]) as AudioStream
	if stream:
		audio_manager.play_track(stream, float(t["bpm"]))

func _on_play_campaign(track_id: int) -> void:
	current_mode = GameMode.CAMPAIGN
	current_track_id = track_id
	_start_level(track_id)

func _on_play_endless() -> void:
	current_mode = GameMode.ENDLESS
	_start_level(current_track_id)

func _start_level(track_id: int) -> void:
	var t := TrackCatalog.get_track_by_id(track_id)
	if t.is_empty():
		return
	current_track_data = t
	
	# Reset state
	score = 0
	target_score = t["target_score"]
	cascade_count = 0
	max_cascade = 0
	on_beat_matches = 0
	total_matches = 0
	level_cleared = false
	is_resolving_turn = false
	
	# Configure Audio & Visuals
	bg_3d.set_track_style(t["style"], t["key_hue"])
	sfx.set_track_tuning(t["root_freq"], t["style"])
	var stream := load(t["file_path"]) as AudioStream
	if stream:
		audio_manager.play_track(stream, float(t["bpm"]))
	
	# Init Board
	board_logic.init_for_track(t)
	board_view.sync_board(board_logic)
	board_view.visible = true
	
	hud.show_gameplay()

func _on_board_swap_requested(p1: Vector2i, p2: Vector2i) -> void:
	if is_resolving_turn or level_cleared:
		return
	
	var is_beat := audio_manager.is_on_beat(0.120)
	var c1 := board_logic.get_cell(p1.x, p1.y)
	var c2 := board_logic.get_cell(p2.x, p2.y)
	
	# Special check for Hypercube swap
	var is_hypercube_swap := (c1.special == BoardLogic.SpecialType.HYPERCUBE or c2.special == BoardLogic.SpecialType.HYPERCUBE)
	
	if not board_logic.can_swap(p1, p2):
		# Invalid swap
		sfx.play_ui_click(false)
		board_view.animate_invalid_swap(p1, p2)
		return
	
	is_resolving_turn = true
	
	if is_hypercube_swap:
		var hyper_pos := p1 if c1.special == BoardLogic.SpecialType.HYPERCUBE else p2
		var target_pos := p2 if hyper_pos == p1 else p1
		board_view.animate_swap(p1, p2, func():
			_execute_hypercube_resolution(hyper_pos, target_pos, is_beat)
		)
	else:
		board_logic.execute_swap(p1, p2)
		board_view.animate_swap(p1, p2, func():
			_start_cascade_chain(p1, p2, is_beat)
		)

func _execute_hypercube_resolution(hyper_pos: Vector2i, target_pos: Vector2i, is_beat: bool) -> void:
	cascade_count = 1
	var result := board_logic.resolve_hypercube_swap(hyper_pos, target_pos)
	sfx.play_hypercube_wipe()
	bg_3d.trigger_beat_shockwave(2.0, Color.WHITE)
	_apply_turn_result(result, is_beat, hyper_pos)

func _start_cascade_chain(p1: Vector2i, p2: Vector2i, is_beat: bool) -> void:
	cascade_count = 0
	_step_cascade(p1, p2, is_beat)

const MAX_CASCADE_STEPS := 30

func _step_cascade(p1: Vector2i, p2: Vector2i, is_beat: bool) -> void:
	if cascade_count >= MAX_CASCADE_STEPS:
		push_warning("Reached maximum cascade depth safety limit.")
		is_resolving_turn = false
		cascade_count = 0
		_check_objectives()
		return

	var result := board_logic.resolve_matches_and_specials(p1, p2)
	var cleared_cells: Array = result["cleared_cells"]
	
	if cleared_cells.is_empty():
		# Cascade sequence finished
		is_resolving_turn = false
		cascade_count = 0
		
		# Dead-board check
		if board_logic.find_all_valid_moves().is_empty():
			board_logic.reshuffle_board()
			board_view.sync_board(board_logic)
			board_view.show_floating_text("RESHUFFLED!", Vector2i(3, 3), Color.YELLOW)
		
		_check_objectives()
		return
	
	# Matches found in this cascade step
	cascade_count += 1
	max_cascade = maxi(max_cascade, cascade_count)
	total_matches += 1
	
	var text_pos := p1 if p1 != Vector2i(-1, -1) else p2
	if text_pos == Vector2i(-1, -1) and not cleared_cells.is_empty():
		text_pos = cleared_cells[0]
	
	_apply_turn_result(result, is_beat, text_pos)

func _apply_turn_result(result: Dictionary, is_beat: bool, text_pos: Vector2i) -> void:
	var delta_score: int = result["score_delta"]
	
	if is_beat:
		delta_score = int(delta_score * 1.5)
		if cascade_count == 1:
			on_beat_matches += 1
			hud.trigger_on_beat_banner()
			bg_3d.trigger_beat_shockwave(1.2, Color(1.0, 0.9, 0.2))
			board_view.show_floating_text("ON BEAT! 1.5x", text_pos, Color(1.0, 0.9, 0.2))
	
	# Apply cascade multiplier
	if cascade_count > 1:
		delta_score = delta_score * cascade_count
		board_view.show_floating_text("CASCADE x%d!" % cascade_count, text_pos, Color(0.4, 0.9, 1.0))
	
	score += delta_score
	
	# Audio SFX handling
	sfx.play_match_chime(cascade_count - 1, is_beat)
	
	var special_events: Array = result["special_events"]
	for ev in special_events:
		match ev:
			"FLAME_BLAST":
				sfx.play_flame_blast()
				bg_3d.trigger_beat_shockwave(1.5, Color(1.0, 0.4, 0.1))
			"STAR_LASER":
				sfx.play_star_laser()
				bg_3d.trigger_beat_shockwave(1.5, Color(0.2, 0.8, 1.0))
			"HYPERCUBE_WIPE":
				sfx.play_hypercube_wipe()
				bg_3d.trigger_beat_shockwave(2.0, Color.WHITE)
	
	var ice_shattered: Array = result["ice_shattered"]
	if not ice_shattered.is_empty():
		sfx.play_ice_shatter()
	
	# Animate clears
	board_view.animate_clears_and_specials(
		result["cleared_cells"],
		result["special_spawns"],
		result["ice_damaged"],
		result["ice_shattered"],
		func():
			# Animate gravity drop
			var refill := board_logic.apply_gravity_and_refill()
			board_view.animate_gravity_and_spawns(refill["movements"], refill["spawns"], func():
				_step_cascade(Vector2i(-1, -1), Vector2i(-1, -1), is_beat)
			)
	)

func _check_objectives() -> void:
	var remaining_ice := board_logic.count_remaining_ice()
	if current_mode == GameMode.CAMPAIGN:
		if score >= target_score and remaining_ice == 0 and not level_cleared:
			level_cleared = true
			_on_campaign_victory()
	elif current_mode == GameMode.ENDLESS:
		# Endless advances to next track when score reaches target
		if score >= target_score:
			_advance_endless_track()

func _on_campaign_victory() -> void:
	# Calculate stars: 1 Star = 100%, 2 Stars = 140%, 3 Stars = 180%
	var stars := 1
	if score >= int(target_score * 1.8):
		stars = 3
	elif score >= int(target_score * 1.4):
		stars = 2
	
	SaveManager.record_level_result(current_track_id, score, stars, max_cascade, on_beat_matches)
	
	var stars_str := ""
	for i in range(3):
		stars_str += "★" if i < stars else "☆"
	
	var acc := int((float(on_beat_matches) / float(maxi(total_matches, 1))) * 100.0)
	var details := "Final Score: %d\nStars: %s\nMax Cascade: %dx\nOn-Beat Accuracy: %d%%" % [
		score, stars_str, max_cascade, acc
	]
	hud.show_results_modal("LEVEL CLEARED!", details, true)

func _advance_endless_track() -> void:
	var next_id := (current_track_id % 36) + 1
	current_track_id = next_id
	var t := TrackCatalog.get_track_by_id(next_id)
	current_track_data = t
	target_score += t["target_score"]
	
	bg_3d.set_track_style(t["style"], t["key_hue"])
	sfx.set_track_tuning(t["root_freq"], t["style"])
	var stream := load(t["file_path"]) as AudioStream
	if stream:
		audio_manager.play_track(stream, float(t["bpm"]))
	
	board_view.show_floating_text("STAGE CLEARED! NEXT TRACK", Vector2i(2, 3), Color.CYAN)

func _on_track_finished() -> void:
	if current_mode == GameMode.CAMPAIGN:
		if not level_cleared:
			# Track ended before objectives were met
			var details := "Target: %d pts | Scored: %d pts\nRemaining Ice: %d" % [
				target_score, score, board_logic.count_remaining_ice()
			]
			hud.show_results_modal("TRACK ENDED", details, false)
	elif current_mode == GameMode.ENDLESS:
		# In endless, loop/cycle to next track seamlessly
		_advance_endless_track()

func _on_pause_toggled() -> void:
	if audio_manager.is_playing:
		audio_manager.pause_track()
		hud.show_results_modal("PAUSED", "Current Score: %d" % score, false)
	else:
		audio_manager.resume_track()
		hud.hide_modal()

func _on_next_level() -> void:
	var next_id := (current_track_id % 36) + 1
	hud.hide_modal()
	_start_level(next_id)

func _on_replay_level() -> void:
	hud.hide_modal()
	_start_level(current_track_id)

func _on_return_to_carousel() -> void:
	board_view.visible = false
	current_mode = GameMode.NONE
	hud.show_carousel()

func _process(delta: float) -> void:
	var bass := audio_manager.bass_magnitude
	var mid := audio_manager.mid_magnitude
	var treble := audio_manager.treble_magnitude
	var phase := audio_manager.beat_phase
	
	# Update 3D background reaction
	if bg_3d:
		bg_3d.update_audio_reaction(delta, bass, mid, treble, phase)
	
	# Update 2D Board & HUD visuals
	if board_view and board_view.visible:
		board_view.update_beat_visuals(phase, bass)
		hud.update_hud_state(
			current_track_data,
			score,
			target_score,
			audio_manager.get_time_remaining(),
			board_logic.count_remaining_ice(),
			cascade_count if cascade_count > 0 else 1,
			phase
		)
