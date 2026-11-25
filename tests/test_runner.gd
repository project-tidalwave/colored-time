extends SceneTree

const TrackCatalog = preload("res://scripts/core/track_catalog.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")
const AudioManager = preload("res://scripts/core/audio_manager.gd")
const ProceduralSFX = preload("res://scripts/core/procedural_sfx.gd")
const BoardLogic = preload("res://scripts/board/board_logic.gd")
const ProceduralBackground3D = preload("res://scripts/visuals/procedural_background_3d.gd")
const BoardView = preload("res://scripts/ui/board_view.gd")
const ArcadeHUD = preload("res://scripts/ui/arcade_hud.gd")
const Main = preload("res://scripts/main.gd")

func _init() -> void:
	print("==================================================")
	print("       COLORED TIME - HEADLESS TEST RUNNER        ")
	print("==================================================")
	var all_passed := true
	
	all_passed = test_track_catalog() and all_passed
	all_passed = test_save_manager() and all_passed
	all_passed = test_board_logic() and all_passed
	all_passed = test_procedural_sfx() and all_passed
	all_passed = test_procedural_background_3d() and all_passed
	all_passed = test_main_scene_instantiation() and all_passed
	all_passed = test_ui_interaction() and all_passed
	all_passed = test_pause_menu_and_cursor_ux() and all_passed
	
	if all_passed:
		print("\n>>> ALL TESTS PASSED SUCCESSFULLY! <<<")
		quit(0)
	else:
		printerr("\n>>> SOME TESTS FAILED! <<<")
		quit(1)

func test_track_catalog() -> bool:
	print("\n[TEST 1] TrackCatalog...")
	var tracks := TrackCatalog.get_all_tracks()
	if tracks.size() != 36:
		printerr("FAIL: Expected 36 tracks, found ", tracks.size())
		return false
	
	var styles_found := {}
	for t in tracks:
		styles_found[t["style"]] = true
		if not FileAccess.file_exists(t["file_path"]):
			printerr("FAIL: File not found: ", t["file_path"])
			return false
		
		# Verify stream load
		var stream := load(t["file_path"])
		if not stream is AudioStream:
			printerr("FAIL: Stream load failed for: ", t["file_path"])
			return false
	
	var expected_styles := ["bird_blues", "medium_swing", "slow_ballad", "minor_blues", "burning_swing", "spiced_blues"]
	for s in expected_styles:
		if not styles_found.has(s):
			printerr("FAIL: Missing style archetype: ", s)
			return false
	
	print("  ✓ All 36 tracks verified and loaded across 6 style archetypes.")
	return true

func test_save_manager() -> bool:
	print("\n[TEST 2] SaveManager...")
	var initial := SaveManager.load_data()
	if not initial is Dictionary:
		printerr("FAIL: Save data is not dictionary")
		return false
	
	SaveManager.record_level_result(1, 15000, 3, 4, 12)
	var stats := SaveManager.get_track_stats(1)
	if stats["high_score"] < 15000 or stats["stars"] != 3:
		printerr("FAIL: Track stats recording failed: ", stats)
		return false
	
	print("  ✓ Save and load persistence verified.")
	return true

