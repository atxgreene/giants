extends Control
class_name GameOverScreen
## Death screen. The Witness falls; the Watchtower receives them again.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := UIKit.center()
	add_child(root)
	var v := UIKit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UIKit.title("THE WITNESS FALLS", 42, UIKit.CRIMSON.lightened(0.25)))
	var sub := UIKit.label("The desert keeps what it kills. The Watchtower keeps what it sends.", 16, UIKit.ASH)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(UIKit.label(" ", 8))
	var route_line := UIKit.label("%s      Seed: %s" % [RunState.route_name, RunState.seed_display()], 14, UIKit.ASH)
	route_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(route_line)
	var stats := UIKit.label(
		"Rooms cleared: %d      Foes destroyed: %d      Bound: %d\nSeals carried home: %d      Corruption at the end: %d      Revelation: %d" % [
			RunState.rooms_cleared, RunState.kills, RunState.bound_kills,
			RunState.seals_earned, int(RunState.corruption), int(RunState.revelation)],
		16, UIKit.PARCHMENT)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	v.add_child(UIKit.label(" ", 8))
	var back := UIKit.button("Return to the Watchtower", 20)
	back.pressed.connect(func(): Game.goto("hub"))
	var bc := CenterContainer.new()
	bc.add_child(back)
	v.add_child(bc)
	root.add_child(v)
	back.grab_focus()
