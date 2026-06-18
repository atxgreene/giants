extends RefCounted
class_name RunDirector
## Data-driven run graph. Replaces the old fixed room sequence with a seeded,
## route-flavoured plan. The Run Director decides:
##   - which room templates fill the variable slots (weighted, no-repeat)
##   - which reward gates each cleared room opens (weighted, route-biased)
##   - corrupted room variants once Corruption is high
##   - hidden Revelation rooms once Revelation is high
##   - bad-luck protection so dead reward pools are not offered repeatedly
##
## Determinism: the whole plan (room order + reward-type rolls) is generated
## from a single integer seed via a private RandomNumberGenerator, so the same
## seed always produces the same route and the same reward rolls. Dynamic
## swaps (corruption variants, revelation rooms) are applied at play time but
## are still a pure function of (plan + meters), so they stay reproducible.

var seed_value: int = 0
var route_id := "pilgrimage"
var route: Dictionary = {}
var data: Dictionary = {}

# Planned room template ids (mutable: revelation rooms can be spliced in).
var nodes: Array = []
# Planned gate options per node index (the gate opened when node i clears).
var gate_plan: Array = []

var _rng := RandomNumberGenerator.new()
var _revelation_room_used := false
var _bad_luck := {}     # reward_type -> consecutive dead offers

# ---------------------------------------------------------------- generation

func generate(seed_input: int = 0, route_input := "") -> void:
	data = DataDB.run_routes
	if data.is_empty():
		_fallback_plan()
		return
	seed_value = seed_input if seed_input != 0 else _make_seed()
	_rng.seed = seed_value
	var routes: Dictionary = data.get("routes", {})
	route_id = route_input
	if route_id == "" or not routes.has(route_id):
		# Pick a route deterministically from the seed (the start gate lets the
		# player re-choose; this is the default the seed lands on).
		route_id = _weighted_route()
	route = routes.get(route_id, {})
	_build_nodes()
	_build_gates()

func _make_seed() -> int:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r.randi() & 0x7FFFFFFF

func _weighted_route() -> String:
	var routes: Dictionary = data.get("routes", {})
	var keys: Array = routes.keys()
	if keys.is_empty():
		return "pilgrimage"
	return str(keys[_rng.randi() % keys.size()])

func _build_nodes() -> void:
	var st: Dictionary = data.get("structure", {})
	var length := int(st.get("length", 9))
	var mb := int(st.get("miniboss_index", 6))
	var pre_boss := int(st.get("pre_boss_combat_index", 7))
	var boss := int(st.get("boss_index", 8))
	nodes.resize(length)
	nodes[0] = "start"
	nodes[mb] = "miniboss_arena"
	nodes[pre_boss] = _pick_from_category("combat", "")
	nodes[boss] = "boss_arena"
	var slots: Array = st.get("variable_slots", [1, 2, 3, 4, 5])
	# Sample a category per slot, weighted by the route, never repeating the
	# exact template back-to-back.
	for i in slots.size():
		var slot := int(slots[i])
		var prev := str(nodes[slot - 1]) if slot - 1 >= 0 and nodes[slot - 1] != null else ""
		var category := _pick_category()
		nodes[slot] = _pick_from_category(category, prev)
	_enforce_guarantees(slots)

func _pick_category() -> String:
	var weights: Dictionary = route.get("slot_weights", {"combat": 5})
	return _weighted_key(weights)

func _pick_from_category(category: String, avoid: String) -> String:
	var cats: Dictionary = data.get("categories", {})
	var pool: Array = cats.get(category, cats.get("combat", ["arena_small"]))
	if pool.is_empty():
		return "arena_small"
	var choices: Array = pool.duplicate()
	if choices.size() > 1 and avoid in choices:
		choices.erase(avoid)
	return str(choices[_rng.randi() % choices.size()])