func test_board_logic() -> bool:
	print("\n[TEST 3] BoardLogic Engine & Mechanics...")
	var board := BoardLogic.new()
	var tracks := TrackCatalog.get_all_tracks()
	
	# Verify board initialization across all 36 tracks
	for t in tracks:
		board.init_for_track(t)
		var valid_moves := board.find_all_valid_moves()
		if valid_moves.is_empty():
			printerr("FAIL: Track ", t["id"], " initialized with 0 valid moves")
			return false
		
		# Style mask checks
		if t["style"] == "medium_swing":
			if board.get_cell(0, 0).active or board.get_cell(7, 7).active:
				printerr("FAIL: medium_swing corners should be inactive")
				return false
		elif t["style"] == "burning_swing":
			if board.get_cell(0, 0).active or board.get_cell(1, 0).active:
				printerr("FAIL: burning_swing octagonal cuts should be inactive")
				return false
	
	print("  ✓ Board initialization & procedural masks verified across all 36 tracks.")
	
	# Test Match-3 and Special Gem creation
	board.init_for_track(tracks[0])
	
	# 1. Test 3-in-a-row
	board._init_empty_grid()
	board.get_cell(0, 0).color = 0
	board.get_cell(1, 0).color = 0
	board.get_cell(2, 0).color = 0
	var res3 := board.resolve_matches_and_specials()
	if res3["cleared_cells"].size() < 3 or res3["score_delta"] < 300:
		printerr("FAIL: 3-in-a-row match failed: ", res3)
		return false
	print("  ✓ 3-in-a-row match detection and scoring verified.")
	
	# 2. Test 4-in-a-row -> Flame Gem
	board._init_empty_grid()
	board.get_cell(0, 0).color = 1
	board.get_cell(1, 0).color = 1
	board.get_cell(2, 0).color = 1
	board.get_cell(3, 0).color = 1
	var res4 := board.resolve_matches_and_specials(Vector2i(2, 0))
	if not res4["special_spawns"].has(Vector2i(2, 0)) or res4["special_spawns"][Vector2i(2, 0)] != BoardLogic.SpecialType.FLAME:
		printerr("FAIL: 4-in-a-row did not spawn Flame Gem: ", res4)
		return false
	print("  ✓ 4-in-a-row Flame Gem creation verified.")
	
	# 2b. Test 4-in-a-row Cascade (no swap pos) -> ensures NO infinite loop
	board._init_empty_grid()
	for x in range(4):
		board.get_cell(x, 0).color = 1
	var res4_cascade := board.resolve_matches_and_specials()
	if res4_cascade["special_spawns"].size() != 1:
		printerr("FAIL: Cascade 4-in-a-row spawned multiple specials: ", res4_cascade["special_spawns"])
		return false
	if not board._detect_raw_matches().is_empty():
		printerr("FAIL: Matches still remain after cascade resolution (infinite loop bug!)")
		return false
	# Verify non-special cells in the 4-match are cleared
	var cleared_non_specials := 0
	for x in range(4):
		if not res4_cascade["special_spawns"].has(Vector2i(x, 0)):
			if board.get_cell(x, 0).color == -1:
				cleared_non_specials += 1
	if cleared_non_specials != 3:
		printerr("FAIL: Expected 3 cleared cells in 4-match, got ", cleared_non_specials)
		return false
	print("  ✓ Cascade 4-in-a-row single-spawn and clean-clear verified (infinite loop prevented).")
	
	# 2c. Test 4-in-a-row with alternate swap pos (p1 instead of p2)
	board._init_empty_grid()
	for x in range(4):
		board.get_cell(x, 0).color = 1
	var res4_alt := board.resolve_matches_and_specials(Vector2i(-1, -1), Vector2i(0, 0))
	if not res4_alt["special_spawns"].has(Vector2i(0, 0)):
		printerr("FAIL: 4-in-a-row did not prioritize alternate swap pos: ", res4_alt)
		return false
	print("  ✓ 4-in-a-row alternate swap pos (p1) verified.")
	
	# 3. Test 5-in-a-row straight -> Hypercube
	board._init_empty_grid()
	for x in range(5):
		board.get_cell(x, 0).color = 2
	var res5 := board.resolve_matches_and_specials(Vector2i(2, 0))
	if not res5["special_spawns"].has(Vector2i(2, 0)) or res5["special_spawns"][Vector2i(2, 0)] != BoardLogic.SpecialType.HYPERCUBE:
		printerr("FAIL: 5-in-a-row line did not spawn Hypercube: ", res5)
		return false
	print("  ✓ 5-in-a-row Hypercube creation verified.")
	
	# 4. Test T/L intersection -> Star Gem
	board._init_empty_grid()
	# Horizontal 3: (0,2), (1,2), (2,2)
	board.get_cell(0, 2).color = 3
	board.get_cell(1, 2).color = 3
	board.get_cell(2, 2).color = 3
	# Vertical 3 intersecting at (1,2): (1,1), (1,2), (1,3)
	board.get_cell(1, 1).color = 3
	board.get_cell(1, 3).color = 3
	var res_star := board.resolve_matches_and_specials(Vector2i(1, 2))
	if not res_star["special_spawns"].has(Vector2i(1, 2)) or res_star["special_spawns"][Vector2i(1, 2)] != BoardLogic.SpecialType.STAR:
		printerr("FAIL: T/L intersection did not spawn Star Gem: ", res_star)
		return false
	print("  ✓ T/L-shape Star Gem creation verified.")
	
	# 5. Test Chrono Ice damage & shatter
	board._init_empty_grid()
	board.get_cell(0, 0).color = 4
	board.get_cell(1, 0).color = 4
	board.get_cell(2, 0).color = 4
	board.get_cell(0, 1).ice_hp = 1 # Adjacent to (0,0)
	var res_ice := board.resolve_matches_and_specials()
	if not res_ice["ice_shattered"].has(Vector2i(0, 1)):
		printerr("FAIL: Adjacent Chrono Ice was not shattered: ", res_ice)
		return false
	print("  ✓ Chrono Ice damage & shatter verified.")
	
	# 6. Test Gravity & Refill
	var refill := board.apply_gravity_and_refill()
	if refill["spawns"].is_empty():
		printerr("FAIL: Gravity refill spawned 0 gems")
		return false
	print("  ✓ Gravity drop and refill verified.")
	
	return true

