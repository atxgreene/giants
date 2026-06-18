extends Node
## Combat juice singleton: hit-stop, slow motion, screen shake,
## damage numbers, particle bursts, slash arcs, expanding rings,
## and full-screen flashes. Screens register their world + camera here.

var world: Node2D = null
var camera = null
var _hitstop_lock := false
var _light_tex: GradientTexture2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Shared soft radial texture for Light2D pools (cached). Works on every
## renderer, including the web/mobile GL Compatibility backend where the
## WorldEnvironment glow is unavailable.
func light_texture() -> GradientTexture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.5))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 1.0)
		t.width = 256
		t.height = 256
		_light_tex = t
	return _light_tex

## Make and return an additive warm key-light (a PointLight2D). The caller
## parents it (e.g. the player) so the lit pool follows. Gated by the Bloom
## setting so it can be turned off; additive, so it can never darken.
func make_key_light(color := Color(1.0, 0.86, 0.6), energy := 0.85, scale := 2.6) -> Node:
	var light := PointLight2D.new()
	light.texture = light_texture()
	light.color = color
	light.energy = energy
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.texture_scale = scale
	light.z_index = -8
	return light

func clear_refs() -> void:
	world = null
	camera = null
	Engine.time_scale = 1.0
	_hitstop_lock = false

func _target() -> Node:
	if is_instance_valid(world):
		return world
	return null

func hitstop(dur := 0.05, scale := 0.05) -> void:
	if _hitstop_lock:
		return
	_hitstop_lock = true
	Engine.time_scale = scale
	var t := get_tree().create_timer(dur, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		_hitstop_lock = false)

func slowmo(scale := 0.35, dur := 0.55) -> void:
	if _hitstop_lock:
		return
	_hitstop_lock = true
	Engine.time_scale = scale
	AudioMan.play("whisper")
	var t := get_tree().create_timer(dur, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		_hitstop_lock = false)

func shake(amount: float) -> void:
	if camera != null and is_instance_valid(camera) and Game.setting("screenshake"):
		camera.add_trauma(amount * float(Game.setting("screenshake_amount")))

func damage_number(pos: Vector2, amount: float, color := Color(1, 0.9, 0.6)) -> void:
	if not Game.setting("damage_numbers"):
		return
	var t := _target()
	if t == null:
		return
	var dn := DamageNumber.new()
	dn.text_value = str(int(maxf(amount, 1.0)))
	dn.color = color
	dn.position = pos + Vector2(randf_range(-10, 10), -26)
	t.add_child(dn)

func burst(pos: Vector2, color: Color, count := 14, speed := 170.0, life := 0.5) -> void:
	var t := _target()
	if t == null:
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 50
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, 60)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = color
	p.finished.connect(p.queue_free)
	t.add_child(p)

func slash(pos: Vector2, dir: Vector2, reach: float, arc_deg: float, color: Color) -> void:
	var t := _target()
	if t == null:
		return
	var s := SlashArc.new()
	s.position = pos
	s.dir = dir
	s.reach = reach
	s.arc = deg_to_rad(arc_deg)
	s.color = color
	s.z_index = 40
	t.add_child(s)

func ring(pos: Vector2, color: Color, r_from: float, r_to: float, dur := 0.4) -> void:
	var t := _target()
	if t == null:
		return
	var r := VisualRing.new()
	r.position = pos
	r.r_from = r_from
	r.r_to = r_to
	r.dur = dur
	r.color = color
	r.z_index = 45
	t.add_child(r)

## HD-2D "diorama under warm light" atmosphere. Adds screen bloom (toggle-gated
## so it can never black-screen), a tilt-shift depth blur, drifting light shafts
## from the Eye, and a warm/cool grade — on top of the existing vignette. Add
## once per screen; everything is freed with the screen.
func attach_atmosphere(parent: Node, kind := "desert") -> void:
	attach_bloom(parent)
	attach_vignette(parent)
	var layer := CanvasLayer.new()
	layer.layer = 54
	var atmo := Atmosphere.new()
	atmo.kind = kind
	atmo.set_anchors_preset(Control.PRESET_FULL_RECT)
	atmo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(atmo)
	parent.add_child(layer)

