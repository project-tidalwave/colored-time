class_name SaveManager
extends RefCounted

const SAVE_PATH := "user://game_save.json"

static func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return get_default_data()
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return get_default_data()
	
	var content := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(content)
	if error != OK or not (json.data is Dictionary):
		return get_default_data()
	
	return json.data

static func save_data(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

static func get_default_data() -> Dictionary:
	return {
		"unlocked_level": 1,
		"per_track_scores": {},
		"endless_high_score": 0,
		"music_volume": 1.0,
		"sfx_volume": 1.0
	}

static func record_level_result(track_id: int, score: int, stars: int, max_cascade: int, on_beat_count: int) -> void:
	var data := load_data()
	var track_key := str(track_id)
	var prev: Dictionary = data["per_track_scores"].get(track_key, {
		"high_score": 0,
		"stars": 0,
		"max_cascade": 0,
		"best_on_beat": 0
	})
	
	prev["high_score"] = maxi(prev["high_score"], score)
	prev["stars"] = maxi(prev["stars"], stars)
	prev["max_cascade"] = maxi(prev["max_cascade"], max_cascade)
	prev["best_on_beat"] = maxi(prev["best_on_beat"], on_beat_count)
	data["per_track_scores"][track_key] = prev
	
	if stars >= 1:
		data["unlocked_level"] = maxi(data.get("unlocked_level", 1), track_id + 1)
	
	save_data(data)

static func get_track_stats(track_id: int) -> Dictionary:
	var data := load_data()
	return data["per_track_scores"].get(str(track_id), {
		"high_score": 0,
		"stars": 0,
		"max_cascade": 0,
		"best_on_beat": 0
	})
