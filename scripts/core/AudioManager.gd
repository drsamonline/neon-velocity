extends Node
## Procedural audio.
##
## The spec called for AudioStreamGenerator, but that class is a real-time push
## buffer: you cannot fill it offline and you cannot save it. Everything here is
## synthesised into PCM float buffers and wrapped in AudioStreamWAV instead, so
## the sounds exist the moment the game starts and no .ogg files are needed.
##
## 24 SFX and a four-layer adaptive music loop, all deterministic.

const SFX_RATE := 22050
const MUSIC_RATE := 11025
const LOOP_SECONDS := 6.857  # 4 bars at 140 BPM
const MAX_SFX_CHANNELS := 24

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _music_targets: Array[float] = [0.0, -80.0, -80.0, -80.0]
var _intensity: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20251025
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)
	_apply_saved_volumes()
	_build_sfx()
	_build_players()
	_build_music()


# --- Buses --------------------------------------------------------------

func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	return idx


func _apply_saved_volumes() -> void:
	set_bus_volume(SFX_BUS, float(SaveSystem.get_setting("audio", "sfx_volume", 0.8)))
	set_bus_volume(MUSIC_BUS, float(SaveSystem.get_setting("audio", "music_volume", 0.6)))


func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


# --- Public API ---------------------------------------------------------

func play_sfx(sound: String, pitch_variation: float = 0.05) -> void:
	var stream: AudioStream = _sfx.get(sound)
	if stream == null:
		return
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = 1.0 + _rng.randf_range(-pitch_variation, pitch_variation)
			player.play()
			return
	# All channels busy: steal the first one rather than dropping the sound.
	var first := _players[0]
	first.stream = stream
	first.pitch_scale = 1.0
	first.play()


func has_sfx(sound: String) -> bool:
	return _sfx.has(sound)


func set_music_intensity(level: int) -> void:
	_intensity = clampi(level, 0, 3)
	for i in _music_targets.size():
		_music_targets[i] = 0.0 if i <= _intensity else -80.0


func stop_music() -> void:
	for player in _music_players:
		player.stop()


func music_intensity() -> int:
	return _intensity


func _process(delta: float) -> void:
	# Gentle crossfade so layers slide in instead of popping.
	for i in _music_players.size():
		var player := _music_players[i]
		if not player.playing:
			continue
		var target: float = _music_targets[i]
		if target <= -79.0:
			player.volume_db = move_toward(player.volume_db, -60.0, 40.0 * delta)
		else:
			player.volume_db = move_toward(player.volume_db, -6.0, 25.0 * delta)


# --- Players ------------------------------------------------------------

func _build_players() -> void:
	for i in MAX_SFX_CHANNELS:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)


func _build_music() -> void:
	var layers := [
		_music_bass(),
		_music_lead(),
		_music_pad(),
		_music_drums(),
	]
	for i in layers.size():
		var player := AudioStreamPlayer.new()
		player.bus = MUSIC_BUS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.stream = _to_wav(layers[i], MUSIC_RATE, true)
		player.volume_db = -6.0 if i == 0 else -60.0
		add_child(player)
		_music_players.append(player)
		player.play()
	_music_targets = [0.0, -80.0, -80.0, -80.0]


# --- WAV packaging ------------------------------------------------------

func _to_wav(samples: PackedFloat32Array, rate: int = SFX_RATE, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var value := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


# --- Synthesis primitives ----------------------------------------------

func _buffer(duration: float, rate: int = SFX_RATE) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(1, int(rate * duration)))
	return out


func _wave(shape: String, phase: float) -> float:
	match shape:
		"sine":
			return sin(phase)
		"square":
			return 1.0 if fmod(phase, TAU) < PI else -1.0
		"saw":
			return 2.0 * (fmod(phase, TAU) / TAU) - 1.0
		"triangle":
			var p := fmod(phase, TAU) / TAU
			return 4.0 * absf(p - 0.5) - 1.0
		_:
			return sin(phase)


## Single tone with exponential decay.
func tone(freq: float, duration: float, shape: String = "sine", decay: float = 8.0, volume: float = 0.5) -> PackedFloat32Array:
	var rate := SFX_RATE
	var out := _buffer(duration, rate)
	var phase := 0.0
	var step := TAU * freq / float(rate)
	for i in out.size():
		var t := float(i) / rate
		var env := exp(-t * decay) * minf(1.0, t * 400.0)
		out[i] = _wave(shape, phase) * env * volume
		phase += step
	return out


## Tone whose pitch glides from start_freq to end_freq.
func sweep(start_freq: float, end_freq: float, duration: float, shape: String = "sine", volume: float = 0.5, decay: float = 0.0) -> PackedFloat32Array:
	var rate := SFX_RATE
	var out := _buffer(duration, rate)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / rate
		var progress := t / duration
		var freq: float = lerpf(start_freq, end_freq, progress)
		var env: float = (1.0 - progress) if decay <= 0.0 else exp(-t * decay)
		env *= minf(1.0, t * 300.0)
		out[i] = _wave(shape, phase) * env * volume
		phase += TAU * freq / float(rate)
	return out


