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
	var v := UIKit.vbox(14)
	v.custom_minimum_size = Vector2(420, 0)
	v.add_child(UIKit.title("SETTINGS", 28))
	v.add_child(_slider_row("Music Volume", "music"))
	v.add_child(_slider_row("Effects Volume", "sfx"))
	v.add_child(_check_row("Damage Numbers", "damage_numbers"))
	v.add_child(_check_row("Screen Shake", "screenshake"))
	v.add_child(_check_row("Fullscreen", "fullscreen"))
	var back := UIKit.button("Back", 18)
	back.pressed.connect(queue_free)
	var bc := CenterContainer.new()
	bc.add_child(back)
	v.add_child(bc)
	panel.add_child(v)
	root.add_child(panel)
	back.grab_focus()

func _slider_row(label_text: String, key: String) -> HBoxContainer:
	var h := UIKit.hbox(12)
	var l := UIKit.label(label_text, 16)
	l.custom_minimum_size = Vector2(180, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Game.setting(key))
	s.custom_minimum_size = Vector2(190, 24)
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