func _enforce_guarantees(slots: Array) -> void:
	# Guarantee at least one codex/vision opportunity (shrine or vision room).
	if not _slots_have_kind(slots, ["shrine", "vision"]):
		var slot := int(slots[_rng.randi() % slots.size()])
		nodes[slot] = _pick_from_category("vision", "")
	# Guarantee the route's minimum elite count.
	var min_elite := int(route.get("min_elite", 0))
	var elites := _count_category(slots, "elite")
	while elites < min_elite:
		var candidates: Array = []
		for s in slots:
			if _category_of(str(nodes[int(s)])) == "combat":
				candidates.append(int(s))
		if candidates.is_empty():
			break
		var slot: int = candidates[_rng.randi() % candidates.size()]
		nodes[slot] = _pick_from_category("elite", "")
		elites += 1

func _slots_have_kind(slots: Array, kinds: Array) -> bool:
	for s in slots:
		var k := _kind_of(str(nodes[int(s)]))
		if k in kinds:
			return true
	return false

func _count_category(slots: Array, category: String) -> int:
	var n := 0
	for s in slots:
		if _category_of(str(nodes[int(s)])) == category:
			n += 1
	return n

func _category_of(template_id: String) -> String:
	var cats: Dictionary = data.get("categories", {})
	for c in cats:
		if template_id in cats[c]:
			return str(c)
	return _kind_of(template_id)

func _kind_of(template_id: String) -> String:
	var t: Dictionary = DataDB.rooms.get("templates", {}).get(template_id, {})
	return str(t.get("kind", "combat"))

# ---------------------------------------------------------------- gate plan

func _build_gates() -> void:
	gate_plan.resize(nodes.size())
	for i in nodes.size():
		gate_plan[i] = _roll_gate(i)

func _roll_gate(idx: int) -> Array:
	var next := idx + 1
	if next >= nodes.size():
		return []
	var next_kind := _kind_of(str(nodes[next]))
	match next_kind:
		"miniboss":
			return ["miniboss"]
		"boss":
			return ["boss"]
		"shrine", "vision":
			return ["advance"]
	if idx == 0:
		return ["blessing"]
	if _kind_of(str(nodes[idx])) == "miniboss":
		return ["heal", _roll_reward(["heal"])]
	var first := _roll_reward([])
	return [first, _roll_reward([first])]

func _roll_reward(exclude: Array) -> String:
	var weights: Dictionary = route.get("reward_weights", {})
	if weights.is_empty():
		weights = {"blessing": 4, "currency": 2, "heal": 2, "codex": 2, "relic": 2, "weapon": 1, "forbidden": 1}
	var filtered := {}
	for k in weights:
		if not (k in exclude) and int(weights[k]) > 0:
			filtered[k] = weights[k]
	if filtered.is_empty():
		return "currency"
	return _weighted_key(filtered)

# ---------------------------------------------------------------- play-time API

func gate_options(idx: int, extra_choice: bool) -> Array:
	## The live gate list, with bad-luck protection, an optional extra choice,
	## and a hidden Revelation door when Revelation is high.
	if idx < 0 or idx >= gate_plan.size():
		return []
	var opts: Array = (gate_plan[idx] as Array).duplicate()
	# Only reroute "reward" gates; locks/advance/blessing-intro pass through.
	var is_reward_gate := opts.size() > 0 and not (opts[0] in ["miniboss", "boss", "advance"])
	if is_reward_gate:
		for i in opts.size():
			opts[i] = _bad_luck_protect(str(opts[i]), opts)
		if extra_choice and opts.size() < 3:
			opts.append(_roll_reward(opts))
		if RunState.revelation >= 80.0 and not _revelation_room_used:
			opts.append("revelation")
	return opts

func _bad_luck_protect(reward_type: String, current: Array) -> String:
	## If a reward pool is exhausted, swap it for something the player can use,
	## and remember it so the same dead pool is not handed out again next time.
	if _pool_alive(reward_type):
		_bad_luck[reward_type] = 0
		return reward_type
	_bad_luck[reward_type] = int(_bad_luck.get(reward_type, 0)) + 1
	for alt in ["heal", "currency", "codex", "weapon"]:
		if alt != reward_type and not (alt in current) and _pool_alive(alt):
			return alt
	return "currency"