func noise(duration: float, volume: float = 0.4, decay: float = 12.0) -> PackedFloat32Array:
	var rate := SFX_RATE
	var out := _buffer(duration, rate)
	for i in out.size():
		var t := float(i) / rate
		out[i] = _rng.randf_range(-1.0, 1.0) * exp(-t * decay) * volume
	return out


## Mix layers together. Each entry is [offset_seconds, PackedFloat32Array].
func mix(layers: Array, rate: int = SFX_RATE) -> PackedFloat32Array:
	var total := 0
	for entry in layers:
		var offset: float = entry[0]
		var samples: PackedFloat32Array = entry[1]
		total = maxi(total, int(rate * offset) + samples.size())
	var out := PackedFloat32Array()
	out.resize(total)
	for entry in layers:
		var offset := int(rate * float(entry[0]))
		var samples: PackedFloat32Array = entry[1]
		for i in samples.size():
			out[offset + i] += samples[i]
	for i in out.size():
		out[i] = clampf(out[i], -1.0, 1.0)
	return out


# --- SFX bank -----------------------------------------------------------

func _build_sfx() -> void:
	_sfx["shoot_plasma"] = _to_wav(mix([
		[0.0, sweep(700.0, 220.0, 0.12, "square", 0.45, 22.0)],
		[0.0, noise(0.05, 0.12, 60.0)],
	]))
	_sfx["shoot_spread"] = _to_wav(mix([
		[0.0, tone(660.0, 0.06, "square", 26.0, 0.35)],
		[0.02, tone(880.0, 0.05, "square", 26.0, 0.28)],
		[0.04, tone(1320.0, 0.05, "square", 26.0, 0.22)],
	]))
	_sfx["shoot_laser"] = _to_wav(mix([
		[0.0, sweep(800.0, 400.0, 0.4, "sine", 0.4, 3.0)],
		[0.0, sweep(1600.0, 800.0, 0.4, "sine", 0.15, 4.0)],
	]))
	_sfx["shoot_missile"] = _to_wav(mix([
		[0.0, sweep(160.0, 90.0, 0.3, "saw", 0.35, 6.0)],
		[0.0, noise(0.22, 0.2, 14.0)],
	]))
	_sfx["shoot_railgun"] = _to_wav(mix([
		[0.0, sweep(200.0, 2000.0, 0.45, "triangle", 0.35, 0.0)],
		[0.45, sweep(3000.0, 300.0, 0.2, "square", 0.4, 18.0)],
		[0.45, noise(0.15, 0.3, 24.0)],
	]))
	_sfx["shoot_nova"] = _to_wav(mix([
		[0.0, sweep(120.0, 900.0, 0.4, "saw", 0.3, 0.0)],
		[0.35, sweep(900.0, 60.0, 0.35, "sine", 0.45, 8.0)],
	]))
	_sfx["hit_enemy"] = _to_wav(tone(440.0, 0.08, "square", 30.0, 0.3))
	_sfx["hit_player"] = _to_wav(mix([
		[0.0, tone(220.0, 0.18, "saw", 16.0, 0.4)],
		[0.0, noise(0.1, 0.2, 30.0)],
	]))
	_sfx["explosion_small"] = _to_wav(mix([
		[0.0, sweep(220.0, 60.0, 0.3, "sine", 0.35, 9.0)],
		[0.0, noise(0.3, 0.35, 10.0)],
	]))
	_sfx["explosion_large"] = _to_wav(mix([
		[0.0, sweep(200.0, 40.0, 0.8, "sine", 0.4, 4.0)],
		[0.0, noise(0.8, 0.45, 4.0)],
		[0.1, noise(0.6, 0.2, 6.0)],
	]))
	_sfx["dash"] = _to_wav(mix([
		[0.0, sweep(300.0, 120.0, 0.1, "sine", 0.3, 20.0)],
		[0.0, noise(0.08, 0.25, 30.0)],
	]))
	_sfx["pickup_weapon"] = _to_wav(_arpeggio(880.0, 0.1, 30.0))
	_sfx["pickup_mod"] = _to_wav(_arpeggio(660.0, 0.15, 20.0))
	_sfx["pickup_health"] = _to_wav(_arpeggio(550.0, 0.2, 15.0))
	_sfx["pickup_currency"] = _to_wav(tone(1000.0, 0.05, "sine", 30.0, 0.35))
	_sfx["pickup_shield"] = _to_wav(_arpeggio(700.0, 0.18, 18.0))
	_sfx["ui_click"] = _to_wav(tone(800.0, 0.04, "sine", 40.0, 0.3))
	_sfx["ui_confirm"] = _to_wav(tone(1200.0, 0.05, "sine", 34.0, 0.3))
	_sfx["ui_back"] = _to_wav(tone(400.0, 0.05, "sine", 34.0, 0.3))
	_sfx["ui_pause"] = _to_wav(tone(600.0, 0.06, "sine", 28.0, 0.3))
	_sfx["boss_spawn"] = _to_wav(mix([
		[0.0, tone(55.0, 1.5, "saw", 2.0, 0.35)],
		[0.0, tone(110.0, 1.2, "square", 2.5, 0.2)],
		[0.0, noise(1.5, 0.18, 2.0)],
	]))
	_sfx["boss_hit"] = _to_wav(tone(180.0, 0.2, "square", 14.0, 0.35))
	_sfx["boss_death"] = _to_wav(mix([
		[0.0, noise(2.0, 0.5, 2.2)],
		[0.0, sweep(180.0, 30.0, 2.0, "sine", 0.4, 2.0)],
	]))
	_sfx["level_up"] = _to_wav(mix([
		[0.0, tone(523.25, 0.16, "sine", 8.0, 0.35)],
		[0.14, tone(659.25, 0.16, "sine", 8.0, 0.35)],
		[0.28, tone(783.99, 0.24, "sine", 6.0, 0.4)],
	]))
	_sfx["combo_break"] = _to_wav(tone(150.0, 0.3, "saw", 10.0, 0.3))


