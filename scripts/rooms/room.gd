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
	"revelation": {"label": "✶ A HIDDEN DOOR ✶", "color": Color(0.45, 0.85, 1.0)},
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
	var templates: Dictionary = DataDB.rooms.get("templates", {})
	template = templates.get(t_id, {})
	if template.is_empty():
		# Never let a bad/unknown id collapse the room (null name, zero bounds,
		# broken camera). Fall back to a valid arena.
		push_warning("Unknown room template '%s' — falling back to arena_small" % t_id)
		template_id = "arena_small"
		template = templates.get("arena_small", {})
	kind = str(template.get("kind", "combat"))
	var size: Array = template["size"]
	bounds = Rect2(-float(size[0]) * 0.5, -float(size[1]) * 0.5, float(size[0]), float(size[1]))
	var floor_node := FloorLayer.new()
	floor_node.bounds = bounds
	floor_node.room_kind = kind
	floor_node.z_index = -20
	add_child(floor_node)
	_build_walls()
	_build_props()
	_build_atmosphere()
	_build_environment_lights()
	match kind:
		"combat":
			pass # waves start via start_room()
		"miniboss":
			pass
		"boss":
			pass

func _build_environment_lights() -> void:
	# Animated molten cracks in the floor (desert rooms): motion + danger read.
	if kind != "hub":
		var lava := LavaCracks.new()
		lava.bounds = bounds
		lava.z_index = -18  # above the floor (-20), below props/actors
		add_child(lava)
	# Big fixed light sources so the arena is lit by its own fire/starlight.
	if not bool(Game.setting("bloom")):
		return
	if kind == "hub":
		# Steady holy glow over the great seal.
		var seal := FX.make_emissive_light(Color(0.95, 0.85, 0.55), 0.5, 3.2, false)
		seal.position = bounds.get_center()
		add_child(seal)
		return
	# North-corner braziers (matching the drawn brazier flames).
	for bx in [bounds.position.x - 13.0, bounds.end.x + 13.0]:
		var br := FX.make_emissive_light(Color(1.0, 0.5, 0.15), 0.9, 1.7, true)
		br.position = Vector2(bx, bounds.position.y - 108.0)
		add_child(br)
	if kind == "boss":
		# The First Forge: a deep, restless forge-glow fills the arena.
		var forge_glow := FX.make_emissive_light(Color(1.0, 0.4, 0.14), 0.7, 4.0, true)
		forge_glow.position = bounds.get_center()
		add_child(forge_glow)

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

func _build_atmosphere() -> void:
	# Drifting ash storm (desert) or golden dust motes (hub).
	var p := CPUParticles2D.new()
	p.position = bounds.get_center()
	p.amount = clampi(int(bounds.get_area() / 26000.0), 18, 64)
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = bounds.size * 0.55
	p.gravity = Vector2.ZERO
	p.spread = 25.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 3.0
	if kind == "hub":
		p.direction = Vector2(0.15, -1.0)
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 16.0
		p.color = Color(0.9, 0.8, 0.5, 0.13)
	else:
		p.direction = Vector2(-1.0, 0.22)
		p.initial_velocity_min = 18.0
		p.initial_velocity_max = 44.0
		p.color = Color(0.85, 0.5, 0.35, 0.14)
	p.z_index = 28
	add_child(p)

# ============================================================ inner classes

