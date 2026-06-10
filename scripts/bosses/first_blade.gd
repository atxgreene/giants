extends EnemyBase
class_name FirstBlade
## MAJOR BOSS — Azazel's First Blade. A living blade-forge entity with
## corrupted radiant wings, iron halos, and orbiting sword fragments.
## Phase 1: sword dashes, linear blade beams, summoned shard darts.
## Phase 2 (≤66%): forge-fire lanes + rotating blade halo + faster combos.
## Phase 3 (≤33%): the temptation — accept forbidden power (corruption)
## or refuse (Seal of Michael) and face a desperate final phase.

var phase := 1
var halo_on := false
var halo_angle := 0.0
var halo_hit_cd := 0.0
var choice_done := false
var desperate := false
var dying := false

var dash_from := Vector2.ZERO
var dash_to := Vector2.ZERO
var dash_t := 0.0
var dash_hit := false
var dash_count := 0
var dashes_left := 0

func _ready() -> void:
	super()
	unbindable = true
	stunnable = false
	kb_resist = true
	add_to_group("boss")

func boss_title() -> String:
	return "AZAZEL'S FIRST BLADE"

func _physics_process(delta: float) -> void:
	halo_angle += delta * 2.4
	halo_hit_cd = maxf(halo_hit_cd - delta, 0.0)
	if not dead:
		_check_phase()
		if halo_on and halo_hit_cd <= 0.0 and player and not player.get("dead"):
			for i in 3:
				var bp := global_position + Vector2.from_angle(halo_angle + TAU * i / 3.0) * 88.0
				if bp.distance_to(player.global_position) < 24.0:
					halo_hit_cd = 0.8
					player.call("take_hit", dmg * 0.6, bp)
					break
	super(delta)

func _check_phase() -> void:
	var frac := hp / max_hp
	if phase == 1 and frac <= 0.66:
		phase = 2
		halo_on = true
		AudioMan.play("roar")
		FX.flash_screen(Color(1.0, 0.6, 0.2, 0.25), 0.4)
		FX.shake(0.6)
		Game.toast("The forge answers its blade. The arena ignites.", Color(1.0, 0.55, 0.2))
	elif phase == 2 and frac <= 0.33 and not choice_done:
		choice_done = true
		phase = 3
		state = "recover"
		st = 1.0
		telegraph = {}
		var run := get_tree().get_first_node_in_group("run")
		if run:
			run.call("boss_temptation", self)

func apply_temptation(accepted: bool) -> void:
	if accepted:
		Game.profile["edge_of_azazel"] = true
		Game.profile["michael_disapproves"] = true
		Game.save()
		RunState.add_corruption(25.0)
		RunState.rebuild_mods()
		Game.toast("EDGE OF AZAZEL accepted: +10% sword damage, forever. Michael saw.", Color(0.85, 0.2, 0.25))
		AudioMan.play("whisper")
	else:
		Game.profile["seal_of_michael"] = true
		Game.save()
		RunState.add_revelation(10.0)
		desperate = true
		dmg *= 1.12
		speed *= 1.2
		Game.toast("SEAL OF MICHAEL: the refusal itself is a weapon. The Blade despairs.", Color(0.95, 0.85, 0.5))
		AudioMan.play("revelation")
	CodexMan.unlock("forbidden-knowledge")

func desired_position() -> Vector2:
	var to_self := global_position - player.global_position
	if to_self.length() < 120.0:
		return player.global_position + to_self.normalized() * 200.0
	return player.global_position + to_self.normalized() * 160.0

func attack_ready() -> bool:
	return attack_cd <= 0.0

func _cd_scale() -> float:
	if desperate:
		return 0.55
	return 0.75 if phase >= 2 else 1.0

func pick_attack() -> void:
	var options := ["dash_slash", "blade_fan", "summon_shards"]
	if phase >= 2:
		options.append("fire_lanes")
		options.append("double_dash")
	if desperate:
		options.append("radial_burst")
		options.append("radial_burst")
	current_attack = options[randi() % options.size()]
	windup_total = float(cfg["windup"]) * (_cd_scale() * 0.9 + 0.25)
	match current_attack:
		"dash_slash", "double_dash":
			dashes_left = 2 if current_attack == "double_dash" else 1
			_aim_dash()
		"blade_fan":
			telegraph = {"kind": "cone",
				"dir": (player.global_position - global_position).normalized(),
				"range": 320.0, "arc": 55.0}
		"summon_shards":
			telegraph = {"kind": "circle", "pos": global_position, "radius": 70.0}
		"fire_lanes":
			windup_total = 0.9
			telegraph = {"kind": "circle", "pos": player.global_position, "radius": 60.0}
		"radial_burst":
			windup_total = 1.0
			telegraph = {"kind": "ring", "radius": 240.0}

