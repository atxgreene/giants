extends CharacterBody2D
class_name EnemyBase
## Base enemy: data-driven stats from data/enemies.json, a simple state
## machine (spawn → chase → windup → attack → recover, plus stun/bound/dead),
## telegraph drawing, stagger/poise, burn / mark / bind statuses, and
## procedural silhouette rendering by shape.

signal died(enemy)

var id := ""
var cfg: Dictionary = {}
var max_hp := 10.0
var hp := 10.0
var dmg := 5.0
var speed := 100.0
var poise := 20.0
var stagger_meter := 0.0
var hit_radius := 16.0
var armored := false
var elite := false
var passive := false
var unbindable := false
var stunnable := true
var kb_resist := false
var dead := false

var state := "spawn"
var st := 0.45               # current state countdown
var attack_cd := 0.0
var current_attack := ""
var windup_total := 0.0
var telegraph: Dictionary = {}

var flash_t := 0.0
var burn_dps := 0.0
var burn_t := 0.0
var burn_tick := 0.0
var marked_t := 0.0
var bound_t := 0.0
var buff_t := 0.0
var body_color := Color.WHITE
var facing := 1.0
var anim_t := 0.0
var player: Node2D = null
var seals_drop := 0

const SUBCLASS_PATHS := {
	"ash_thrall": "res://scripts/enemies/ash_thrall.gd",
	"iron_brute": "res://scripts/enemies/iron_brute.gd",
	"star_archer": "res://scripts/enemies/star_archer.gd",
	"nephilim_bloodling": "res://scripts/enemies/nephilim_bloodling.gd",
	"bound_giant_spirit": "res://scripts/enemies/bound_giant_spirit.gd",
	"watcher_hound": "res://scripts/enemies/watcher_hound.gd",
	"smith_priest": "res://scripts/enemies/smith_priest.gd",
	"half_buried_giant": "res://scripts/bosses/half_buried_giant.gd",
	"first_blade": "res://scripts/bosses/first_blade.gd",
	"training_dummy": "res://scripts/hub/training_dummy.gd"
}

static func create(enemy_id: String) -> EnemyBase:
	var script = load(SUBCLASS_PATHS[enemy_id])
	var e: EnemyBase = script.new()
	e.setup(enemy_id)
	return e

func setup(enemy_id: String) -> void:
	id = enemy_id
	cfg = DataDB.enemies[id]
	var sc := RunState.enemy_scale() if RunState.active else {"hp": 1.0, "dmg": 1.0}
	max_hp = float(cfg["hp"]) * float(sc["hp"])
	hp = max_hp
	dmg = float(cfg["dmg"]) * float(sc["dmg"])
	speed = float(cfg["speed"])
	poise = float(cfg["poise"])
	hit_radius = float(cfg["hit_radius"])
	armored = bool(cfg.get("armored", false))
	elite = bool(cfg.get("elite", false))
	passive = bool(cfg.get("passive", false))
	seals_drop = int(cfg.get("seals", 0))
	body_color = Color(str(cfg["color"]))
	anim_t = randf() * 10.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1 | 2
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = minf(hit_radius * 0.8, 18.0)
	cs.shape = sh
	add_child(cs)

func _physics_process(delta: float) -> void:
	anim_t += delta
	queue_redraw()
	flash_t = maxf(flash_t - delta, 0.0)
	marked_t = maxf(marked_t - delta, 0.0)
	buff_t = maxf(buff_t - delta, 0.0)
	attack_cd = maxf(attack_cd - delta, 0.0)
	_tick_burn(delta)
	if dead:
		return
	if bound_t > 0.0:
		bound_t -= delta
		velocity = Vector2.ZERO
		telegraph = {}
		if state == "windup" or state == "attack":
			state = "recover"
			st = 0.4
		return
	if passive:
		return
	player = get_tree().get_first_node_in_group("player")
	if player == null or player.get("dead"):
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return
	match state:
		"spawn":
			st -= delta
			if st <= 0.0:
				state = "chase"
		"chase":
			_chase(delta)
		"windup":
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			move_and_slide()
			_windup_track(delta)
			st -= delta
			if st <= 0.0:
				state = "attack"
				_attack_begin()
		"attack":
			if _attack_tick(delta):
				_end_attack()
		"recover":
			velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
			move_and_slide()
			st -= delta
			if st <= 0.0:
				state = "chase"
		"stun":
			velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
			move_and_slide()
			st -= delta
			if st <= 0.0:
				state = "chase"

