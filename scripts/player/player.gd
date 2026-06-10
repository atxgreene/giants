extends CharacterBody2D
class_name Player
## The Appointed Witness. Movement, dash with i-frames, 3-hit light combo,
## heavy flame arc, dash slash, crescent of holy fire (special), Binding Seal,
## and Michael's Verdict (ultimate). All damage flows through calc_damage()
## so blessings, relics, aspects, and upgrades stack data-driven.

signal died
signal hp_changed

const BASE_SPEED := 278.0
const DASH_SPEED := 770.0
const DASH_TIME := 0.16
const BASE_DASH_CD := 0.95

var weapon: Dictionary = {}
var max_hp := 100.0
var hp := 100.0
var dead := false
var input_locked := false

var aim_dir := Vector2.RIGHT
var move_dir := Vector2.ZERO
var using_controller := false
var facing := 1.0

var dashing := false
var dash_t := 0.0
var dash_dir := Vector2.RIGHT
var dash_cd_t := 0.0
var post_dash_t := 0.0
var iframes := 0.0
var trail_tick := 0.0

var state := "free"          # free | attack
var atk: Dictionary = {}
var atk_phase := ""          # windup | recover
var atk_t := 0.0
var atk_dir := Vector2.RIGHT
var atk_is_heavy := false
var combo_idx := 0
var combo_t := 0.0
var queued := ""

var special_cd_t := 0.0
var seal_cd_t := 0.0
var ult_charge := 0.0
var slowmo_cd_t := 0.0
var hurt_flash := 0.0
var anim_t := 0.0
var swing_vis := 0.0         # 0..1 visual swing progress
var ghost_tick := 0.0        # dash afterimage spawner
var trail: Array = []        # sword trail ribbon: [{p: Vector2, t: float}]

func _ready() -> void:
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1 | 2
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 11.0
	cs.shape = sh
	add_child(cs)
	weapon = DataDB.weapons["flaming_sword"]
	refresh_stats()
	if RunState.active and RunState.run_hp > 0.0:
		hp = minf(RunState.run_hp, max_hp)
	else:
		hp = max_hp
	hp_changed.emit()

func refresh_stats() -> void:
	max_hp = 100.0 + RunState.mod("max_hp")
	hp = minf(hp, max_hp)
	hp_changed.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		using_controller = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		using_controller = false
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		using_controller = false
		# Basic touch-to-mouse simulation for web/mobile
		if event is InputEventScreenTouch:
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = MOUSE_BUTTON_LEFT
			mouse_event.pressed = event.pressed
			mouse_event.position = event.position
			mouse_event.global_position = event.position
			Input.parse_input_event(mouse_event)
		elif event is InputEventScreenDrag:
			var mouse_motion := InputEventMouseMotion.new()
			mouse_motion.position = event.position
			mouse_motion.global_position = event.position
			mouse_motion.relative = event.relative
			Input.parse_input_event(mouse_motion)

func _physics_process(delta: float) -> void:
	anim_t += delta
	queue_redraw()
	_tick_timers(delta)
	if dead:
		velocity = Vector2.ZERO
		return
	_update_aim()
	if not input_locked:
		_read_combat_input()
	_update_attack(delta)
	_update_movement(delta)
	move_and_slide()
	if dashing:
		ghost_tick -= delta
		if ghost_tick <= 0.0:
			ghost_tick = 0.035
			FX.ghost(global_position, facing,
				Color(1.0, 0.6, 0.25) if RunState.has_mod("flame_trail") else Color(0.5, 0.6, 0.9))
		if RunState.has_mod("flame_trail"):
			trail_tick -= delta
			if trail_tick <= 0.0:
				trail_tick = 0.045
				GroundHazard.spawn(get_parent(), global_position,
					{"kind": "pool", "radius": 26.0, "active": 1.4, "dps": 14.0,
					 "friendly": true, "color": Color(1.0, 0.55, 0.15)})
	# sword trail ribbon
	if swing_vis > 0.0 or dashing:
		trail.append({"p": _sword_tip_global(), "t": 0.18})
	for seg in trail:
		seg["t"] -= delta
	while trail.size() > 0 and float(trail[0]["t"]) <= 0.0:
		trail.pop_front()
	if trail.size() > 16:
		trail.pop_front()

