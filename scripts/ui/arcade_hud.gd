class_name ArcadeHUD
extends Control

const TrackCatalog = preload("res://scripts/core/track_catalog.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")

signal new_game_requested()
signal high_scores_requested()
signal exit_requested()
signal back_to_home_requested()
signal play_campaign_requested(track_id: int)
signal play_endless_requested()
signal track_selected_for_preview(track_id: int)
signal pause_toggled()
signal next_level_requested()
signal replay_requested()
signal return_to_carousel_requested()

# Sub-views
var home_layer: Control
var carousel_layer: Control
var high_scores_layer: Control
var ingame_layer: Control
var modal_layer: Control

# In-Game HUD Elements
var track_title_label: Label
var track_info_pill: Label
var score_label: Label
var combo_label: Label
var time_label: Label
var ice_label: Label
var chrono_gauge: ProgressBar
var beat_ring: ColorRect
var on_beat_popup: Label

# Carousel Elements
var carousel_track_label: Label
var carousel_style_label: Label
var carousel_stats_label: Label
var track_list_container: VBoxContainer
var current_preview_id: int = 1

# Modal Elements
var modal_title: Label
var modal_details: Label
var modal_next_btn: Button
var modal_resume_btn: Button

func _init() -> void:
	name = "ArcadeHUD"
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_home_layer()
	_build_carousel_overlay()
	_build_high_scores_layer()
	_build_ingame_hud()
	_build_modal_layer()

func _ready() -> void:
	show_home()

func _build_home_layer() -> void:
	home_layer = Control.new()
	home_layer.set_anchors_preset(PRESET_FULL_RECT)
	home_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(home_layer)

	# Scrim background
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.02, 0.06, 0.65)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_layer.add_child(scrim)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 24)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_layer.add_child(main_vbox)

	# Title & Subtitle
	var title := Label.new()
	title.text = "COLORED TIME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.modulate = Color(0.3, 0.85, 1.0)
	main_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "3D Audio-Reactive Jazz Match-3 Grid"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.modulate = Color(0.7, 0.75, 0.85)
	main_vbox.add_child(subtitle)

	# Home Card Panel
	var card_panel := Panel.new()
	card_panel.custom_minimum_size = Vector2(440, 240)
	card_panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.05, 0.04, 0.1, 0.90)
	csb.set_corner_radius_all(16)
	csb.border_width_left = 2
	csb.border_width_top = 2
	csb.border_width_right = 2
	csb.border_width_bottom = 2
	csb.border_color = Color(0.3, 0.7, 1.0, 0.6)
	card_panel.add_theme_stylebox_override("panel", csb)
	main_vbox.add_child(card_panel)

	var card_vbox := VBoxContainer.new()
	card_vbox.set_anchors_preset(PRESET_FULL_RECT)
	card_vbox.offset_left = 32
	card_vbox.offset_right = -32
	card_vbox.offset_top = 24
	card_vbox.offset_bottom = -24
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 14)
	card_panel.add_child(card_vbox)

	# 1. New Game button
	var new_game_btn := Button.new()
	new_game_btn.text = "New Game"
	new_game_btn.custom_minimum_size = Vector2(280, 46)
	new_game_btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	new_game_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	new_game_btn.pressed.connect(func(): new_game_requested.emit())
	card_vbox.add_child(new_game_btn)

	# 2. High Scores button
	var high_scores_btn := Button.new()
	high_scores_btn.text = "High Scores"
	high_scores_btn.custom_minimum_size = Vector2(280, 46)
	high_scores_btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	high_scores_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	high_scores_btn.pressed.connect(func(): high_scores_requested.emit())
	card_vbox.add_child(high_scores_btn)

	# 3. Exit button
	var exit_btn := Button.new()
	exit_btn.text = "Exit"
	exit_btn.custom_minimum_size = Vector2(280, 46)
	exit_btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	exit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	exit_btn.pressed.connect(func(): exit_requested.emit())
	card_vbox.add_child(exit_btn)

