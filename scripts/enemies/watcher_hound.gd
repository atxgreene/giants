extends EnemyBase
class_name WatcherHound
## Fast pack beast. Circles the player, lunges, and leaves corruption pools.

var orbit_sign := 1.0
var orbit_phase := 0.0
var lunge_dir := Vector2.RIGHT
var lunge_t := 0.0
var lunge_hit := false

func _ready() -> void:
	super()
	orbit_sign = 1.0 if randf() < 0.5 else -1.0
	# A per-hound angular slot so the pack rings the player instead of stacking.
	orbit_phase = randf_range(0.5, 1.4)

func desired_position() -> Vector2:
	var to_self := global_position - player.global_position
	var d := maxf(to_self.length(), 1.0)
	# Orbit toward a slot offset around the player; packs spread into a ring.
	var slot := to_self.normalized().rotated(orbit_sign * orbit_phase)
	var ideal := player.global_position + slot * 165.0
	if d > 260.0:
		return player.global_position
	return ideal

func pick_attack() -> void:
	current_attack = "lunge"
	windup_total = float(cfg["windup"])
	lunge_dir = (player.global_position - global_position).normalized()
	telegraph = {"kind": "line", "dir": lunge_dir, "length": 170.0, "width": 24.0}

func _windup_track(_delta: float) -> void:
	if windup_progress() < 0.6:
		lunge_dir = (player.global_position - global_position).normalized()
		telegraph["dir"] = lunge_dir

func _attack_begin() -> void:
	lunge_t = 0.26
	lunge_hit = false
	AudioMan.play("dash")

func _attack_tick(delta: float) -> bool:
	lunge_t -= delta
	velocity = lunge_dir * speed * 2.6
	move_and_slide()
	if not lunge_hit and player and not player.get("dead"):
		if global_position.distance_to(player.global_position) < 24.0:
			lunge_hit = true
			player.call("take_hit", dmg * _dmg_mult(), global_position)
	if lunge_t <= 0.0:
		GroundHazard.spawn(get_parent(), global_position, {
			"kind": "pool", "radius": 34.0, "active": 4.0, "dps": 6.0,
			"corrupting": true, "color": Color(0.35, 0.65, 0.25)})
		return true
	return false

func on_death() -> void:
	GroundHazard.spawn(get_parent(), global_position, {
		"kind": "pool", "radius": 40.0, "active": 5.0, "dps": 6.0,
		"corrupting": true, "color": Color(0.35, 0.65, 0.25)})