func _tick_timers(delta: float) -> void:
	dash_cd_t = maxf(dash_cd_t - delta, 0.0)
	post_dash_t = maxf(post_dash_t - delta, 0.0)
	iframes = maxf(iframes - delta, 0.0)
	special_cd_t = maxf(special_cd_t - delta, 0.0)
	seal_cd_t = maxf(seal_cd_t - delta, 0.0)
	slowmo_cd_t = maxf(slowmo_cd_t - delta, 0.0)
	hurt_flash = maxf(hurt_flash - delta, 0.0)
	combo_t = maxf(combo_t - delta, 0.0)
	if combo_t <= 0.0 and state != "attack":
		combo_idx = 0
	if swing_vis > 0.0:
		swing_vis = maxf(swing_vis - delta * 6.0, 0.0)
	if dashing:
		dash_t -= delta
		if dash_t <= 0.0:
			dashing = false
			post_dash_t = 0.28

func _update_aim() -> void:
	if using_controller:
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > 0.3:
			aim_dir = stick.normalized()
		elif move_dir.length() > 0.1:
			aim_dir = move_dir.normalized()
	else:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 4.0:
			aim_dir = to_mouse.normalized()
	facing = 1.0 if aim_dir.x >= 0.0 else -1.0

func _read_combat_input() -> void:
	if Input.is_action_just_pressed("attack"):
		_try_attack("light")
	elif Input.is_action_just_pressed("attack_heavy"):
		_try_attack("heavy")
	if Input.is_action_just_pressed("dash"):
		_try_dash()
	if Input.is_action_just_pressed("special"):
		_try_special()
	if Input.is_action_just_pressed("seal"):
		_try_seal()
	if Input.is_action_just_pressed("ultimate"):
		_try_ultimate()
	if Input.is_action_just_pressed("interact"):
		_try_interact()

func _try_interact() -> void:
	var best = null
	var best_d := 70.0
	for ip in get_tree().get_nodes_in_group("interact"):
		if not is_instance_valid(ip):
			continue
		var d: float = ip.global_position.distance_to(global_position)
		if d < best_d and str(ip.call("get_prompt")) != "":
			best_d = d
			best = ip
	if best != null:
		best.call("try_interact", self)

func _update_movement(delta: float) -> void:
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down") if not input_locked else Vector2.ZERO
	if dashing:
		velocity = dash_dir * DASH_SPEED
	elif state == "attack":
		velocity = velocity.move_toward(move_dir * BASE_SPEED * 0.15, 2600.0 * delta)
	else:
		velocity = move_dir * BASE_SPEED

# ------------------------------------------------------------------ attacks

func _try_attack(kind: String) -> void:
	if state == "attack":
		if atk_phase == "recover":
			queued = kind
		return
	_start_attack(kind)

func _start_attack(kind: String) -> void:
	var move: Dictionary
	atk_is_heavy = kind == "heavy"
	if atk_is_heavy:
		move = weapon["heavy"]
	elif post_dash_t > 0.0:
		move = weapon["dash_slash"]
	else:
		move = weapon["light"][combo_idx]
	atk = move
	atk_dir = aim_dir
	state = "attack"
	atk_phase = "windup"
	atk_t = float(move["windup"])
	AudioMan.play("swing")

func _update_attack(delta: float) -> void:
	if state != "attack":
		return
	atk_t -= delta
	if atk_t > 0.0:
		return
	if atk_phase == "windup":
		_strike()
		atk_phase = "recover"
		atk_t = float(atk["recover"])
	else:
		state = "free"
		if queued != "":
			var q := queued
			queued = ""
			_start_attack(q)

