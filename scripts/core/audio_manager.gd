extends Node
## Procedural audio. Every SFX and music loop is synthesized into
## AudioStreamWAV buffers at startup — no external audio files required.
## Direction: bronze impacts, deep drums, desert wind, angelic pads,
## distorted whispers, sword fire, giant roars, low cosmic drones.
## Replace by dropping real files into assets/audio/ and assets/music/
## (see assets/audio/README.md for the expected names).

const SFX_RATE := 22050
const MUS_RATE := 16000

const SFX_DIR := "res://assets/audio/"
const MUSIC_DIR := "res://assets/music/"

## Music state → {file: external .ogg basename, gen: generated fallback key}.
## Lookup order is: external file exists → use it; otherwise generated fallback.
const MUSIC_STATES := {
	"hub": {"file": "hub_theme", "gen": "hub"},
	"desert": {"file": "desert_combat", "gen": "desert"},
	"desert_calm": {"file": "desert_calm", "gen": "hub"},
	"combat_low": {"file": "combat_low", "gen": "desert"},
	"combat_high": {"file": "combat_high", "gen": "desert"},
	"elite": {"file": "elite", "gen": "boss"},
	"miniboss": {"file": "miniboss", "gen": "boss"},
	"boss": {"file": "boss_theme", "gen": "boss"},
	"boss_p1": {"file": "boss_phase_1", "gen": "boss"},
	"boss_p2": {"file": "boss_phase_2", "gen": "boss"},
	"boss_p3": {"file": "boss_phase_3", "gen": "boss"},
	"victory": {"file": "victory", "gen": "hub"},
	"death": {"file": "death", "gen": "hub"},
}

var sfx: Dictionary = {}
var music_tracks: Dictionary = {}
var generated_music: Dictionary = {}
var players: Array = []
var music_player: AudioStreamPlayer
var current_track := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	_build_sfx()
	_build_music()
	_apply_external_overrides()

func _apply_external_overrides() -> void:
	# Prefer real recordings dropped into assets/ over the procedural buffers.
	for name in sfx.keys():
		var ext := _load_external(SFX_DIR + str(name) + ".wav")
		if ext != null:
			sfx[name] = ext
	for state in MUSIC_STATES:
		var info: Dictionary = MUSIC_STATES[state]
		var ext_music := _load_external(MUSIC_DIR + str(info["file"]) + ".ogg")
		if ext_music != null:
			music_tracks[state] = ext_music
		elif generated_music.has(info["gen"]):
			music_tracks[state] = generated_music[info["gen"]]

func _load_external(path: String):
	# Imported resources load normally; raw-dropped .ogg can load at runtime.
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is AudioStream:
			return res
	if path.ends_with(".ogg") and FileAccess.file_exists(path):
		return AudioStreamOggVorbis.load_from_file(path)
	return null

func set_volumes(music_v: float, sfx_v: float) -> void:
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	if mi >= 0:
		AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(music_v, 0.001)))
		AudioServer.set_bus_mute(mi, music_v <= 0.001)
	if si >= 0:
		AudioServer.set_bus_volume_db(si, linear_to_db(maxf(sfx_v, 0.001)))
		AudioServer.set_bus_mute(si, sfx_v <= 0.001)

func play(sound: String, pitch_var := 0.08) -> void:
	if not sfx.has(sound):
		return
	for p in players:
		if not p.playing:
			p.stream = sfx[sound]
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return
	players[0].stream = sfx[sound]
	players[0].play()

func music(track: String) -> void:
	if current_track == track:
		return
	current_track = track
	if not music_tracks.has(track):
		music_player.stop()
		return
	music_player.stream = music_tracks[track]
	music_player.play()

func stop_music() -> void:
	current_track = ""
	music_player.stop()

# ------------------------------------------------------------------ helpers

