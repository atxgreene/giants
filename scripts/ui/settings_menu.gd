extends CanvasLayer
class_name SettingsMenu
## Settings overlay: volumes, damage numbers, screen shake, fullscreen.

func _ready() -> void:
	layer = 79
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dim_layer())
	var root := UIKit.center()
	add_child(root)
	var panel := UIKit.panel()
	var outer := UIKit.vbox(10)
	outer.add_child(UIKit.title("SETTINGS", 28))
	var v := UIKit.vbox(10)
	v.custom_minimum_size = Vector2(460, 0)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(480, 440)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	outer.add_child(sc)
	v.add_child(UIKit.label("— AUDIO —", 14, UIKit.GOLD))
	v.add_child(_slider_row("Music Volume", "music"))
	v.add_child(_slider_row("Effects Volume", "sfx"))
	v.add_child(UIKit.label("— DISPLAY —", 14, UIKit.GOLD))
	v.add_child(_check_row("Bloom / HD-2D Glow", "bloom"))
	v.add_child(_check_row("Damage Numbers", "damage_numbers"))
	v.add_child(_check_row("Screen Shake", "screenshake"))
	v.add_child(_slider_row("Screen Shake Amount", "screenshake_amount", 0.0, 1.5))
	v.add_child(_slider_row("Flash Intensity", "flash_amount", 0.0, 1.0))
	v.add_child(_check_row("Fullscreen", "fullscreen"))
	v.add_child(UIKit.label("— ACCESSIBILITY —", 14, UIKit.GOLD))
	v.add_child(_slider_row("Text Scale", "text_scale", 0.8, 1.6))
	v.add_child(_check_row("High-Contrast Telegraphs", "high_contrast"))
	v.add_child(_check_row("Colorblind-Safe Telegraphs", "colorblind_telegraphs"))
	v.add_child(_check_row("Hold to Dash", "hold_to_dash"))
	v.add_child(_check_row("Touch Auto-Aim Assist", "auto_aim_assist"))
	v.add_child(UIKit.label("— CONTROLS —", 14, UIKit.GOLD))
	v.add_child(_control_map())
	var back := UIKit.button("Back", 18)
	back.pressed.connect(queue_free)
	var bc := CenterContainer.new()
	bc.add_child(back)
	outer.add_child(bc)
	panel.add_child(outer)
	root.add_child(panel)
	back.grab_focus()

func _control_map() -> Control:
	var box := UIKit.vbox(2)
	var rows := [
		["Move", "WASD / Arrows / Left Stick"],
		["Aim", "Mouse / Right Stick / (auto on touch)"],
		["Attack", "Left Click / X"],
		["Heavy Attack", "Shift / Mid Click / Y"],
		["Special", "Right Click / RT"],
		["Dash", "Space / RB"],
		["Binding Seal", "Q / LB"],
		["Ultimate", "R / B"],
		["Interact", "E / A"],
		["Pause", "Esc / Start"],
	]
	for r in rows:
		var h := UIKit.hbox(10)
		var name_l := UIKit.label(str(r[0]), 13, UIKit.PARCHMENT)
		name_l.custom_minimum_size = Vector2(150, 0)
		h.add_child(name_l)
		h.add_child(UIKit.label(str(r[1]), 13, UIKit.ASH.lightened(0.2)))
		box.add_child(h)
	return box

func _slider_row(label_text: String, key: String, lo := 0.0, hi := 1.0) -> HBoxContainer:
	var h := UIKit.hbox(12)
	var l := UIKit.label(label_text, 16)
	l.custom_minimum_size = Vector2(190, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Game.setting(key))
	s.custom_minimum_size = Vector2(180, 24)
	s.value_changed.connect(func(val: float): Game.set_setting(key, val))
	h.add_child(s)
	return h

func _check_row(label_text: String, key: String) -> HBoxContainer:
	var h := UIKit.hbox(12)
	var l := UIKit.label(label_text, 16)
	l.custom_minimum_size = Vector2(180, 0)
	h.add_child(l)
	var c := CheckBox.new()
	c.button_pressed = bool(Game.setting(key))
	c.toggled.connect(func(on: bool): Game.set_setting(key, on))
	h.add_child(c)
	return h

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		queue_free()
