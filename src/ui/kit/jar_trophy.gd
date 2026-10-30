## The level's own jar, big, on the Win card: its layers are the categories just sorted, its lid gold for a clean
## sort. It drops in and settles with one small bounce, then the shelf below shows it landing in its slot.
class_name JarTrophy
extends Control

var layers: Array = []
var gold := false
var t := 0.0:
	set(v):
		t = v
		queue_redraw()


func _init(jar_layers: Array = [], gold_lid: bool = false) -> void:
	layers = jar_layers
	gold = gold_lid
	custom_minimum_size = Vector2(0, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play() -> void:
	t = 0.0
	create_tween().tween_property(self, "t", 1.0, 0.55)


func _draw() -> void:
	var jar := Vector2(150, 200)
	var fall := (1.0 - ShelfView._bounce(clampf(t, 0.0, 1.0))) * 120.0
	var rect := Rect2(Vector2((size.x - jar.x) / 2.0, size.y - jar.y - 6.0 - fall), jar)
	modulate.a = clampf(t * 3.0, 0.0, 1.0)
	var shadow := Rect2(Vector2((size.x - jar.x * 0.9) / 2.0, size.y - 14.0), Vector2(jar.x * 0.9, 12.0))
	draw_style_box(Style.glow(Color(Style.INK, 0.18 * clampf(t, 0.0, 1.0)), 6, 8), shadow)
	var lid: Color = Style.GOLD if gold else Style.PAPRIKA
	var key := "trophy|%s|%s" % [",".join(layers.map(func(c: Color) -> String: return c.to_html(false))), lid.to_html(false)]
	draw_texture_rect(Art.tex(key, jar, Materials.mini_jar.bind(layers, lid)), rect, false)
