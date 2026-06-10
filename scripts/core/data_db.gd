extends Node
## Loads every JSON data table at startup. All game content
## (enemies, blessings, weapons, rooms, codex, upgrades, dialogue)
## is data-driven from res://data/.

var weapons: Dictionary = {}
var blessings: Dictionary = {}
var enemies: Dictionary = {}
var rooms: Dictionary = {}
var upgrades: Dictionary = {}
var codex: Dictionary = {}
var dialogue: Dictionary = {}

func _ready() -> void:
	weapons = _load_json("res://data/weapons.json")
	blessings = _load_json("res://data/blessings.json")
	enemies = _load_json("res://data/enemies.json")
	rooms = _load_json("res://data/rooms.json")
	upgrades = _load_json("res://data/upgrades.json")
	codex = _load_json("res://data/codex_entries.json")
	dialogue = _load_json("res://data/dialogue.json")

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data file: " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("Malformed data file: " + path)
		return {}
	return parsed

func blessing_by_id(id: String) -> Dictionary:
	for pool_key in blessings.get("pools", {}):
		for b in blessings["pools"][pool_key]["blessings"]:
			if b["id"] == id:
				var copy: Dictionary = b.duplicate()
				copy["pool"] = pool_key
				return copy
	for b in blessings.get("forbidden", []):
		if b["id"] == id:
			var copy: Dictionary = b.duplicate()
			copy["pool"] = "forbidden"
			return copy
	for r in blessings.get("relics", []):
		if r["id"] == id:
			var copy: Dictionary = r.duplicate()
			copy["pool"] = "relic"
			return copy
	return {}

func pool_color(pool_key: String) -> Color:
	if blessings.get("pools", {}).has(pool_key):
		return Color(blessings["pools"][pool_key]["color"])
	if pool_key == "forbidden":
		return Color(0.75, 0.15, 0.2)
	return Color(0.7, 0.5, 0.9)

func dialogue_lines(key: String) -> Array:
	return dialogue.get(key, [])
