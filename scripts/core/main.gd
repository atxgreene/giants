extends Node
## Root screen router. Every screen (menu, hub, run, game over, victory)
## is a code-built node swapped in under this root.

var current: Node = null

func _ready() -> void:
	Game.main = self
	show_screen("menu")

func show_screen(screen_name: String, args: Dictionary = {}) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	FX.clear_refs()
	if is_instance_valid(current):
		current.queue_free()
	current = null
	match screen_name:
		"menu":
			current = MainMenu.new()
		"hub":
			current = Hub.new()
		"run":
			current = RunScene.new()
		"gameover":
			current = GameOverScreen.new()
		"victory":
			current = VictoryScreen.new()
	if current == null:
		push_error("Unknown screen: " + screen_name)
		return
	if current.has_method("setup") and not args.is_empty():
		current.call("setup", args)
	add_child(current)
