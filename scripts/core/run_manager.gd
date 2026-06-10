extends Node
## State of the current run: blessings, relics, corruption, revelation,
## room progress, and the stacked modifier table that combines blessings,
## relics, weapon aspect, persistent upgrades, and run weapon upgrades.

signal meters_changed
signal blessings_changed

var active := false
var blessings: Array = []        # blessing/forbidden ids
var relics: Array = []           # relic ids
var corruption := 0.0            # 0..100
var revelation := 0.0            # 0..100
var room_index := 0
var rooms_cleared := 0
var seals_earned := 0
var kills := 0
var bound_kills := 0
var took_damage_this_room := false
var weapon_upgrade := 0.0        # additive sword_dmg gathered this run
var run_hp := -1.0               # player hp carried between rooms
var pools_available: Array = []
var rev_50_announced := false

var _mods: Dictionary = {}

func _ready() -> void:
	rebuild_mods()

func reset() -> void:
	active = true
	blessings.clear()
	relics.clear()
	corruption = 0.0
	revelation = 0.0
	room_index = 0
	rooms_cleared = 0
	seals_earned = 0
	kills = 0
	bound_kills = 0
	took_damage_this_room = false
	weapon_upgrade = 0.0
	run_hp = -1.0
	rev_50_announced = false
	pools_available = ["michael", "gabriel", "raphael"]
	if Game.profile.get("uriel_unlocked", false):
		pools_available.append("uriel")
	rebuild_mods()
	if Game.upgrade_level("favor") > 0:
		var pool: Array = DataDB.blessings["pools"]["michael"]["blessings"]
		add_blessing(pool[randi() % pool.size()]["id"], true)

func end_run() -> void:
	active = false
	Game.profile["last_corruption"] = corruption
	Game.save()
	rebuild_mods()

# ---------------------------------------------------------------- modifiers

func mod(key: String) -> float:
	return float(_mods.get(key, 0.0))

func has_mod(key: String) -> bool:
	return mod(key) > 0.0

func rebuild_mods() -> void:
	_mods.clear()
	# Weapon aspect
	var aspect: String = Game.profile.get("aspect", "commission")
	var aspects: Dictionary = DataDB.weapons.get("aspects", {})
	if aspects.has(aspect):
		_accum(aspects[aspect].get("mods", {}))
	# Persistent upgrades
	for up_id in Game.profile.get("upgrades", {}):
		var lvl: int = Game.upgrade_level(up_id)
		var up: Dictionary = DataDB.upgrades.get(up_id, {})
		for i in lvl:
			_accum(up.get("mods_per_level", {}))
	# Run blessings + relics
	if active:
		for id in blessings:
			_accum(DataDB.blessing_by_id(id).get("mods", {}))
		for id in relics:
			_accum(DataDB.blessing_by_id(id).get("mods", {}))
		if weapon_upgrade > 0.0:
			_accum({"sword_dmg": weapon_upgrade})

func _accum(mods: Dictionary) -> void:
	for k in mods:
		_mods[k] = float(_mods.get(k, 0.0)) + float(mods[k])

# ---------------------------------------------------------------- pickups

func add_blessing(id: String, silent := false) -> void:
	blessings.append(id)
	var b := DataDB.blessing_by_id(id)
	if b.get("pool", "") == "forbidden":
		add_corruption(float(b.get("corruption", 0)))
	rebuild_mods()
	blessings_changed.emit()
	if not silent:
		var col := DataDB.pool_color(b.get("pool", ""))
		Game.toast("Blessing: " + str(b.get("name", id)), col)
		AudioMan.play("blessing")

func add_relic(id: String) -> void:
	relics.append(id)
	rebuild_mods()
	blessings_changed.emit()
	Game.toast("Relic: " + str(DataDB.blessing_by_id(id).get("name", id)), Color(0.7, 0.5, 0.9))
	AudioMan.play("blessing")

func add_weapon_upgrade(amount: float) -> void:
	weapon_upgrade += amount
	rebuild_mods()
	Game.toast("The Commission burns brighter. +%d%% sword damage." % int(amount * 100), Color(1, 0.6, 0.3))

# ---------------------------------------------------------------- meters

func add_corruption(v: float) -> void:
	if v > 0.0:
		v *= 1.0 - clampf(mod("corrupt_reduce"), 0.0, 0.9)
	var before := corruption
	corruption = clampf(corruption + v, 0.0, 100.0)
	if corruption >= 100.0 and before < 100.0:
		Game.profile["full_corruption"] = true
		Game.toast("The corruption is complete. Something else is keeping score now.", Color(0.8, 0.2, 0.3))
	elif corruption >= 50.0 and before < 50.0:
		Game.toast("Corruption thickens. The desert grows bolder against you.", Color(0.8, 0.3, 0.4))
		AudioMan.play("whisper")
	meters_changed.emit()

func add_revelation(v: float) -> void:
	if v > 0.0:
		v *= 1.0 + mod("rev_gain")
	var before := revelation
	revelation = clampf(revelation + v, 0.0, 100.0)
	if revelation >= 50.0 and before < 50.0 and not rev_50_announced:
		rev_50_announced = true
		Game.toast("Revelation: you see them as they are. +10% damage against the fallen.", Color(0.45, 0.75, 1.0))
		AudioMan.play("revelation")
	if revelation >= 90.0 and before < 90.0:
		CodexMan.unlock("final-revelation")
	meters_changed.emit()

func enemy_scale() -> Dictionary:
	var depth_mult := 1.0 + float(room_index) * 0.05
	var corrupt_mult := 1.2 if corruption >= 50.0 else 1.0
	return {"hp": depth_mult * corrupt_mult, "dmg": depth_mult * corrupt_mult}

func earn_seals(n: int) -> void:
	seals_earned += n
	Game.add_seals(n)
