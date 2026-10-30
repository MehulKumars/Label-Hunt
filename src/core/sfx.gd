## Sound effects (autoload "Sfx"): a pool of players on the SFX bus, random variants and pitch.
## Sound is never the only signal for anything, and gameplay never waits on audio.
extends Node

## name -> number of variants (files are name_1.wav ... or name.wav when there is one).
const SOUNDS := {
	"lift": 3, "drop": 3, "slip": 2, "type": 3, "refuse": 1, "lid": 1, "tag": 1, "frost": 1, "tap": 1, "win": 1,
}
const POOL := 12

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _bus := "SFX"


func _ready() -> void:
	if AudioServer.get_bus_index(_bus) < 0:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, _bus)
		AudioServer.set_bus_send(idx, "Master")
	for name in SOUNDS:
		var list: Array[AudioStream] = []
		var n: int = SOUNDS[name]
		for i in n:
			var path := "res://assets/audio/sfx/%s.wav" % name if n == 1 else "res://assets/audio/sfx/%s_%d.wav" % [name, i + 1]
			list.append(load(path))
		_streams[name] = list
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = _bus
		add_child(p)
		_pool.append(p)


## pitch: base multiplier (combo steps pass 1.06^n); spread: random +- fraction.
func play(name: String, pitch: float = 1.0, spread: float = 0.05, volume_db: float = 0.0) -> void:
	var list: Array = _streams.get(name, [])
	if list.is_empty():
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = list[randi() % list.size()]
	p.pitch_scale = pitch * (1.0 + randf_range(-spread, spread))
	p.volume_db = volume_db
	p.play()


func set_enabled(on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(_bus), not on)