func _wav(samples: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

func _env(t: float, dur: float, attack := 0.005) -> float:
	if t < attack:
		return t / attack
	return maxf(0.0, 1.0 - (t - attack) / maxf(dur - attack, 0.001))

# ------------------------------------------------------------------ sfx

func _build_sfx() -> void:
	sfx["swing"] = _gen(0.14, func(t, d):
		return (randf() * 2.0 - 1.0) * _env(t, d) * 0.5 * (1.0 - t / d))
	sfx["hit"] = _gen(0.16, func(t, d):
		return (sin(TAU * (170.0 - t * 500.0) * t) * 0.8 + (randf() * 2.0 - 1.0) * 0.4) * _env(t, d))
	sfx["hit_heavy"] = _gen(0.3, func(t, d):
		return (sin(TAU * (95.0 - t * 160.0) * t) * 0.95 + (randf() * 2.0 - 1.0) * 0.45) * _env(t, d))
	sfx["bronze"] = _gen(0.5, func(t, d):
		return (sin(TAU * 410.0 * t) * 0.4 + sin(TAU * 619.0 * t) * 0.3 + sin(TAU * 1033.0 * t) * 0.2) * _env(t, d, 0.002))
	sfx["dash"] = _gen(0.18, func(t, d):
		return (randf() * 2.0 - 1.0) * _env(t, d, 0.02) * 0.35 * sin(TAU * 3.0 * t / d))
	sfx["hurt"] = _gen(0.25, func(t, d):
		return (signf(sin(TAU * (240.0 - 300.0 * t) * t)) * 0.3 + (randf() * 2.0 - 1.0) * 0.3) * _env(t, d))
	sfx["death"] = _gen(0.9, func(t, d):
		return (sin(TAU * (110.0 - 70.0 * t) * t) * 0.7 + (randf() * 2.0 - 1.0) * 0.25) * _env(t, d, 0.01))
	sfx["edeath"] = _gen(0.4, func(t, d):
		return (sin(TAU * (150.0 - 120.0 * t) * t) * 0.6 + (randf() * 2.0 - 1.0) * 0.35) * _env(t, d))
	sfx["pickup"] = _gen(0.35, func(t, d):
		var f := 523.0 if t < 0.12 else 784.0
		return sin(TAU * f * t) * _env(t, d, 0.01) * 0.5)
	sfx["blessing"] = _gen(0.9, func(t, d):
		return (sin(TAU * 440.0 * t) * 0.3 + sin(TAU * 554.0 * t) * 0.25 + sin(TAU * 659.0 * t) * 0.25) * _env(t, d, 0.05))
	sfx["ui"] = _gen(0.07, func(t, d):
		return sin(TAU * 700.0 * t) * _env(t, d) * 0.35)
	sfx["seal"] = _gen(0.7, func(t, d):
		return (sin(TAU * 660.0 * t) * 0.35 + sin(TAU * 990.0 * t) * 0.2) * _env(t, d, 0.02) * (1.0 + 0.3 * sin(TAU * 8.0 * t)))
	sfx["ult"] = _gen(1.1, func(t, d):
		return (sin(TAU * (60.0 + 20.0 * sin(TAU * 2.0 * t)) * t) * 0.8 + (randf() * 2.0 - 1.0) * 0.4 * _env(t, 0.3)) * _env(t, d, 0.01))
	sfx["roar"] = _gen(1.2, func(t, d):
		return (sin(TAU * (75.0 + 22.0 * sin(TAU * 5.5 * t)) * t) * 0.8 + (randf() * 2.0 - 1.0) * 0.3) * _env(t, d, 0.08))
	sfx["whisper"] = _gen(1.0, func(t, d):
		return (randf() * 2.0 - 1.0) * 0.25 * (0.6 + 0.4 * sin(TAU * (2.0 + t * 4.0) * t)) * _env(t, d, 0.15))
	sfx["fire"] = _gen(0.4, func(t, d):
		return (randf() * 2.0 - 1.0) * 0.4 * (0.5 + 0.5 * sin(TAU * 13.0 * t)) * _env(t, d, 0.03))
	sfx["bolt"] = _gen(0.2, func(t, d):
		return sin(TAU * (900.0 - 700.0 * t) * t) * _env(t, d) * 0.4)
	sfx["gate"] = _gen(0.8, func(t, d):
		var f := 392.0 if t < 0.25 else (494.0 if t < 0.5 else 587.0)
		return sin(TAU * f * t) * _env(t, d, 0.02) * 0.4)
	sfx["revelation"] = _gen(1.4, func(t, d):
		var f := 523.0
		if t > 0.3: f = 659.0
		if t > 0.6: f = 784.0
		if t > 0.9: f = 1047.0
		return (sin(TAU * f * t) * 0.4 + sin(TAU * f * 2.0 * t) * 0.12) * _env(t, d, 0.05))
	sfx["sting_death"] = _gen(2.0, func(t, d):
		var f := 220.0
		if t > 0.5: f = 174.6
		if t > 1.0: f = 130.8
		return (sin(TAU * f * t) * 0.4 + sin(TAU * f * 0.5 * t) * 0.3) * _env(t, d, 0.05))

func _gen(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(dur * SFX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / SFX_RATE
		s[i] = fn.call(t, dur)
	return _wav(s, SFX_RATE)

# ------------------------------------------------------------------ music

func _build_music() -> void:
	# Generated fallbacks. Every music state maps to one of these unless an
	# external file overrides it in _apply_external_overrides().
	generated_music["hub"] = _render_hub()
	generated_music["desert"] = _render_desert()
	generated_music["boss"] = _render_boss()
	for state in MUSIC_STATES:
		music_tracks[state] = generated_music[MUSIC_STATES[state]["gen"]]

func _render_hub() -> AudioStreamWAV:
	# Angelic pad: D minor add9 stack with slow tremolo and soft wind.
	# Shorter loop on web to keep WASM startup snappy.
	var dur := 4.0 if OS.has_feature("web") else 8.0
	var n := int(dur * MUS_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var wind := 0.0
	var freqs := [73.42, 110.0, 146.83, 220.0, 293.66, 329.63]
	var amps := [0.22, 0.16, 0.13, 0.10, 0.07, 0.045]
	for i in n:
		var t := float(i) / MUS_RATE
		var v := 0.0
		for j in freqs.size():
			v += sin(TAU * freqs[j] * t) * amps[j]
		v *= 0.75 + 0.25 * sin(TAU * 0.125 * t)
		wind = wind * 0.995 + (randf() * 2.0 - 1.0) * 0.005
		s[i] = v + wind * 2.2
	return _wav(s, MUS_RATE, true)

func _render_desert() -> AudioStreamWAV:
	# Drone + ritual drums. 8 beats at 0.5s.
	var dur := 4.0
	var n := int(dur * MUS_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var wind := 0.0
	for i in n:
		var t := float(i) / MUS_RATE
		var v := sin(TAU * 73.42 * t) * 0.16 + sin(TAU * 110.0 * t) * 0.1
		v *= 0.8 + 0.2 * sin(TAU * 0.25 * t)
		var beat := fmod(t, 0.5)
		var beat_idx := int(t / 0.5)
		if beat_idx % 2 == 0 and beat < 0.15:
			v += sin(TAU * (130.0 - beat * 600.0) * beat) * (1.0 - beat / 0.15) * 0.5
		if beat_idx % 4 == 3 and beat < 0.1:
			v += (randf() * 2.0 - 1.0) * (1.0 - beat / 0.1) * 0.22
		wind = wind * 0.993 + (randf() * 2.0 - 1.0) * 0.007
		s[i] = v + wind * 1.6
	return _wav(s, MUS_RATE, true)

func _render_boss() -> AudioStreamWAV:
	# Faster drums over a tritone drone, with a high alarm pulse.
	var dur := 4.0
	var n := int(dur * MUS_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / MUS_RATE
		var v := sin(TAU * 73.42 * t) * 0.15 + sin(TAU * 103.83 * t) * 0.12
		var beat := fmod(t, 0.375)
		var beat_idx := int(t / 0.375)
		if beat < 0.12:
			v += sin(TAU * (140.0 - beat * 700.0) * beat) * (1.0 - beat / 0.12) * 0.55
		if beat_idx % 2 == 1 and beat < 0.07:
			v += (randf() * 2.0 - 1.0) * (1.0 - beat / 0.07) * 0.3
		v += sin(TAU * 587.33 * t) * 0.045 * maxf(0.0, sin(TAU * 0.5 * t))
		s[i] = v
	return _wav(s, MUS_RATE, true)
