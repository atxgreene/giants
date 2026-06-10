extends EnemyBase
class_name HalfBuriedGiant
## MINI-BOSS — an immobile giant torso erupting from the sand.
## Slams fists at the player's position, releases arena-wide shockwave
## rings, and summons Bloodlings. After each slam it exposes a weak point
## (gold cracks) and takes double damage for a short window.

var pattern_idx := 0
var weak_t := 0.0
var second_ring_t := -1.0
var slam_pos := Vector2.ZERO
var slam_arm := 1.0
const PATTERNS := ["slam", "slam", "ring", "summon"]

func _ready() -> void:
	super()
	unbindable = true
	stunnable = false
	kb_resist = true
	add_to_group("boss")

func boss_title() -> String:
	return "THE HALF-BURIED GIANT"

func _physics_process(delta: float) -> void:
	weak_t = maxf(weak_t - delta, 0.0)
	if second_ring_t > 0.0:
		second_ring_t -= delta
		if second_ring_t <= 0.0:
			second_ring_t = -1.0
			RingHazard.spawn(get_parent(), global_position + Vector2(0, 20), {
				"speed": 250.0, "max_r": 650.0, "dmg": dmg,
				"color": Color(0.85, 0.6, 0.35)})
	super(delta)

func desired_position() -> Vector2:
	return global_position  # buried: cannot move

func _chase(delta: float) -> void:
	velocity = Vector2.ZERO
	facing = 1.0 if (player.global_position.x - global_position.x) >= 0.0 else -1.0
	if attack_cd <= 0.0:
		_start_windup()
	else:
		attack_cd = maxf(attack_cd - 0.0, 0.0)
	move_and_slide()

func damage_taken_mult() -> float:
	return 2.0 if weak_t > 0.0 else 1.0

func pick_attack() -> void:
	current_attack = PATTERNS[pattern_idx % PATTERNS.size()]
	pattern_idx += 1
	windup_total = float(cfg["windup"])
	match current_attack:
		"slam":
			slam_pos = player.global_position
			slam_arm = 1.0 if player.global_position.x >= global_position.x else -1.0
			telegraph = {"kind": "circle", "pos": slam_pos, "radius": 105.0}
		"ring":
			windup_total = 1.3
			telegraph = {"kind": "ring", "radius": 280.0}
		"summon":
			windup_total = 1.0
			telegraph = {"kind": "circle", "pos": global_position, "radius": 90.0}

func _windup_track(_delta: float) -> void:
	if current_attack == "slam" and windup_progress() < 0.6:
		slam_pos = slam_pos.lerp(player.global_position, 0.18)
		telegraph["pos"] = slam_pos

func _attack_begin() -> void:
	match current_attack:
		"slam":
			AudioMan.play("hit_heavy")
			FX.shake(0.55)
			FX.ring(slam_pos, Color(0.85, 0.65, 0.4), 20.0, 105.0, 0.35)
			FX.burst(slam_pos, Color(0.75, 0.6, 0.45), 22, 220.0, 0.5)
			if player and not player.get("dead") and slam_pos.distance_to(player.global_position) <= 110.0:
				player.call("take_hit", dmg * 1.3 * _dmg_mult(), slam_pos)
			weak_t = 1.7
			Game.toast("The giant's old wounds glow. Strike now!", Color(0.95, 0.85, 0.5))
		"ring":
			AudioMan.play("roar")
			FX.shake(0.5)
			RingHazard.spawn(get_parent(), global_position + Vector2(0, 20), {
				"speed": 240.0, "max_r": 650.0, "dmg": dmg,
				"color": Color(0.85, 0.6, 0.35)})
			if hp < max_hp * 0.5:
				second_ring_t = 0.55
		"summon":
			AudioMan.play("roar")
			var alive := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if e != self and is_instance_valid(e) and not e.get("dead"):
					alive += 1
			if alive < 3:
				for offset in [Vector2(-150, 60), Vector2(150, 60)]:
					var b := EnemyBase.create("nephilim_bloodling")
					b.position = global_position + offset
					get_parent().add_child(b)
					FX.burst(b.global_position, Color(0.7, 0.3, 0.2), 12, 160.0, 0.4)

func on_death() -> void:
	if RunState.active:
		RunState.add_revelation(10.0)
	AudioMan.play("roar")
	FX.shake(1.0)
	FX.flash_screen(Color(0.9, 0.8, 0.6, 0.3), 0.5)

func _draw_body() -> void:
	var c := col(body_color)
	var breathe := sin(anim_t * 1.8) * 3.0
	# molten heat bleeding up from whatever lies beneath
	Painter.glow(self, Vector2(0, 26), 80.0, Color(1.0, 0.4, 0.1, 0.16 + 0.05 * sin(anim_t * 2.5)), 3)
	# half-buried torso
	var torso := PackedVector2Array([
		Vector2(-58, 20), Vector2(-50, -38 + breathe), Vector2(-26, -62 + breathe),
		Vector2(26, -62 + breathe), Vector2(50, -38 + breathe), Vector2(58, 20)])
	Painter.outlined(self, torso, c, 2.2)
	# stone-skin cracks
	draw_line(Vector2(-30, -50 + breathe), Vector2(-18, -30 + breathe), c.darkened(0.35), 2.0)
	draw_line(Vector2(24, -54 + breathe), Vector2(34, -34 + breathe), c.darkened(0.35), 2.0)
	# sand mound at base
	draw_set_transform(Vector2(0, 22), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 72.0, Color(0.55, 0.3, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# exposed ribs
	for i in 3:
		draw_arc(Vector2(0, -14 + i * 12 + breathe * 0.5), 36.0 - i * 5.0, PI * 0.15, PI * 0.85, 12, c.darkened(0.3), 3.0)
	# head
	draw_circle(Vector2(0, -74 + breathe), 20.0, c.darkened(0.1))
	draw_circle(Vector2(-8, -78 + breathe), 4.0, Color(0.1, 0.12, 0.1))
	draw_circle(Vector2(8, -78 + breathe), 4.0, Color(0.1, 0.12, 0.1))
	# arms: reach toward slam target during windup
	var arm_target := Vector2(70 * facing, -10)
	if state == "windup" and current_attack == "slam":
		arm_target = to_local(slam_pos) * windup_progress()
	draw_line(Vector2(48 * slam_arm, -34 + breathe), Vector2(48 * slam_arm, -34 + breathe).lerp(arm_target, 0.8), c.darkened(0.15), 13.0)
	draw_line(Vector2(-48 * slam_arm, -34 + breathe), Vector2(-58 * slam_arm, 4), c.darkened(0.2), 12.0)
	# weak point glow
	if weak_t > 0.0:
		var gold := Color(1.0, 0.85, 0.35, 0.5 + 0.3 * sin(anim_t * 14.0))
		draw_arc(Vector2(0, -20 + breathe), 26.0, 0, TAU, 20, gold, 4.0)
		for i in 4:
			var a := TAU * i / 4.0 + 0.5
			draw_line(Vector2(0, -20 + breathe) + Vector2.from_angle(a) * 12.0,
				Vector2(0, -20 + breathe) + Vector2.from_angle(a) * 30.0, gold, 2.5)