## Real screen-space bloom that works on EVERY renderer, including the web /
## mobile GL-Compatibility backend (where WorldEnvironment 2D glow is absent).
## A BackBufferCopy snapshots the framebuffer, then a full-screen shader
## extracts the bright pixels, blurs them, and adds them back. Placed at layer
## 56 so it blooms the world + atmosphere (layers ≤55) but leaves the HUD (60)
## and touch controls (65) crisp. Gated by the Bloom setting.
func attach_bloom(parent: Node) -> void:
	if not bool(Game.setting("bloom")):
		return
	var layer := CanvasLayer.new()
	layer.layer = 56
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(bb)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _bloom_material()
	layer.add_child(rect)
	parent.add_child(layer)

var _bloom_mat: ShaderMaterial = null

func _bloom_material() -> ShaderMaterial:
	if _bloom_mat == null:
		var sh := Shader.new()
		sh.code = BLOOM_SHADER
		_bloom_mat = ShaderMaterial.new()
		_bloom_mat.shader = sh
	return _bloom_mat

const BLOOM_SHADER := "\
shader_type canvas_item;\n\
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;\n\
uniform float threshold : hint_range(0.0, 1.0) = 0.70;\n\
uniform float intensity : hint_range(0.0, 3.0) = 0.95;\n\
uniform float spread : hint_range(0.5, 5.0) = 2.6;\n\
void fragment() {\n\
	vec2 px = SCREEN_PIXEL_SIZE * spread;\n\
	vec3 sum = vec3(0.0);\n\
	float total = 0.0;\n\
	for (int x = -2; x <= 2; x++) {\n\
		for (int y = -2; y <= 2; y++) {\n\
			vec2 off = vec2(float(x), float(y)) * px;\n\
			vec3 c = texture(screen_tex, SCREEN_UV + off).rgb;\n\
			float b = max(c.r, max(c.g, c.b));\n\
			float e = max(b - threshold, 0.0);\n\
			vec3 bright = c * (e / max(b, 0.0001));\n\
			float w = 1.0 / (1.0 + float(x * x + y * y));\n\
			sum += bright * w;\n\
			total += w;\n\
		}\n\
	}\n\
	vec3 bloom = (sum / total) * intensity;\n\
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;\n\
	COLOR = vec4(base + bloom, 1.0);\n\
}\n"

## Screen-space vignette + warm grade for the 2.5D look. Add once per screen.
func attach_vignette(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 55
	var rect := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0.02, 0.01, 0.03, 0.32))
	grad.add_point(0.66, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 512
	tex.height = 512
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	parent.add_child(layer)

## Fading afterimage ghost (dash trails).
func ghost(pos: Vector2, facing: float, color := Color(0.45, 0.55, 0.85)) -> void:
	var t := _target()
	if t == null:
		return
	var g := DashGhost.new()
	g.position = pos
	g.facing = facing
	g.color = color
	g.z_index = -1
	t.add_child(g)

func flash_screen(color := Color(1, 1, 1, 0.35), dur := 0.25) -> void:
	var intensity := float(Game.setting("flash_amount"))
	if intensity <= 0.01:
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	var rect := ColorRect.new()
	color.a *= clampf(intensity, 0.0, 1.0)
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, dur)
	tw.tween_callback(layer.queue_free)

# ------------------------------------------------------------- inner classes

class Atmosphere extends Control:
	## Screen-space HD-2D pass: tilt-shift depth bands (top/bottom), drifting
	## light shafts from the upper "Eye", and a gentle warm/cool grade. Pure
	## drawing — it can darken/tint but never blank the framebuffer.
	var kind := "desert"
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var vp := get_viewport_rect().size
		var warm := Color(1.0, 0.72, 0.4)
		var cool := Color(0.35, 0.45, 0.75)
		if kind == "hub":
			warm = Color(0.85, 0.78, 0.55)
			cool = Color(0.3, 0.4, 0.7)
		elif kind == "boss":
			warm = Color(1.0, 0.5, 0.25)
			cool = Color(0.45, 0.3, 0.4)
		# --- tilt-shift: soft dark focal bands top and bottom (fakes DOF).
		# Kept light enough that enemies near the edges stay readable. ---
		var band := vp.y * 0.15
		_grad_band(Rect2(0, 0, vp.x, band), Color(0.02, 0.02, 0.05, 0.26), Color(0.02, 0.02, 0.05, 0.0), true)
		_grad_band(Rect2(0, vp.y - band, vp.x, band), Color(0.03, 0.02, 0.04, 0.0), Color(0.03, 0.02, 0.04, 0.30), true)
		# --- warm/cool vertical grade (lit-diorama feel); lean warm so the
		# scene doesn't read cold/murky on the glow-less web renderer ---
		var top_tint := cool
		top_tint.a = 0.06
		var bot_tint := warm
		bot_tint.a = 0.12
		_grad_band(Rect2(0, 0, vp.x, vp.y), top_tint, bot_tint, true)
		# --- drifting light shafts from the Eye (upper centre) ---
		var src := Vector2(vp.x * 0.5, -vp.y * 0.12)
		for i in 5:
			var phase := t * 0.12 + float(i) * 1.7
			var sway := sin(phase) * vp.x * 0.04
			var x_mid := vp.x * 0.5 + sway + (float(i) - 2.0) * vp.x * 0.12
			var w := vp.x * 0.05
			var a := 0.05 + 0.025 * sin(t * 0.7 + float(i))
			var c := warm
			c.a = maxf(a, 0.02)
			draw_colored_polygon(PackedVector2Array([
				src + Vector2(-6, 0), src + Vector2(6, 0),
				Vector2(x_mid + w, vp.y), Vector2(x_mid - w, vp.y)]), c)

	func _grad_band(rect: Rect2, c_top: Color, c_bot: Color, vertical: bool) -> void:
		# Cheap vertical gradient via a stack of thin rects.
		var steps := 24
		for i in steps:
			var k := float(i) / float(steps - 1)
			var c := c_top.lerp(c_bot, k) if vertical else c_top
			var y := rect.position.y + rect.size.y * (float(i) / steps)
			draw_rect(Rect2(rect.position.x, y, rect.size.x, rect.size.y / steps + 1.0), c)