func _build_ingame_hud() -> void:
	ingame_layer = Control.new()
	ingame_layer.set_anchors_preset(PRESET_FULL_RECT)
	ingame_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ingame_layer)

	# Top Header Bar
	var top_bar := Panel.new()
	top_bar.custom_minimum_size = Vector2(0, 90)
	top_bar.set_anchors_preset(PRESET_TOP_WIDE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.08, 0.75)
	sb.border_width_bottom = 2
	sb.border_color = Color(0.2, 0.6, 1.0, 0.4)
	top_bar.add_theme_stylebox_override("panel", sb)
	ingame_layer.add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(PRESET_FULL_RECT)
	hbox.offset_left = 30
	hbox.offset_right = -30
	top_bar.add_child(hbox)

	# Track metadata
	var track_box := VBoxContainer.new()
	track_box.size_flags_horizontal = SIZE_EXPAND_FILL
	track_title_label = Label.new()
	track_title_label.text = "Track 01: Bird Blues"
	track_title_label.add_theme_font_size_override("font_size", 22)
	track_info_pill = Label.new()
	track_info_pill.text = "Key: F | 140 BPM | Style: Bebop"
	track_info_pill.modulate = Color(0.6, 0.85, 1.0)
	track_box.add_child(track_title_label)
	track_box.add_child(track_info_pill)
	hbox.add_child(track_box)

	# Central Beat Metronome & Chrono Gauge
	var center_box := VBoxContainer.new()
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.custom_minimum_size = Vector2(360, 0)

	# Beat indicator
	var beat_bar := HBoxContainer.new()
	beat_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	beat_ring = ColorRect.new()
	beat_ring.custom_minimum_size = Vector2(28, 28)
	beat_ring.color = Color(0.0, 1.0, 0.8, 1.0)
	beat_bar.add_child(beat_ring)
	center_box.add_child(beat_bar)

	# Chrono Gauge
	chrono_gauge = ProgressBar.new()
	chrono_gauge.custom_minimum_size = Vector2(340, 18)
	chrono_gauge.max_value = 100.0
	chrono_gauge.value = 0.0
	chrono_gauge.show_percentage = false
	center_box.add_child(chrono_gauge)
	hbox.add_child(center_box)

	# Stats Box (Score, Multiplier, Time, Ice)
	var stats_box := VBoxContainer.new()
	stats_box.size_flags_horizontal = SIZE_EXPAND_FILL
	stats_box.alignment = BoxContainer.ALIGNMENT_CENTER

	score_label = Label.new()
	score_label.text = "SCORE: 0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", 20)

	var sub_stats := HBoxContainer.new()
	sub_stats.alignment = BoxContainer.ALIGNMENT_END
	time_label = Label.new()
	time_label.text = "TIME: 02:45  "
	ice_label = Label.new()
	ice_label.text = "ICE: 8  "
	combo_label = Label.new()
	combo_label.text = "CHAIN: 1x"
	combo_label.modulate = Color(1.0, 0.85, 0.2)

	sub_stats.add_child(time_label)
	sub_stats.add_child(ice_label)
	sub_stats.add_child(combo_label)

	stats_box.add_child(score_label)
	stats_box.add_child(sub_stats)
	hbox.add_child(stats_box)

	# Floating On-Beat Banner
	on_beat_popup = Label.new()
	on_beat_popup.text = "ON BEAT! 1.5x"
	on_beat_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	on_beat_popup.set_anchors_preset(PRESET_CENTER_TOP)
	on_beat_popup.position = Vector2(540, 100)
	on_beat_popup.modulate = Color(1.0, 0.9, 0.1, 0.0)
	on_beat_popup.add_theme_font_size_override("font_size", 24)
	ingame_layer.add_child(on_beat_popup)

	# Pause button
	var pause_btn := Button.new()
	pause_btn.text = "Pause"
	pause_btn.position = Vector2(20, 105)
	pause_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pause_btn.pressed.connect(func(): pause_toggled.emit())
	ingame_layer.add_child(pause_btn)

