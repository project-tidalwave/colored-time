class_name TrackCatalog
extends RefCounted

const TRACKS_DIR := "res://tracks/"

# Circle of fifths / chromatic hue mapping for musical keys
const KEY_HUES := {
	"c": 0.0,
	"db": 0.58,
	"d": 0.16,
	"eb": 0.75,
	"e": 0.33,
	"f": 0.91,
	"gb": 0.50,
	"g": 0.08,
	"ab": 0.66,
	"a": 0.25,
	"bb": 0.83,
	"b": 0.41,
}

# Root frequency (approximate 4th octave) for procedural scale synthesis
const KEY_ROOT_FREQS := {
	"c": 261.63,
	"db": 277.18,
	"d": 293.66,
	"eb": 311.13,
	"e": 329.63,
	"f": 349.23,
	"gb": 369.99,
	"g": 392.00,
	"ab": 415.30,
	"a": 440.00,
	"bb": 466.16,
	"b": 493.88,
}

static var _tracks_cache: Array[Dictionary] = []

static func get_all_tracks() -> Array[Dictionary]:
	if not _tracks_cache.is_empty():
		return _tracks_cache
	
	var tracks: Array[Dictionary] = []
	var dir := DirAccess.open(TRACKS_DIR)
	var filenames: Array[String] = []
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".mp3"):
				filenames.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	filenames.sort()
	
	# Regex for track filename: track_01_bird_blues_f_140bpm.mp3
	var regex := RegEx.new()
	regex.compile("^track_(\\d+)_([a-z_]+)_([a-z]+)_(\\d+)bpm\\.mp3$")
	
	for fname in filenames:
		var match_res := regex.search(fname)
		if match_res:
			var id := match_res.get_string(1).to_int()
			var style := match_res.get_string(2)
			var key := match_res.get_string(3)
			var bpm := match_res.get_string(4).to_int()
			
			var hue: float = KEY_HUES.get(key, 0.0)
			var root_freq: float = KEY_ROOT_FREQS.get(key, 261.63)
			
			var is_advanced_style := (style in ["minor_blues", "burning_swing", "spiced_blues"])
			var gem_color_count: int = 7 if is_advanced_style else 6
			
			# Deterministic target score and ice count based on level progression
			var target_score: int = 4000 + (id * 350)
			var ice_count: int = 6 + int(id * 0.4)
			if style == "slow_ballad":
				ice_count = int(ice_count * 0.6)
			elif style in ["minor_blues", "spiced_blues"]:
				ice_count = int(ice_count * 1.3)
			
			var style_display_names := {
				"bird_blues": "Bird Blues",
				"medium_swing": "Medium Swing",
				"slow_ballad": "Slow Ballad",
				"minor_blues": "Minor Blues",
				"burning_swing": "Burning Swing",
				"spiced_blues": "Spiced Blues"
			}
			
			var style_display: String = style_display_names.get(style, style.capitalize())
			var key_display := key.to_upper()
			if key_display.length() == 2 and key_display.ends_with("B"):
				key_display = key_display[0] + "♭"
			
			tracks.append({
				"id": id,
				"filename": fname,
				"file_path": TRACKS_DIR + fname,
				"style": style,
				"style_display": style_display,
				"key": key,
				"key_display": key_display,
				"bpm": bpm,
				"key_hue": hue,
				"root_freq": root_freq,
				"gem_color_count": gem_color_count,
				"target_score": target_score,
				"ice_count": ice_count,
				"title": "Track %02d: %s (%s, %d BPM)" % [id, style_display, key_display, bpm]
			})
	
	tracks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["id"] < b["id"]
	)
	_tracks_cache = tracks
	return _tracks_cache

static func get_track_by_id(id: int) -> Dictionary:
	var list := get_all_tracks()
	for t in list:
		if t["id"] == id:
			return t
	return list[0] if not list.is_empty() else {}
