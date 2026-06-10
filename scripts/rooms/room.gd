extends Node2D
class_name RoomNode
## One room of the Desert of Azazel. Builds an isometric diamond-tile floor,
## boundary walls, scattered props, enemy waves, and exit gates with reward
## previews. The room node itself is the y-sorted world layer.

signal room_cleared
signal gate_entered(reward: String)

const REWARD_INFO := {
	"blessing": {"label": "Archangel Blessing", "color": Color(0.95, 0.85, 0.5)},
	"heal": {"label": "Healing Fountain", "color": Color(0.5, 0.9, 0.6)},
	"currency": {"label": "Seals of Witness", "color": Color(0.8, 0.6, 0.3)},
	"codex": {"label": "Codex Fragment", "color": Color(0.45, 0.75, 1.0)},
	"relic": {"label": "Relic", "color": Color(0.7, 0.5, 0.9)},
	"weapon": {"label": "Weapon Fire", "color": Color(1.0, 0.55, 0.2)},
	"forbidden": {"label": "FORBIDDEN KNOWLEDGE", "color": Color(0.85, 0.2, 0.25)},
	"advance": {"label": "Onward", "color": Color(0.8, 0.8, 0.8)},
	"miniboss": {"label": "The Grave of the Half-Buried", "color": Color(0.85, 0.6, 0.35)},
	"boss": {"label": "The First Forge", "color": Color(0.9, 0.3, 0.2)},
	"none": {"label": "", "color": Color(0.8, 0.8, 0.8)}
}

var template: Dictionary = {}
var template_id := ""
var bounds := Rect2()
var kind := "combat"
var wave_idx := -1
var alive := 0
var cleared := false
var gates: Array = []
var gates_open := false
var spawn_queue: Array = []
var spawn_tick := 0.0

func _ready() -> void:
	add_to_group("room")
	y_sort_enabled = true

func build(t_id: String) -> void:
	template_id = t_id
	template = DataDB.rooms["templates"][t_id]
	kind = str(template["kind"])
	var size: Array = template["size"]
	bounds = Rect2(-float(size[0]) * 0.5, -float(size[1]) * 0.5, float(size[0]), float(size[1]))
	var floor_node := FloorLayer.new()
	floor_node.bounds = bounds
	floor_node.room_kind = kind
	floor_node.z_index = -20
	add_child(floor_node)
	_build_walls()
	_build_props()
	match kind:
		"combat":
			pass # waves start via start_room()
		"miniboss":
			pass
		"boss":
			pass

func player_spawn() -> Vector2:
	return Vector2(bounds.position.x + 110.0, bounds.get_center().y)

func start_room() -> void:
	match kind:
		"combat":
			_next_wave()
		"miniboss":
			var g := EnemyBase.create("half_buried_giant")
			g.position = Vector2(bounds.get_center().x + bounds.size.x * 0.18, bounds.position.y + 170.0)
			g.died.connect(_on_enemy_died)
			alive = 1
			add_child(g)
			AudioMan.play("roar")
		"boss":
			var b := EnemyBase.create("first_blade")
			b.position = Vector2(bounds.get_center().x + bounds.size.x * 0.22, bounds.get_center().y)
			add_child(b)
			alive = 1
			# boss clears the run itself via on_boss_defeated
		_:
			_set_cleared(false)

func _physics_process(delta: float) -> void:
	if not spawn_queue.is_empty():
		spawn_tick -= delta
		if spawn_tick <= 0.0:
			spawn_tick = 0.12
			_spawn_one(spawn_queue.pop_front())
	if gates_open:
		var player := get_tree().get_first_node_in_group("player")
		if player and not player.get("dead"):
			for g in gates:
				if g.position.distance_to(player.position) < 52.0:
					gates_open = false
					gate_entered.emit(g.reward)
					return

# ----------------------------------------------------------------- waves

func _next_wave() -> void:
	wave_idx += 1
	var waves: Array = template.get("waves", [])
	if wave_idx >= waves.size():
		_set_cleared(true)
		return
	var wave: Array = waves[wave_idx]
	for spec in wave:
		for i in int(spec["count"]):
			spawn_queue.append(str(spec["type"]))
	alive += spawn_queue.size()

func _spawn_one(enemy_id: String) -> void:
	var e := EnemyBase.create(enemy_id)
	e.position = _find_spawn_pos()
	e.died.connect(_on_enemy_died)
	add_child(e)
	FX.burst(e.position, Color(0.6, 0.3, 0.5), 10, 120.0, 0.4)

