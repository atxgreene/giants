extends CanvasLayer
class_name PauseMenu
## Pause overlay. Resume / Settings / Codex / Abandon Run / Quit to Menu.

var menu_box: VBoxContainer

func _ready() -> void:
	layer = 78
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	add_child(UIKit.dim_layer())
	var root := UIKit.center()
	add_child(root)
	menu_box = UIKit.vbox(12)
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_child(UIKit.title("PAUSED", 34))
	menu_box.add_child(UIKit.label(" ", 6))
	var resume := UIKit.button("Resume", 20)
	resume.custom_minimum_size = Vector2(280, 0)
	resume.pressed.connect(_resume)
	menu_box.add_child(resume)
	var settings := UIKit.button("Settings", 20)
	settings.pressed.connect(func():
		var sm := SettingsMenu.new()
		add_child(sm))
	menu_box.add_child(settings)
	var codex := UIKit.button("The Witness Archive", 20)
	codex.pressed.connect(func():
		var cm := CodexMenu.new()
		add_child(cm))
	menu_box.add_child(codex)
	if RunState.active:
		var abandon := UIKit.button("Abandon Run", 20)
		abandon.pressed.connect(func():
			RunState.end_run()
			get_tree().paused = false
			Game.goto("hub"))
		menu_box.add_child(abandon)
	var quit := UIKit.button("Quit to Main Menu", 20)
	quit.pressed.connect(func():
		RunState.end_run()
		get_tree().paused = false
		Game.goto("menu"))
	menu_box.add_child(quit)
	root.add_child(menu_box)
	resume.grab_focus()
	AudioMan.play("ui")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_resume()

func _resume() -> void:
	get_tree().paused = false
	queue_free()
