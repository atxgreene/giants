extends EnemyBase
class_name IronBrute
## Heavy armored melee. Slow overhead slam with a big circular telegraph.
## High poise — barely staggers. Michael's aspect punishes its armor.

var slam_pos := Vector2.ZERO

func pick_attack() -> void:
	current_attack = "slam"
	windup_total = float(cfg["windup"])
	slam_pos = player.global_position
	telegraph = {"kind": "circle", "pos": slam_pos, "radius": 82.0}

func _windup_track(_delta: float) -> void:
	if windup_progress() < 0.5:
		slam_pos = slam_pos.lerp(player.global_position, 0.2)
		telegraph["pos"] = slam_pos

func _attack_begin() -> void:
	AudioMan.play("hit_heavy")
	FX.ring(slam_pos, Color(0.8, 0.6, 0.4), 16.0, 82.0, 0.3)
	FX.burst(slam_pos, Color(0.7, 0.6, 0.5), 14, 160.0, 0.4)
	FX.shake(0.3)
	if player and not player.get("dead"):
		if slam_pos.distance_to(player.global_position) <= 86.0:
			player.call("take_hit", dmg * _dmg_mult(), slam_pos)