func _strike() -> void:
	swing_vis = 1.0
	var reach := float(atk["range"])
	var arc := float(atk["arc"])
	var dmg := calc_damage(float(atk["dmg"]))
	var opts := hit_opts(atk)
	var stagger := float(atk["stagger"]) * (1.0 + RunState.mod("stagger_mult"))
	var hits := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("dead"):
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() - float(e.get("hit_radius")) <= reach:
			var diff := absf(angle_difference(atk_dir.angle(), to.angle()))
			if diff <= deg_to_rad(arc * 0.5) or to.length() < 30.0:
				e.call("take_hit", dmg, global_position, float(atk["kb"]), stagger, opts)
				on_dealt(dmg, e)
				hits += 1
	var col := Color(1.0, 0.72, 0.3) if not atk_is_heavy else Color(1.0, 0.5, 0.15)
	FX.slash(global_position, atk_dir, reach, arc, col)
	if hits > 0:
		AudioMan.play("hit_heavy" if atk_is_heavy else "hit")
		FX.hitstop(0.07 if atk_is_heavy else 0.045)
		FX.shake(0.35 if atk_is_heavy else 0.2)
	if not atk_is_heavy and post_dash_t <= 0.0:
		combo_idx = (combo_idx + 1) % 3
		combo_t = 0.95
	else:
		combo_idx = 0

func _try_dash() -> void:
	if dashing or dash_cd_t > 0.0:
		return
	dashing = true
	dash_t = DASH_TIME
	dash_cd_t = BASE_DASH_CD * (1.0 + RunState.mod("dash_cd"))
	dash_dir = move_dir.normalized() if move_dir.length() > 0.1 else aim_dir
	iframes = maxf(iframes, DASH_TIME + 0.05)
	trail_tick = 0.0
	AudioMan.play("dash")
	FX.burst(global_position, Color(0.9, 0.85, 0.7, 0.7), 8, 90.0, 0.3)
	if RunState.has_mod("dash_spark"):
		var dmg := calc_damage(9.0)
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.get("dead") and global_position.distance_to(e.global_position) < 80.0:
				e.call("take_hit", dmg, global_position, 160.0, 1.2, hit_opts({}))
				on_dealt(dmg, e)
		FX.ring(global_position, Color(0.95, 0.85, 0.5), 20.0, 80.0, 0.25)

func _try_special() -> void:
	if special_cd_t > 0.0 or state == "attack":
		return
	special_cd_t = float(weapon["special"]["cd"])
	_fire_crescent(aim_dir)
	if RunState.has_mod("extra_projectile"):
		_fire_crescent(aim_dir.rotated(0.22))
	AudioMan.play("fire")
	FX.shake(0.12)

func _fire_crescent(dir: Vector2) -> void:
	var sp: Dictionary = weapon["special"]
	Projectile.spawn(get_parent(), global_position + dir * 24.0, dir, {
		"kind": "crescent",
		"dmg": calc_damage(float(sp["dmg"])),
		"speed": float(sp["speed"]),
		"radius": float(sp["radius"]),
		"life": float(sp["life"]),
		"color": Color(1.0, 0.75, 0.3),
		"friendly": true,
		"pierce": RunState.has_mod("special_pierce"),
		"split": RunState.has_mod("special_split"),
		"mark": RunState.has_mod("mark_on_special"),
		"kb": 140.0, "stagger": 1.2})

func _try_seal() -> void:
	if seal_cd_t > 0.0:
		return
	var cfg: Dictionary = weapon["seal"]
	seal_cd_t = float(cfg["cd"])
	var cast_range := float(cfg["cast_range"])
	var target := global_position + aim_dir * minf(cast_range,
		global_position.distance_to(get_global_mouse_position()) if not using_controller else cast_range * 0.6)
	BindingSeal.spawn(get_parent(), target, cfg)

