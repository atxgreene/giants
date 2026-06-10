extends CanvasLayer
class_name RewardScreen
## Roguelike reward selection: up to 3 cards (+ optional refuse).
## Pauses the tree while open. Works with mouse, keyboard, and controller.

signal chosen(id: String)

var title_text := "REWARD"
var subtitle_text := ""
var cards: Array = []          # [{id, name, desc, color}]
var allow_refuse := false
var refuse_text := "Refuse"

func _ready() -> void:
	layer = 75
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	add_child(UIKit.dim_layer())
	var root := UIKit.center()
	add_child(root)
	var v := UIKit.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UIKit.title(title_text, 32))
	if subtitle_text != "":
		var sub := UIKit.label(subtitle_text, 15, Color(0.7, 0.66, 0.6))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sub)
	var h := UIKit.hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var first_btn: Button = null
	for card in cards:
		var b := _card_button(card)
		h.add_child(b)
		if first_btn == null:
			first_btn = b
	v.add_child(h)
	if allow_refuse:
		var rb := UIKit.button(refuse_text, 16)
		rb.pressed.connect(func(): _pick(""))
		var rc := CenterContainer.new()
		rc.add_child(rb)
		v.add_child(rc)
	root.add_child(v)
	if first_btn:
		first_btn.grab_focus()
	AudioMan.play("gate")

func _card_button(card: Dictionary) -> Button:
	var col: Color = card.get("color", UIKit.GOLD)
	var b := Button.new()
	b.custom_minimum_size = Vector2(230, 190)
	b.add_theme_stylebox_override("normal", UIKit.panel_style(Color(0.08, 0.07, 0.1, 0.97), col.darkened(0.35), 2))
	b.add_theme_stylebox_override("hover", UIKit.panel_style(Color(0.12, 0.1, 0.13, 1.0), col, 3))
	b.add_theme_stylebox_override("focus", UIKit.panel_style(Color(0.12, 0.1, 0.13, 1.0), col, 3))
	b.add_theme_stylebox_override("pressed", UIKit.panel_style(Color(0.16, 0.13, 0.14, 1.0), col, 3))
	var v := UIKit.vbox(8)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 12
	v.offset_bottom = -12
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := ColorRect.new()
	icon.color = col
	icon.custom_minimum_size = Vector2(28, 28)
	var ic := CenterContainer.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(icon)
	v.add_child(ic)
	var nm := UIKit.label(str(card.get("name", "?")), 17, col)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	var ds := UIKit.label(str(card.get("desc", "")), 13, UIKit.PARCHMENT)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ds)
	b.add_child(v)
	b.pressed.connect(func(): _pick(str(card.get("id", ""))))
	return b

func _pick(id: String) -> void:
	get_tree().paused = false
	chosen.emit(id)
	queue_free()