func _find_spawn_pos() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	for attempt in 24:
		var p := Vector2(
			randf_range(bounds.position.x + 90.0, bounds.end.x - 90.0),
			randf_range(bounds.position.y + 90.0, bounds.end.y - 90.0))
		if player == null or p.distance_to(player.position) > 230.0:
			return p
	return bounds.get_center()

func _on_enemy_died(_e) -> void:
	alive -= 1
	if alive <= 0 and spawn_queue.is_empty() and not cleared:
		if kind == "combat":
			_next_wave()
		elif kind == "miniboss":
			_set_cleared(true)

func _set_cleared(was_combat: bool) -> void:
	if cleared:
		return
	cleared = true
	if was_combat:
		AudioMan.play("gate")
	room_cleared.emit()

func force_clear() -> void:
	_set_cleared(false)

# ----------------------------------------------------------------- gates

func open_gates(options: Array) -> void:
	# options: Array of reward type strings
	var n := options.size()
	for i in n:
		var g := Gate.new()
		g.reward = options[i]
		var info: Dictionary = REWARD_INFO.get(options[i], REWARD_INFO["none"])
		g.color = info["color"]
		g.label_text = info["label"]
		var spread := float(i) - float(n - 1) * 0.5
		g.position = Vector2(bounds.end.x - 46.0, bounds.get_center().y + spread * 170.0)
		gates.append(g)
		add_child(g)
	gates_open = true
	AudioMan.play("gate")

# ----------------------------------------------------------------- interact points

func add_interact_point(pos: Vector2, prompt: String, style: String, callback: Callable) -> Node2D:
	var p := InteractPoint.new()
	p.position = pos
	p.prompt = prompt
	p.style = style
	p.callback = callback
	add_child(p)
	return p

# ----------------------------------------------------------------- build

func _build_walls() -> void:
	var thick := 60.0
	var specs := [
		Rect2(bounds.position.x - thick, bounds.position.y - thick, bounds.size.x + thick * 2.0, thick),
		Rect2(bounds.position.x - thick, bounds.end.y, bounds.size.x + thick * 2.0, thick),
		Rect2(bounds.position.x - thick, bounds.position.y, thick, bounds.size.y),
		Rect2(bounds.end.x, bounds.position.y, thick, bounds.size.y)
	]
	for r in specs:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		body.position = r.get_center()
		body.add_child(cs)
		add_child(body)

func _build_props() -> void:
	var list: Array = template.get("props", [])
	var spawn := player_spawn()
	for prop_kind in list:
		for attempt in 16:
			var p := Vector2(
				randf_range(bounds.position.x + 120.0, bounds.end.x - 150.0),
				randf_range(bounds.position.y + 110.0, bounds.end.y - 110.0))
			if p.distance_to(spawn) > 180.0 and p.distance_to(bounds.get_center()) > 110.0:
				var prop := PropNode.new()
				prop.kind = str(prop_kind)
				prop.position = p
				add_child(prop)
				break

# ============================================================ inner classes