func _try_ultimate() -> void:
	if ult_charge < 100.0:
		AudioMan.play("ui")
		return
	ult_charge = 0.0
	var cfg: Dictionary = weapon["ult"]
	var dmg := calc_damage(float(cfg["dmg"]) * (1.0 + RunState.mod("ult_dmg")))
	var beam_dmg := calc_damage(float(cfg["beam_dmg"]) * (1.0 + RunState.mod("ult_dmg")))
	var radius := float(cfg["radius"])
	var beam_len := float(cfg["beam_len"])
	var beam_w := float(cfg["beam_w"])
	var opts := hit_opts({})
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("dead"):
			continue
		var to: Vector2 = e.global_position - global_position
		var total := 0.0
		if to.length() <= radius + float(e.get("hit_radius")):
			total += dmg
		var along := to.dot(atk_dir if state == "attack" else aim_dir)
		var across := absf(to.cross(aim_dir))
		if along > 0.0 and along < beam_len and across < beam_w * 0.5:
			total += beam_dmg
		if total > 0.0:
			e.call("take_hit", total, global_position, 380.0, 6.0, opts)
			on_dealt(total, e)
	AudioMan.play("ult")
	FX.ring(global_position, Color(1.0, 0.9, 0.5), 40.0, radius, 0.5)
	FX.ring(global_position, Color(0.6, 0.8, 1.0), 20.0, radius * 0.7, 0.4)
	FX.slash(global_position, aim_dir, beam_len * 0.8, 18.0, Color(1.0, 0.95, 0.7))
	FX.flash_screen(Color(1.0, 0.95, 0.8, 0.3), 0.3)
	FX.hitstop(0.1, 0.04)
	FX.shake(0.8)

# ------------------------------------------------------------------ damage

func calc_damage(base: float) -> float:
	var m := 1.0 + RunState.mod("dmg_mult") + RunState.mod("sword_dmg")
	if Game.profile.get("edge_of_azazel", false):
		m += 0.10
	if RunState.mod("judgment") > 0.0 and hp < max_hp * 0.35:
		m += RunState.mod("judgment")
	if RunState.active and RunState.revelation >= 50.0:
		m += 0.10
	return base * m

func hit_opts(_move: Dictionary) -> Dictionary:
	return {
		"burn": RunState.has_mod("burn_on_hit"),
		"armored_bonus": RunState.mod("armored_bonus"),
		"mark": false
	}

func on_dealt(dmg: float, _enemy) -> void:
	ult_charge = clampf(ult_charge + dmg * 0.42 * (1.0 + RunState.mod("ult_charge_mult")), 0.0, 100.0)
	var leech := RunState.mod("lifesteal")
	if leech > 0.0:
		heal(dmg * leech, true)

func take_hit(dmg: float, from_pos: Vector2) -> void:
	if dead:
		return
	if iframes > 0.0 or dashing:
		if RunState.has_mod("near_dodge_slow") and slowmo_cd_t <= 0.0 and dashing:
			slowmo_cd_t = 6.0
			FX.slowmo(0.35, 0.55)
		return
	if RunState.active and RunState.corruption >= 50.0:
		dmg *= 1.15
	hp -= dmg
	RunState.took_damage_this_room = true
	iframes = 0.55
	hurt_flash = 0.25
	velocity += (global_position - from_pos).normalized() * 180.0
	AudioMan.play("hurt")
	FX.shake(0.4)
	FX.burst(global_position, Color(0.85, 0.2, 0.2), 10, 150.0, 0.4)
	FX.hitstop(0.05, 0.1)
	hp_changed.emit()
	if hp <= 0.0:
		_die()

func take_dot(dmg: float) -> void:
	if dead or RunState.has_mod("dot_immune"):
		return
	hp -= dmg
	RunState.took_damage_this_room = true
	hurt_flash = 0.15
	hp_changed.emit()
	if hp <= 0.0:
		_die()

