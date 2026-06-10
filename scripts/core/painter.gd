class_name Painter
## Shared 2.5D rendering helpers: directional sun shadows, outlined shapes,
## layered glows, and rune rings. One global sun direction keeps every
## shadow in the world coherent.

## Light comes from the upper-left; shadows fall to the lower-right.
const SUN_DIR := Vector2(0.78, 0.52)
const OUTLINE := Color(0.05, 0.04, 0.07, 0.85)

## Directional soft shadow + contact blob under an entity of radius r.
static func shadow(c: CanvasItem, r: float, stretch := 1.7, alpha := 0.3) -> void:
	var d := SUN_DIR.normalized()
	c.draw_set_transform(d * r * stretch * 0.42 + Vector2(0, r * 0.45), d.angle(), Vector2(stretch, 0.42))
	c.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, alpha * 0.75))
	c.draw_set_transform(Vector2(0, r * 0.5), 0.0, Vector2(1.0, 0.42))
	c.draw_circle(Vector2.ZERO, r * 0.82, Color(0, 0, 0, alpha))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Filled polygon with a crisp dark outline (readability against any floor).
static func outlined(c: CanvasItem, pts: PackedVector2Array, fill: Color, w := 1.6, outline := OUTLINE) -> void:
	c.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, outline, w)

## Layered translucent glow (cheap radial gradient).
static func glow(c: CanvasItem, pos: Vector2, r: float, col: Color, layers := 3) -> void:
	for i in layers:
		var t := float(i) / float(layers)
		var cc := col
		cc.a = col.a * (0.22 + 0.3 * t)
		c.draw_circle(pos, r * (1.0 - 0.62 * t), cc)

## Rotating rune ring: circle + tick marks (used for seals, elites, halos).
static func rune_ring(c: CanvasItem, pos: Vector2, r: float, col: Color, ticks := 8, rot := 0.0, width := 1.6) -> void:
	c.draw_arc(pos, r, 0, TAU, 36, col, width)
	for i in ticks:
		var a := TAU * float(i) / float(ticks) + rot
		c.draw_line(pos + Vector2.from_angle(a) * (r - 3.0), pos + Vector2.from_angle(a) * (r + 3.0), col, width)

## Tapered two-tone blade along an angle from a hand position.
static func blade(c: CanvasItem, hand: Vector2, angle: float, length: float, flicker: float) -> void:
	var dir := Vector2.from_angle(angle)
	var n := dir.orthogonal()
	var tip := hand + dir * length
	# heat glow under the blade
	glow(c, hand + dir * length * 0.55, length * 0.42, Color(1.0, 0.5, 0.15, 0.3), 3)
	# blade body (tapered)
	var w := length * 0.11
	outlined(c, PackedVector2Array([
		hand + n * w * 0.5, hand + dir * length * 0.82 + n * w * 0.3, tip,
		hand + dir * length * 0.82 - n * w * 0.3, hand - n * w * 0.5]),
		Color(0.96, 0.78, 0.4), 1.2)
	# bright core
	c.draw_line(hand + dir * 4.0, hand + dir * length * 0.9, Color(1.0, 0.95, 0.75, 0.9), 1.8)
	# cross guard + pommel
	c.draw_line(hand + n * 6.0, hand - n * 6.0, Color(0.62, 0.45, 0.22), 3.0)
	c.draw_circle(hand - dir * 4.0, 2.4, Color(0.85, 0.68, 0.32))
	# flame tongues climbing the edge
	for i in 3:
		var t := 0.35 + 0.25 * i
		var fp := hand + dir * length * t + n * (2.5 + sin(flicker * 16.0 + i * 2.4) * 2.0)
		var fr := 2.6 + sin(flicker * 19.0 + i * 1.7) * 1.2
		c.draw_circle(fp, fr, Color(1.0, 0.55 + 0.15 * sin(flicker * 11.0 + i), 0.12, 0.8))
	c.draw_circle(tip, 3.2 + sin(flicker * 17.0) * 1.3, Color(1.0, 0.8, 0.3, 0.85))

## Small ember/eye glow (e.g. cult eyes, idol eyes).
static func ember(c: CanvasItem, pos: Vector2, r: float, col := Color(1.0, 0.45, 0.15)) -> void:
	var halo := col
	halo.a = 0.35
	c.draw_circle(pos, r * 2.2, halo)
	c.draw_circle(pos, r, col)