func _arpeggio(base: float, duration: float, rate_hz: float) -> PackedFloat32Array:
	var notes := [1.0, 1.25, 1.5]
	var layers := []
	var step := 1.0 / rate_hz
	for i in notes.size():
		layers.append([i * step, tone(base * notes[i], duration, "sine", 14.0, 0.3)])
	return mix(layers)


# --- Adaptive music -----------------------------------------------------

const _BASS_PATTERN := [0, 0, 12, 0, 7, 0, 10, 0, 5, 5, 17, 5, 3, 3, 15, 3]
const _LEAD_PATTERN := [24, -1, 27, 31, -1, 29, 27, -1, 24, -1, 22, 24, 27, -1, 31, 34]
const _CHORDS := [[0, 7, 12], [0, 5, 10], [3, 8, 15], [5, 10, 17]]


func _music_bass() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(MUSIC_RATE * LOOP_SECONDS))
	var step_duration := LOOP_SECONDS / 64.0
	var phase := 0.0
	for i in out.size():
		var t := float(i) / MUSIC_RATE
		var step := int(t / step_duration)
		var semitone: int = _BASS_PATTERN[step % _BASS_PATTERN.size()]
		var freq := 55.0 * pow(2.0, float(semitone) / 12.0)
		var local := fmod(t, step_duration) / step_duration
		var env := exp(-local * 4.5) * minf(1.0, local * 40.0)
		phase += TAU * freq / float(MUSIC_RATE)
		out[i] = (_wave("saw", phase) * 0.5 + sin(phase) * 0.5) * env * 0.4
	return out


func _music_lead() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(MUSIC_RATE * LOOP_SECONDS))
	var step_duration := LOOP_SECONDS / 32.0
	var phase := 0.0
	for i in out.size():
		var t := float(i) / MUSIC_RATE
		var step := int(t / step_duration)
		var semitone: int = _LEAD_PATTERN[step % _LEAD_PATTERN.size()]
		if semitone < 0:
			out[i] = 0.0
			continue
		var freq := 110.0 * pow(2.0, float(semitone) / 12.0)
		var local := fmod(t, step_duration) / step_duration
		var env := exp(-local * 3.0) * minf(1.0, local * 20.0)
		phase += TAU * freq / float(MUSIC_RATE)
		out[i] = _wave("square", phase) * env * 0.13
	return out


func _music_pad() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(MUSIC_RATE * LOOP_SECONDS))
	var bar_duration := LOOP_SECONDS / 4.0
	var phases := [0.0, 0.0, 0.0]
	for i in out.size():
		var t := float(i) / MUSIC_RATE
		var bar := int(t / bar_duration) % _CHORDS.size()
		var chord: Array = _CHORDS[bar]
		var local := fmod(t, bar_duration) / bar_duration
		var env := sin(PI * local) * 0.6
		var sample := 0.0
		for n in chord.size():
			var freq := 110.0 * pow(2.0, float(chord[n]) / 12.0)
			phases[n] += TAU * freq / float(MUSIC_RATE)
			sample += _wave("triangle", phases[n])
		out[i] = (sample / float(chord.size())) * env * 0.10
	return out


func _music_drums() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(MUSIC_RATE * LOOP_SECONDS))
	var eighth := LOOP_SECONDS / 32.0
	var kick_phase := 0.0
	for i in out.size():
		var t := float(i) / MUSIC_RATE
		var step := int(t / eighth)
		var local := fmod(t, eighth)
		var value := 0.0
		# Kick on every quarter note.
		if step % 8 == 0:
			var kt := local
			var freq := lerpf(120.0, 45.0, minf(1.0, kt / 0.14))
			kick_phase += TAU * freq / float(MUSIC_RATE)
			value += sin(kick_phase) * exp(-kt * 18.0) * 0.5
		# Snare on the backbeat.
		if step % 8 == 4:
			value += _rng.randf_range(-1.0, 1.0) * exp(-local * 30.0) * 0.22
		# Hats on every eighth.
		value += _rng.randf_range(-1.0, 1.0) * exp(-local * 90.0) * 0.05
		out[i] = clampf(value, -1.0, 1.0)
	return out
