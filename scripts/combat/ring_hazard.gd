extends Node2D
class_name RingHazard
## Expanding shockwave ring. Damages the player once as the wave front
## crosses them — dodge through it with dash i-frames.

var r := 16.0
var speed := 250.0
var max_r := 420.0
var thickness := 30.0
var dmg := 12.0
var color := Color(1.0, 0.55, 0.25)
var attempted := false

static func spawn(parent: Node, pos: Vector2, cfg: Dictionary = {}) -> RingHazard:
	var h := RingHazard.new()
	h.position = pos
	h.speed = float(cfg.get("speed", 250.0))
	h.max_r = float(cfg.get("max_r", 420.0))
	h.dmg = float(cfg.get("dmg", 12.0))
	h.color = cfg.get("color", Color(1.0, 0.55, 0.25))
	h.z_index = 35
	parent.add_child(h)
	return h

func _process(delta: float) -> void:
	r += speed * delta
	queue_redraw()
	if r > max_r:
		queue_free()
		return
	if attempted:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and not player.get("dead"):
		var d := global_position.distance_to(player.global_position)
		if absf(d - r) < thickness * 0.5 + 10.0:
			attempted = true
			player.call("take_hit", dmg, global_position)

func _draw() -> void:
	var fade := clampf(1.0 - r / max_r, 0.15, 1.0)
	var c := color
	c.a = 0.85 * fade
	draw_arc(Vector2.ZERO, r, 0, TAU, 56, c, 6.0)
	c.a = 0.35 * fade
	draw_arc(Vector2.ZERO, maxf(r - 8.0, 2.0), 0, TAU, 56, c, 12.0)