func _tick_burn(delta: float) -> void:
	if burn_t > 0.0:
		burn_t -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 0.5
			_burn_damage(burn_dps * 0.5)

func _burn_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	FX.damage_number(global_position, amount, Color(1.0, 0.55, 0.2))
	if hp <= 0.0:
		die()

# -------------------------------------------------------------- movement/AI

func desired_position() -> Vector2:
	return player.global_position

func attack_ready() -> bool:
	return attack_cd <= 0.0 and global_position.distance_to(player.global_position) <= float(cfg["attack_range"])

func _chase(delta: float) -> void:
	var target := desired_position()
	var to := target - global_position
	if to.length() > 10.0:
		velocity = velocity.lerp(to.normalized() * speed, clampf(8.0 * delta, 0.0, 1.0))
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
	# soft separation
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e) or e.get("dead"):
			continue
		var d: Vector2 = global_position - e.global_position
		var dist := d.length()
		if dist > 0.1 and dist < 34.0:
			velocity += d.normalized() * (34.0 - dist) * 6.0
	move_and_slide()
	facing = 1.0 if (player.global_position.x - global_position.x) >= 0.0 else -1.0
	if attack_ready():
		_start_windup()

func _start_windup() -> void:
	pick_attack()
	state = "windup"
	st = windup_total

func windup_progress() -> float:
	if windup_total <= 0.0:
		return 1.0
	return clampf(1.0 - st / windup_total, 0.0, 1.0)

## Subclass hooks -------------------------------------------------------------

func pick_attack() -> void:
	current_attack = "swipe"
	windup_total = float(cfg["windup"])
	telegraph = {"kind": "cone", "dir": (player.global_position - global_position).normalized(),
		"range": float(cfg["attack_range"]), "arc": 70.0}

func _windup_track(_delta: float) -> void:
	# Allow telegraphs to track the player during the first 60% of windup.
	if windup_progress() < 0.6 and telegraph.get("kind", "") == "cone":
		telegraph["dir"] = (player.global_position - global_position).normalized()

func _attack_begin() -> void:
	_melee_cone(float(cfg["attack_range"]), 70.0, dmg)

func _attack_tick(_delta: float) -> bool:
	return true

func _end_attack() -> void:
	state = "recover"
	st = float(cfg["recover"])
	attack_cd = float(cfg["cd"])
	telegraph = {}

func _melee_cone(reach: float, arc_deg: float, amount: float) -> void:
	var dir: Vector2 = telegraph.get("dir", Vector2.RIGHT)
	FX.slash(global_position, dir, reach * 0.9, arc_deg, Color(0.9, 0.3, 0.25))
	AudioMan.play("swing")
	if player == null or player.get("dead"):
		return
	var to: Vector2 = player.global_position - global_position
	if to.length() <= reach + 14.0 and absf(angle_difference(dir.angle(), to.angle())) <= deg_to_rad(arc_deg * 0.5):
		player.call("take_hit", amount * _dmg_mult(), global_position)

func _dmg_mult() -> float:
	return 1.3 if buff_t > 0.0 else 1.0

# ------------------------------------------------------------------ damage

func damage_taken_mult() -> float:
	return 1.0

func take_hit(amount: float, from_pos: Vector2, kb := 120.0, stagger := 1.0, opts: Dictionary = {}) -> void:
	if dead:
		return
	var final := amount
	if marked_t > 0.0:
		final *= 1.2 + RunState.mod("mark_dmg")
	if armored and float(opts.get("armored_bonus", 0.0)) > 0.0:
		final *= 1.0 + float(opts["armored_bonus"])
	final *= damage_taken_mult()
	hp -= final
	flash_t = 0.12
	var num_col := Color(1.0, 0.9, 0.6)
	if marked_t > 0.0:
		num_col = Color(0.45, 0.75, 1.0)
	FX.damage_number(global_position, final, num_col)
	FX.burst(global_position + Vector2(0, -10), body_color.lightened(0.2), 7, 130.0, 0.3)
	if bool(opts.get("burn", false)):
		apply_burn(4.0, 3.0)
	if bool(opts.get("mark", false)):
		marked_t = 5.0
	if not kb_resist and kb > 0.0:
		velocity += (global_position - from_pos).normalized() * kb
	if stunnable and poise < 9000.0:
		stagger_meter += stagger
		if stagger_meter >= poise * 0.1 and state != "stun":
			stagger_meter = 0.0
			stun(0.65)
	if hp <= 0.0:
		die()

