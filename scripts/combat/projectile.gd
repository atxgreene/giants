extends Node2D
class_name Projectile
## Generic projectile for both sides. Drawn procedurally by kind:
## "crescent" (holy fire arc), "bolt" (small flame), "star" (corrupted star),
## "shard" (forged blade fragment), "blade" (boss beam), "dart" (homing shard).

var vel := Vector2.ZERO
var dmg := 10.0
var radius := 10.0
var friendly := true
var pierce := false
var life := 3.0
var color := Color.WHITE
var kind := "bolt"
var stagger := 1.0
var kb := 110.0
var homing := 0.0           # radians/sec of turn toward player (enemy darts)
var mark := false           # gabriel: mark on hit
var split := false          # uriel: split into bolts on first impact
var did_split := false
var hit_ids := {}
var spin := 0.0

static func spawn(parent: Node, pos: Vector2, dir: Vector2, cfg: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.position = pos
	p.vel = dir.normalized() * float(cfg.get("speed", 400.0))
	p.dmg = float(cfg.get("dmg", 10.0))
	p.radius = float(cfg.get("radius", 10.0))
	p.friendly = bool(cfg.get("friendly", true))
	p.pierce = bool(cfg.get("pierce", false))
	p.life = float(cfg.get("life", 3.0))
	p.color = cfg.get("color", Color.WHITE)
	p.kind = str(cfg.get("kind", "bolt"))
	p.stagger = float(cfg.get("stagger", 1.0))
	p.kb = float(cfg.get("kb", 110.0))
	p.homing = float(cfg.get("homing", 0.0))
	p.mark = bool(cfg.get("mark", false))
	p.split = bool(cfg.get("split", false))
	p.z_index = 30
	parent.add_child(p)
	return p

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_die()
		return
	if homing > 0.0:
		var player := get_tree().get_first_node_in_group("player")
		if player and not player.get("dead"):
			var want: float = ((player as Node2D).global_position - global_position).angle()
			vel = Vector2.from_angle(rotate_toward(vel.angle(), want, homing * delta)) * vel.length()
	position += vel * delta
	spin += delta * 9.0
	queue_redraw()
	var room := get_tree().get_first_node_in_group("room")
	if room:
		var bounds: Rect2 = room.get("bounds")
		if not bounds.grow(80.0).has_point(global_position):
			_die()
			return
	if friendly:
		_hit_enemies()
	else:
		_hit_player()

func _hit_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("dead"):
			continue
		var eid := e.get_instance_id()
		if hit_ids.has(eid):
			continue
		if global_position.distance_to(e.global_position) <= radius + float(e.get("hit_radius")):
			hit_ids[eid] = true
			var opts := {"mark": mark}
			var player := get_tree().get_first_node_in_group("player")
			if player:
				opts = player.call("hit_opts", {})
				opts["mark"] = mark or bool(opts.get("mark", false))
			e.call("take_hit", dmg, global_position, kb, stagger, opts)
			if player:
				player.call("on_dealt", dmg, e)
			FX.burst(global_position, color, 8, 130.0, 0.35)
			AudioMan.play("bolt")
			if split and not did_split:
				did_split = true
				for off in [-0.5, 0.0, 0.5]:
					Projectile.spawn(get_parent(), global_position,
						Vector2.from_angle(vel.angle() + off),
						{"kind": "bolt", "dmg": dmg * 0.4, "speed": 460.0, "radius": 8.0,
						 "color": Color(1.0, 0.55, 0.2), "life": 0.7, "friendly": true})
			if not pierce:
				_die()
				return

func _hit_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.get("dead"):
		return
	if global_position.distance_to(player.global_position) <= radius + 12.0:
		player.call("take_hit", dmg, global_position)
		_die()

func _die() -> void:
	FX.burst(global_position, color, 5, 90.0, 0.25)
	queue_free()

func _draw() -> void:
	var a := vel.angle()
	match kind:
		"crescent":
			draw_set_transform(Vector2.ZERO, a, Vector2.ONE)
			var glow := color
			glow.a = 0.3
			draw_arc(Vector2.ZERO, radius, -1.3, 1.3, 16, glow, 14.0)
			draw_arc(Vector2.ZERO, radius, -1.2, 1.2, 16, color, 6.0)
			draw_arc(Vector2.ZERO, radius * 0.8, -1.0, 1.0, 12, color.lightened(0.4), 3.0)
		"star":
			draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
			var pts := PackedVector2Array()
			for i in 8:
				var r := radius if i % 2 == 0 else radius * 0.4
				pts.append(Vector2.from_angle(TAU * i / 8.0) * r)
			var glow2 := color
			glow2.a = 0.35
			draw_circle(Vector2.ZERO, radius * 1.5, glow2)
			draw_colored_polygon(pts, color)
		"shard", "blade":
			draw_set_transform(Vector2.ZERO, a, Vector2.ONE)
			var l := radius * (2.6 if kind == "shard" else 3.4)
			draw_colored_polygon(PackedVector2Array([
				Vector2(l, 0), Vector2(-l * 0.4, -radius * 0.5),
				Vector2(-l * 0.7, 0), Vector2(-l * 0.4, radius * 0.5)]), color)
			draw_line(Vector2(-l * 0.6, 0), Vector2(l * 0.85, 0), color.lightened(0.45), 2.0)
		"dart":
			draw_set_transform(Vector2.ZERO, a, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([
				Vector2(radius * 1.8, 0), Vector2(-radius, -radius * 0.6),
				Vector2(-radius, radius * 0.6)]), color)
		_:
			var glow3 := color
			glow3.a = 0.3
			draw_circle(Vector2.ZERO, radius * 1.6, glow3)
			draw_circle(Vector2.ZERO, radius * 0.8, color)
			draw_circle(Vector2.ZERO, radius * 0.4, color.lightened(0.5))