func _pool_alive(reward_type: String) -> bool:
	match reward_type:
		"blessing":
			for pool_key in RunState.pools_available:
				var pool: Dictionary = DataDB.blessings.get("pools", {}).get(pool_key, {})
				for b in pool.get("blessings", []):
					if not (b["id"] in RunState.blessings):
						return true
			return false
		"relic":
			for rel in DataDB.blessings.get("relics", []):
				if not (rel["id"] in RunState.relics):
					return true
			return false
		"forbidden":
			for b in DataDB.blessings.get("forbidden", []):
				if not (b["id"] in RunState.blessings):
					return true
			return false
		_:
			return true

func template_for(idx: int) -> String:
	## The room actually built for node idx, applying corrupted variants once
	## Corruption is high enough.
	if idx < 0 or idx >= nodes.size():
		return "arena_small"
	var base := str(nodes[idx])
	if RunState.corruption >= 50.0:
		var variants: Dictionary = data.get("corrupt_variants", {})
		if variants.has(base):
			return str(variants[base])
	return base

func insert_revelation_room(after_idx: int) -> void:
	## Splice a hidden Revelation room into the plan right after `after_idx`.
	_revelation_room_used = true
	var rev_room := str(data.get("revelation_room", "revelation_chamber"))
	nodes.insert(after_idx + 1, rev_room)
	gate_plan.insert(after_idx + 1, ["advance"])

func pick_revelation_event() -> String:
	var events: Array = data.get("revelation_events", [])
	if events.is_empty():
		return ""
	return str(events[_rng.randi() % events.size()])

func pick_blessing_pool() -> String:
	## Route-biased blessing pool selection among the pools currently available.
	var bias: Dictionary = route.get("blessing_bias", {})
	var weights := {}
	for pool_key in RunState.pools_available:
		weights[pool_key] = int(bias.get(pool_key, 1))
	if weights.is_empty():
		return RunState.pools_available[0] if not RunState.pools_available.is_empty() else "michael"
	return _weighted_key(weights)

func enemy_scale_bonus() -> float:
	return float(route.get("enemy_bonus", 0.0))

func route_name() -> String:
	return str(route.get("name", "The Pilgrim Road"))

func route_color() -> Color:
	return Color(str(route.get("color", "#e8d8a8")))

func route_gate_label() -> String:
	return str(route.get("gate_label", route_name()))

func seed_string() -> String:
	## Short, readable, shareable seed (base-36, upper case).
	var n := absi(seed_value)
	if n == 0:
		return "AZAZEL"
	const DIGITS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var s := ""
	while n > 0:
		s = DIGITS[n % 36] + s
		n /= 36
	return s

static func parse_seed(text: String) -> int:
	## Inverse of seed_string for "enter a seed" support.
	var t := text.strip_edges().to_upper()
	if t == "" or t == "AZAZEL":
		return 0
	const DIGITS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var n := 0
	for ch in t:
		var d := DIGITS.find(ch)
		if d < 0:
			return int(t.hash() & 0x7FFFFFFF)
		n = n * 36 + d
	return n

# ---------------------------------------------------------------- helpers

func _weighted_key(weights: Dictionary) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	if total <= 0:
		return str(weights.keys()[0]) if not weights.is_empty() else ""
	var roll := _rng.randi() % total
	for k in weights:
		roll -= int(weights[k])
		if roll < 0:
			return str(k)
	return str(weights.keys()[0])

func _fallback_plan() -> void:
	# If route data is missing, reproduce the original hand-authored sequence so
	# the game still completes a full run hub-to-boss.
	nodes = ["start", "arena_small", "forge_ambush", "elite_forge",
		"bone_corridor", "vision_room", "miniboss_arena", "arena_wide", "boss_arena"]
	gate_plan = [
		["blessing"], ["currency", "heal"], ["blessing", "relic"], ["advance"],
		["advance"], ["miniboss"], ["heal", "currency"], ["boss"], []]
	route = {"name": "The Pilgrim Road", "color": "#e8d8a8",
		"gate_label": "THE PILGRIM ROAD", "blessing_bias": {}}
	route_id = "pilgrimage"
