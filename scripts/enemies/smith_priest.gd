extends EnemyBase
class_name SmithPriest
## ELITE — Azazel's Smith-Priest. Cycles three patterns:
## summoning forged weapon shards, buffing all allies, and a cone of forge fire.

var rotation_idx := 0
const PATTERNS := ["shards", "cone", "buff"]

func desired_position() -> Vector2:
	var to_self := global_position - player.global_position
	if to_self.length() < 170.0:
		return player.global_position + to_self.normalized() * 240.0
	return player.global_position + to_self.normalized() * 200.0

func attack_ready() -> bool:
	return attack_cd <= 0.0 and global_position.distance_to(player.global_position) <= float(cfg["attack_range"])

func pick_attack() -> void:
	current_attack = PATTERNS[rotation_idx % PATTERNS.size()]
	rotation_idx += 1
	windup_total = float(cfg["windup"])
	match current_attack:
		"shards":
			telegraph = {"kind": "circle", "pos": global_position, "radius": 50.0}
		"cone":
			telegraph = {"kind": "cone",
				"dir": (player.global_position - global_position).normalized(),
				"range": 230.0, "arc": 62.0}
		"buff":
			telegraph = {"kind": "ring", "radius": 130.0}

func _attack_begin() -> void:
	match current_attack:
		"shards":
			for off in [-0.35, 0.0, 0.35]:
				var dir: Vector2 = (player.global_position - global_position).normalized().rotated(off)
				Projectile.spawn(get_parent(), global_position + dir * 20.0, dir, {
					"kind": "shard", "dmg": dmg * _dmg_mult(), "speed": 380.0, "radius": 8.0,
					"color": Color(0.85, 0.7, 0.4), "friendly": false, "life": 2.2})
			AudioMan.play("bronze")
		"cone":
			var dir2: Vector2 = telegraph.get("dir", Vector2.RIGHT)
			AudioMan.play("fire")
			FX.slash(global_position, dir2, 230.0, 62.0, Color(1.0, 0.5, 0.1))
			if player and not player.get("dead"):
				var to: Vector2 = player.global_position - global_position
				if to.length() <= 244.0 and absf(angle_difference(dir2.angle(), to.angle())) <= deg_to_rad(31.0):
					player.call("take_hit", dmg * 1.4 * _dmg_mult(), global_position)
			# lingering flame pools in the cone
			for i in 3:
				GroundHazard.spawn(get_parent(), global_position + dir2 * (70.0 + 60.0 * i) + Vector2(randf_range(-20, 20), randf_range(-20, 20)),
					{"kind": "pool", "radius": 30.0, "active": 2.5, "dps": 8.0, "color": Color(0.9, 0.4, 0.1)})
		"buff":
			AudioMan.play("bronze")
			FX.ring(global_position, Color(0.95, 0.8, 0.3), 30.0, 200.0, 0.5)
			for e in get_tree().get_nodes_in_group("enemies"):
				if e != self and is_instance_valid(e) and not e.get("dead") and not e.get("passive"):
					e.set("buff_t", 6.0)
					FX.burst(e.global_position, Color(0.95, 0.8, 0.3), 6, 80.0, 0.4)
