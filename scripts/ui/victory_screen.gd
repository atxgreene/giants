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
	v.add_child(UIKit.label(" ", 4))
	v.add_child(_summary())
	v.add_child(UIKit.label(" ", 8))
	var back := UIKit.button("Return to the Watchtower", 20)
	back.pressed.connect(func(): Game.goto("hub"))
	var bc := CenterContainer.new()
	bc.add_child(back)
	v.add_child(bc)
	root.add_child(v)
	back.grab_focus()
	AudioMan.music("hub")

func _summary() -> Label:
	# Full run summary: route, seed, meters, bound kills, forbidden choices,
	# weapon/aspect, and codex unlocked this run.
	var weapon_name := "Flaming Sword of Commission"
	var weapon_id := str(Game.profile.get("weapon", "flaming_sword"))
	var wdef: Dictionary = DataDB.weapons.get(weapon_id, {})
	if wdef.has("name"):
		weapon_name = str(wdef["name"])
	var aspect_id := str(Game.profile.get("aspect", "commission"))
	var aspect_name := str(DataDB.weapons.get("aspects", {}).get(aspect_id, {}).get("name", aspect_id))
	var codex_new := CodexMan.unlocked_this_run
	var text := "—  RUN SUMMARY  —\n"
	text += "Route: %s          Seed: %s\n" % [RunState.route_name, RunState.seed_display()]
	text += "Rooms cleared: %d      Foes destroyed: %d      Bound kills: %d\n" % [
		RunState.rooms_cleared, RunState.kills, RunState.bound_kills]
	text += "Corruption: %d      Revelation: %d\n" % [int(RunState.corruption), int(RunState.revelation)]
	text += "Forbidden gifts — accepted: %d, refused: %d\n" % [
		RunState.forbidden_accepted, RunState.forbidden_refused]
	text += "Weapon: %s  ·  Aspect: %s\n" % [weapon_name, aspect_name]
	text += "Codex pages unlocked this run: %d" % codex_new
	var stats := UIKit.label(text, 14, UIKit.ASH)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return stats
