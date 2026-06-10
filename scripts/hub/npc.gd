extends Node2D
class_name NPCNode
## Hub interactable: archangel NPCs, the Scribe, altars, lecterns, and the
## run gate. Drawn procedurally; interaction is routed back to the Hub.

var npc_id := ""
var display_name := ""
var prompt := "Speak"
var style := "angel"        # angel | scribe | altar | lectern | gate | shrine_upgrade
var accent := Color(0.95, 0.85, 0.5)
var callback := Callable()
var anim := 0.0

func _ready() -> void:
	add_to_group("interact")
	anim = randf() * 10.0
	if display_name != "":
		var l := Label.new()
		l.text = display_name
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", accent)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 4)
		l.position = Vector2(-70, -76)
		l.size = Vector2(140, 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(l)

func get_prompt() -> String:
	return prompt

func try_interact(_player) -> void:
	if callback.is_valid():
		callback.call()

func _process(delta: float) -> void:
	anim += delta
	queue_redraw()

func _draw() -> void:
	var hover := sin(anim * 1.6) * 2.5
	# shadow
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match style:
		"angel":
			_draw_angel(hover)
		"scribe":
			_draw_scribe(hover)
		"altar":
			_draw_altar()
		"lectern":
			_draw_lectern()
		"gate":
			_draw_gate()

func _draw_angel(hover: float) -> void:
	# wings — soft fans of light
	for side in [-1.0, 1.0]:
		for i in 4:
			var a: float = -PI * 0.5 + side * (0.4 + 0.2 * i) + sin(anim * 1.2) * 0.04
			var root := Vector2(0, -30 + hover)
			var tip := root + Vector2.from_angle(a) * (40.0 - i * 5.0)
			var wc := accent
			wc.a = 0.5 - 0.08 * i
			draw_line(root, tip, wc, 3.5 - i * 0.5)
	# robe
	var robe := accent.darkened(0.45)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -38 + hover), Vector2(11, -24 + hover), Vector2(13, 10),
		Vector2(-13, 10), Vector2(-11, -24 + hover)]), robe)
	draw_polyline(PackedVector2Array([Vector2(-11, -24 + hover), Vector2(0, -30 + hover), Vector2(11, -24 + hover)]), accent, 2.0)
	# head + halo
	draw_circle(Vector2(0, -44 + hover), 6.5, Color(0.92, 0.88, 0.8))
	draw_arc(Vector2(0, -44 + hover), 10.5, 0, TAU, 20, accent, 2.0)
	# emblem
	draw_circle(Vector2(0, -12 + hover), 3.5, accent)

func _draw_scribe(hover: float) -> void:
	var robe := Color(0.35, 0.32, 0.28)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -32 + hover), Vector2(9, -20 + hover), Vector2(11, 10),
		Vector2(-11, 10), Vector2(-9, -20 + hover)]), robe)
	draw_circle(Vector2(0, -38 + hover), 6.0, Color(0.85, 0.74, 0.6))
	# scroll
	draw_rect(Rect2(8, -18 + hover, 14, 5), Color(0.9, 0.85, 0.7))
	draw_circle(Vector2(8, -15 + hover), 3.0, Color(0.8, 0.72, 0.55))
	# dust motes
	for i in 3:
		var p := Vector2(sin(anim * 1.3 + i * 2.0) * 16.0, -28 + cos(anim * 1.7 + i) * 10.0)
		draw_circle(p, 1.2, Color(0.9, 0.85, 0.7, 0.4))

func _draw_altar() -> void:
	var stone := Color(0.18, 0.16, 0.2)
	draw_rect(Rect2(-24, -10, 48, 14), stone)
	draw_rect(Rect2(-18, -30, 36, 20), stone.lightened(0.08))
	var pulse := 0.6 + 0.4 * sin(anim * 3.0)
	var g := accent
	g.a = 0.55 * pulse
	# floating sword above the weapon altar
	draw_line(Vector2(0, -58), Vector2(0, -34), accent, 3.0)
	draw_line(Vector2(-6, -52), Vector2(6, -52), accent, 2.5)
	draw_circle(Vector2(0, -46), 10.0 + 2.0 * pulse, g)

func _draw_lectern() -> void:
	var wood := Color(0.3, 0.22, 0.15)
	draw_rect(Rect2(-4, -26, 8, 28), wood)
	draw_set_transform(Vector2(0, -28), -0.25, Vector2.ONE)
	draw_rect(Rect2(-16, -6, 32, 8), wood.lightened(0.15))
	draw_rect(Rect2(-14, -5, 13, 6), Color(0.9, 0.85, 0.7))
	draw_rect(Rect2(1, -5, 13, 6), Color(0.9, 0.85, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var g := accent
	g.a = 0.3 + 0.2 * sin(anim * 2.5)
	draw_circle(Vector2(0, -34), 9.0, g)

func _draw_gate() -> void:
	var pulse := 0.65 + 0.35 * sin(anim * 2.2)
	var stone := Color(0.14, 0.12, 0.16)
	draw_rect(Rect2(-40, -78, 13, 88), stone)
	draw_rect(Rect2(27, -78, 13, 88), stone)
	draw_arc(Vector2(0, -76), 38.0, PI, TAU, 20, stone, 10.0)
	# desert seen through the gate
	var sand := Color(0.6, 0.28, 0.16, 0.5 + 0.2 * pulse)
	draw_rect(Rect2(-27, -70, 54, 80), sand)
	var sun := Color(1.0, 0.6, 0.25, 0.7)
	draw_circle(Vector2(0, -48), 8.0 + pulse * 2.0, sun)
	# warding script
	var g := accent
	g.a = 0.8
	for i in 5:
		var a := PI + PI * (0.12 + 0.19 * i)
		draw_circle(Vector2(0, -76) + Vector2.from_angle(a) * 38.0, 2.0, g)
