class_name ProceduralSFX
extends Node

const SAMPLE_RATE := 44100

# Scale intervals (semitones from root)
const BLUES_SCALE := [0, 3, 5, 6, 7, 10, 12, 15, 17, 18, 19, 22]
const MAJOR_SCALE := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]

var current_root_freq: float = 261.63 # Middle C default
var current_scale: Array = MAJOR_SCALE

var _sample_cache: Dictionary = {} # cache key: "chime_<freq>", etc.
var _voice_pool: Array[AudioStreamPlayer] = []
var _voice_index: int = 0
const VOICE_COUNT := 12

func _init() -> void:
	name = "ProceduralSFX"
	_setup_voices()

func _ready() -> void:
	if _voice_pool.is_empty():
		_setup_voices()

func _setup_voices() -> void:
	if not _voice_pool.is_empty():
		return
	for i in range(VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_voice_pool.append(player)

func set_track_tuning(root_freq: float, style: String) -> void:
	current_root_freq = root_freq
	if style in ["minor_blues", "bird_blues", "spiced_blues"]:
		current_scale = BLUES_SCALE
	else:
		current_scale = MAJOR_SCALE
	_sample_cache.clear()

func _get_voice() -> AudioStreamPlayer:
	if _voice_pool.is_empty():
		return null
	var player = _voice_pool[_voice_index]
	_voice_index = (_voice_index + 1) % _voice_pool.size()
	return player

func play_match_chime(cascade_index: int, is_on_beat: bool = false) -> void:
	var note_idx := clampi(cascade_index, 0, current_scale.size() - 1)
	var semitones: int = current_scale[note_idx]
	var freq: float = current_root_freq * pow(2.0, semitones / 12.0)
	
	var cache_key := "chime_%d_%s" % [int(freq), str(is_on_beat)]
	var stream: AudioStreamWAV
	if _sample_cache.has(cache_key):
		stream = _sample_cache[cache_key]
	else:
		stream = _generate_chime_wav(freq, is_on_beat)
		_sample_cache[cache_key] = stream
	
	var voice := _get_voice()
	if voice and voice.is_inside_tree():
		voice.stream = stream
		voice.volume_db = 1.0 if is_on_beat else -2.0
		voice.play()

func play_ice_shatter() -> void:
	var stream: AudioStreamWAV
	if _sample_cache.has("ice_shatter"):
		stream = _sample_cache["ice_shatter"]
	else:
		stream = _generate_ice_shatter_wav()
		_sample_cache["ice_shatter"] = stream
	
	var voice := _get_voice()
	if voice and voice.is_inside_tree():
		voice.stream = stream
		voice.volume_db = 0.0
		voice.play()

func play_flame_blast() -> void:
	var stream: AudioStreamWAV
	if _sample_cache.has("flame_blast"):
		stream = _sample_cache["flame_blast"]
	else:
		stream = _generate_flame_blast_wav()
		_sample_cache["flame_blast"] = stream
	
	var voice := _get_voice()
	if voice and voice.is_inside_tree():
		voice.stream = stream
		voice.volume_db = 2.0
		voice.play()

func play_star_laser() -> void:
	var stream: AudioStreamWAV
	if _sample_cache.has("star_laser"):
		stream = _sample_cache["star_laser"]
	else:
		stream = _generate_star_laser_wav()
		_sample_cache["star_laser"] = stream
	
	var voice := _get_voice()
	if voice and voice.is_inside_tree():
		voice.stream = stream
		voice.volume_db = 2.0
		voice.play()

func play_hypercube_wipe() -> void:
	var stream: AudioStreamWAV
	if _sample_cache.has("hypercube_wipe"):
		stream = _sample_cache["hypercube_wipe"]
	else:
		stream = _generate_hypercube_wipe_wav()
		_sample_cache["hypercube_wipe"] = stream
	
	var voice := _get_voice()
	if voice and voice.is_inside_tree():
		voice.stream = stream
		voice.volume_db = 3.0
		voice.play()

func play_ui_click(success: bool = true) -> void:
	var key := "ui_click_%s" % str(success)
	var stream: AudioStreamWAV
	if _sample_cache.has(key):
		stream = _sample_cache[key]
	else:
		stream = _generate_click_wav(success)
		_sample_cache[key] = stream
	
	var voice := _get_voice()
	if voice and voice.is_inside_tree():
		voice.stream = stream
		voice.volume_db = -4.0
		voice.play()

# Audio synthesis generators
func _generate_chime_wav(freq: float, is_on_beat: bool) -> AudioStreamWAV:
	var duration: float = 0.35 if is_on_beat else 0.25
	var total_samples: int = int(duration * SAMPLE_RATE)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2) # 16-bit mono
	
	for i in range(total_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * (10.0 if not is_on_beat else 7.0))
		# Harmonic vibraphone: fundamental + 2nd harmonic + 3rd harmonic
		var s1 := sin(TAU * freq * t) * 0.65
		var s2 := sin(TAU * freq * 2.0 * t) * 0.25
		var s3 := sin(TAU * freq * 3.0 * t) * 0.10
		var sample := (s1 + s2 + s3) * env
		var val16 := int(clampf(sample * 30000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, val16)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = buffer
	return wav

func _generate_ice_shatter_wav() -> AudioStreamWAV:
	var duration := 0.28
	var total_samples := int(duration * SAMPLE_RATE)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	
	for i in range(total_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 16.0)
		var noise := rng.randf_range(-1.0, 1.0)
		var high_tink := sin(TAU * 2800.0 * t) * 0.4 + sin(TAU * 4200.0 * t) * 0.3
		var sample := (noise * 0.5 + high_tink * 0.5) * env
		var val16 := int(clampf(sample * 28000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, val16)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = buffer
	return wav

func _generate_flame_blast_wav() -> AudioStreamWAV:
	var duration := 0.35
	var total_samples := int(duration * SAMPLE_RATE)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321
	
	for i in range(total_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 9.0)
		var freq := lerpf(180.0, 45.0, t / duration)
		var sub := sin(TAU * freq * t) * 0.7
		var noise := rng.randf_range(-1.0, 1.0) * 0.3
		var sample := (sub + noise) * env
		var val16 := int(clampf(sample * 31000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, val16)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = buffer
	return wav

func _generate_star_laser_wav() -> AudioStreamWAV:
	var duration := 0.30
	var total_samples := int(duration * SAMPLE_RATE)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 11.0)
		var sweep_freq := lerpf(1200.0, 280.0, t / duration)
		var sample := sin(TAU * sweep_freq * t) * env
		var val16 := int(clampf(sample * 30000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, val16)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = buffer
	return wav

func _generate_hypercube_wipe_wav() -> AudioStreamWAV:
	var duration := 0.50
	var total_samples := int(duration * SAMPLE_RATE)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 5.0)
		var sub_drop := sin(TAU * lerpf(90.0, 30.0, t / duration) * t) * 0.6
		var shimmer := sin(TAU * (current_root_freq * 2.0) * t) * 0.25 + sin(TAU * (current_root_freq * 3.0) * t) * 0.15
		var sample := (sub_drop + shimmer) * env
		var val16 := int(clampf(sample * 31000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, val16)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = buffer
	return wav

func _generate_click_wav(success: bool) -> AudioStreamWAV:
	var duration := 0.06
	var total_samples := int(duration * SAMPLE_RATE)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)
	var freq := 880.0 if success else 220.0
	
	for i in range(total_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 60.0)
		var sample := sin(TAU * freq * t) * env
		var val16 := int(clampf(sample * 24000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, val16)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = buffer
	return wav
