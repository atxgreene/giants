extends Node
## Headless smoke test for CI. Runs as the main scene (CI temporarily points
## project.godot's main_scene here), exercises the data tables, the Run
## Director, save migration, and live enemy/player instantiation, then quits
## with code 0 (pass) or 1 (fail). Broken scripts fail at import; broken data,
## a softlockable route graph, or a broken save migration fail here.

var errors: Array = []

func _ready() -> void:
	await get_tree().process_frame
	print("== THE WATCHERS — CI smoke test ==")
	_test_data_loaded()
	_test_cross_references()
	_test_run_director()
	_test_save_migration()
	await _test_live_objects()
	if errors.is_empty():
		print("SMOKE TEST PASSED")
		get_tree().quit(0)
	else:
		printerr("SMOKE TEST FAILED with %d error(s):" % errors.size())
		for e in errors:
			printerr("  - " + e)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)

# --------------------------------------------------------------- data tables

func _test_data_loaded() -> void:
	_check(not DataDB.weapons.is_empty(), "weapons.json empty")
	_check(not DataDB.blessings.is_empty(), "blessings.json empty")
	_check(not DataDB.enemies.is_empty(), "enemies.json empty")
	_check(not DataDB.rooms.is_empty(), "rooms.json empty")
	_check(not DataDB.upgrades.is_empty(), "upgrades.json empty")
	_check(not DataDB.codex.is_empty(), "codex_entries.json empty")
	_check(not DataDB.dialogue.is_empty(), "dialogue.json empty")
	_check(not DataDB.run_routes.is_empty(), "run_routes.json empty")

func _test_cross_references() -> void:
	# Every enemy referenced by a room exists and has a subclass path.
	for t_id in DataDB.rooms.get("templates", {}):
		var t: Dictionary = DataDB.rooms["templates"][t_id]
		for wave in t.get("waves", []):
			for spec in wave:
				var etype := str(spec["type"])
				_check(DataDB.enemies.has(etype), "room %s references unknown enemy %s" % [t_id, etype])
				_check(EnemyBase.SUBCLASS_PATHS.has(etype), "enemy %s has no subclass path" % etype)
	# Every weapon aspect points at an existing weapon.
	for a_id in DataDB.weapons.get("aspects", {}):
		var w := str(DataDB.weapons["aspects"][a_id].get("weapon", ""))
		_check(DataDB.weapons.has(w), "aspect %s references unknown weapon %s" % [a_id, w])
	# Every route's room categories reference existing templates.
	var cats: Dictionary = DataDB.run_routes.get("categories", {})
	for c in cats:
		for tmpl in cats[c]:
			_check(DataDB.rooms["templates"].has(tmpl), "route category %s references unknown room %s" % [c, tmpl])
	# Corrupt variants exist.
	for base in DataDB.run_routes.get("corrupt_variants", {}):
		var variant := str(DataDB.run_routes["corrupt_variants"][base])
		_check(DataDB.rooms["templates"].has(variant), "corrupt variant %s missing" % variant)
	# Revelation events map to codex + dialogue.
	for ev in DataDB.run_routes.get("revelation_events", []):
		_check(DataDB.codex.has(ev), "revelation event %s has no codex entry" % ev)
		var key := "rev_" + str(ev).replace("-", "_")
		_check(not DataDB.dialogue_lines(key).is_empty(), "revelation event %s has no dialogue (%s)" % [ev, key])

# --------------------------------------------------------------- run director

func _test_run_director() -> void:
	for route_id in DataDB.run_routes.get("routes", {}):
		var d := RunDirector.new()
		d.generate(12345, route_id)
		_validate_plan(d, route_id)
		# Determinism: same seed → identical plan.
		var d2 := RunDirector.new()
		d2.generate(12345, route_id)
		_check(d.nodes == d2.nodes, "route %s not deterministic (nodes)" % route_id)
		_check(d.gate_plan == d2.gate_plan, "route %s not deterministic (gates)" % route_id)
	# Fallback plan (no data) must still complete.
	var fb := RunDirector.new()
	fb._fallback_plan()
	_check(fb.nodes.size() >= 3, "fallback plan too short")