func _build_carousel_overlay() -> void:
	carousel_layer = Control.new()
	carousel_layer.set_anchors_preset(PRESET_FULL_RECT)
	carousel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(carousel_layer)

	# Dark semi-transparent scrim
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.02, 0.06, 0.65)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carousel_layer.add_child(scrim)

	# Top-left Back button
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(90, 36)
	back_btn.position = Vector2(30, 30)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.pressed.connect(func(): back_to_home_requested.emit())
	carousel_layer.add_child(back_btn)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 18)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carousel_layer.add_child(main_vbox)

	# Title
	var title := Label.new()
	title.text = "COLORED TIME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.modulate = Color(0.3, 0.85, 1.0)
	main_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "3D Audio-Reactive Jazz Match-3 Grid"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.modulate = Color(0.7, 0.75, 0.85)
	main_vbox.add_child(subtitle)

	# Carousel Center Card
	var card_panel := Panel.new()
	card_panel.name = "CarouselCardPanel"
	card_panel.custom_minimum_size = Vector2(840, 260)
	card_panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.05, 0.04, 0.1, 0.90)
	csb.set_corner_radius_all(16)
	csb.border_width_left = 2
	csb.border_width_top = 2
	csb.border_width_right = 2
	csb.border_width_bottom = 2
	csb.border_color = Color(0.3, 0.7, 1.0, 0.6)
	card_panel.add_theme_stylebox_override("panel", csb)
	main_vbox.add_child(card_panel)

	var card_vbox := VBoxContainer.new()
	card_vbox.set_anchors_preset(PRESET_FULL_RECT)
	card_vbox.offset_left = 32
	card_vbox.offset_right = -32
	card_vbox.offset_top = 20
	card_vbox.offset_bottom = -20
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 14)
	card_panel.add_child(card_vbox)

	# Nav row
	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.size_flags_horizontal = SIZE_EXPAND_FILL
	nav_row.add_theme_constant_override("separation", 16)
	var prev_btn := Button.new()
	prev_btn.text = "Previous"
	prev_btn.custom_minimum_size = Vector2(110, 36)
	prev_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	prev_btn.pressed.connect(_on_prev_track)
	nav_row.add_child(prev_btn)

	carousel_track_label = Label.new()
	carousel_track_label.text = "Track 01: Bird Blues"
	carousel_track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carousel_track_label.size_flags_horizontal = SIZE_EXPAND_FILL
	carousel_track_label.add_theme_font_size_override("font_size", 22)
	nav_row.add_child(carousel_track_label)

	var next_btn := Button.new()
	next_btn.text = "Next"
	next_btn.custom_minimum_size = Vector2(110, 36)
	next_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	next_btn.pressed.connect(_on_next_track)
	nav_row.add_child(next_btn)
	card_vbox.add_child(nav_row)

	carousel_style_label = Label.new()
	carousel_style_label.text = "Style: Bebop Prism Tunnel | Key: F | 140 BPM"
	carousel_style_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carousel_style_label.modulate = Color(0.4, 0.9, 1.0)
	card_vbox.add_child(carousel_style_label)

	carousel_stats_label = Label.new()
	carousel_stats_label.text = "Rating: ☆☆☆ | High Score: 0 | Max Cascade: 0x"
	carousel_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carousel_stats_label.modulate = Color(1.0, 0.85, 0.3)
	card_vbox.add_child(carousel_stats_label)

	# Mode Launch Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)

	var play_campaign_btn := Button.new()
	play_campaign_btn.text = "Play Campaign"
	play_campaign_btn.custom_minimum_size = Vector2(210, 46)
	play_campaign_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	play_campaign_btn.pressed.connect(func():
		play_campaign_requested.emit(current_preview_id)
	)
	btn_row.add_child(play_campaign_btn)

	var play_endless_btn := Button.new()
	play_endless_btn.text = "Endless / Zen Mode"
	play_endless_btn.custom_minimum_size = Vector2(230, 46)
	play_endless_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	play_endless_btn.pressed.connect(func():
		play_endless_requested.emit()
	)
	btn_row.add_child(play_endless_btn)

	card_vbox.add_child(btn_row)