class DamageNumber extends Node2D:
	var text_value := "0"
	var color := Color.WHITE
	var life := 0.7
	var vel := Vector2(0, -70)
	var label: Label

	func _ready() -> void:
		z_index = 100
		label = Label.new()
		label.text = text_value
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", 4)
		label.position = Vector2(-14, -10)
		add_child(label)

	func _process(delta: float) -> void:
		life -= delta
		position += vel * delta
		vel.y += 60.0 * delta
		modulate.a = clampf(life / 0.3, 0.0, 1.0)
		if life <= 0.0:
			queue_free()

class DashGhost extends Node2D:
	var facing := 1.0
	var color := Color(0.45, 0.55, 0.85)
	var life := 0.22
	var max_life := 0.22

	func _process(delta: float) -> void:
		life -= delta
		queue_redraw()
		if life <= 0.0:
			queue_free()

	func _draw() -> void:
		var a := clampf(life / max_life, 0.0, 1.0)
		var c := color
		c.a = 0.4 * a
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -24), Vector2(10 * facing, -14), Vector2(12 * facing, 8),
			Vector2(-12 * facing, 8), Vector2(-8 * facing, -14)]), c)
		c.a = 0.55 * a
		draw_circle(Vector2(2 * facing, -28), 6.0, c)

class SlashArc extends Node2D:
	var dir := Vector2.RIGHT
	var reach := 90.0
	var arc := PI * 0.6
	var color := Color(1, 0.7, 0.3)
	var life := 0.16
	var max_life := 0.16

	func _process(delta: float) -> void:
		life -= delta
		queue_redraw()
		if life <= 0.0:
			queue_free()

	func _draw() -> void:
		var a := clampf(life / max_life, 0.0, 1.0)
		var base := dir.angle()
		var pts := PackedVector2Array()
		var steps := 14
		for i in steps + 1:
			var ang := base - arc * 0.5 + arc * float(i) / steps
			pts.append(Vector2.from_angle(ang) * reach)
		for i in range(steps, -1, -1):
			var ang2 := base - arc * 0.5 + arc * float(i) / steps
			pts.append(Vector2.from_angle(ang2) * reach * 0.45)
		var c := color
		c.a = 0.55 * a
		draw_colored_polygon(pts, c)
		var edge := color.lightened(0.3)
		edge.a = 0.9 * a
		draw_arc(Vector2.ZERO, reach, base - arc * 0.5, base + arc * 0.5, 18, edge, 3.0)

class VisualRing extends Node2D:
	var r_from := 10.0
	var r_to := 200.0
	var dur := 0.4
	var t := 0.0
	var color := Color(1, 0.85, 0.4)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t >= dur:
			queue_free()

	func _draw() -> void:
		var k := clampf(t / dur, 0.0, 1.0)
		var r := lerpf(r_from, r_to, 1.0 - pow(1.0 - k, 2.0))
		var c := color
		c.a = (1.0 - k) * 0.85
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, 5.0)
		c.a *= 0.4
		draw_arc(Vector2.ZERO, r * 0.92, 0, TAU, 48, c, 9.0)
