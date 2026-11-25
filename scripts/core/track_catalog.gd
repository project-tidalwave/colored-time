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

# 36 standard track filenames used as deterministic fallback if directory listing is restricted
const DEFAULT_TRACK_FILENAMES: Array[String] = [
	"track_01_bird_blues_f_140bpm.mp3",
	"track_02_bird_blues_bb_155bpm.mp3",
	"track_03_bird_blues_c_135bpm.mp3",
	"track_04_bird_blues_g_145bpm.mp3",
	"track_05_bird_blues_eb_150bpm.mp3",
	"track_06_bird_blues_ab_160bpm.mp3",
	"track_07_medium_swing_f_124bpm.mp3",
	"track_08_medium_swing_bb_120bpm.mp3",
	"track_09_medium_swing_g_128bpm.mp3",
	"track_10_medium_swing_c_118bpm.mp3",
	"track_11_medium_swing_d_130bpm.mp3",
	"track_12_medium_swing_a_122bpm.mp3",
	"track_13_slow_ballad_c_76bpm.mp3",
	"track_14_slow_ballad_g_80bpm.mp3",
	"track_15_slow_ballad_f_72bpm.mp3",
	"track_16_slow_ballad_bb_84bpm.mp3",
	"track_17_slow_ballad_eb_78bpm.mp3",
	"track_18_slow_ballad_ab_82bpm.mp3",
	"track_19_minor_blues_d_125bpm.mp3",
	"track_20_minor_blues_g_132bpm.mp3",
	"track_21_minor_blues_c_120bpm.mp3",
	"track_22_minor_blues_f_138bpm.mp3",
	"track_23_minor_blues_a_128bpm.mp3",
	"track_24_minor_blues_e_135bpm.mp3",
	"track_25_burning_swing_bb_190bpm.mp3",
	"track_26_burning_swing_f_200bpm.mp3",
	"track_27_burning_swing_c_195bpm.mp3",
	"track_28_burning_swing_g_205bpm.mp3",
	"track_29_burning_swing_eb_185bpm.mp3",
	"track_30_burning_swing_d_210bpm.mp3",
	"track_31_spiced_blues_db_130bpm.mp3",
	"track_32_spiced_blues_gb_142bpm.mp3",
	"track_33_spiced_blues_b_136bpm.mp3",
	"track_34_spiced_blues_e_148bpm.mp3",
	"track_35_spiced_blues_ab_134bpm.mp3",
	"track_36_spiced_blues_eb_152bpm.mp3"
]

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
			if not dir.current_is_dir():
				# In exported PCK archives, Godot renames imported resources to .import or .remap
				var clean_name := file_name.trim_suffix(".import").trim_suffix(".remap")
				if clean_name.ends_with(".mp3") and not filenames.has(clean_name):
					filenames.append(clean_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Fallback to static manifest if directory scanning produced no results
	if filenames.is_empty():
		filenames = DEFAULT_TRACK_FILENAMES.duplicate()
	
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