func _build_modal_layer() -> void:
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.visible = false
	add_child(modal_layer)
	
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(PRESET_FULL_RECT)
	scrim.color = Color(0.01, 0.01, 0.03, 0.8)
	modal_layer.add_child(scrim)
	
	var center_container := CenterContainer.new()
	center_container.set_anchors_preset(PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.add_child(center_container)
	
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(400, 270)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.12, 0.95)
	sb.set_corner_radius_all(14)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.4, 0.8, 1.0, 0.7)
	panel.add_theme_stylebox_override("panel", sb)
	center_container.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 28
	vbox.offset_right = -28
	vbox.offset_top = 20
	vbox.offset_bottom = -20
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	modal_title = Label.new()
	modal_title.text = "LEVEL CLEARED!"
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(modal_title)
	
	modal_details = Label.new()
	modal_details.text = "Score: 12,500\nStars: ★★★\nMax Cascade: 5x\nOn-Beat Acc: 85%"
	modal_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_details.add_theme_font_size_override("font_size", 18)
	vbox.add_child(modal_details)
	
	var btn_vbox := VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.add_theme_constant_override("separation", 8)
	
	modal_resume_btn = Button.new()
	modal_resume_btn.text = "Resume"
	modal_resume_btn.custom_minimum_size = Vector2(200, 38)
	modal_resume_btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	modal_resume_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	modal_resume_btn.pressed.connect(func(): pause_toggled.emit())
	btn_vbox.add_child(modal_resume_btn)
	
	modal_next_btn = Button.new()
	modal_next_btn.text = "Next Level"
	modal_next_btn.custom_minimum_size = Vector2(200, 38)
	modal_next_btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	modal_next_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	modal_next_btn.pressed.connect(func(): next_level_requested.emit())
	btn_vbox.add_child(modal_next_btn)
	
	var replay_btn := Button.new()
	replay_btn.text = "Replay"
	replay_btn.custom_minimum_size = Vector2(200, 38)
	replay_btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	replay_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	replay_btn.pressed.connect(func(): replay_requested.emit())
	btn_vbox.add_child(replay_btn)
	
	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(200, 38)
	menu_btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	menu_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	menu_btn.pressed.connect(func(): return_to_carousel_requested.emit())
	btn_vbox.add_child(menu_btn)
	
	vbox.add_child(btn_vbox)

func _build_high_scores_layer() -> void:
	high_scores_layer = Control.new()
	high_scores_layer.set_anchors_preset(PRESET_FULL_RECT)
	high_scores_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	high_scores_layer.visible = false
	add_child(high_scores_layer)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.02, 0.06, 0.75)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	high_scores_layer.add_child(scrim)

	# Top-left Back button
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(90, 36)
	back_btn.position = Vector2(30, 30)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.pressed.connect(func(): back_to_home_requested.emit())
	high_scores_layer.add_child(back_btn)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.offset_top = 25
	main_vbox.offset_bottom = -25
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 12)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	high_scores_layer.add_child(main_vbox)

	var title := Label.new()
	title.text = "HIGH SCORES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = Color(0.3, 0.85, 1.0)
	main_vbox.add_child(title)

	var summary_label := Label.new()
	summary_label.name = "SummaryLabel"
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.add_theme_font_size_override("font_size", 16)
	summary_label.modulate = Color(1.0, 0.85, 0.3)
	main_vbox.add_child(summary_label)

	# Panel container for scrollable list
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(920, 560)
	panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.05, 0.04, 0.1, 0.90)
	psb.set_corner_radius_all(14)
	psb.border_width_left = 2
	psb.border_width_top = 2
	psb.border_width_right = 2
	psb.border_width_bottom = 2
	psb.border_color = Color(0.3, 0.7, 1.0, 0.6)
	panel.add_theme_stylebox_override("panel", psb)
	main_vbox.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.offset_left = 16
	scroll.offset_right = -16
	scroll.offset_top = 16
	scroll.offset_bottom = -16
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.name = "TrackListVBox"
	list_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(list_vbox)

