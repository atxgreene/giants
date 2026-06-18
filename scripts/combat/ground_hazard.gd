extends Node2D
class_name GroundHazard
## Ground areas: corruption pools, forge-fire lanes, and friendly flame
## trails. Telegraphs first (outline), then becomes active and ticks damage.

var kind := "pool"            # "pool" (circle) or "lane" (oriented rect)
var radius := 55.0            # pool radius
var length := 600.0           # lane length
var width := 70.0             # lane width
var angle := 0.0              # lane orientation
var telegraph_t := 0.0
var active_t := 3.0
var dps := 8.0
var tick := 0.0
var friendly := false         # true = damages enemies (Uriel flame trail)
var corrupting := false       # adds corruption to the player on tick
var cleanse := false          # Raphael cleanse zone: soothes the Witness
var convert_pools := false    # Dudael: unmakes nearby corruption pools
var color := Color(0.5, 0.2, 0.6)
var phase := "telegraph"
var anim := 0.0
var enemy_tick_ids := {}

func _ready() -> void:
	add_to_group("hazards")

static func spawn(parent: Node, pos: Vector2, cfg: Dictionary = {}) -> GroundHazard:
	var h := GroundHazard.new()
	h.position = pos
	h.kind = str(cfg.get("kind", "pool"))
	h.radius = float(cfg.get("radius", 55.0))
	h.length = float(cfg.get("length", 600.0))
	h.width = float(cfg.get("width", 70.0))
	h.angle = float(cfg.get("angle", 0.0))
	h.telegraph_t = float(cfg.get("telegraph", 0.0))
	h.active_t = float(cfg.get("active", 3.0))
	h.dps = float(cfg.get("dps", 8.0))
	h.friendly = bool(cfg.get("friendly", false))
	h.corrupting = bool(cfg.get("corrupting", false))
	h.cleanse = bool(cfg.get("cleanse", false))
	h.convert_pools = bool(cfg.get("convert_pools", false))
	h.color = cfg.get("color", Color(0.5, 0.2, 0.6))
	if h.telegraph_t <= 0.0:
		h.phase = "active"
	h.z_index = -5
	parent.add_child(h)
	return h

func neutralize() -> void:
	## Turn a harmful corruption pool into harmless ash (Dudael / Wound ult).
	if friendly:
		return
	corrupting = false
	dps = 0.0
	color = Color(0.55, 0.5, 0.45)

func _process(delta: float) -> void:
	anim += delta
	queue_redraw()
	match phase:
		"telegraph":
			telegraph_t -= delta
			if telegraph_t <= 0.0:
				phase = "active"
				if not friendly:
					AudioMan.play("fire")
		"active":
			active_t -= delta
			tick -= delta
			if tick <= 0.0:
				tick = 0.4
				_apply_tick()
			if active_t <= 0.0:
				phase = "fade"
		"fade":
			modulate.a -= delta * 3.0
			if modulate.a <= 0.0:
				queue_free()

func _contains(point: Vector2) -> bool:
	if kind != "lane":
		return global_position.distance_to(point) <= radius
	var local := (point - global_position).rotated(-angle)
	return absf(local.x) <= length * 0.5 and absf(local.y) <= width * 0.5

func _apply_tick() -> void:
	if friendly:
		var corrupted_bonus := 1.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.get("dead") and _contains(e.global_position):
				# Cleanse zones bite harder against corruption-born foes (hounds).
				var mult := corrupted_bonus
				if cleanse and str(e.get("id")) in ["watcher_hound", "pack_alpha"]:
					mult = 1.8
				e.call("take_hit", dps * 0.4 * mult, global_position, 0.0, 0.2, {})
		if cleanse:
			var player := get_tree().get_first_node_in_group("player")
			if player and not player.get("dead") and _contains(player.global_position):
				RunState.add_corruption(-1.2)
			if convert_pools:
				for h in get_tree().get_nodes_in_group("hazards"):
					if h != self and is_instance_valid(h) and not h.friendly and global_position.distance_to(h.global_position) <= radius + h.radius:
						h.neutralize()
	else:
		var player := get_tree().get_first_node_in_group("player")
		if player and not player.get("dead") and _contains(player.global_position):
			if RunState.has_mod("dot_immune"):
				return
			player.call("take_dot", dps * 0.4)
			if corrupting:
				RunState.add_corruption(1.5)

func _draw() -> void:
	var pulse := 0.75 + 0.25 * sin(anim * 6.0)
	if phase == "telegraph":
		var c := color
		c.a = 0.3 + 0.2 * pulse
		if kind != "lane":
			draw_arc(Vector2.ZERO, radius, 0, TAU, 40, c, 3.0)
			c.a *= 0.4
			draw_circle(Vector2.ZERO, radius, c)
		else:
			draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
			draw_rect(Rect2(-length * 0.5, -width * 0.5, length, width), c, false, 3.0)
			c.a *= 0.4
			draw_rect(Rect2(-length * 0.5, -width * 0.5, length, width), c, true)
	else:
		var c2 := color
		c2.a = 0.55 * pulse * modulate.a
		if kind != "lane":
			draw_circle(Vector2.ZERO, radius, c2)
			c2 = color.lightened(0.3)
			c2.a = 0.5 * modulate.a
			draw_arc(Vector2.ZERO, radius * (0.7 + 0.2 * sin(anim * 4.0)), 0, TAU, 30, c2, 2.5)
		else:
			draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
			draw_rect(Rect2(-length * 0.5, -width * 0.5, length, width), c2, true)
			var flick := color.lightened(0.4)
			flick.a = 0.6 * modulate.a
			for i in 7:
				var fx_x := -length * 0.5 + length * fmod(0.137 * float(i) + anim * 0.35, 1.0)
				var h := width * (0.3 + 0.25 * sin(anim * 9.0 + float(i) * 2.1))
				draw_line(Vector2(fx_x, width * 0.3), Vector2(fx_x, width * 0.3 - h), flick, 3.0)
