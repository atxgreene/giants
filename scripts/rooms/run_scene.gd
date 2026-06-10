extends Node2D
class_name RunScene
## A full run through the Desert of Azazel. Semi-procedural sequence of
## room templates with Hades-style reward gates:
## start → combat → combat → elite/shrine → combat → vision → mini-boss
## → combat → boss. Owns the player, camera, HUD, fades, reward screens,
## the boss temptation, victory and death flow.

var player: Player
var cam: GameCamera
var hud: HUD
var room: RoomNode
var seq: Array = []
var idx := -1
var pending_reward := ""
var fade_rect: ColorRect
var transitioning := false
var run_over := false
var heal_drunk := false

func _ready() -> void:
	add_to_group("run")
	RunState.reset()
	Game.profile["runs"] = int(Game.profile.get("runs", 0)) + 1
	Game.save()
	seq = ["start", "arena_small", "forge_ambush",
		"elite_forge" if randf() < 0.6 else "relic_shrine",
		"bone_corridor", "vision_room", "miniboss_arena", "arena_wide", "boss_arena"]
	player = Player.new()
	player.died.connect(_on_player_died)
	cam = GameCamera.new()
	player.add_child(cam)
	FX.camera = cam
	hud = HUD.new()
	add_child(hud)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 80
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)
	add_child(fade_layer)
	AudioMan.music("desert")
	CodexMan.unlock("desert-of-azazel")
	CodexMan.unlock("watchers")
	_enter_room("")
	Game.toast("The Desert of Azazel. Walk as a Witness.", Color(0.92, 0.86, 0.7))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not run_over:
		toggle_pause()

func toggle_pause() -> void:
	if get_tree().paused:
		return # pause menu handles unpausing
	var pm := PauseMenu.new()
	add_child(pm)

# ------------------------------------------------------------- room flow

func _enter_room(reward_from_gate: String) -> void:
	idx += 1
	pending_reward = reward_from_gate
	transitioning = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.22)
	tw.tween_callback(_swap_room)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.3)
	tw.tween_callback(func(): transitioning = false)

func _swap_room() -> void:
	if player.get_parent():
		player.get_parent().remove_child(player)
	if is_instance_valid(room):
		room.queue_free()
	room = RoomNode.new()
	room.build(seq[idx])
	room.room_cleared.connect(_on_room_cleared)
	room.gate_entered.connect(_on_gate_entered)
	add_child(room)
	room.add_child(player)
	player.position = room.player_spawn()
	player.velocity = Vector2.ZERO
	FX.world = room
	cam.set_limits(room.bounds)
	cam.reset_smoothing()
	RunState.room_index = idx
	RunState.took_damage_this_room = false
	hud.set_room_label(str(room.template["name"]), idx, seq.size() - 1)
	hud.set_pending_reward(pending_reward)
	if seq[idx] == "boss_arena":
		AudioMan.music("boss")
		Game.toast("\"You call this judgment? I gave mankind the blade. You gave them silence.\"", Color(0.95, 0.8, 0.45))
	match room.kind:
		"start":
			room.force_clear()
		"shrine":
			room.add_interact_point(room.bounds.get_center(), "Commune at the shrine", "shrine", _shrine_relic)
		"vision":
			room.add_interact_point(room.bounds.get_center(), "Witness the dream", "vision", _vision_dream)
		_:
			room.start_room()

func _on_room_cleared() -> void:
	if room.kind == "combat" or room.kind == "miniboss":
		RunState.rooms_cleared += 1
		RunState.earn_seals(randi_range(2, 4))
		if not RunState.took_damage_this_room:
			RunState.add_revelation(8.0)
			Game.toast("Untouched. Revelation stirs.", Color(0.45, 0.75, 1.0))
		var room_heal := RunState.mod("room_heal")
		if room_heal > 0.0:
			player.heal(room_heal)
	_grant_pending_reward()
	_open_exit_gates()

func _on_gate_entered(reward: String) -> void:
	if transitioning or run_over:
		return
	var carried := reward
	if reward in ["advance", "miniboss", "boss"]:
		carried = ""
	RunState.run_hp = player.hp
	_enter_room(carried)

func _open_exit_gates() -> void:
	var next := idx + 1
	if next >= seq.size():
		return
	var next_kind := str(DataDB.rooms["templates"][seq[next]]["kind"])
	var options: Array = []
	match next_kind:
		"miniboss":
			options = ["miniboss"]
		"boss":
			options = ["boss"]
		"shrine", "vision":
			options = ["advance"]
		_:
			if idx == 0:
				options = ["blessing"]
			elif seq[idx] == "miniboss_arena":
				options = ["heal", _random_reward(["heal"])]
			else:
				var first := _random_reward([])
				options = [first, _random_reward([first])]
				if RunState.has_mod("extra_choice"):
					options.append(_random_reward(options))
	room.open_gates(options)

func _random_reward(exclude: Array) -> String:
	var weighted := {
		"blessing": 4, "currency": 2, "heal": 2, "codex": 2,
		"relic": 2, "weapon": 1, "forbidden": 1
	}
	var pool: Array = []
	for k in weighted:
		if k in exclude:
			continue
		for i in int(weighted[k]):
			pool.append(k)
	return pool[randi() % pool.size()]

# ------------------------------------------------------------- rewards