func _refresh_high_scores_display() -> void:
	var summary_label: Label = high_scores_layer.find_child("SummaryLabel", true, false)
	var list_vbox: VBoxContainer = high_scores_layer.find_child("TrackListVBox", true, false)
	if not list_vbox:
		return

	for child in list_vbox.get_children():
		child.queue_free()

	var save_data := SaveManager.load_data()
	var endless_best: int = save_data.get("endless_high_score", 0)
	var total_stars: int = 0

	# Header Row with matching padding
	var header_bar := HBoxContainer.new()
	header_bar.custom_minimum_size = Vector2(0, 32)

	var h_spacer_left := Control.new()
	h_spacer_left.custom_minimum_size = Vector2(12, 0)
	header_bar.add_child(h_spacer_left)

	var h_track := Label.new()
	h_track.text = "TRACK / TITLE"
	h_track.size_flags_horizontal = SIZE_EXPAND_FILL
	h_track.modulate = Color(0.5, 0.7, 1.0)
	header_bar.add_child(h_track)

	var h_style := Label.new()
	h_style.text = "STYLE"
	h_style.custom_minimum_size = Vector2(160, 0)
	h_style.modulate = Color(0.5, 0.7, 1.0)
	header_bar.add_child(h_style)

	var h_stars := Label.new()
	h_stars.text = "RATING"
	h_stars.custom_minimum_size = Vector2(100, 0)
	h_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_stars.modulate = Color(0.5, 0.7, 1.0)
	header_bar.add_child(h_stars)

	var h_score := Label.new()
	h_score.text = "HIGH SCORE"
	h_score.custom_minimum_size = Vector2(120, 0)
	h_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h_score.modulate = Color(0.5, 0.7, 1.0)
	header_bar.add_child(h_score)

	var h_cascade := Label.new()
	h_cascade.text = "MAX CASCADE"
	h_cascade.custom_minimum_size = Vector2(120, 0)
	h_cascade.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h_cascade.modulate = Color(0.5, 0.7, 1.0)
	header_bar.add_child(h_cascade)

	var h_spacer_right := Control.new()
	h_spacer_right.custom_minimum_size = Vector2(32, 0)
	header_bar.add_child(h_spacer_right)

	list_vbox.add_child(header_bar)

	# Add each of the 36 tracks
	for track_id in range(1, 37):
		var t := TrackCatalog.get_track_by_id(track_id)
		if t.is_empty():
			continue
		var stats := SaveManager.get_track_stats(track_id)
		var stars_count: int = stats.get("stars", 0)
		total_stars += stars_count
		var stars_str := ""
		for s in range(3):
			stars_str += "★" if s < stars_count else "☆"

		var row := PanelContainer.new()
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0.08, 0.07, 0.16, 0.6) if track_id % 2 == 0 else Color(0.05, 0.04, 0.11, 0.6)
		rsb.set_corner_radius_all(6)
		rsb.content_margin_left = 12
		rsb.content_margin_right = 32
		rsb.content_margin_top = 4
		rsb.content_margin_bottom = 4
		row.add_theme_stylebox_override("panel", rsb)

		var hbox := HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(0, 30)
		row.add_child(hbox)

		var t_title := Label.new()
		t_title.text = "%02d. %s" % [track_id, t.get("title", "Track")]
		t_title.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox.add_child(t_title)

		var t_style := Label.new()
		t_style.text = t.get("style_display", "")
		t_style.custom_minimum_size = Vector2(160, 0)
		t_style.modulate = Color(0.6, 0.85, 1.0)
		hbox.add_child(t_style)

		var t_stars := Label.new()
		t_stars.text = stars_str
		t_stars.custom_minimum_size = Vector2(100, 0)
		t_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t_stars.modulate = Color(1.0, 0.85, 0.3)
		hbox.add_child(t_stars)

		var t_score := Label.new()
		t_score.text = str(stats.get("high_score", 0))
		t_score.custom_minimum_size = Vector2(120, 0)
		t_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(t_score)

		var t_casc := Label.new()
		t_casc.text = "%dx" % stats.get("max_cascade", 0)
		t_casc.custom_minimum_size = Vector2(120, 0)
		t_casc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		t_casc.modulate = Color(0.4, 1.0, 0.6)
		hbox.add_child(t_casc)

		list_vbox.add_child(row)

	if summary_label:
		summary_label.text = "Total Stars: %d / 108   |   Endless High Score: %d pts" % [total_stars, endless_best]

func show_home() -> void:
	if home_layer:
		home_layer.visible = true
	if carousel_layer:
		carousel_layer.visible = false
	if high_scores_layer:
		high_scores_layer.visible = false
	if ingame_layer:
		ingame_layer.visible = false
	if modal_layer:
		modal_layer.visible = false

