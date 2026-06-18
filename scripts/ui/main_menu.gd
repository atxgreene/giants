extends Control
class_name MainMenu
## Title screen: animated sigil backdrop, New Game / Continue / Settings /
## Archive / Quit.

var anim := 0.0
var backdrop: SigilBackdrop

const KEY_ART := "res://assets/sprites/key_art.jpg"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var has_art := ResourceLoader.exists(KEY_ART)
	if has_art:
		var art := TextureRect.new()
		art.texture = load(KEY_ART)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
	backdrop = SigilBackdrop.new()
	backdrop.has_key_art = has_art
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	FX.attach_bloom(self)
	var root := UIKit.center()
	add_child(root)
	var menu_panel := PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel",
		UIKit.panel_style(Color(0.05, 0.04, 0.08, 0.78), Color(0.85, 0.72, 0.38, 0.5), 1))
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
	menu_panel.add_child(v)
	root.add_child(menu_panel)
	var ver := UIKit.label("v" + Game.VERSION + _build_tag() + " — vertical slice", 12, UIKit.ASH)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-190, -30)
	add_child(ver)
	new_game.grab_focus()
	AudioMan.music("hub")

func _build_tag() -> String:
	# Per-deploy build stamp (written by CI) so you can tell at a glance whether
	# the browser loaded the latest build or a cached one.
	var path := "res://assets/build_info.json"
	if not FileAccess.file_exists(path):
		return ""
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.has("sha"):
		return " · build " + str(parsed["sha"])
	return ""

func _menu_btn(text: String) -> Button:
	var b := UIKit.button(text, 20)
	b.custom_minimum_size = Vector2(340, 0)
	return b

class SigilBackdrop extends Control:
	var t := 0.0
	var has_key_art := false

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _hash01(i: int, j: int) -> float:
		return absf(fmod(sin(float(i) * 12.9898 + float(j) * 78.233) * 43758.5453, 1.0))

	func _draw() -> void:
		if has_key_art:
			# The painted key art is underneath: darken it for legibility,
			# keep only the living elements (embers + a faint seal ring).
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.05, 0.45))
			draw_rect(Rect2(0, size.y * 0.55, size.x, size.y * 0.45), Color(0.03, 0.02, 0.05, 0.25))
			# drifting HD-2D light shafts from above (beneath the menu UI)
			var src := Vector2(size.x * 0.5, -size.y * 0.1)
			for s in 4:
				var sway := sin(t * 0.12 + float(s) * 1.7) * size.x * 0.04
				var x_mid := size.x * 0.5 + sway + (float(s) - 1.5) * size.x * 0.16
				var sw := size.x * 0.06
				var sc := Color(1.0, 0.72, 0.4, 0.05 + 0.02 * sin(t * 0.7 + float(s)))
				draw_colored_polygon(PackedVector2Array([
					src + Vector2(-6, 0), src + Vector2(6, 0),
					Vector2(x_mid + sw, size.y), Vector2(x_mid - sw, size.y)]), sc)
			var cc := size * 0.5
			var faint := Color(0.85, 0.72, 0.38, 0.1)
			draw_arc(cc, 305.0, 0, TAU, 64, faint, 1.5)
			for i in 18:
				var cycle := fmod(t * (0.05 + 0.03 * _hash01(i, 5)) + _hash01(i, 6), 1.0)
				var ex := _hash01(i, 7) * size.x
				var ey := size.y - cycle * size.y * 0.6
				draw_circle(Vector2(ex + sin(t * 2.0 + i) * 12.0, ey), 1.3 + _hash01(i, 8),
					Color(1.0, 0.55, 0.2, (1.0 - cycle) * 0.45))
			return
		# night sky gradient (3 bands)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.07))
		draw_rect(Rect2(0, 0, size.x, size.y * 0.4), Color(0.035, 0.03, 0.06))
		var c := size * 0.5
		# starfield with twinkle
		for i in 90:
			var p := Vector2(_hash01(i, 1) * size.x, _hash01(i, 2) * size.y * 0.78)
			var tw := 0.4 + 0.6 * absf(sin(t * 1.5 + float(i)))
			draw_circle(p, 1.0 + _hash01(i, 3), Color(0.8, 0.85, 1.0, 0.32 * tw))
		# great seal rings + script ring
		var gold := Color(0.85, 0.72, 0.38, 0.15)
		draw_arc(c, 300.0, 0, TAU, 64, gold, 2.0)
		draw_arc(c, 260.0, 0, TAU, 64, gold, 1.0)
		for i in 12:
			var a := TAU * i / 12.0 + t * 0.05
			draw_line(c + Vector2.from_angle(a) * 262.0, c + Vector2.from_angle(a) * 298.0, gold, 1.5)
		for i in 36:
			var a2 := TAU * i / 36.0 - t * 0.02
			draw_circle(c + Vector2.from_angle(a2) * 281.0, 1.6, Color(0.85, 0.72, 0.38, 0.2))
		var pts := PackedVector2Array()
		for i in 3:
			pts.append(c + Vector2.from_angle(TAU * i / 3.0 - t * 0.03) * 220.0)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), gold, 1.0)
		# desert horizon: dune bands
		var hy := size.y * 0.8
		for band in 3:
			var dune := PackedVector2Array()
			dune.append(Vector2(0, size.y))
			var x := 0.0
			while x <= size.x:
				dune.append(Vector2(x, hy + band * 34.0 + sin(x * 0.008 + band * 2.2) * 14.0))
				x += 64.0
			dune.append(Vector2(size.x, size.y))
			draw_colored_polygon(dune, Color(0.13 - band * 0.025, 0.06 - band * 0.012, 0.055 - band * 0.01))
		# half-buried colossus on the horizon: skull + rib arcs
		var gx := size.x * 0.78
		var gy := hy + 6.0
		var bone := Color(0.2, 0.16, 0.14)
		draw_circle(Vector2(gx, gy - 18), 26.0, bone)
		draw_rect(Rect2(gx - 10, gy - 6, 20, 8), Color(0.1, 0.05, 0.05))
		draw_circle(Vector2(gx - 9, gy - 22), 6.0, Color(0.07, 0.04, 0.05))
		draw_circle(Vector2(gx + 9, gy - 22), 6.0, Color(0.07, 0.04, 0.05))
		for i in 4:
			draw_arc(Vector2(gx - 90 - i * 34, gy + 6), 40.0 - i * 4.0, PI * 1.05, PI * 1.9, 12, bone, 4.0)
		# molten crack glow across the foreground
		var glow := Color(0.9, 0.35, 0.1, 0.22)
		draw_line(Vector2(size.x * 0.1, size.y * 0.94), Vector2(size.x * 0.42, size.y * 0.9), glow, 3.0)
		draw_line(Vector2(size.x * 0.42, size.y * 0.9), Vector2(size.x * 0.6, size.y * 0.96), glow, 3.0)
		# rising embers
		for i in 24:
			var cycle := fmod(t * (0.04 + 0.03 * _hash01(i, 5)) + _hash01(i, 6), 1.0)
			var ex := _hash01(i, 7) * size.x
			var ey := size.y - cycle * size.y * 0.55
			var ea := (1.0 - cycle) * 0.5
			draw_circle(Vector2(ex + sin(t * 2.0 + i) * 14.0, ey), 1.4 + _hash01(i, 8), Color(1.0, 0.55, 0.2, ea))
		# horizon heat
		draw_rect(Rect2(0, hy - 12, size.x, 12), Color(0.5, 0.18, 0.1, 0.14))