func apply_burn(dps: float, dur: float) -> void:
	burn_dps = dps
	burn_t = maxf(burn_t, dur)

func bind_for(dur: float) -> void:
	if unbindable or dead:
		return
	bound_t = dur
	telegraph = {}

func stun(dur: float) -> void:
	state = "stun"
	st = dur
	telegraph = {}

func die() -> void:
	if dead:
		return
	dead = true
	telegraph = {}
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if RunState.active:
		RunState.kills += 1
		if bound_t > 0.0:
			RunState.bound_kills += 1
			RunState.add_revelation(3.0)
		if elite:
			RunState.add_revelation(10.0)
			Game.toast("Elite destroyed. Revelation stirs.", Color(0.45, 0.75, 1.0))
		if seals_drop > 0:
			RunState.earn_seals(seals_drop)
	on_death()
	AudioMan.play("edeath")
	FX.burst(global_position, body_color, 18, 200.0, 0.55)
	FX.burst(global_position, Color(0.95, 0.85, 0.5), 8, 120.0, 0.4)
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)

func on_death() -> void:
	pass

# ------------------------------------------------------------------ drawing

func col(c: Color) -> Color:
	var white := clampf(flash_t * 8.0, 0.0, 1.0)
	var out := c.lerp(Color.WHITE, white)
	if burn_t > 0.0:
		out = out.lerp(Color(1.0, 0.5, 0.1), 0.25 + 0.15 * sin(anim_t * 18.0))
	if buff_t > 0.0:
		out = out.lerp(Color(0.95, 0.8, 0.3), 0.25)
	return out

func _draw() -> void:
	_draw_telegraph()
	# shadow
	draw_set_transform(Vector2(0, hit_radius * 0.55), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, hit_radius * 0.9, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_body()
	_draw_status()

func _draw_status() -> void:
	if dead:
		return
	# HP bar
	if hp < max_hp:
		var w := maxf(hit_radius * 2.2, 26.0)
		var y := -hit_radius * 2.0 - 8.0
		draw_rect(Rect2(-w / 2, y, w, 4), Color(0, 0, 0, 0.6))
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		var bar_col := Color(0.85, 0.25, 0.2) if not elite else Color(0.95, 0.75, 0.3)
		draw_rect(Rect2(-w / 2, y, w * frac, 4), bar_col)
	if marked_t > 0.0:
		var mc := Color(0.45, 0.75, 1.0, 0.9)
		var my := -hit_radius * 2.0 - 18.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, my - 5), Vector2(4, my), Vector2(0, my + 5), Vector2(-4, my)]), mc)
	if bound_t > 0.0:
		var gold := Color(0.95, 0.85, 0.5, 0.8)
		draw_arc(Vector2.ZERO, hit_radius + 6.0, 0, TAU, 24, gold, 2.5)
		for i in 6:
			var a := TAU * i / 6.0 + anim_t * 2.0
			draw_line(Vector2.from_angle(a) * (hit_radius + 2.0), Vector2.from_angle(a) * (hit_radius + 10.0), gold, 2.0)

