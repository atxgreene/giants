extends Node
## The Witness Archive. Tracks unlocked codex entries in the save profile
## and labels every entry with its source tier (the lore honesty system).

const TIER_LABELS := {
	1: "Canonical Scripture",
	2: "Enochic Tradition",
	3: "Book of Giants Fragment",
	4: "Scholarly Reconstruction",
	5: "Game-Original Mythic Extrapolation",
	6: "Unknown / Hidden"
}

const TIER_COLORS := {
	1: Color(0.91, 0.85, 0.65),
	2: Color(0.75, 0.65, 0.95),
	3: Color(0.65, 0.85, 0.8),
	4: Color(0.6, 0.7, 0.85),
	5: Color(0.9, 0.6, 0.4),
	6: Color(0.85, 0.3, 0.4)
}

var unlocked_this_run := 0

func is_unlocked(id: String) -> bool:
	return id in Game.profile.get("codex", [])

func unlock(id: String) -> bool:
	if not DataDB.codex.has(id):
		return false
	if is_unlocked(id):
		return false
	Game.profile["codex"].append(id)
	if RunState.active:
		unlocked_this_run += 1
	Game.save()
	var title: String = DataDB.codex[id].get("title", id)
	Game.toast("Archive entry unlocked: " + title, Color(0.45, 0.75, 1.0))
	AudioMan.play("revelation")
	if RunState.active:
		RunState.add_revelation(8.0)
	# The Archive notices being read. Witness enough of it, and it witnesses back.
	if unlocked_count() >= 10 and not is_unlocked("the-scribe-of-dust"):
		unlock("the-scribe-of-dust")
	return true

func unlock_random_fragment() -> bool:
	var pool: Array = []
	for id in DataDB.codex:
		var tier := int(DataDB.codex[id].get("tier", 5))
		if not is_unlocked(id) and tier != 6 and id != "teaching-of-weapons" and id != "uriel":
			pool.append(id)
	if pool.is_empty():
		Game.toast("The Archive holds its remaining pages close.", Color(0.45, 0.75, 1.0))
		return false
	return unlock(pool[randi() % pool.size()])

func tier_label(tier: int) -> String:
	return TIER_LABELS.get(tier, "Unknown")

func tier_color(tier: int) -> Color:
	return TIER_COLORS.get(tier, Color.WHITE)

func unlocked_count() -> int:
	return Game.profile.get("codex", []).size()

func total_count() -> int:
	return DataDB.codex.size()