func _aim_dash() -> void:
	var dir := (player.global_position - global_position).normalized()
	dash_to = player.global_position + dir * 130.0
	telegraph = {"kind": "line", "dir": dir,
		"length": global_position.distance_to(dash_to), "width": 44.0}

func _windup_track(_delta: float) -> void:
	if windup_progress() < 0.7:
		match current_attack:
			"dash_slash", "double_dash":
				_aim_dash()
			"blade_fan":
				telegraph["dir"] = (player.global_position - global_position).normalized()

func _attack_begin() -> void:
	match current_attack:
		"dash_slash", "double_dash":
			dash_from = global_position
			dash_t = 0.0
			dash_hit = false
			AudioMan.play("dash")
		"blade_fan":
			var dir: Vector2 = telegraph.get("dir", Vector2.RIGHT)
			var n := 5 if phase >= 2 else 3
			for i in n:
				var off := (float(i) - float(n - 1) * 0.5) * 0.22
				Projectile.spawn(get_parent(), global_position + dir * 28.0, dir.rotated(off), {
					"kind": "blade", "dmg": dmg * _dmg_mult(), "speed": 560.0, "radius": 10.0,
					"color": Color(0.95, 0.8, 0.45), "friendly": false, "life": 1.8})
			AudioMan.play("bronze")
		"summon_shards":
			for i in 3:
				var a := TAU * i / 3.0 + randf()
				Projectile.spawn(get_parent(), global_position + Vector2.from_angle(a) * 60.0,
					Vector2.from_angle(a), {
					"kind": "dart", "dmg": dmg * 0.8 * _dmg_mult(), "speed": 230.0, "radius": 8.0,
					"color": Color(0.8, 0.55, 0.3), "friendly": false, "life": 4.5, "homing": 2.6})
			AudioMan.play("seal")
		"fire_lanes":
			var n2 := 3 if phase >= 3 else 2
			var room := get_tree().get_first_node_in_group("room")
			var lane_len := 1700.0
			var center_x := global_position.x
			if room:
				var bounds: Rect2 = room.get("bounds")
				lane_len = bounds.size.x + 200.0
				center_x = bounds.get_center().x
			for i in n2:
				var y_off := float(i - n2 / 2) * 150.0
				GroundHazard.spawn(get_parent(), Vector2(center_x, player.global_position.y + y_off), {
					"kind": "lane", "length": lane_len, "width": 64.0, "angle": 0.0,
					"telegraph": 0.85, "active": 2.4, "dps": 14.0,
					"color": Color(1.0, 0.45, 0.1)})
			AudioMan.play("fire")
		"radial_burst":
			RingHazard.spawn(get_parent(), global_position, {
				"speed": 300.0, "max_r": 420.0, "dmg": dmg,
				"color": Color(1.0, 0.6, 0.2)})
			for i in 8:
				var a2 := TAU * i / 8.0
				Projectile.spawn(get_parent(), global_position, Vector2.from_angle(a2), {
					"kind": "blade", "dmg": dmg * 0.7, "speed": 420.0, "radius": 9.0,
					"color": Color(1.0, 0.7, 0.35), "friendly": false, "life": 1.6})
			AudioMan.play("ult")
			FX.shake(0.5)

