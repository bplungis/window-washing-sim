extends Node

## Handles all game audio using procedurally generated sounds.
## Uses AudioStreamGenerator for real-time synthesis of satisfying tool sounds.

var sfx_bus_idx: int
var music_bus_idx: int

# Audio players
var tool_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer

# State
var current_tool_sound: String = ""
var is_tool_active: bool = false
var _phase: float = 0.0
var _noise_state: float = 0.0
var _playback: AudioStreamGeneratorPlayback
var _sample_rate: float = 22050.0

# Pre-generated buffers for UI sounds
var _click_buffer: PackedVector2Array
var _complete_buffer: PackedVector2Array


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create audio bus layout
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	sfx_bus_idx = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_bus_idx, -3.0)

	# Tool sound player (generator-based for real-time synthesis)
	tool_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _sample_rate
	gen.buffer_length = 0.1
	tool_player.stream = gen
	tool_player.bus = "SFX"
	add_child(tool_player)

	# UI sound player
	ui_player = AudioStreamPlayer.new()
	ui_player.bus = "SFX"
	add_child(ui_player)

	# Pre-generate UI sounds
	_click_buffer = _generate_click_sound()
	_complete_buffer = _generate_complete_sound()


func _process(_delta: float) -> void:
	if is_tool_active and tool_player.playing:
		_fill_tool_audio_buffer()


## Start playing the sound for a tool being used.
func start_tool_sound(tool_id: String) -> void:
	current_tool_sound = tool_id
	is_tool_active = true
	_phase = 0.0
	if not tool_player.playing:
		tool_player.play()
		# Get playback after starting
		await get_tree().process_frame
	_playback = tool_player.get_stream_playback()


## Stop the current tool sound.
func stop_tool_sound() -> void:
	is_tool_active = false
	current_tool_sound = ""
	tool_player.stop()


## Play a short UI click.
func play_click() -> void:
	_play_buffer(_click_buffer, -10.0)


## Play job completion fanfare.
func play_complete() -> void:
	_play_buffer(_complete_buffer, -5.0)


func _fill_tool_audio_buffer() -> void:
	if _playback == null:
		return

	var frames_available := _playback.get_frames_available()
	if frames_available <= 0:
		return

	var buffer := PackedVector2Array()
	buffer.resize(frames_available)

	for i in range(frames_available):
		var sample := _generate_tool_sample()
		buffer[i] = Vector2(sample, sample)

	_playback.push_buffer(buffer)


func _generate_tool_sample() -> float:
	var sample := 0.0
	var dt := 1.0 / _sample_rate

	match current_tool_sound:
		"squeegee":
			# Squeegee: filtered noise with slight pitch modulation (rubber on glass)
			_noise_state = _noise_state * 0.92 + (randf() * 2.0 - 1.0) * 0.08
			var freq := 2200.0 + sin(_phase * 3.0) * 400.0
			sample = sin(_phase * freq * TAU) * 0.03 + _noise_state * 0.15
			# Add subtle harmonic for that "squeaky" quality
			sample += sin(_phase * freq * 1.5 * TAU) * 0.01
		"sponge":
			# Sponge: soft wet scrubbing - low filtered noise
			_noise_state = _noise_state * 0.96 + (randf() * 2.0 - 1.0) * 0.04
			sample = _noise_state * 0.12
			# Subtle water squelch
			sample += sin(_phase * 180.0 * TAU) * 0.02 * abs(_noise_state)
		"steelwool":
			# Steel wool: harsher scraping noise
			_noise_state = _noise_state * 0.85 + (randf() * 2.0 - 1.0) * 0.15
			sample = _noise_state * 0.18
			# Add gritty harmonics
			sample += sin(_phase * 4500.0 * TAU) * _noise_state * 0.04
		"spray":
			# Spray: hissing white noise burst
			sample = (randf() * 2.0 - 1.0) * 0.2
			# High-pass filter approximation
			sample = sample - _noise_state
			_noise_state = sample * 0.3
		"razor":
			# Razor: sharp scraping
			_noise_state = _noise_state * 0.88 + (randf() * 2.0 - 1.0) * 0.12
			sample = _noise_state * 0.1
			# Metallic ring
			sample += sin(_phase * 6000.0 * TAU) * 0.02
			sample += sin(_phase * 8500.0 * TAU) * 0.01

	_phase += dt
	return clampf(sample, -1.0, 1.0)


func _generate_click_sound() -> PackedVector2Array:
	var length := int(_sample_rate * 0.05)
	var buffer := PackedVector2Array()
	buffer.resize(length)
	for i in range(length):
		var t := float(i) / _sample_rate
		var env := exp(-t * 80.0)
		var s := sin(t * 1200.0 * TAU) * env * 0.3
		buffer[i] = Vector2(s, s)
	return buffer


func _generate_complete_sound() -> PackedVector2Array:
	var length := int(_sample_rate * 0.8)
	var buffer := PackedVector2Array()
	buffer.resize(length)
	for i in range(length):
		var t := float(i) / _sample_rate
		var env := exp(-t * 3.0)
		# Pleasant major chord arpeggio
		var s := 0.0
		if t < 0.25:
			s = sin(t * 523.25 * TAU) * 0.2  # C5
		elif t < 0.5:
			s = sin(t * 659.25 * TAU) * 0.2  # E5
		else:
			s = sin(t * 783.99 * TAU) * 0.2  # G5
		s *= env
		buffer[i] = Vector2(s, s)
	return buffer


func _play_buffer(buffer: PackedVector2Array, volume_db: float = 0.0) -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _sample_rate
	gen.buffer_length = float(buffer.size()) / _sample_rate + 0.05
	ui_player.stream = gen
	ui_player.volume_db = volume_db
	ui_player.play()
	await get_tree().process_frame
	var playback: AudioStreamGeneratorPlayback = ui_player.get_stream_playback()
	if playback:
		playback.push_buffer(buffer)