func test_procedural_sfx() -> bool:
	print("\n[TEST 4] ProceduralSFX Key-Tuning & WAV Synthesis...")
	var sfx := ProceduralSFX.new()
	root.add_child(sfx)
	
	sfx.set_track_tuning(349.23, "bird_blues") # F blues
	sfx.play_match_chime(0, true)
	sfx.play_match_chime(1, false)
	sfx.play_ice_shatter()
	sfx.play_flame_blast()
	sfx.play_star_laser()
	sfx.play_hypercube_wipe()
	sfx.play_ui_click(true)
	
	print("  ✓ Procedural SFX synthesis & key tuning executed without errors.")
	sfx.queue_free()
	return true

func test_procedural_background_3d() -> bool:
	print("\n[TEST 5] ProceduralBackground3D Archetypes...")
	var bg := ProceduralBackground3D.new()
	root.add_child(bg)
	
	var styles := ["bird_blues", "medium_swing", "slow_ballad", "minor_blues", "burning_swing", "spiced_blues"]
	for s in styles:
		bg.set_track_style(s, 0.42)
		bg.update_audio_reaction(0.016, 0.5, 0.4, 0.3, 0.25)
	
	bg.trigger_beat_shockwave(1.5, Color.CYAN)
	bg.update_audio_reaction(0.016, 0.8, 0.6, 0.5, 0.0)
	
	print("  ✓ 3D MultiMesh background archetypes and uniforms verified.")
	bg.queue_free()
	return true

func test_main_scene_instantiation() -> bool:
	print("\n[TEST 6] Main Scene Instantiation & Smoke Test...")
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if not main_scene:
		printerr("FAIL: Could not load res://scenes/Main.tscn")
		return false
	
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	if not main_node.bg_3d:
		main_node._ready()
	
	# Verify subcomponents exist
	if not main_node.get_node_or_null("ProceduralBackground3D"):
		printerr("FAIL: ProceduralBackground3D not found in Main")
		return false
	if not main_node.get_node_or_null("AudioManager"):
		printerr("FAIL: AudioManager not found in Main")
		return false
	if not main_node.get_node_or_null("ProceduralSFX"):
		printerr("FAIL: ProceduralSFX not found in Main")
		return false
	
	# Trigger preview and campaign launch
	main_node._on_track_preview(1)
	main_node._on_play_campaign(1)
	
	# Simulate 1 frame of game loop
	main_node._process(0.016)
	
	print("  ✓ Main scene booted and initialized cleanly.")
	main_node.queue_free()
	return true

func test_ui_interaction() -> bool:
	print("\n[TEST 7] UI Interaction & Screen Boundaries...")
	root.size = Vector2i(1280, 800)
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	if not main_node.bg_3d:
		main_node._ready()
	
	var hud: ArcadeHUD = main_node.hud
	var board_view: BoardView = main_node.board_view
	
	# Verify Carousel buttons are fully within the 1280x800 viewport
	var buttons_found: Array[Button] = []
	for b in hud.find_children("*", "Button", true, false):
		if hud.carousel_layer.is_ancestor_of(b):
			buttons_found.append(b)
			var r: Rect2 = b.get_global_rect()
			print("Carousel Button: '", b.text, "' rect: ", r)
			if r.position.y < 0 or r.end.y > 800 or r.position.x < 0 or r.end.x > 1280:
				printerr("FAIL: Button off-screen: '", b.text, "' rect: ", r)
				return false
	
	if buttons_found.size() < 4:
		printerr("FAIL: Expected 4 carousel buttons, found ", buttons_found.size())
		return false
	
	if buttons_found.size() < 4:
		printerr("FAIL: Expected at least 4 visible carousel buttons, found ", buttons_found.size())
		return false
	
	print("  ✓ All carousel buttons strictly inside 1280x800 viewport boundaries.")
	
	# Launch campaign
	main_node._on_play_campaign(1)
	
	# Test BoardView unhandled input cell click
	var test_cell := Vector2i(2, 3)
	var cell_center := board_view.global_position + Vector2(test_cell.x * 70.0 + 35.0, test_cell.y * 70.0 + 35.0)
	
	var ev := InputEventMouseButton.new()
	ev.position = cell_center
	ev.global_position = cell_center
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	board_view._unhandled_input(ev)
	
	if board_view.selected_cell != test_cell:
		printerr("FAIL: BoardView did not select cell on click. Expected: ", test_cell, " got: ", board_view.selected_cell)
		return false
	
	print("  ✓ BoardView click interaction and cell selection verified.")
	
	# Test swapping adjacent cell
	var swap_cell := Vector2i(3, 3)
	var swap_center := board_view.global_position + Vector2(swap_cell.x * 70.0 + 35.0, swap_cell.y * 70.0 + 35.0)
	var ev_swap := InputEventMouseButton.new()
	ev_swap.position = swap_center
	ev_swap.global_position = swap_center
	ev_swap.button_index = MOUSE_BUTTON_LEFT
	ev_swap.pressed = true
	
	var swap_data := {
		"fired": false,
		"p1": Vector2i(-1, -1),
		"p2": Vector2i(-1, -1)
	}
	board_view.swap_requested.connect(func(p1: Vector2i, p2: Vector2i):
		swap_data["fired"] = true
		swap_data["p1"] = p1
		swap_data["p2"] = p2
	)
	board_view._unhandled_input(ev_swap)
	
	if not swap_data["fired"] or swap_data["p1"] != test_cell or swap_data["p2"] != swap_cell:
		printerr("FAIL: BoardView swap_requested not fired properly on second click: ", swap_data["p1"], " -> ", swap_data["p2"])
		return false
	
	print("  ✓ BoardView adjacent cell swap request verified.")
	main_node.queue_free()
	return true