class FloorLayer extends Node2D:
	## 2.5D environment renderer: layered horizon apron, lit diamond tiles,
	## scattered decals, glowing molten fissures, walls with real height and
	## brickwork, edge ambient occlusion, and per-room-type floor inlays.
	var bounds := Rect2()
	var room_kind := "combat"

	func _ready() -> void:
		queue_redraw()

	func _hash01(x: int, y: int) -> float:
		return absf(fmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0))

	func _base_color() -> Color:
		match room_kind:
			"boss":
				return Color(0.33, 0.15, 0.13)
			"vision", "shrine":
				return Color(0.37, 0.21, 0.2)
			"hub":
				return Color(0.16, 0.17, 0.23)
			_:
				return Color(0.46, 0.23, 0.16)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(bounds.size.x * 7.0 + bounds.size.y) + room_kind.hash() % 1000
		_draw_apron(rng)
		_draw_tiles()
		_draw_decals(rng)
		if room_kind != "hub":
			_draw_cracks(rng)
		_draw_inlay()
		_draw_walls()
		_draw_ao()

	func _draw_apron(rng: RandomNumberGenerator) -> void:
		var apron := bounds.grow(230.0)
		if room_kind == "hub":
			# The void between worlds: deep blue, stars, drifting rock shards.
			draw_rect(apron, Color(0.03, 0.03, 0.07))
			for i in 90:
				var p := Vector2(
					apron.position.x + _hash01(i, 7) * apron.size.x,
					apron.position.y + _hash01(i, 13) * apron.size.y)
				if not bounds.grow(30.0).has_point(p):
					draw_circle(p, 1.0 + _hash01(i, 3) * 1.2, Color(0.75, 0.8, 1.0, 0.25 + 0.3 * _hash01(i, 5)))
			for i in 7:
				var sp := Vector2(
					apron.position.x + _hash01(i, 21) * apron.size.x,
					apron.position.y + _hash01(i, 33) * apron.size.y)
				if bounds.grow(70.0).has_point(sp):
					continue
				var s := 10.0 + _hash01(i, 9) * 18.0
				draw_colored_polygon(PackedVector2Array([
					sp + Vector2(0, -s), sp + Vector2(s * 0.8, -s * 0.2),
					sp + Vector2(s * 0.4, s * 0.7), sp + Vector2(-s * 0.6, s * 0.5),
					sp + Vector2(-s * 0.7, -s * 0.3)]), Color(0.09, 0.09, 0.14))
			return
		# Desert horizon: dark sand, distant basalt range to the north,
		# moonlit dune bands elsewhere.
		draw_rect(apron, Color(0.11, 0.055, 0.06))
		# basalt mountains (top apron)
		var mx := apron.position.x
		while mx < apron.end.x:
			var mw := rng.randf_range(90.0, 190.0)
			var mh := rng.randf_range(50.0, 120.0)
			var base_y := bounds.position.y - 64.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(mx, base_y), Vector2(mx + mw * 0.5, base_y - mh), Vector2(mx + mw, base_y)]),
				Color(0.06, 0.05, 0.08))
			# moon rim on the lit (left) slope
			draw_line(Vector2(mx, base_y), Vector2(mx + mw * 0.5, base_y - mh), Color(0.45, 0.3, 0.3, 0.35), 1.5)
			mx += mw * rng.randf_range(0.6, 0.85)
		# dune bands (bottom + sides)
		for band in 3:
			var y := bounds.end.y + 60.0 + band * 55.0
			var pts := PackedVector2Array()
			pts.append(Vector2(apron.position.x, apron.end.y))
			var x := apron.position.x
			while x <= apron.end.x:
				pts.append(Vector2(x, y + sin(x * 0.013 + band * 2.0) * 16.0))
				x += 60.0
			pts.append(Vector2(apron.end.x, apron.end.y))
			draw_colored_polygon(pts, Color(0.16 - band * 0.03, 0.08 - band * 0.015, 0.075 - band * 0.012))

	func _draw_tiles() -> void:
		var tw := 64.0
		var th := 32.0
		var cols := int(bounds.size.x / tw) + 2
		var rows := int(bounds.size.y / (th * 0.5)) + 2
		var base := _base_color()
		var center := bounds.get_center()
		for gy in rows:
			for gx in cols:
				var off_x := tw * 0.5 if gy % 2 == 1 else 0.0
				var cx := bounds.position.x + gx * tw + off_x
				var cy := bounds.position.y + gy * th * 0.5
				if cx > bounds.end.x + tw or cy > bounds.end.y + th:
					continue
				var v := _hash01(gx, gy)
				var c := base.lightened(v * 0.12)
				if v > 0.93:
					c = base.darkened(0.18)
				# lighting: bright near the arena heart, falling off to the walls
				var dx := absf(cx - center.x) / (bounds.size.x * 0.5)
				var dy := absf(cy - center.y) / (bounds.size.y * 0.5)
				var edge := clampf(maxf(dx, dy), 0.0, 1.0)
				c = c.darkened(edge * edge * 0.34)
				c = c.lightened((1.0 - edge) * 0.05)
				var top := Vector2(cx, cy - th * 0.5)
				var rgt := Vector2(cx + tw * 0.5, cy)
				var bot := Vector2(cx, cy + th * 0.5)
				var lft := Vector2(cx - tw * 0.5, cy)
				draw_colored_polygon(PackedVector2Array([top, rgt, bot, lft]), c)
				# Subtle bevel on a scattered subset: lit upper edges, shadowed
				# lower edges — fakes height/grout so the floor isn't flat.
				if v < 0.30:
					draw_line(top, rgt, c.lightened(0.22), 1.0)
					draw_line(top, lft, c.lightened(0.12), 1.0)
				elif v > 0.80:
					draw_line(bot, rgt, c.darkened(0.28), 1.0)
					draw_line(bot, lft, c.darkened(0.28), 1.0)

	func _draw_decals(rng: RandomNumberGenerator) -> void:
		# Pebbles, bone chips, and faint sand drifts.
		for i in 16:
			var p := Vector2(
				rng.randf_range(bounds.position.x + 60.0, bounds.end.x - 60.0),
				rng.randf_range(bounds.position.y + 50.0, bounds.end.y - 50.0))
			var k := rng.randf()
			if k < 0.5:
				var s := rng.randf_range(2.0, 4.5)
				draw_colored_polygon(PackedVector2Array([
					p + Vector2(0, -s), p + Vector2(s, s * 0.6), p + Vector2(-s, s * 0.6)]),
					_base_color().darkened(0.38))
			elif k < 0.8 and room_kind != "hub":
				draw_arc(p, rng.randf_range(5.0, 10.0), PI * 1.1, PI * 1.8, 6, Color(0.8, 0.76, 0.66, 0.5), 2.0)
			else:
				draw_set_transform(p, rng.randf_range(-0.4, 0.4), Vector2(1.0, 0.35))
				draw_circle(Vector2.ZERO, rng.randf_range(14.0, 30.0), Color(1, 1, 1, 0.03))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_cracks(rng: RandomNumberGenerator) -> void:
		for i in 4:
			var p := Vector2(
				rng.randf_range(bounds.position.x + 100.0, bounds.end.x - 100.0),
				rng.randf_range(bounds.position.y + 80.0, bounds.end.y - 80.0))
			Painter.glow(self, p, 56.0, Color(1.0, 0.42, 0.1, 0.2), 3)
			for seg in 5:
				var q: Vector2 = p + Vector2(rng.randf_range(-70, 70), rng.randf_range(-40, 40))
				draw_line(p, q, Color(0.06, 0.03, 0.03, 0.8), 7.0)
				draw_line(p, q, Color(1.0, 0.42, 0.1, 0.7), 3.2)
				draw_line(p, q, Color(1.0, 0.78, 0.35, 0.8), 1.3)
				p = q

	func _draw_inlay() -> void:
		var center := bounds.get_center()
		match room_kind:
			"hub":
				# The great seal of the Watchtower, inlaid in the floor.
				var gold := Color(0.85, 0.72, 0.38, 0.28)
				Painter.rune_ring(self, center, 200.0, gold, 16, 0.0, 2.0)
				draw_arc(center, 168.0, 0, TAU, 48, gold, 1.2)
				var tri := PackedVector2Array()
				for i in 3:
					tri.append(center + Vector2.from_angle(TAU * i / 3.0 - PI * 0.5) * 140.0)
				draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), gold, 1.5)
				for i in 24:
					draw_circle(center + Vector2.from_angle(TAU * i / 24.0) * 184.0, 2.0, gold)
				Painter.glow(self, center, 120.0, Color(0.85, 0.72, 0.38, 0.1), 3)
			"boss":
				var iron := Color(0.9, 0.4, 0.15, 0.16)
				Painter.rune_ring(self, center, 250.0, iron, 12, 0.4, 2.0)
				draw_arc(center, 218.0, 0, TAU, 48, iron, 1.0)
			"vision", "shrine":
				var lapis := Color(0.45, 0.65, 1.0, 0.16)
				Painter.rune_ring(self, center, 150.0, lapis, 10, 0.0, 1.5)

	func _draw_walls() -> void:
		var lit := Color(0.2, 0.17, 0.22)      # sun-facing cap
		var face := Color(0.115, 0.1, 0.13)    # vertical south face
		var dark := Color(0.075, 0.065, 0.09)
		var seam := Color(0.05, 0.045, 0.06)
		var rim := Color(0.95, 0.55, 0.25, 0.2)
		var x0 := bounds.position.x
		var y0 := bounds.position.y
		var x1 := bounds.end.x
		var y1 := bounds.end.y
		# NORTH wall: tall face with brickwork + lit cap.
		var wh := 58.0
		draw_rect(Rect2(x0 - 26, y0 - wh - 14, bounds.size.x + 52, wh), face)
		draw_rect(Rect2(x0 - 26, y0 - wh - 14, bounds.size.x + 52, wh * 0.45), face.lightened(0.07))
		draw_rect(Rect2(x0 - 26, y0 - 18, bounds.size.x + 52, 4), dark)
		# brick seams
		var bx := x0 - 26.0
		var row2_off := 34.0
		while bx < x1 + 26.0:
			draw_line(Vector2(bx, y0 - wh - 14), Vector2(bx, y0 - wh * 0.5 - 14), seam, 1.5)
			draw_line(Vector2(bx + row2_off, y0 - wh * 0.5 - 14), Vector2(bx + row2_off, y0 - 16), seam, 1.5)
			bx += 68.0
		draw_line(Vector2(x0 - 26, y0 - wh * 0.5 - 14), Vector2(x1 + 26, y0 - wh * 0.5 - 14), seam, 1.5)
		# cap + merlons + ember rim light
		draw_rect(Rect2(x0 - 26, y0 - wh - 24, bounds.size.x + 52, 12), lit)
		var mx := x0
		while mx < x1 - 30.0:
			draw_rect(Rect2(mx, y0 - wh - 34, 22, 12), lit)
			draw_rect(Rect2(mx, y0 - wh - 34, 22, 3), lit.lightened(0.15))
			mx += 96.0
		draw_rect(Rect2(x0 - 26, y0 - 15, bounds.size.x + 52, 2.5), rim)
		# EAST / WEST walls: slim faces with seams.
		for side in 2:
			var wx := x0 - 26.0 if side == 0 else x1
			draw_rect(Rect2(wx, y0 - 14, 26, bounds.size.y + 14), face if side == 1 else dark)
			draw_rect(Rect2(wx + (20 if side == 0 else 0), y0 - 14, 6, bounds.size.y + 14), dark if side == 0 else face.lightened(0.06))
			var sy := y0
			while sy < y1:
				draw_line(Vector2(wx, sy), Vector2(wx + 26, sy), seam, 1.2)
				sy += 52.0
		# SOUTH wall: low parapet so combat stays readable.
		draw_rect(Rect2(x0 - 26, y1, bounds.size.x + 52, 20), face.lightened(0.05))
		draw_rect(Rect2(x0 - 26, y1, bounds.size.x + 52, 5), lit)
		draw_rect(Rect2(x0 - 26, y1 + 20, bounds.size.x + 52, 6), dark)
		# corner pillars with ember braziers (north corners)
		for cx in [x0 - 30.0, x1 - 4.0]:
			draw_rect(Rect2(cx, y0 - wh - 40, 34, wh + 40), dark.lightened(0.04))
			draw_rect(Rect2(cx - 3, y0 - wh - 46, 40, 10), lit)
			if room_kind != "hub":
				Painter.glow(self, Vector2(cx + 17, y0 - wh - 50), 16.0, Color(1.0, 0.5, 0.15, 0.5), 3)
				draw_circle(Vector2(cx + 17, y0 - wh - 50), 4.0, Color(1.0, 0.75, 0.3))

	func _draw_ao() -> void:
		# Soft ambient occlusion where floor meets walls.
		var steps := [[0.0, 0.16], [10.0, 0.09], [20.0, 0.045]]
		for s in steps:
			var inset: float = s[0]
			var a: float = s[1]
			var c := Color(0, 0, 0, a)
			draw_rect(Rect2(bounds.position.x, bounds.position.y + inset, bounds.size.x, 10), c)
			draw_rect(Rect2(bounds.position.x, bounds.end.y - inset - 10, bounds.size.x, 10), c)
			draw_rect(Rect2(bounds.position.x + inset, bounds.position.y, 10, bounds.size.y), c)
			draw_rect(Rect2(bounds.end.x - inset - 10, bounds.position.y, 10, bounds.size.y), c)
		# North wall casts a soft shadow down onto the floor (walls have height,
		# light reads from above) — grounds the room.
		var nsh := 70.0
		for i in 14:
			var k := float(i) / 14.0
			draw_rect(Rect2(bounds.position.x, bounds.position.y + k * nsh, bounds.size.x, nsh / 14.0 + 1.0),
				Color(0.02, 0.01, 0.03, 0.22 * (1.0 - k)))
		# Corner occlusion: darken the four corners so the floor reads as a pit.
		for cpt in [bounds.position, Vector2(bounds.end.x, bounds.position.y),
				Vector2(bounds.position.x, bounds.end.y), bounds.end]:
			for r in 3:
				draw_circle(cpt, 110.0 - float(r) * 30.0, Color(0, 0, 0, 0.05))

