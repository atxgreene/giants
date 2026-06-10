extends EnemyBase
class_name BoundGiantSpirit
## Floating remnant of a drowned giant. Slow drift, telegraphed radial
## scream that releases an expanding shockwave ring.

func _ready() -> void:
	super()
	# Spirits drift through other bodies.
	collision_mask = 1

func desired_position() -> Vector2:
	var sway := Vector2(sin(anim_t * 1.3) * 60.0, cos(anim_t * 1.1) * 40.0)
	return player.global_position + sway

func pick_attack() -> void:
	current_attack = "scream"
	windup_total = float(cfg["windup"])
	telegraph = {"kind": "ring", "radius": 230.0}

func _attack_begin() -> void:
	AudioMan.play("roar")
	FX.shake(0.35)
	RingHazard.spawn(get_parent(), global_position, {
		"speed": 260.0, "max_r": 250.0, "dmg": dmg * _dmg_mult(),
		"color": Color(0.6, 0.9, 0.85)})
	# inner pulse for point-blank pressure
	if player and not player.get("dead") and global_position.distance_to(player.global_position) < 60.0:
		player.call("take_hit", dmg * 0.6 * _dmg_mult(), global_position)

func on_death() -> void:
	if not RunState.active:
		return
	CodexMan.unlock("giant-spirits")
