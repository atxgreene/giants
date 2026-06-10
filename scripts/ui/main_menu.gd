extends Control
class_name MainMenu
## Title screen: animated sigil backdrop, New Game / Continue / Settings /
## Archive / Quit.

var anim := 0.0
var backdrop: SigilBackdrop

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop = SigilBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var root := UIKit.center()
	add_child(root)
	var v := UIKit.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UIKit.title("THE WATCHERS", 52))
	v.add_child(UIKit.title("FALL OF THE GIANTS", 24, UIKit.PARCHMENT))
	var tag := UIKit.label("The giants dreamed before the flood. Their dreams were judgments.", 14, UIKit.ASH)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	v.add_child(UIKit.label(" ", 10))
	var has_save := SaveMan.has_save() and bool(Game.profile.get("intro_seen", false))
	if has_save:
		var cont := _menu_btn("Continue")
		cont.pressed.connect(func(): Game.goto("hub"))
		v.add_child(cont)
	var new_game := _menu_btn("New Game" if not has_save else "New Game (erases save)")
	new_game.pressed.connect(func():
		Game.new_game()
		Game.goto("hub"))
	v.add_child(new_game)
	var settings := _menu_btn("Settings")
	settings.pressed.connect(func(): add_child(SettingsMenu.new()))
	v.add_child(settings)
	var codex := _menu_btn("The Witness Archive")
	codex.pressed.connect(func(): add_child(CodexMenu.new()))
	v.add_child(codex)
	var quit := _menu_btn("Quit")
	quit.pressed.connect(func(): get_tree().quit())
	v.add_child(quit)
	var controls := UIKit.label("WASD move · Mouse aim · LMB attack · Shift/MMB heavy · RMB crescent · Space dash · Q seal · E interact · R ultimate · Esc pause", 12, UIKit.ASH)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(UIKit.label(" ", 8))
	v.add_child(controls)
	root.add_child(v)
	new_game.grab_focus()
	AudioMan.music("hub")

func _menu_btn(text: String) -> Button:
	var b := UIKit.button(text, 20)
	b.custom_minimum_size = Vector2(340, 0)
	return b

class SigilBackdrop extends Control:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.06))
		var c := size * 0.5
		# starfield
		for i in 70:
			var px := fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
			var py := fmod(sin(float(i) * 78.233) * 12543.123, 1.0)
			var p := Vector2(absf(px) * size.x, absf(py) * size.y)
			var tw := 0.4 + 0.6 * absf(sin(t * 1.5 + float(i)))
			draw_circle(p, 1.2, Color(0.8, 0.85, 1.0, 0.35 * tw))
		# great seal rings
		var gold := Color(0.85, 0.72, 0.38, 0.16)
		draw_arc(c, 300.0, 0, TAU, 64, gold, 2.0)
		draw_arc(c, 260.0, 0, TAU, 64, gold, 1.0)
		for i in 12:
			var a := TAU * i / 12.0 + t * 0.05
			draw_line(c + Vector2.from_angle(a) * 262.0, c + Vector2.from_angle(a) * 298.0, gold, 1.5)
		# slow rotating inner triangle
		var pts := PackedVector2Array()
		for i in 3:
			pts.append(c + Vector2.from_angle(TAU * i / 3.0 - t * 0.03) * 220.0)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), gold, 1.0)
		# desert horizon glow
		var glow := Color(0.5, 0.18, 0.1, 0.25)
		draw_rect(Rect2(0, size.y * 0.82, size.x, size.y * 0.18), glow)
