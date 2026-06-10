extends Node2D
class_name BindingSeal
## The Witness's circular sigil trap. Arms briefly, then binds every enemy
## inside: bound enemies cannot move or act, and enemies slain while bound
## fill Revelation. With Raphael's "Mercy in the Circle", captures heal.

var radius := 88.0
var arm_t := 0.35
var duration := 2.7
var pulse_dmg := 3.0
var phase := "arming"
var anim := 0.0
var recheck := 0.0
var captured := 0

static func spawn(parent: Node, pos: Vector2, cfg: Dictionary) -> BindingSeal:
	var s := BindingSeal.new()
	s.position = pos
	s.radius = float(cfg.get("radius", 88.0))
	s.arm_t = float(cfg.get("arm", 0.35))
	s.duration = float(cfg.get("duration", 2.7))
	s.pulse_dmg = float(cfg.get("dmg", 3.0))
	s.z_index = -4
	parent.add_child(s)
	AudioMan.play("seal")
	return s

func _process(delta: float) -> void:
	anim += delta
	queue_redraw()
	match phase:
		"arming":
			arm_t -= delta
			if arm_t <= 0.0:
				phase = "active"
				_capture()
				FX.ring(global_position, Color(0.95, 0.85, 0.5), radius * 0.3, radius, 0.25)
		"active":
			duration -= delta
			recheck -= delta
			if recheck <= 0.0:
				recheck = 0.25
				_capture()
			if duration <= 0.0:
				phase = "fade"
		"fade":
			modulate.a -= delta * 4.0
			if modulate.a <= 0.0:
				queue_free()

func _capture() -> void:
	var player := get_tree().get_first_node_in_group("player")
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("dead") or e.get("passive"):
			continue
		if bool(e.get("unbindable")):
			continue
		if global_position.distance_to(e.global_position) <= radius + float(e.get("hit_radius")):
			if float(e.get("bound_t")) <= 0.0:
				captured += 1
				e.call("bind_for", duration)
				e.call("take_hit", pulse_dmg, global_position, 0.0, 0.5, {})
				if player and RunState.has_mod("seal_heal"):
					player.call("heal", RunState.mod("seal_heal"))

func _draw() -> void:
	var gold := Color(0.95, 0.85, 0.5)
	var alpha := 0.9 if phase == "active" else 0.45
	gold.a = alpha * modulate.a
	var r := radius * (1.0 if phase != "arming" else 0.5 + 0.5 * (1.0 - arm_t / 0.35))
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, gold, 3.0)
	draw_arc(Vector2.ZERO, r * 0.82, 0, TAU, 40, gold, 1.5)
	# rotating rune ticks
	for i in 12:
		var a := TAU * float(i) / 12.0 + anim * 0.8
		var p1 := Vector2.from_angle(a) * r * 0.86
		var p2 := Vector2.from_angle(a) * r * 0.96
		draw_line(p1, p2, gold, 2.0)
	# inner triangle, slowly counter-rotating
	var tri := PackedVector2Array()
	for i in 3:
		tri.append(Vector2.from_angle(TAU * float(i) / 3.0 - anim * 0.5) * r * 0.6)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), gold, 1.5)
	var fill := gold
	fill.a = 0.08 * modulate.a
	draw_circle(Vector2.ZERO, r, fill)