class LavaCracks extends Node2D:
	## A few animated molten fissures across the floor — pulsing glow plus a
	## bright "flow" highlight travelling along each crack. Only a handful of
	## cracks, so redrawing every frame is cheap.
	var bounds := Rect2()
	var t := 0.0
	var cracks: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(bounds.size.x * 13.0 + bounds.size.y * 7.0)
		var n := clampi(int(bounds.get_area() / 150000.0), 2, 4)
		for i in n:
			var p := Vector2(
				rng.randf_range(bounds.position.x + 130.0, bounds.end.x - 130.0),
				rng.randf_range(bounds.position.y + 110.0, bounds.end.y - 110.0))
			var pts := PackedVector2Array([p])
			var dir := Vector2.from_angle(rng.randf() * TAU)
			for seg in rng.randi_range(4, 6):
				dir = dir.rotated(rng.randf_range(-0.8, 0.8)).normalized()
				p += dir * rng.randf_range(34.0, 62.0)
				pts.append(p)
			cracks.append(pts)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		for ci in cracks.size():
			var pts: PackedVector2Array = cracks[ci]
			var last := pts.size() - 1
			if last < 1:
				continue
			var pulse := 0.55 + 0.45 * sin(t * 2.0 + float(ci) * 1.7)
			for i in last:
				draw_line(pts[i], pts[i + 1], Color(0.05, 0.02, 0.02, 0.85), 7.0)
				draw_line(pts[i], pts[i + 1], Color(1.0, 0.42, 0.1, 0.5 * pulse), 3.4)
				draw_line(pts[i], pts[i + 1], Color(1.0, 0.8, 0.4, 0.6 * pulse), 1.3)
			# travelling molten flow highlight
			var fpos := fmod(t * 0.5 + float(ci) * 0.3, 1.0) * float(last)
			var seg := clampi(int(fpos), 0, last - 1)
			var fp: Vector2 = pts[seg].lerp(pts[seg + 1], fpos - float(seg))
			draw_circle(fp, 3.5 + 2.0 * pulse, Color(1.0, 0.9, 0.5, 0.7))

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
	var anim_t := 0.0
	var obstacle_radius := 0.0

	func _process(delta: float) -> void:
		# Only the forge animates (heat shimmer); others are drawn once.
		if kind == "forge":
			anim_t += delta
			queue_redraw()

	func _draw_heat_shimmer() -> void:
		# Cheap procedural heat haze rising off the forge — sells the heat
		# without a screen-space shader.
		for i in 5:
			var ph := anim_t * 1.6 + float(i) * 1.3
			var rise := fmod(anim_t * 26.0 + float(i) * 13.0, 46.0)
			var x := sin(ph) * 12.0 + (float(i) - 2.0) * 6.0
			var y := -22.0 - rise
			var a := 0.10 * (1.0 - rise / 46.0)
			draw_circle(Vector2(x, y), 5.0 + 2.0 * sin(ph * 1.7), Color(1.0, 0.7, 0.4, a))

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
			# Make it known to the enemy navigation layer so AI steers around it
			# instead of grinding against the collider.
			obstacle_radius = 30.0 if kind == "forge" else 24.0
			add_to_group("obstacles")
		_add_emissive_light()
		queue_redraw()

	func _add_emissive_light() -> void:
		# Emissive props light the floor around them (HD-2D). Gated by the Bloom
		# setting; additive, so it only ever brightens.
		if not bool(Game.setting("bloom")):
			return
		match kind:
			"forge":
				var l := FX.make_emissive_light(Color(1.0, 0.5, 0.16), 1.0, 1.7, true)
				l.position = Vector2(0, -14)
				add_child(l)
			"crack":
				var l2 := FX.make_emissive_light(Color(1.0, 0.45, 0.12), 0.7, 1.3, true)
				add_child(l2)
			"starfall":
				var l3 := FX.make_emissive_light(Color(0.5, 0.8, 1.0), 0.75, 1.4, false)
				l3.position = Vector2(0, -12)
				add_child(l3)
			"idol":
				var l4 := FX.make_emissive_light(Color(0.95, 0.3, 0.2), 0.35, 0.8, true)
				l4.position = Vector2(0, -50)
				add_child(l4)

	const SHADOW_R := {"bones": 22.0, "idol": 15.0, "forge": 27.0, "rack": 21.0,
		"altar_broken": 26.0, "starfall": 13.0}

	func _draw() -> void:
		if kind != "crack" and SHADOW_R.has(kind):
			Painter.shadow(self, SHADOW_R[kind], 2.0, 0.3)
		# Drop-in prop art (assets/props/<kind>.png) renders instead of the
		# procedural shape if present — no room-code changes needed to add art.
		var tex: Texture2D = Assets.prop_texture(kind)
		if tex != null:
			var sz := tex.get_size()
			draw_texture(tex, Vector2(-sz.x * 0.5, -sz.y))  # feet at origin
			if kind == "forge":
				_draw_heat_shimmer()
			return
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
				Painter.glow(self, Vector2(0, -15), 30.0, Color(1.0, 0.45, 0.12, 0.4), 3)
				var ember := Color(1.0, 0.45, 0.12, 0.85)
				draw_rect(Rect2(-12, -22, 24, 14), ember)
				draw_rect(Rect2(-8, -19, 16, 8), Color(1.0, 0.75, 0.3, 0.9))
				_draw_heat_shimmer()
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
				Painter.glow(self, Vector2(0, -10), 26.0, Color(0.45, 0.75, 1.0, 0.45), 3)
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