func _draw_telegraph() -> void:
	if telegraph.is_empty() or state != "windup":
		return
	var prog := windup_progress()
	var c := Color(0.95, 0.25, 0.2)
	match str(telegraph.get("kind", "")):
		"cone":
			var dir: Vector2 = telegraph["dir"]
			var reach := float(telegraph["range"])
			var arc := deg_to_rad(float(telegraph["arc"]))
			var base := dir.angle()
			var pts := PackedVector2Array([Vector2.ZERO])
			for i in 13:
				pts.append(Vector2.from_angle(base - arc * 0.5 + arc * i / 12.0) * reach)
			c.a = 0.12 + 0.2 * prog
			draw_colored_polygon(pts, c)
			c.a = 0.65
			draw_arc(Vector2.ZERO, reach, base - arc * 0.5, base + arc * 0.5, 16, c, 2.0)
		"circle":
			var pos: Vector2 = to_local(telegraph["pos"])
			var radius := float(telegraph["radius"])
			c.a = 0.5
			draw_arc(pos, radius, 0, TAU, 36, c, 2.5)
			c.a = 0.18
			draw_circle(pos, radius * prog, c)
		"line":
			var dir2: Vector2 = telegraph["dir"]
			var l := float(telegraph["length"])
			var w := float(telegraph.get("width", 26.0))
			draw_set_transform(Vector2.ZERO, dir2.angle(), Vector2.ONE)
			c.a = 0.14 + 0.2 * prog
			draw_rect(Rect2(0, -w / 2, l, w), c, true)
			c.a = 0.6
			draw_rect(Rect2(0, -w / 2, l * prog, w), c, false, 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"ring":
			var r := float(telegraph["radius"])
			c.a = 0.5
			draw_arc(Vector2.ZERO, r * prog, 0, TAU, 40, c, 3.0)
			c.a = 0.25
			draw_arc(Vector2.ZERO, r, 0, TAU, 40, c, 2.0)

func _draw_body() -> void:
	var bob := sin(anim_t * 7.0) * 1.5
	match str(cfg.get("shape", "thrall")):
		"thrall":
			_draw_humanoid(bob, 1.0)
		"brute":
			_draw_brute(bob)
		"archer":
			_draw_archer(bob)
		"bloodling":
			_draw_bloodling(bob)
		"spirit":
			_draw_spirit()
		"hound":
			_draw_hound(bob)
		"priest":
			_draw_priest(bob)
		"dummy":
			_draw_dummy()
		_:
			draw_circle(Vector2.ZERO, hit_radius, col(body_color))

func _draw_humanoid(bob: float, scale_k: float) -> void:
	var c := col(body_color)
	var pts := PackedVector2Array([
		Vector2(0, -18 * scale_k + bob), Vector2(8 * scale_k * facing, -10 * scale_k + bob),
		Vector2(9 * scale_k * facing, 8 * scale_k), Vector2(-9 * scale_k * facing, 8 * scale_k),
		Vector2(-7 * scale_k * facing, -10 * scale_k + bob)])
	draw_colored_polygon(pts, c)
	draw_circle(Vector2(1 * facing, -22 * scale_k + bob), 5.5 * scale_k, c.darkened(0.15))
	# ember eyes
	draw_circle(Vector2(3 * facing, -23 * scale_k + bob), 1.4, Color(1.0, 0.45, 0.15))

func _draw_brute(bob: float) -> void:
	var c := col(body_color)
	var pts := PackedVector2Array([
		Vector2(0, -26 + bob), Vector2(16 * facing, -18 + bob), Vector2(18 * facing, 4),
		Vector2(10 * facing, 12), Vector2(-10 * facing, 12), Vector2(-18 * facing, 4),
		Vector2(-16 * facing, -18 + bob)])
	draw_colored_polygon(pts, c)
	# pauldrons
	draw_circle(Vector2(14 * facing, -18 + bob), 7.0, c.darkened(0.25))
	draw_circle(Vector2(-14 * facing, -18 + bob), 7.0, c.darkened(0.25))
	# iron mask
	draw_circle(Vector2(2 * facing, -30 + bob), 7.0, c.lightened(0.15))
	draw_line(Vector2(-2 * facing, -30 + bob), Vector2(6 * facing, -30 + bob), Color(0.1, 0.1, 0.12), 2.0)
	# club
	draw_line(Vector2(16 * facing, -10 + bob), Vector2(28 * facing, -28 + bob), Color(0.35, 0.3, 0.28), 5.0)

func _draw_archer(bob: float) -> void:
	var c := col(body_color)
	_draw_humanoid(bob, 0.9)
	# bow
	var bow_x := 11.0 * facing
	draw_arc(Vector2(bow_x, -12 + bob), 10.0, -PI * 0.45 + (0.0 if facing > 0 else PI), PI * 0.45 + (0.0 if facing > 0 else PI), 10, c.lightened(0.3), 2.0)
	# star-sickness glow
	var glow := Color(0.7, 0.5, 1.0, 0.3 + 0.15 * sin(anim_t * 5.0))
	draw_circle(Vector2(1 * facing, -20 + bob), 9.0, glow)

func _draw_bloodling(bob: float) -> void:
	var c := col(body_color)
	var pts := PackedVector2Array([
		Vector2(0, -16 + bob), Vector2(13 * facing, -6 + bob), Vector2(10 * facing, 10),
		Vector2(-10 * facing, 10), Vector2(-13 * facing, -6 + bob)])
	draw_colored_polygon(pts, c)
	# long arms
	draw_line(Vector2(10 * facing, -6 + bob), Vector2(20 * facing, 8), c.darkened(0.1), 4.0)
	draw_line(Vector2(-10 * facing, -6 + bob), Vector2(-18 * facing, 8), c.darkened(0.1), 4.0)
	draw_circle(Vector2(2 * facing, -21 + bob), 6.0, c.darkened(0.2))
	# enrage glow
	if hp < max_hp * 0.3:
		var rage := Color(1.0, 0.2, 0.1, 0.35 + 0.2 * sin(anim_t * 12.0))
		draw_circle(Vector2(0, -10), 18.0, rage)
	draw_circle(Vector2(4 * facing, -22 + bob), 1.5, Color(1.0, 0.9, 0.3))

func _draw_spirit() -> void:
	var c := col(body_color)
	c.a = 0.55
	var hover := sin(anim_t * 2.5) * 4.0
	draw_circle(Vector2(0, -18 + hover), 16.0, c)
	# wavy lower shroud
	var pts := PackedVector2Array()
	for i in 9:
		var x := -16.0 + 4.0 * i
		pts.append(Vector2(x, -6 + hover + sin(anim_t * 4.0 + i) * 3.0))
	pts.append(Vector2(16, -18 + hover))
	pts.append(Vector2(-16, -18 + hover))
	draw_colored_polygon(pts, c)
	# hollow eyes
	draw_circle(Vector2(-5, -20 + hover), 2.5, Color(0.05, 0.1, 0.12))
	draw_circle(Vector2(5, -20 + hover), 2.5, Color(0.05, 0.1, 0.12))
	# old binding chains (gold marks)
	var gold := Color(0.85, 0.72, 0.38, 0.5)
	draw_arc(Vector2(0, -16 + hover), 20.0, PI * 0.15, PI * 0.85, 10, gold, 2.0)

func _draw_hound(bob: float) -> void:
	var c := col(body_color)
	# body
	draw_set_transform(Vector2(0, -8), 0.0, Vector2(1.3, 0.7))
	draw_circle(Vector2.ZERO, 11.0, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# head
	draw_circle(Vector2(12 * facing, -12 + bob * 0.5), 6.0, c.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([
		Vector2(16 * facing, -12), Vector2(22 * facing, -10), Vector2(16 * facing, -8)]), c.darkened(0.2))
	# legs (simple run cycle)
	var leg := sin(anim_t * 14.0) * 4.0
	draw_line(Vector2(6 * facing, -4), Vector2(8 * facing + leg, 4), c.darkened(0.2), 2.5)
	draw_line(Vector2(-6 * facing, -4), Vector2(-8 * facing - leg, 4), c.darkened(0.2), 2.5)
	# corruption glow
	var glow := Color(0.4, 0.9, 0.3, 0.25 + 0.1 * sin(anim_t * 8.0))
	draw_circle(Vector2(0, -8), 14.0, glow)

func _draw_priest(bob: float) -> void:
	var c := col(body_color)
	var pts := PackedVector2Array([
		Vector2(0, -30 + bob), Vector2(11 * facing, -18 + bob), Vector2(13 * facing, 12),
		Vector2(-13 * facing, 12), Vector2(-11 * facing, -18 + bob)])
	draw_colored_polygon(pts, c)
	draw_circle(Vector2(1 * facing, -34 + bob), 6.0, Color(0.2, 0.16, 0.14))
	# floating shard halo
	for i in 4:
		var a := anim_t * 1.6 + TAU * i / 4.0
		var p := Vector2(cos(a) * 22.0, -34 + bob + sin(a) * 7.0)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, -6), p + Vector2(3, 2), p + Vector2(-3, 2)]), Color(0.85, 0.7, 0.4))
	# gold trim
	draw_polyline(PackedVector2Array([Vector2(-11 * facing, -18 + bob), Vector2(0, -24 + bob), Vector2(11 * facing, -18 + bob)]), Color(0.95, 0.8, 0.35), 2.0)

func _draw_dummy() -> void:
	var c := col(body_color)
	draw_line(Vector2(0, 10), Vector2(0, -26), c.darkened(0.3), 5.0)
	draw_circle(Vector2(0, -30), 7.0, c)
	draw_line(Vector2(-14, -18), Vector2(14, -18), c.darkened(0.2), 4.0)
	var gold := Color(0.85, 0.72, 0.38, 0.5)
	draw_arc(Vector2(0, -12), 18.0, 0, TAU, 20, gold, 1.5)
