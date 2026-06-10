extends EnemyBase
class_name AshThrall
## Basic melee cultist. Telegraphs a straight charge, then rushes the player.

var charge_dir := Vector2.RIGHT
var charge_t := 0.0
var charge_hit := false

func pick_attack() -> void:
	current_attack = "charge"
	windup_total = float(cfg["windup"])
	charge_dir = (player.global_position - global_position).normalized()
	telegraph = {"kind": "line", "dir": charge_dir, "length": 190.0, "width": 30.0}

func _windup_track(_delta: float) -> void:
	if windup_progress() < 0.55:
		charge_dir = (player.global_position - global_position).normalized()
		telegraph["dir"] = charge_dir

func _attack_begin() -> void:
	charge_t = 0.32
	charge_hit = false
	AudioMan.play("dash")

func _attack_tick(delta: float) -> bool:
	charge_t -= delta
	velocity = charge_dir * speed * 3.4
	move_and_slide()
	if not charge_hit and player and not player.get("dead"):
		if global_position.distance_to(player.global_position) < 26.0:
			charge_hit = true
			player.call("take_hit", dmg * _dmg_mult(), global_position)
	return charge_t <= 0.0