class FloorLayer extends Node2D:
	var bounds := Rect2()
	var room_kind := "combat"

	func _ready() -> void:
		queue_redraw()

	func _hash01(x: int, y: int) -> float:
		var h := fmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)
		return absf(h)

	func _draw() -> void:
		# Apron of darker sand beyond the walls
		var apron := bounds.grow(170.0)
		draw_rect(apron, Color(0.04, 0.04, 0.08) if room_kind == "hub" else Color(0.13, 0.07, 0.07))
		# Iso diamond tiles
		var tw := 64.0
		var th := 32.0
		var cols := int(bounds.size.x / tw) + 2
		var rows := int(bounds.size.y / (th * 0.5)) + 2
		var base := Color(0.45, 0.22, 0.16)
		if room_kind == "boss":
			base = Color(0.32, 0.15, 0.13)
		elif room_kind == "vision" or room_kind == "shrine":
			base = Color(0.36, 0.21, 0.2)
		elif room_kind == "hub":
			base = Color(0.15, 0.16, 0.22)
		for gy in rows:
			for gx in cols:
				var off_x := tw * 0.5 if gy % 2 == 1 else 0.0
				var cx := bounds.position.x + gx * tw + off_x
				var cy := bounds.position.y + gy * th * 0.5
				if cx > bounds.end.x + tw or cy > bounds.end.y + th:
					continue
				var v := _hash01(gx, gy)
				var c := base.lightened(v * 0.13)
				if v > 0.93:
					c = base.darkened(0.2)
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx, cy - th * 0.5), Vector2(cx + tw * 0.5, cy),
					Vector2(cx, cy + th * 0.5), Vector2(cx - tw * 0.5, cy)]), c)
		# Molten crack veins
		var rng := RandomNumberGenerator.new()
		rng.seed = int(bounds.size.x * 7.0 + bounds.size.y)
		for i in 4:
			var p := Vector2(
				rng.randf_range(bounds.position.x + 100.0, bounds.end.x - 100.0),
				rng.randf_range(bounds.position.y + 80.0, bounds.end.y - 80.0))
			var glow := Color(1.0, 0.4, 0.1, 0.5)
			for seg in 5:
				var q: Vector2 = p + Vector2(rng.randf_range(-70, 70), rng.randf_range(-40, 40))
				draw_line(p, q, glow, 3.0)
				draw_line(p, q, Color(1.0, 0.7, 0.3, 0.25), 6.0)
				p = q
		# Boundary wall blocks (basalt)
		var basalt := Color(0.1, 0.09, 0.11)
		var wall_h := 26.0
		draw_rect(Rect2(bounds.position.x - 24, bounds.position.y - wall_h - 12, bounds.size.x + 48, wall_h), basalt)
		draw_rect(Rect2(bounds.position.x - 24, bounds.end.y, bounds.size.x + 48, wall_h), basalt)
		draw_rect(Rect2(bounds.position.x - 24, bounds.position.y - wall_h - 12, 24, bounds.size.y + wall_h * 2 + 12), basalt)
		draw_rect(Rect2(bounds.end.x, bounds.position.y - wall_h - 12, 24, bounds.size.y + wall_h * 2 + 12), basalt)
		var rim := Color(0.85, 0.5, 0.2, 0.18)
		draw_rect(Rect2(bounds.position.x - 24, bounds.position.y - 14, bounds.size.x + 48, 3), rim)

