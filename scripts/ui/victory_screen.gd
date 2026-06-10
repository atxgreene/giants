extends Control
class_name VictoryScreen
## Vertical-slice ending: the First Blade is broken, Uriel appears,
## the codex opens, and the loop continues.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := UIKit.center()
	add_child(root)
	var v := UIKit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UIKit.title("THE FIRST BLADE IS BROKEN", 38))
	var uriel1 := UIKit.label("URIEL — \"So. The First Blade is unmade, and the Witness still stands. Fire reveals the shape of a thing.\"", 16, Color(1.0, 0.55, 0.2))
	uriel1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uriel1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	uriel1.custom_minimum_size = Vector2(720, 0)
	v.add_child(uriel1)
	var line := UIKit.label("One blade has been broken. The forgemaster remains.", 20, UIKit.PARCHMENT)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(line)
	v.add_child(UIKit.label(" ", 6))
	var unlocks := UIKit.label(
		"ARCHIVE UNLOCKED — \"The Teaching of Weapons\" · \"Uriel\"\nBLESSING POOL UNLOCKED — Uriel, Flame over the Abyss\nSEALS OF WITNESS EARNED THIS RUN — %d" % RunState.seals_earned,
		15, UIKit.STARFIRE)
	unlocks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(unlocks)
	var stats := UIKit.label(
		"Rooms cleared: %d      Foes destroyed: %d      Bound: %d      Corruption: %d      Revelation: %d" % [
			RunState.rooms_cleared, RunState.kills, RunState.bound_kills,
			int(RunState.corruption), int(RunState.revelation)],
		14, UIKit.ASH)
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
	AudioMan.music("hub")