func _attack_tick(delta: float) -> bool:
	if current_attack != "dash_slash" and current_attack != "double_dash":
		return true
	dash_t += delta
	var k := clampf(dash_t / 0.26, 0.0, 1.0)
	global_position = dash_from.lerp(dash_to, k)
	if not dash_hit and player and not player.get("dead"):
		# damage along the dash path
		var seg := dash_to - dash_from
		var t := clampf((player.global_position - dash_from).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var closest := dash_from + seg * t
		if closest.distance_to(player.global_position) < 34.0 and global_position.distance_to(player.global_position) < 90.0:
			dash_hit = true
			player.call("take_hit", dmg * 1.2 * _dmg_mult(), global_position)
	if k >= 1.0:
		FX.slash(global_position, (dash_to - dash_from).normalized(), 90.0, 120.0, Color(1.0, 0.75, 0.4))
		dashes_left -= 1
		if dashes_left > 0:
			_aim_dash()
			dash_from = global_position
			dash_t = 0.0
			dash_hit = false
			return false
		return true
	return false

func _end_attack() -> void:
	super()
	attack_cd = float(cfg["cd"]) * _cd_scale()

func die() -> void:
	if dying:
		return
	dying = true
	halo_on = false
	var run := get_tree().get_first_node_in_group("run")
	super()
	if run:
		run.call("on_boss_defeated")

func _draw_body() -> void:
	var hover := sin(anim_t * 2.2) * 4.0
	var c := col(body_color)
	# wing membranes — radiant fans shading from gold to rust
	for side in [-1.0, 1.0]:
		var root := Vector2(0, -34 + hover)
		var fan := PackedVector2Array([root])
		for i in 6:
			var ma: float = -PI * 0.5 + side * (0.3 + 0.16 * i) + sin(anim_t * 1.5) * 0.05
			fan.append(root + Vector2.from_angle(ma) * (54.0 - i * 4.0))
		var mem := Color(0.85, 0.55, 0.25, 0.22)
		if desperate:
			mem = Color(1.0, 0.35, 0.15, 0.28)
		draw_colored_polygon(fan, mem)
	# corrupted radiant wings — two fans of blades
	for side in [-1.0, 1.0]:
		for i in 5:
			var a: float = -PI * 0.5 + side * (0.35 + 0.18 * i) + sin(anim_t * 1.5) * 0.05
			var root := Vector2(0, -34 + hover)
			var tip := root + Vector2.from_angle(a) * (52.0 - i * 5.0)
			var wing_c := Color(0.95, 0.75, 0.4, 0.8).lerp(Color(0.7, 0.2, 0.2, 0.8), float(i) / 5.0)
			if desperate:
				wing_c = wing_c.lerp(Color(1.0, 0.3, 0.1, 0.9), 0.4)
			draw_line(root, tip, wing_c, 4.0 - i * 0.5)
	# tall body
	var pts := PackedVector2Array([
		Vector2(0, -44 + hover), Vector2(10 * facing, -28 + hover), Vector2(12 * facing, 8),
		Vector2(-12 * facing, 8), Vector2(-10 * facing, -28 + hover)])
	draw_colored_polygon(pts, c)
	# head with iron halos
	draw_circle(Vector2(0, -50 + hover), 7.5, c.lightened(0.2))
	var iron := Color(0.45, 0.45, 0.5)
	draw_arc(Vector2(0, -56 + hover), 12.0, 0, TAU, 20, iron, 2.0)
	draw_arc(Vector2(0, -56 + hover), 17.0, 0, TAU, 24, iron.darkened(0.2), 1.5)
	# blade arm
	var aim := Vector2(facing, 0.0)
	if player != null and not dead:
		aim = (player.global_position - global_position).normalized()
	var hand := Vector2(10 * facing, -22 + hover)
	draw_line(hand, hand + aim * 42.0, Color(1.0, 0.85, 0.55), 4.0)
	draw_line(hand, hand + aim * 20.0, Color(0.9, 0.5, 0.2), 6.0)
	# orbiting sword fragments / halo
	var n := 3
	for i in n:
		var a2 := halo_angle + TAU * i / n
		var p := Vector2.from_angle(a2) * (88.0 if halo_on else 40.0) + Vector2(0, -20 + hover)
		var frag_c := Color(1.0, 0.7, 0.3) if halo_on else Color(0.85, 0.7, 0.45, 0.7)
		draw_set_transform(p, a2 + PI * 0.5, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -12), Vector2(4, 6), Vector2(-4, 6)]), frag_c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# wrongness aura
	var aura := Color(0.9, 0.6, 0.25, 0.12 + 0.05 * sin(anim_t * 3.0))
	draw_circle(Vector2(0, -24 + hover), 56.0, aura)