func heal(amount: float, silent := false) -> void:
	if dead:
		return
	var before := hp
	hp = minf(hp + amount, max_hp)
	if hp > before and not silent:
		FX.burst(global_position, Color(0.5, 0.9, 0.6), 10, 100.0, 0.5)
		AudioMan.play("pickup")
	hp_changed.emit()

func _die() -> void:
	dead = true
	hp = 0.0
	hp_changed.emit()
	AudioMan.play("death")
	FX.burst(global_position, Color(0.9, 0.8, 0.5), 30, 240.0, 0.8)
	FX.shake(1.0)
	died.emit()

# ------------------------------------------------------------------ drawing

func _sword_angle() -> float:
	var a := aim_dir.angle()
	if swing_vis > 0.0:
		a += (1.0 - swing_vis) * 2.4 - 1.2
	return a

func _sword_tip_global() -> Vector2:
	var bob := _bob()
	var hand := Vector2(12 * facing, -10 + bob)
	return global_position + hand + Vector2.from_angle(_sword_angle()) * 34.0

func _bob() -> float:
	return sin(anim_t * 9.0) * (1.8 if velocity.length() > 20.0 else 0.6)

func _draw() -> void:
	Painter.shadow(self, 13.0, 1.8, 0.34)
	if dead:
		draw_circle(Vector2(0, 4), 10.0, Color(0.4, 0.35, 0.3, 0.6))
		draw_line(Vector2(-8, 2), Vector2(14, -4), Color(0.6, 0.5, 0.35, 0.7), 2.5)
		return
	# Sword trail ribbon (drawn under the body, world-space points)
	if trail.size() > 1:
		for i in range(trail.size() - 1):
			var a1 := to_local(trail[i]["p"])
			var a2 := to_local(trail[i + 1]["p"])
			var k := float(trail[i]["t"]) / 0.18
			draw_line(a1, a2, Color(1.0, 0.75, 0.3, 0.45 * k), 2.0 + 4.0 * k)
	var bob := _bob()
	var moving := velocity.length() > 20.0
	var white := clampf(hurt_flash * 4.0, 0.0, 1.0)
	var robe := Color(0.2, 0.3, 0.56).lerp(Color.WHITE, white)
	var robe_dark := Color(0.13, 0.2, 0.4).lerp(Color.WHITE, white)
	var trim := Color(0.87, 0.73, 0.38).lerp(Color.WHITE, white)
	var skin := Color(0.85, 0.72, 0.58).lerp(Color.WHITE, white)
	var leather := Color(0.35, 0.25, 0.16).lerp(Color.WHITE, white)
	modulate.a = 0.62 if dashing else 1.0
	# movement lean + breathing
	var lean := clampf(velocity.x / 900.0, -0.1, 0.1)
	var breathe := 1.0 + (0.0 if moving else 0.018 * sin(anim_t * 2.2))
	draw_set_transform(Vector2(0, 12.0 * (1.0 - breathe)), lean, Vector2(1.0, breathe))
	# boots (walk cycle peeking under the hem)
	if moving:
		var step := sin(anim_t * 13.0) * 5.0
		draw_circle(Vector2(step, 11), 3.2, leather)
		draw_circle(Vector2(-step, 11), 3.2, leather)
	# under-robe with waving hem
	var hem := PackedVector2Array()
	hem.append(Vector2(-11 * facing, -14 + bob))
	hem.append(Vector2(0, -20 + bob))
	hem.append(Vector2(11 * facing, -14 + bob))
	for i in 5:
		var hx := (10.0 - 5.0 * i) * facing
		hem.append(Vector2(hx, 10.0 + sin(anim_t * 7.0 + i * 1.9) * (1.8 if moving else 0.7)))
	Painter.outlined(self, hem, robe_dark, 1.6)
	# over-cloak
	var cloak := PackedVector2Array([
		Vector2(0, -23 + bob), Vector2(9 * facing, -15 + bob),
		Vector2(10 * facing, 4), Vector2(-9 * facing, 6), Vector2(-8 * facing, -15 + bob)])
	draw_colored_polygon(cloak, robe)
	# gold trim + clasp
	draw_polyline(PackedVector2Array([Vector2(-8 * facing, -15 + bob), Vector2(0, -11 + bob), Vector2(9 * facing, -15 + bob)]), trim, 1.6)
	draw_circle(Vector2(0, -16 + bob), 1.8, trim)
	# belt + scroll case (the scribe's office)
	draw_line(Vector2(-9 * facing, 1), Vector2(9 * facing, -1), leather, 2.5)
	draw_set_transform(Vector2(-8 * facing, 3), 0.5 * facing, Vector2.ONE)
	draw_rect(Rect2(-2, -6, 4.5, 12), Color(0.72, 0.64, 0.48).lerp(Color.WHITE, white))
	draw_circle(Vector2(0.2, -6), 2.2, leather)
	draw_set_transform(Vector2(0, 12.0 * (1.0 - breathe)), lean, Vector2(1.0, breathe))
	# shoulder mantle + pauldron on the sword arm
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9 * facing, -16 + bob), Vector2(0, -21 + bob), Vector2(9 * facing, -16 + bob),
		Vector2(6 * facing, -11 + bob), Vector2(-6 * facing, -11 + bob)]), robe_dark.darkened(0.1))
	draw_circle(Vector2(10 * facing, -15 + bob), 4.0, Color(0.55, 0.45, 0.3).lerp(Color.WHITE, white))
	draw_arc(Vector2(10 * facing, -15 + bob), 4.0, 0, TAU, 10, Painter.OUTLINE, 1.2)
	# head: face + deep hood
	draw_circle(Vector2(2.5 * facing, -27 + bob), 6.0, skin)
	draw_circle(Vector2(4 * facing, -28 + bob), 1.1, Color(0.18, 0.14, 0.1))
	var hood := PackedVector2Array([
		Vector2(-5 * facing, -34 + bob), Vector2(2 * facing, -36 + bob),
		Vector2(8 * facing, -31 + bob), Vector2(7 * facing, -24 + bob),
		Vector2(2 * facing, -21 + bob), Vector2(-7 * facing, -23 + bob)])
	var hood_open := PackedVector2Array([
		Vector2(8 * facing, -31 + bob), Vector2(7 * facing, -24 + bob),
		Vector2(2 * facing, -21 + bob)])
	draw_colored_polygon(hood, robe.darkened(0.12))
	draw_polyline(hood_open, trim, 1.2)
	# Witness halo — three slow-orbiting marks of commission
	var halo := trim
	halo.a = 0.5 + 0.18 * sin(anim_t * 3.0)
	draw_arc(Vector2(2 * facing, -40 + bob), 7.5, 0, TAU, 18, halo, 1.4)
	for i in 3:
		var ha := anim_t * 1.4 + TAU * i / 3.0
		draw_circle(Vector2(2 * facing, -40 + bob) + Vector2.from_angle(ha) * 7.5, 1.3, halo)
	# sword arm + flaming blade
	var hand := Vector2(12 * facing, -10 + bob)
	draw_line(Vector2(7 * facing, -15 + bob), hand, skin.darkened(0.1), 3.0)
	Painter.blade(self, hand, _sword_angle(), 34.0, anim_t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Ult-ready aura
	if ult_charge >= 100.0:
		Painter.glow(self, Vector2(0, -14 + bob), 30.0, Color(1.0, 0.95, 0.6, 0.3 + 0.1 * sin(anim_t * 6.0)), 3)
		Painter.rune_ring(self, Vector2(0, -14 + bob), 24.0 + sin(anim_t * 6.0) * 2.0, Color(1.0, 0.9, 0.55, 0.5), 6, anim_t * 2.0, 1.2)
