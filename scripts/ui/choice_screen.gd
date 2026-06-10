extends CanvasLayer
class_name ChoiceScreen
## Binary moral choice modal (used for the boss temptation). Pauses the tree.

signal decided(accepted: bool)

var title_text := "A CHOICE"
var body_text := ""
var accept_text := "Accept"
var refuse_text := "Refuse"

func _ready() -> void:
	layer = 76
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	add_child(UIKit.dim_layer())
	var root := UIKit.center()
	add_child(root)
	var v := UIKit.vbox(20)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UIKit.title(title_text, 30, UIKit.CRIMSON.lightened(0.3)))
	var body := UIKit.label(body_text, 16, UIKit.PARCHMENT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(640, 0)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	var h := UIKit.hbox(24)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var accept := _big_button(accept_text, Color(0.85, 0.25, 0.25))
	accept.pressed.connect(func(): _pick(true))
	var refuse := _big_button(refuse_text, Color(0.95, 0.85, 0.5))
	refuse.pressed.connect(func(): _pick(false))
	h.add_child(accept)
	h.add_child(refuse)
	v.add_child(h)
	root.add_child(v)
	refuse.grab_focus()
	AudioMan.play("whisper")

func _big_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 130)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", UIKit.PARCHMENT)
	b.add_theme_color_override("font_hover_color", col.lightened(0.3))
	b.add_theme_color_override("font_focus_color", col.lightened(0.3))
	b.add_theme_stylebox_override("normal", UIKit.panel_style(Color(0.08, 0.07, 0.1, 0.97), col.darkened(0.4), 2))
	b.add_theme_stylebox_override("hover", UIKit.panel_style(Color(0.12, 0.1, 0.13, 1.0), col, 3))
	b.add_theme_stylebox_override("focus", UIKit.panel_style(Color(0.12, 0.1, 0.13, 1.0), col, 3))
	b.add_theme_stylebox_override("pressed", UIKit.panel_style(Color(0.15, 0.12, 0.13, 1.0), col, 3))
	return b

func _pick(accepted: bool) -> void:
	get_tree().paused = false
	decided.emit(accepted)
	queue_free()
