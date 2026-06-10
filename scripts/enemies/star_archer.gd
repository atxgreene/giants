extends EnemyBase
class_name StarArcher
## Ranged cultist. Keeps its distance and fires corrupted star bolts.

func desired_position() -> Vector2:
	var to_self := global_position - player.global_position
	var d := to_self.length()
	if d < 230.0:
		return player.global_position + to_self.normalized() * 320.0
	if d > 400.0:
		return player.global_position + to_self.normalized() * 320.0
	return global_position

func attack_ready() -> bool:
	if attack_cd > 0.0:
		return false
	var d := global_position.distance_to(player.global_position)
	return d > 150.0 and d <= float(cfg["attack_range"])

func pick_attack() -> void:
	current_attack = "starbolt"
	windup_total = float(cfg["windup"])
	telegraph = {"kind": "line",
		"dir": (player.global_position - global_position).normalized(),
		"length": 320.0, "width": 14.0}

func _windup_track(_delta: float) -> void:
	if windup_progress() < 0.7:
		telegraph["dir"] = (player.global_position - global_position).normalized()

func _attack_begin() -> void:
	var dir: Vector2 = telegraph.get("dir", Vector2.RIGHT)
	Projectile.spawn(get_parent(), global_position + dir * 16.0, dir, {
		"kind": "star", "dmg": dmg * _dmg_mult(), "speed": 330.0, "radius": 9.0,
		"color": Color(0.65, 0.45, 1.0), "friendly": false, "life": 2.5})
	AudioMan.play("bolt")
