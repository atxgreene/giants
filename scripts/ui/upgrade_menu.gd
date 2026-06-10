extends CanvasLayer
class_name UpgradeMenu
## Michael's training altar: spend Seals of Witness on persistent upgrades.

var rows_box: VBoxContainer
var seals_label: Label

func _ready() -> void:
	layer = 74
	add_child(UIKit.dim_layer())
	var root := UIKit.center()
	add_child(root)
	var panel := UIKit.panel()
	var v := UIKit.vbox(12)
	v.custom_minimum_size = Vector2(560, 0)
	v.add_child(UIKit.title("TRAINING OF THE HOST", 26))
	seals_label = UIKit.label("", 16, UIKit.BRONZE.lightened(0.3))
	seals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(seals_label)
	rows_box = UIKit.vbox(8)
	v.add_child(rows_box)
	var back := UIKit.button("Leave the altar", 16)
	back.pressed.connect(queue_free)
	var bc := CenterContainer.new()
	bc.add_child(back)
	v.add_child(bc)
	panel.add_child(v)
	root.add_child(panel)
	_refresh()

func _refresh() -> void:
	seals_label.text = "%d Seals of Witness" % int(Game.profile["seals"])
	for child in rows_box.get_children():
		child.queue_free()
	for up_id in DataDB.upgrades:
		var up: Dictionary = DataDB.upgrades[up_id]
		var lvl := Game.upgrade_level(up_id)
		var max_lvl := int(up["max_level"])
		var h := UIKit.hbox(10)
		var info := UIKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.label("%s   [%d/%d]" % [str(up["name"]), lvl, max_lvl], 16, UIKit.GOLD))
		var d := UIKit.label(str(up["desc"]), 13, UIKit.PARCHMENT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(d)
		h.add_child(info)
		if lvl >= max_lvl:
			h.add_child(UIKit.label("MASTERED", 14, UIKit.ASH))
		else:
			var cost := int(up["costs"][lvl])
			var b := UIKit.button("%d Seals" % cost, 15)
			b.disabled = int(Game.profile["seals"]) < cost
			b.pressed.connect(func():
				if Game.spend_seals(cost):
					Game.profile["upgrades"][up_id] = lvl + 1
					Game.save()
					RunState.rebuild_mods()
					var player := get_tree().get_first_node_in_group("player")
					if player:
						player.call("refresh_stats")
					AudioMan.play("blessing")
					_refresh())
			h.add_child(b)
		rows_box.add_child(h)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		queue_free()