func _validate_plan(d: RunDirector, route_id: String) -> void:
	var kinds: Array = []
	for n in d.nodes:
		_check(DataDB.rooms["templates"].has(str(n)), "route %s plans unknown room %s" % [route_id, n])
		kinds.append(str(DataDB.rooms["templates"][str(n)]["kind"]))
	_check("miniboss" in kinds, "route %s has no miniboss" % route_id)
	_check("boss" in kinds, "route %s has no boss" % route_id)
	_check(("vision" in kinds) or ("shrine" in kinds), "route %s has no codex/vision room" % route_id)
	# No softlock: every non-final node opens at least one gate.
	for i in d.nodes.size() - 1:
		var opts: Array = d.gate_options(i, false)
		_check(opts.size() >= 1, "route %s node %d has no exit gate" % [route_id, i])
	# Guaranteed blessing (first gate) and heal (after miniboss).
	_check("blessing" in d.gate_options(0, false), "route %s missing guaranteed blessing" % route_id)
	var heal_found := false
	for i in d.nodes.size():
		if "heal" in d.gate_plan[i]:
			heal_found = true
	_check(heal_found, "route %s missing guaranteed heal" % route_id)

# --------------------------------------------------------------- save migration

func _test_save_migration() -> void:
	# A pre-versioning (v0) save lacking weapon fields must migrate + repair.
	var old_v0 := {"seals": 42, "aspect": "michael", "aspects": ["commission", "michael"], "codex": ["michael"]}
	var migrated := SaveMan.migrate(old_v0.duplicate(true), 0)
	migrated = SaveMan.repair(migrated, Game.DEFAULT_PROFILE)
	_check(int(migrated.get("save_version", -1)) == SaveManager.CURRENT_SAVE_VERSION, "v0 save did not reach current version")
	_check(migrated.has("weapon"), "migrated save missing weapon")
	_check("flaming_sword" in migrated.get("weapons_unlocked", []), "migrated save missing weapon unlock")
	_check(int(migrated.get("seals", 0)) == 42, "migration lost seals")
	# A v1 save with an equipped aspect should carry it into the per-weapon map.
	var old_v1 := {"save_version": 1, "aspect": "uriel", "aspects": ["commission", "uriel"]}
	var m1 := SaveMan.migrate(old_v1.duplicate(true), 1)
	m1 = SaveMan.repair(m1, Game.DEFAULT_PROFILE)
	_check(str(m1.get("weapon_aspects", {}).get("flaming_sword", "")) == "uriel", "v1->v2 lost equipped aspect")

# --------------------------------------------------------------- live objects

func _test_live_objects() -> void:
	var world := Node2D.new()
	add_child(world)
	# Spawn one of every enemy type to exercise their scripts + combat.
	for etype in EnemyBase.SUBCLASS_PATHS:
		var e = EnemyBase.create(etype)
		e.position = Vector2(randf() * 200.0, randf() * 200.0)
		world.add_child(e)
	# Spawn the player and grant it damage against a simple enemy.
	var player := Player.new()
	world.add_child(player)
	var dummy_foe := EnemyBase.create("ash_thrall")
	dummy_foe.position = Vector2(60, 0)
	world.add_child(dummy_foe)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before: float = dummy_foe.hp
	dummy_foe.take_hit(9.0, player.global_position, 80.0, 1.0, {})
	_check(dummy_foe.hp < before, "enemy took no damage")
	# A binding seal + a censer cleanse zone should instantiate cleanly.
	BindingSeal.spawn(world, dummy_foe.global_position, {"radius": 80.0})
	GroundHazard.spawn(world, dummy_foe.global_position, {"kind": "cleanse", "friendly": true, "cleanse": true})
	await get_tree().physics_frame
	world.queue_free()