func show_carousel() -> void:
	if home_layer:
		home_layer.visible = false
	if carousel_layer:
		carousel_layer.visible = true
	if high_scores_layer:
		high_scores_layer.visible = false
	if ingame_layer:
		ingame_layer.visible = false
	if modal_layer:
		modal_layer.visible = false
	update_carousel_preview(current_preview_id)

func show_high_scores() -> void:
	if home_layer:
		home_layer.visible = false
	if carousel_layer:
		carousel_layer.visible = false
	if high_scores_layer:
		high_scores_layer.visible = true
	if ingame_layer:
		ingame_layer.visible = false
	if modal_layer:
		modal_layer.visible = false
	_refresh_high_scores_display()

func show_gameplay() -> void:
	if home_layer:
		home_layer.visible = false
	if carousel_layer:
		carousel_layer.visible = false
	if high_scores_layer:
		high_scores_layer.visible = false
	if ingame_layer:
		ingame_layer.visible = true
	if modal_layer:
		modal_layer.visible = false

func show_results_modal(title: String, details: String, allow_next: bool, is_pause: bool = false) -> void:
	modal_title.text = title
	modal_details.text = details
	if modal_resume_btn:
		modal_resume_btn.visible = is_pause
	modal_next_btn.visible = allow_next and not is_pause
	modal_layer.visible = true

func hide_modal() -> void:
	modal_layer.visible = false

func update_carousel_preview(track_id: int) -> void:
	current_preview_id = track_id
	var t := TrackCatalog.get_track_by_id(track_id)
	if t.is_empty():
		return
	
	carousel_track_label.text = t["title"]
	carousel_style_label.text = "Style: %s | Key: %s | Tempo: %d BPM" % [t["style_display"], t["key_display"], t["bpm"]]
	
	var stats := SaveManager.get_track_stats(track_id)
	var stars_count: int = stats.get("stars", 0)
	var stars_str := ""
	for i in range(3):
		stars_str += "★" if i < stars_count else "☆"
	
	carousel_stats_label.text = "Rating: %s | High Score: %d | Max Cascade: %dx" % [
		stars_str,
		stats.get("high_score", 0),
		stats.get("max_cascade", 0)
	]
	
	track_selected_for_preview.emit(track_id)

func _on_prev_track() -> void:
	var next_id := current_preview_id - 1
	if next_id < 1:
		next_id = 36
	update_carousel_preview(next_id)

func _on_next_track() -> void:
	var next_id := current_preview_id + 1
	if next_id > 36:
		next_id = 1
	update_carousel_preview(next_id)

func update_hud_state(
	track_data: Dictionary,
	score: int,
	target_score: int,
	time_left: float,
	remaining_ice: int,
	combo_multiplier: int,
	beat_phase: float
) -> void:
	track_title_label.text = track_data.get("title", "")
	score_label.text = "SCORE: %d / %d" % [score, target_score]
	
	var mins := int(time_left / 60.0)
	var secs := int(time_left) % 60
	time_label.text = "TIME: %02d:%02d  " % [mins, secs]
	ice_label.text = "ICE: %d  " % remaining_ice
	combo_label.text = "CHAIN: %dx" % combo_multiplier
	
	var pct := clampf((float(score) / float(target_score)) * 100.0, 0.0, 100.0)
	chrono_gauge.value = pct
	
	# Pulse beat ring
	var scale_factor := 1.0 + (1.0 - beat_phase) * 0.4
	beat_ring.scale = Vector2(scale_factor, scale_factor)
	beat_ring.color = Color(0.2, 1.0, 0.8, 0.5 + (1.0 - beat_phase) * 0.5)

func trigger_on_beat_banner() -> void:
	on_beat_popup.modulate = Color(1.0, 0.9, 0.1, 1.0)
	on_beat_popup.scale = Vector2(1.3, 1.3)
	var t := create_tween().set_parallel(true)
	t.tween_property(on_beat_popup, "scale", Vector2.ONE, 0.3)
	t.tween_property(on_beat_popup, "modulate:a", 0.0, 0.4).set_delay(0.2)
