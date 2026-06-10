extends CanvasLayer
class_name CodexMenu
## The Witness Archive reader. Entry list on the left (locked entries appear
## as ???), full entry with source-tier badge on the right.

var detail_box: VBoxContainer
var scroll: ScrollContainer

func _ready() -> void:
	layer = 79
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dim_layer())
	var root := UIKit.center()
	add_child(root)
	var panel := UIKit.panel()
	var v := UIKit.vbox(10)
	v.custom_minimum_size = Vector2(940, 560)
	var head := UIKit.hbox(10)
	var t := UIKit.title("THE WITNESS ARCHIVE", 26)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.label("%d / %d witnessed" % [CodexMan.unlocked_count(), CodexMan.total_count()], 14, UIKit.ASH))
	v.add_child(head)
	var h := UIKit.hbox(14)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# entry list
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(280, 470)
	var list := UIKit.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var first_btn: Button = null
	for id in DataDB.codex:
		var unlocked := CodexMan.is_unlocked(id)
		var entry: Dictionary = DataDB.codex[id]
		var label_txt := str(entry["title"]) if unlocked else "? ? ?"
		var b := UIKit.button(label_txt, 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not unlocked:
			b.modulate = Color(0.55, 0.55, 0.55)
		b.pressed.connect(_show_entry.bind(id))
		list.add_child(b)
		if first_btn == null and unlocked:
			first_btn = b
	list_scroll.add_child(list)
	h.add_child(list_scroll)
	# detail panel
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 470)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box = UIKit.vbox(10)
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(detail_box)
	h.add_child(scroll)
	v.add_child(h)
	var back := UIKit.button("Close the Archive", 16)
	back.pressed.connect(queue_free)
	var bc := CenterContainer.new()
	bc.add_child(back)
	v.add_child(bc)
	panel.add_child(v)
	root.add_child(panel)
	if first_btn:
		first_btn.grab_focus()
		_show_entry("appointed-witness")

func _show_entry(id: String) -> void:
	for child in detail_box.get_children():
		child.queue_free()
	var entry: Dictionary = DataDB.codex[id]
	var unlocked := CodexMan.is_unlocked(id)
	if not unlocked:
		detail_box.add_child(UIKit.label("This page has not yet been witnessed.", 16, UIKit.ASH))
		return
	var tier := int(entry.get("tier", 5))
	detail_box.add_child(UIKit.title(str(entry["title"]), 24))
	var badge := UIKit.label("SOURCE: " + CodexMan.tier_label(tier).to_upper(), 13, CodexMan.tier_color(tier))
	detail_box.add_child(badge)
	detail_box.add_child(_body("", str(entry["summary"])))
	detail_box.add_child(_body("UNLOCKED BY — ", str(entry["unlocked_by"])))
	detail_box.add_child(_body("IN THE FIELD — ", str(entry["relevance"])))
	var myst := _body("MYSTERY — ", str(entry["mystery"]))
	myst.add_theme_color_override("font_color", Color(0.75, 0.65, 0.95))
	detail_box.add_child(myst)
	AudioMan.play("ui")

func _body(prefix: String, text: String) -> Label:
	var l := UIKit.label(prefix + text, 15, UIKit.PARCHMENT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	return l

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		queue_free()