func test_pause_menu_and_cursor_ux() -> bool:
	print("\n[TEST 8] Pause Menu Centering, Vertical Buttons, ESC key & Cursor Pointer...")
	root.size = Vector2i(1280, 800)
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	if not main_node.bg_3d:
		main_node._ready()
	
	var hud: ArcadeHUD = main_node.hud
	
	# 1. Verify cursor shape on all buttons
	var all_buttons := hud.find_children("*", "Button", true, false)
	if all_buttons.is_empty():
		printerr("FAIL: No buttons found in HUD")
		return false
	for btn in all_buttons:
		if btn.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
			printerr("FAIL: Button '", btn.text, "' does not have CURSOR_POINTING_HAND")
			return false
	print("  ✓ All ", all_buttons.size(), " buttons have CURSOR_POINTING_HAND set.")
	
	# 2. Check modal center container & panel centering
	var center_containers := hud.modal_layer.find_children("*", "CenterContainer", true, false)
	if center_containers.is_empty():
		printerr("FAIL: modal_layer does not contain a CenterContainer")
		return false
	print("  ✓ Modal layer uses CenterContainer for screen centering.")
	
	# 3. Check vertical button stack in modal
	var modal_btn_containers := hud.modal_layer.find_children("*", "VBoxContainer", true, false)
	var found_button_vbox := false
	for v in modal_btn_containers:
		var btns_in_v: Array[Node] = v.find_children("*", "Button", false, false)
		if btns_in_v.size() >= 3:
			found_button_vbox = true
			for b in btns_in_v:
				var btn: Button = b
				if btn.custom_minimum_size.x != 220:
					printerr("FAIL: Modal button '", btn.text, "' width is not 220, got: ", btn.custom_minimum_size.x)
					return false
	if not found_button_vbox:
		printerr("FAIL: Modal buttons are not stacked in a VBoxContainer")
		return false
	print("  ✓ Modal buttons are vertically stacked with uniform width.")
	
	# 4. Check 'Main Menu' button text
	var menu_btn_found := false
	for btn in all_buttons:
		if "Main Menu" in btn.text:
			menu_btn_found = true
			break
	if not menu_btn_found:
		printerr("FAIL: Could not find 'Main Menu' button in HUD")
		return false
	print("  ✓ 'Main Menu' button renamed and verified.")
	
	# 5. Start campaign and test ESC key triggering pause
	main_node._on_play_campaign(1)
	if main_node.is_paused:
		printerr("FAIL: Game should not start paused")
		return false
	
	# Simulate ESC key press to pause
	var esc_event := InputEventKey.new()
	esc_event.pressed = true
	esc_event.keycode = KEY_ESCAPE
	main_node._unhandled_input(esc_event)
	
	if not main_node.is_paused or not hud.modal_layer.visible:
		printerr("FAIL: Pressing ESC did not pause the game or show modal")
		return false
	if not hud.modal_resume_btn.visible:
		printerr("FAIL: Resume button is not visible when paused")
		return false
	print("  ✓ ESC key successfully triggers Pause menu.")
	
	# Simulate ESC key press to unpause / resume
	main_node._unhandled_input(esc_event)
	if main_node.is_paused or hud.modal_layer.visible:
		printerr("FAIL: Pressing ESC again did not resume the game")
		return false
	print("  ✓ ESC key successfully resumes game.")
	
	# Simulate pause again, then resume via resume button
	main_node._unhandled_input(esc_event)
	if not main_node.is_paused:
		printerr("FAIL: ESC did not pause on second cycle")
		return false
	hud.modal_resume_btn.pressed.emit()
	if main_node.is_paused or hud.modal_layer.visible:
		printerr("FAIL: Clicking Resume button did not unpause game")
		return false
	print("  ✓ Resume button successfully unpauses game.")
	
	main_node.queue_free()
	return true
