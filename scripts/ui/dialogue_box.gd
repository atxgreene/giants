extends CanvasLayer
class_name DialogueBox
## Bottom-panel dialogue with a typewriter effect. Locks player input while
## open. Advance with Interact / Attack / ui_accept.

var lines: Array = []
var line_idx := 0
var char_t := 0.0
var done_cb := Callable()
var name_label: Label
var text_label: Label
var hint_label: Label

const SPEAKER_COLORS := {
	"Michael": Color(0.95, 0.85, 0.5),
	"Gabriel": Color(0.45, 0.75, 1.0),
	"Raphael": Color(0.5, 0.9, 0.6),
	"Uriel": Color(1.0, 0.55, 0.2),
	"The Scribe of Dust": Color(0.8, 0.75, 0.65),
	"The Sleeping Dream": Color(0.65, 0.85, 0.8),
	"Azazel's First Blade": Color(0.9, 0.4, 0.25)
}

func _ready() -> void:
	layer = 70
	var panel := UIKit.panel(UIKit.GOLD)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-380, -170)
	panel.custom_minimum_size = Vector2(760, 130)
	panel.size = Vector2(760, 130)
	var v := UIKit.vbox(6)
	name_label = UIKit.label("", 17, UIKit.GOLD)
	text_label = UIKit.label("", 17, UIKit.PARCHMENT)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(710, 60)
	hint_label = UIKit.label("[E / Click]  Continue", 12, Color(0.6, 0.56, 0.5))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(name_label)
	v.add_child(text_label)
	v.add_child(hint_label)
	panel.add_child(v)
	add_child(panel)
	_lock_player(true)

func play(dialogue_lines: Array, cb := Callable()) -> void:
	lines = dialogue_lines
	done_cb = cb
	line_idx = 0
	char_t = 0.0
	_show_line()

func _show_line() -> void:
	if line_idx >= lines.size():
		_finish()
		return
	var line: Dictionary = lines[line_idx]
	var who := str(line.get("who", ""))
	name_label.text = who
	name_label.add_theme_color_override("font_color", SPEAKER_COLORS.get(who, UIKit.GOLD))
	name_label.visible = who != ""
	text_label.text = ""
	char_t = 0.0
	AudioMan.play("ui")

func _process(delta: float) -> void:
	if line_idx >= lines.size():
		return
	var full := str(lines[line_idx].get("text", ""))
	if text_label.text.length() < full.length():
		char_t += delta * 46.0
		text_label.text = full.substr(0, int(char_t))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()

var _advance_guard := 0

func _advance() -> void:
	if line_idx >= lines.size():
		return
	# On touch, one tap can arrive as both an action and an emulated click.
	var now := Time.get_ticks_msec()
	if now - _advance_guard < 200:
		return
	_advance_guard = now
	var full := str(lines[line_idx].get("text", ""))
	if text_label.text.length() < full.length():
		text_label.text = full
		char_t = full.length()
		return
	line_idx += 1
	_show_line()

func _finish() -> void:
	_lock_player(false)
	var cb := done_cb
	queue_free()
	if cb.is_valid():
		cb.call()

func _lock_player(locked: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set("input_locked", locked)
