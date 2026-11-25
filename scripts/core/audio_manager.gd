class_name AudioManager
extends Node

signal beat_tick(beat_number: int)
signal track_finished()

var music_player: AudioStreamPlayer
var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance
var music_bus_index: int = 0
var sfx_bus_index: int = 0

var current_bpm: float = 120.0
var beat_interval: float = 0.5
var current_playback_time: float = 0.0
var track_duration: float = 0.0
var is_playing: bool = false
var last_beat_index: int = -1

# Smoothed spectrum magnitudes
var bass_magnitude: float = 0.0
var mid_magnitude: float = 0.0
var treble_magnitude: float = 0.0

var beat_phase: float = 0.0 # 0.0 to 1.0

func _init() -> void:
	name = "AudioManager"
	_setup_audio_buses()
	_setup_music_player()

func _ready() -> void:
	pass

func _setup_audio_buses() -> void:
	# Check or create Music bus
	music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index < 0:
		music_bus_index = AudioServer.bus_count
		AudioServer.add_bus(music_bus_index)
		AudioServer.set_bus_name(music_bus_index, "Music")
		AudioServer.set_bus_send(music_bus_index, "Master")
	
	# Check or create SFX bus
	sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index < 0:
		sfx_bus_index = AudioServer.bus_count
		AudioServer.add_bus(sfx_bus_index)
		AudioServer.set_bus_name(sfx_bus_index, "SFX")
		AudioServer.set_bus_send(sfx_bus_index, "Master")
	
	# Check or add spectrum analyzer effect to Music bus
	var effect_found := false
	for i in range(AudioServer.get_bus_effect_count(music_bus_index)):
		var eff := AudioServer.get_bus_effect(music_bus_index, i)
		if eff is AudioEffectSpectrumAnalyzer:
			effect_found = true
			break
	
	if not effect_found:
		var analyzer := AudioEffectSpectrumAnalyzer.new()
		analyzer.buffer_length = 0.1
		analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
		AudioServer.add_bus_effect(music_bus_index, analyzer)
	
	for i in range(AudioServer.get_bus_effect_count(music_bus_index)):
		var inst = AudioServer.get_bus_effect_instance(music_bus_index, i)
		if inst is AudioEffectSpectrumAnalyzerInstance:
			spectrum_analyzer = inst
			break

func _setup_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)

func play_track(stream: AudioStream, bpm: float, start_pos: float = 0.0) -> void:
	current_bpm = maxf(bpm, 60.0)
	beat_interval = 60.0 / current_bpm
	last_beat_index = -1
	if music_player:
		music_player.stream = stream
		if music_player.is_inside_tree():
			music_player.play(start_pos)
	is_playing = true
	track_duration = stream.get_length() if stream else 0.0

func stop_track() -> void:
	if music_player:
		music_player.stop()
	is_playing = false

func pause_track() -> void:
	if music_player:
		music_player.stream_paused = true
	is_playing = false

func resume_track() -> void:
	if music_player:
		music_player.stream_paused = false
		is_playing = true

func _on_music_finished() -> void:
	is_playing = false
	track_finished.emit()

func _process(delta: float) -> void:
	if not is_playing or not music_player.playing:
		# Decay spectrum magnitudes gracefully when paused or stopped
		bass_magnitude = lerpf(bass_magnitude, 0.0, delta * 8.0)
		mid_magnitude = lerpf(mid_magnitude, 0.0, delta * 8.0)
		treble_magnitude = lerpf(treble_magnitude, 0.0, delta * 8.0)
		return
	
	# Accurate playback time calculation with audio latency compensation
	var raw_pos := music_player.get_playback_position()
	var time_since_mix := AudioServer.get_time_since_last_mix()
	var latency := AudioServer.get_output_latency()
	current_playback_time = maxf(0.0, raw_pos + time_since_mix - latency)
	
	# Beat tracking
	var beat_time := fposmod(current_playback_time, beat_interval)
	beat_phase = beat_time / beat_interval
	var current_beat := int(current_playback_time / beat_interval)
	if current_beat > last_beat_index:
		last_beat_index = current_beat
		beat_tick.emit(current_beat)
	
	# Sample spectrum analyzer magnitudes
	if spectrum_analyzer:
		var raw_bass := spectrum_analyzer.get_magnitude_for_frequency_range(20.0, 250.0).length()
		var raw_mid := spectrum_analyzer.get_magnitude_for_frequency_range(250.0, 2000.0).length()
		var raw_treble := spectrum_analyzer.get_magnitude_for_frequency_range(2000.0, 16000.0).length()
		
		# Normalize magnitudes roughly to [0, 1] range with exponential smoothing
		bass_magnitude = lerpf(bass_magnitude, clampf(raw_bass * 4.0, 0.0, 1.5), delta * 18.0)
		mid_magnitude = lerpf(mid_magnitude, clampf(raw_mid * 5.0, 0.0, 1.5), delta * 16.0)
		treble_magnitude = lerpf(treble_magnitude, clampf(raw_treble * 8.0, 0.0, 1.5), delta * 14.0)

func is_on_beat(tolerance_sec: float = 0.120) -> bool:
	if not is_playing:
		return false
	var beat_time := fposmod(current_playback_time, beat_interval)
	return beat_time <= tolerance_sec or (beat_interval - beat_time) <= tolerance_sec

func get_time_remaining() -> float:
	return maxf(0.0, track_duration - current_playback_time)
