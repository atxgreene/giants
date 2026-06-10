extends EnemyBase
class_name NephilimBloodling
## Fast semi-giant half-blood. Leaps at the player; enrages below 30% health.

var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var leap_t := 0.0
var leap_dur := 0.4
var enraged := false

func _physics_process(delta: float) -> void:
	if not enraged and hp < max_hp * 0.3 and not dead:
		enraged = true
		speed *= 1.45
		dmg *= 1.3
		FX.burst(global_position, Color(1.0, 0.25, 0.1), 16, 180.0, 0.4)
		AudioMan.play("roar")
	super(delta)

func attack_ready() -> bool:
	if attack_cd > 0.0:
		return false
	var d := global_position.distance_to(player.global_position)
	return d <= float(cfg["attack_range"])

func pick_attack() -> void:
	var d := global_position.distance_to(player.global_position)
	if d > 90.0:
		current_attack = "leap"
		windup_total = float(cfg["windup"])
		leap_to = player.global_position
		telegraph = {"kind": "circle", "pos": leap_to, "radius": 64.0}
	else:
		current_attack = "claw"
		windup_total = 0.35
		telegraph = {"kind": "cone",
			"dir": (player.global_position - global_position).normalized(),
			"range": 70.0, "arc": 90.0}

func _windup_track(_delta: float) -> void:
	if windup_progress() < 0.5:
		if current_attack == "leap":
			leap_to = leap_to.lerp(player.global_position, 0.25)
			telegraph["pos"] = leap_to
		elif telegraph.get("kind", "") == "cone":
			telegraph["dir"] = (player.global_position - global_position).normalized()

func _attack_begin() -> void:
	if current_attack == "leap":
		leap_from = global_position
		leap_t = 0.0
		AudioMan.play("dash")
	else:
		_melee_cone(70.0, 90.0, dmg)

func _attack_tick(delta: float) -> bool:
	if current_attack != "leap":
		return true
	leap_t += delta
	var k := clampf(leap_t / leap_dur, 0.0, 1.0)
	global_position = leap_from.lerp(leap_to, k)
	if k >= 1.0:
		FX.ring(global_position, Color(0.9, 0.35, 0.2), 12.0, 64.0, 0.25)
		FX.burst(global_position, Color(0.7, 0.3, 0.2), 12, 150.0, 0.35)
		AudioMan.play("hit")
		if player and not player.get("dead") and global_position.distance_to(player.global_position) <= 68.0:
			player.call("take_hit", dmg * _dmg_mult(), global_position)
		return true
	return false

func on_death() -> void:
	if RunState.active:
		CodexMan.unlock("nephilim")

func _draw_body() -> void:
	# offset for fake leap height
	if state == "attack" and current_attack == "leap":
		var k := clampf(leap_t / leap_dur, 0.0, 1.0)
		var h := sin(k * PI) * 42.0
		draw_set_transform(Vector2(0, -h), 0.0, Vector2.ONE)
	super()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