class Gate extends Node2D:
	var reward := "advance"
	var color := Color.WHITE
	var label_text := ""
	var anim := 0.0

	func _ready() -> void:
		z_index = -2
		var l := Label.new()
		l.text = label_text
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", color)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 5)
		l.position = Vector2(-90, 30)
		l.size = Vector2(180, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(l)

	func _process(delta: float) -> void:
		anim += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.7 + 0.3 * sin(anim * 4.0)
		# pillars
		var stone := Color(0.16, 0.14, 0.18)
		draw_rect(Rect2(-30, -54, 10, 64), stone)
		draw_rect(Rect2(20, -54, 10, 64), stone)
		draw_arc(Vector2(0, -52), 28.0, PI, TAU, 16, stone, 8.0)
		# portal glow
		var g := color
		g.a = 0.3 * pulse
		draw_rect(Rect2(-20, -48, 40, 58), g)
		g.a = 0.9
		draw_arc(Vector2(0, -52), 24.0, PI, TAU, 16, g, 2.5)
		# reward sigil
		draw_circle(Vector2(0, -20), 8.0 + 2.0 * pulse, g)
		draw_circle(Vector2(0, -20), 4.0, Color(1, 1, 1, 0.8))

class InteractPoint extends Node2D:
	var prompt := "Interact"
	var style := "shrine"     # shrine | vision | fountain
	var callback := Callable()
	var used := false
	var anim := 0.0

	func _ready() -> void:
		add_to_group("interact")

	func get_prompt() -> String:
		return prompt if not used else ""

	func try_interact(_player) -> void:
		if used or not callback.is_valid():
			return
		used = true
		callback.call()
		queue_redraw()

	func _process(delta: float) -> void:
		anim += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.6 + 0.4 * sin(anim * 3.0)
		match style:
			"vision":
				var c := Color(0.45, 0.75, 1.0, 0.35 + 0.2 * pulse)
				if used:
					c.a = 0.1
				draw_circle(Vector2(0, -24), 16.0 + 3.0 * pulse, c)
				draw_circle(Vector2(0, -24), 8.0, Color(0.8, 0.92, 1.0, 0.5 if not used else 0.1))
				for i in 5:
					var a := TAU * i / 5.0 + anim
					draw_line(Vector2.from_angle(a) * 20.0 + Vector2(0, -24),
						Vector2.from_angle(a) * 28.0 + Vector2(0, -24), c, 1.5)
			_:
				var stone := Color(0.2, 0.17, 0.2)
				draw_rect(Rect2(-16, -10, 32, 12), stone)
				draw_rect(Rect2(-12, -30, 24, 22), stone.lightened(0.1))
				var g := Color(0.7, 0.5, 0.9, (0.6 if not used else 0.12) * pulse)
				draw_circle(Vector2(0, -36), 7.0, g)

class PropNode extends Node2D:
	var kind := "bones"
	var seed_v := 0.0

	func _ready() -> void:
		seed_v = randf() * 10.0
		if kind == "crack":
			z_index = -10
		if kind in ["idol", "forge", "altar_broken"]:
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var cs := CollisionShape2D.new()
			var sh := CircleShape2D.new()
			sh.radius = 20.0
			cs.shape = sh
			body.add_child(cs)
			add_child(body)
		queue_redraw()

	func _draw() -> void:
		match kind:
			"bones":
				var bone := Color(0.85, 0.8, 0.72)
				# giant rib arcs
				draw_arc(Vector2(0, 0), 38.0, PI * 1.05, PI * 1.75, 12, bone, 5.0)
				draw_arc(Vector2(24, 4), 30.0, PI * 1.1, PI * 1.7, 10, bone.darkened(0.1), 4.0)
				draw_arc(Vector2(-22, 6), 26.0, PI * 1.15, PI * 1.8, 10, bone.darkened(0.15), 4.0)
				draw_circle(Vector2(-40, 8), 7.0, bone.darkened(0.2))
			"idol":
				var bronze := Color(0.55, 0.38, 0.18)
				draw_rect(Rect2(-14, -6, 28, 10), Color(0.2, 0.16, 0.14))
				draw_colored_polygon(PackedVector2Array([
					Vector2(0, -52), Vector2(10, -36), Vector2(8, -4), Vector2(-8, -4), Vector2(-10, -36)]), bronze)
				draw_circle(Vector2(0, -56), 7.0, bronze.lightened(0.15))
				draw_circle(Vector2(-2, -57), 1.6, Color(0.9, 0.3, 0.2))
				draw_circle(Vector2(3, -57), 1.6, Color(0.9, 0.3, 0.2))
			"forge":
				var iron := Color(0.13, 0.12, 0.14)
				draw_rect(Rect2(-26, -34, 52, 40), iron)
				draw_rect(Rect2(-20, -46, 40, 12), iron.lightened(0.08))
				var ember := Color(1.0, 0.45, 0.12, 0.8)
				draw_rect(Rect2(-12, -22, 24, 14), ember)
				draw_rect(Rect2(-8, -19, 16, 8), Color(1.0, 0.75, 0.3, 0.9))
			"rack":
				var wood := Color(0.3, 0.2, 0.14)
				draw_rect(Rect2(-24, -4, 48, 6), wood)
				draw_rect(Rect2(-22, -36, 4, 34), wood)
				draw_rect(Rect2(18, -36, 4, 34), wood)
				for i in 3:
					var x := -12.0 + i * 11.0
					draw_line(Vector2(x, -34), Vector2(x + 3, -6), Color(0.6, 0.55, 0.5), 2.5)
			"altar_broken":
				var stone := Color(0.32, 0.28, 0.3)
				draw_rect(Rect2(-30, -12, 60, 16), stone)
				draw_rect(Rect2(-24, -26, 28, 16), stone.lightened(0.08))
				draw_colored_polygon(PackedVector2Array([
					Vector2(8, -26), Vector2(26, -22), Vector2(22, -10), Vector2(6, -12)]), stone.darkened(0.12))
				draw_line(Vector2(-6, -26), Vector2(2, -10), Color(0.1, 0.1, 0.1), 2.0)
			"starfall":
				var glow := Color(0.45, 0.75, 1.0, 0.4)
				draw_circle(Vector2(0, -10), 18.0, glow)
				draw_colored_polygon(PackedVector2Array([
					Vector2(0, -34), Vector2(9, -8), Vector2(0, 0), Vector2(-9, -8)]), Color(0.55, 0.8, 1.0))
				draw_colored_polygon(PackedVector2Array([
					Vector2(10, -22), Vector2(16, -6), Vector2(8, -4)]), Color(0.4, 0.6, 0.95))
			"crack":
				var glow2 := Color(1.0, 0.45, 0.1, 0.5)
				var p := Vector2(-30, 0)
				var pts := [Vector2(-30, 0), Vector2(-10, -8), Vector2(8, 2), Vector2(26, -5), Vector2(40, 4)]
				for i in pts.size() - 1:
					draw_line(pts[i], pts[i + 1], glow2, 4.0)
					draw_line(pts[i], pts[i + 1], Color(1.0, 0.7, 0.3, 0.3), 8.0)
