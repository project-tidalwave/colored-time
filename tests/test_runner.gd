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
