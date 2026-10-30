## Sound (autoload "Sfx"): effects on the SFX and UI buses, and the music bed on the Music bus (plan-m2 section 12).
## Effects come from a pool with random variants and pitch, at most 3 voices of one sound; stingers (win, bell) have
## reserved players so a burst of clinks can't steal them. Sound is never the only signal for anything, and gameplay
## never waits on audio.
extends Node

## name -> variants (files are name_1.wav ... or name.wav when there is one).
const SOUNDS := {
	"lift": 2, "drop": 3, "place": 1, "slip": 2, "refuse": 1, "write": 1, "type": 1, "chime": 1, "ratchet": 1,
	"seat": 1, "shelf": 1, "bell": 1, "tap": 1, "whoosh": 1, "win": 1, "frost": 1,
}
const UI_SOUNDS := ["tap", "whoosh"]
const STINGERS := ["win", "bell"]
const POOL := 12
const MAX_VOICES := 3
const MUSIC := "res://assets/audio/music/catmint.ogg"
const MUSIC_DB := -8.0

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _stingers: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _duck: Tween
var _sound_level := 1.0
var _music_level := 0.7


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX", "UI"]:
		_ensure_bus(bus)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 800.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), lp)
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Music"), 0, false)
	for name in SOUNDS:
		var list: Array[AudioStream] = []
		var n: int = SOUNDS[name]
		for i in n:
			var path := "res://assets/audio/sfx/%s.wav" % name if n == 1 else "res://assets/audio/sfx/%s_%d.wav" % [name, i + 1]
			list.append(load(path))
		_streams[name] = list
	for i in POOL:
		_pool.append(_player("SFX"))
	for i in 2:
		_stingers.append(_player("SFX"))
	_music = _player("Music")
	var stream: AudioStreamOggVorbis = load(MUSIC)
	stream.loop = true
	_music.stream = stream
	_music.volume_db = MUSIC_DB


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, "Master")


## pitch: base multiplier (combo steps pass 2^(n/12)); spread: random +- fraction.
func play(name: String, pitch: float = 1.0, spread: float = 0.05, volume_db: float = 0.0) -> void:
	var list: Array = _streams.get(name, [])
	if list.is_empty():
		return
	var p: AudioStreamPlayer
	if STINGERS.has(name):
		p = _stingers[0] if not _stingers[0].playing else _stingers[1]
	else:
		var voices := 0
		for q in _pool:
			if q.playing and list.has(q.stream):
				voices += 1
		if voices >= MAX_VOICES:
			return
		p = _pool[_next]
		_next = (_next + 1) % POOL
		p.bus = "UI" if UI_SOUNDS.has(name) else "SFX"
	p.stream = list[randi() % list.size()]
	p.pitch_scale = pitch * (1.0 + randf_range(-spread, spread))
	p.volume_db = volume_db
	p.play()
	if STINGERS.has(name):
		duck(1.6)


## Plays a sound that should land on a visual moment `delay` seconds from now, started early by the device's audio
## output latency (Android adds roughly 50-150 ms), so the clink and the landing coincide.
func play_at(delay: float, name: String, pitch: float = 1.0, spread: float = 0.05, volume_db: float = 0.0) -> void:
	var wait := delay - AudioServer.get_output_latency()
	if wait <= 0.0:
		play(name, pitch, spread, volume_db)
	else:
		get_tree().create_timer(wait).timeout.connect(play.bind(name, pitch, spread, volume_db))


## Music dips 6 dB under a stinger, then comes back.
func duck(seconds: float) -> void:
	if _duck:
		_duck.kill()
	_duck = create_tween()
	_duck.tween_property(_music, "volume_db", MUSIC_DB - 6.0, 0.12)
	_duck.tween_interval(seconds)
	_duck.tween_property(_music, "volume_db", MUSIC_DB, 0.6)


## Pause puts the music "behind glass": low-passed and a little quieter, never stopped.
func muffle(on: bool) -> void:
	var idx := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_effect_enabled(idx, 0, on)
	AudioServer.set_bus_volume_db(idx, _bus_db(_music_level) - (6.0 if on else 0.0))


## Sound and music volumes, 0..1 each (Settings). Zero mutes the bus.
func set_volumes(sound: float, music: float) -> void:
	_sound_level = sound
	_music_level = music
	for bus in ["SFX", "UI"]:
		var idx := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_mute(idx, sound <= 0.0)
		AudioServer.set_bus_volume_db(idx, _bus_db(sound))
	var m := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(m, music <= 0.0)
	AudioServer.set_bus_volume_db(m, _bus_db(music))
	if music > 0.0 and not _music.playing:
		_music.play()


func set_enabled(on: bool) -> void:
	set_volumes(1.0 if on else 0.0, _music_level)


static func _bus_db(level: float) -> float:
	return linear_to_db(maxf(level, 0.001))