func _grant_pending_reward() -> void:
	var r := pending_reward
	pending_reward = ""
	hud.set_pending_reward("")
	match r:
		"blessing":
			_offer_blessings()
		"forbidden":
			_offer_forbidden()
		"relic":
			_offer_relics()
		"heal":
			player.heal(player.max_hp * 0.3)
			Game.toast("The fountain remembers clean water.", Color(0.5, 0.9, 0.6))
			if not heal_drunk:
				heal_drunk = true
				CodexMan.unlock("raphael")
		"currency":
			RunState.earn_seals(15)
			Game.toast("+15 Seals of Witness", Color(0.8, 0.6, 0.3))
			AudioMan.play("pickup")
		"codex":
			CodexMan.unlock_random_fragment()
		"weapon":
			RunState.add_weapon_upgrade(0.10)
			AudioMan.play("fire")

func _offer_blessings() -> void:
	var pool_key: String = RunState.pools_available[randi() % RunState.pools_available.size()]
	var pool: Dictionary = DataDB.blessings["pools"][pool_key]
	var candidates: Array = []
	for b in pool["blessings"]:
		if not (b["id"] in RunState.blessings):
			candidates.append(b)
	if candidates.is_empty():
		RunState.earn_seals(10)
		Game.toast(str(pool["name"]) + " has nothing left to give — +10 Seals instead.", Color(0.8, 0.6, 0.3))
		return
	candidates.shuffle()
	var cards: Array = []
	for b in candidates.slice(0, 3):
		cards.append({"id": b["id"], "name": b["name"], "desc": b["desc"],
			"color": Color(str(pool["color"]))})
	var rs := RewardScreen.new()
	rs.title_text = "BLESSING OF " + str(pool["name"]).to_upper()
	rs.subtitle_text = str(pool["title"])
	rs.cards = cards
	rs.chosen.connect(func(id: String):
		if id != "":
			RunState.add_blessing(id)
			player.refresh_stats())
	add_child(rs)

func _offer_forbidden() -> void:
	var cards: Array = []
	for b in DataDB.blessings["forbidden"]:
		if not (b["id"] in RunState.blessings):
			cards.append({"id": b["id"], "name": b["name"], "desc": b["desc"],
				"color": Color(0.85, 0.2, 0.25)})
	var rs := RewardScreen.new()
	rs.title_text = "FORBIDDEN KNOWLEDGE"
	rs.subtitle_text = "It will work. That is the terrible thing about it."
	rs.cards = cards
	rs.allow_refuse = true
	rs.refuse_text = "Refuse (+10 Revelation)"
	rs.chosen.connect(func(id: String):
		if id == "":
			RunState.add_revelation(10.0)
			Game.toast("Refused. The desert is quieter for a moment.", Color(0.45, 0.75, 1.0))
		else:
			RunState.add_blessing(id)
			player.refresh_stats()
		CodexMan.unlock("forbidden-knowledge"))
	add_child(rs)

func _offer_relics() -> void:
	var candidates: Array = []
	for rel in DataDB.blessings["relics"]:
		if not (rel["id"] in RunState.relics):
			candidates.append(rel)
	if candidates.is_empty():
		RunState.earn_seals(12)
		Game.toast("No relics remain in this desert. +12 Seals.", Color(0.8, 0.6, 0.3))
		return
	candidates.shuffle()
	var cards: Array = []
	for rel in candidates.slice(0, 3):
		cards.append({"id": rel["id"], "name": rel["name"], "desc": rel["desc"],
			"color": Color(0.7, 0.5, 0.9)})
	var rs := RewardScreen.new()
	rs.title_text = "RELIC"
	rs.subtitle_text = "Carried by witnesses before you."
	rs.cards = cards
	rs.chosen.connect(func(id: String):
		if id != "":
			RunState.add_relic(id)
			player.refresh_stats())
	add_child(rs)

func _shrine_relic() -> void:
	_offer_relics()
	room.force_clear()

func _vision_dream() -> void:
	var db := DialogueBox.new()
	add_child(db)
	db.play(DataDB.dialogue_lines("vision"), func():
		CodexMan.unlock("giants-dream")
		RunState.add_revelation(10.0)
		room.force_clear())

# ------------------------------------------------------------- boss flow

func boss_temptation(boss: FirstBlade) -> void:
	var cs := ChoiceScreen.new()
	cs.title_text = "THE TEMPTATION OF THE FIRST BLADE"
	cs.body_text = "\"I was the first thing he ever forged, Witness. Before swords had names, I was the lesson. Let me teach you one stroke of it — one — and you will never lose again.\""
	cs.accept_text = "ACCEPT — Edge of Azazel\n+10% sword damage, permanently.\n+25 Corruption. Michael will know."
	cs.refuse_text = "REFUSE — Seal of Michael\n+10 Revelation. A codex page turns.\nThe Blade enters its desperate hour."
	cs.decided.connect(func(accepted: bool):
		boss.apply_temptation(accepted))
	add_child(cs)

func on_boss_defeated() -> void:
	if run_over:
		return
	run_over = true
	Game.profile["boss_defeated"] = true
	Game.profile["uriel_unlocked"] = true
	Game.profile["wins"] = int(Game.profile.get("wins", 0)) + 1
	Game.save()
	CodexMan.unlock("teaching-of-weapons")
	CodexMan.unlock("uriel")
	AudioMan.stop_music()
	AudioMan.play("revelation")
	FX.slowmo(0.25, 1.0)
	var t := get_tree().create_timer(1.6, true, false, true)
	t.timeout.connect(func():
		RunState.end_run()
		Game.goto("victory"))

func _on_player_died() -> void:
	if run_over:
		return
	run_over = true
	Game.profile["deaths"] = int(Game.profile.get("deaths", 0)) + 1
	Game.save()
	AudioMan.stop_music()
	AudioMan.play("sting_death")
	var t := get_tree().create_timer(1.4, true, false, true)
	t.timeout.connect(func():
		RunState.end_run()
		Game.goto("gameover"))
