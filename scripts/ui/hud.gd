extends CanvasLayer
class_name HUD
## Combat HUD: health / corruption / revelation bars, ability cooldowns,
## ultimate charge, blessing icons, seals, room label, pending reward,
## boss health bar, interaction prompt, and toast messages.

var draw_node: HudDraw
var room_label: Label
var reward_label: Label
var prompt_label: Label
var toast_label: Label
var toast_t := 0.0

func _ready() -> void:
	layer = 60
	add_to_group("hud")
	add_child(TouchControls.new())
	draw_node = HudDraw.new()
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(draw_node)
	room_label = UIKit.label("", 15, UIKit.PARCHMENT)
	room_label.position = Vector2(14, 96)
	add_child(room_label)
	reward_label = UIKit.label("", 13, UIKit.GOLD)
	reward_label.position = Vector2(14, 118)
	add_child(reward_label)
	prompt_label = UIKit.label("", 16, UIKit.PARCHMENT)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-120, -120)
	prompt_label.size = Vector2(240, 24)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	prompt_label.add_theme_constant_override("outline_size", 5)
	add_child(prompt_label)
	toast_label = UIKit.label("", 16, UIKit.PARCHMENT)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-330, 64)
	toast_label.size = Vector2(660, 48)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast_label.add_theme_constant_override("outline_size", 5)
	add_child(toast_label)

func show_toast(text: String, color: Color) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_t = 3.2
	toast_label.modulate.a = 1.0

func set_room_label(room_name: String, index: int, total: int) -> void:
	room_label.text = "%s   —   %d / %d" % [room_name, index + 1, total + 1]

func set_pending_reward(reward: String) -> void:
	if reward == "":
		reward_label.text = ""
	else:
		var info: Dictionary = RoomNode.REWARD_INFO.get(reward, {})
		reward_label.text = "Awaiting: " + str(info.get("label", reward))
		reward_label.add_theme_color_override("font_color", info.get("color", UIKit.GOLD))

func _process(delta: float) -> void:
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t < 0.6:
			toast_label.modulate.a = maxf(toast_t / 0.6, 0.0)
	# interaction prompt
	var player := get_tree().get_first_node_in_group("player")
	var best_text := ""
	if player and not player.get("dead"):
		var best_d := 70.0
		for ip in get_tree().get_nodes_in_group("interact"):
			if not is_instance_valid(ip):
				continue
			var d: float = ip.global_position.distance_to(player.global_position)
			if d < best_d:
				var txt: String = ip.call("get_prompt")
				if txt != "":
					best_d = d
					best_text = "[E]  " + txt
	prompt_label.text = best_text

class HudDraw extends Control:
	## Illuminated-manuscript combat HUD: sigil portrait, framed gradient
	## bars, drawn ability glyphs, blessing gems, and an ornate boss bar.
	const GOLD := Color(0.85, 0.72, 0.38)
	const GOLD_DIM := Color(0.85, 0.72, 0.38, 0.45)
	const INK := Color(0.04, 0.035, 0.06, 0.78)
	var anim := 0.0

	func _process(delta: float) -> void:
		anim += delta
		queue_redraw()

	func _frame_bar(pos: Vector2, w: float, h: float, frac: float, fill: Color, label_text: String, font: Font) -> void:
		frac = clampf(frac, 0.0, 1.0)
		# backplate + inner shadow
		draw_rect(Rect2(pos - Vector2(2, 2), Vector2(w + 4, h + 4)), INK)
		draw_rect(Rect2(pos, Vector2(w, h * 0.4)), Color(0, 0, 0, 0.35))
		# gradient fill (3 strips, lighter on top)
		var fw := w * frac
		if fw > 1.0:
			draw_rect(Rect2(pos, Vector2(fw, h)), fill.darkened(0.25))
			draw_rect(Rect2(pos, Vector2(fw, h * 0.55)), fill)
			draw_rect(Rect2(pos, Vector2(fw, h * 0.22)), fill.lightened(0.25))
			# leading-edge shimmer
			draw_rect(Rect2(pos + Vector2(fw - 2.0, 0), Vector2(2.0, h)), fill.lightened(0.5))
		# quarter ticks
		for i in range(1, 4):
			var tx := pos.x + w * 0.25 * i
			draw_line(Vector2(tx, pos.y), Vector2(tx, pos.y + h * 0.35), Color(0, 0, 0, 0.4), 1.0)
		# gold frame + end-cap diamonds
		draw_rect(Rect2(pos - Vector2(2, 2), Vector2(w + 4, h + 4)), GOLD_DIM, false, 1.2)
		_diamond(pos + Vector2(-2, h * 0.5), 4.0, GOLD)
		_diamond(pos + Vector2(w + 2, h * 0.5), 4.0, GOLD)
		draw_string(font, pos + Vector2(6, h - 3), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.88))

	func _diamond(c: Vector2, r: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var player := get_tree().get_first_node_in_group("player")
		if player != null:
			var hp := float(player.get("hp"))
			var max_hp := float(player.get("max_hp"))
			var ult := clampf(float(player.get("ult_charge")) / 100.0, 0.0, 1.0)
			# --- sigil portrait ---
			var pc := Vector2(44, 46)
			draw_circle(pc, 30.0, INK)
			draw_arc(pc, 30.0, 0, TAU, 36, GOLD, 2.0)
			draw_arc(pc, 26.0, 0, TAU, 36, GOLD_DIM, 1.0)
			# witness eye sigil
			draw_arc(pc + Vector2(0, 3), 13.0, PI + 0.5, TAU - 0.5, 14, Color(0.92, 0.86, 0.7), 1.6)
			draw_arc(pc - Vector2(0, 9), 13.0, 0.5, PI - 0.5, 14, Color(0.92, 0.86, 0.7), 1.6)
			draw_circle(pc - Vector2(0, 3), 4.5, Color(0.45, 0.7, 1.0, 0.9))
			draw_circle(pc - Vector2(0, 3), 2.0, Color(0.9, 0.97, 1.0))
			if ult >= 1.0:
				draw_arc(pc, 33.0 + sin(anim * 6.0) * 1.5, 0, TAU, 36, Color(1.0, 0.9, 0.5, 0.7), 2.0)
			if hp / maxf(max_hp, 1.0) < 0.3:
				draw_arc(pc, 30.0, 0, TAU, 36, Color(0.9, 0.2, 0.15, 0.4 + 0.3 * sin(anim * 8.0)), 2.5)
			# --- vital bars ---
			_frame_bar(Vector2(86, 18), 220, 17, hp / maxf(max_hp, 1.0), Color(0.72, 0.16, 0.16),
				"VITALITY  %d / %d" % [int(maxf(hp, 0)), int(max_hp)], font)
			if RunState.active:
				_frame_bar(Vector2(86, 43), 168, 10, RunState.corruption / 100.0, Color(0.52, 0.16, 0.58), "CORRUPTION", font)
				_frame_bar(Vector2(86, 59), 168, 10, RunState.revelation / 100.0, Color(0.3, 0.55, 0.85), "REVELATION", font)
			# --- ability glyphs, bottom-right ---
			var base := Vector2(size.x - 248, size.y - 66)
			_ability(base, "dash", 1.0 - float(player.get("dash_cd_t")) / 0.95, Color(0.9, 0.85, 0.7), font, "SPACE")
			_ability(base + Vector2(58, 0), "crescent", 1.0 - float(player.get("special_cd_t")) / 2.2, Color(1.0, 0.6, 0.25), font, "RMB")
			_ability(base + Vector2(116, 0), "seal", 1.0 - float(player.get("seal_cd_t")) / 7.0, Color(0.95, 0.85, 0.5), font, "Q")
			# ultimate ring + sword glyph
			var uc := base + Vector2(206, 23)
			draw_circle(uc, 24.0, INK)
			draw_arc(uc, 22.0, 0, TAU, 36, Color(0.3, 0.27, 0.22), 6.0)
			var ult_col := Color(1.0, 0.9, 0.5) if ult >= 1.0 else Color(0.72, 0.6, 0.38)
			if ult > 0.0:
				draw_arc(uc, 22.0, -PI / 2, -PI / 2 + TAU * ult, 36, ult_col, 6.0)
			draw_line(uc + Vector2(0, 10), uc + Vector2(0, -12), ult_col, 2.2)
			draw_line(uc + Vector2(-5, 4), uc + Vector2(5, 4), ult_col, 2.2)
			if ult >= 1.0:
				draw_arc(uc, 27.0 + sin(anim * 7.0) * 2.0, 0, TAU, 36, Color(1.0, 0.9, 0.5, 0.55), 1.5)
				draw_string(font, uc + Vector2(-8, 42), "R!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.9, 0.5))
			# --- weapon plate, bottom-left ---
			var aspect_id: String = Game.profile.get("aspect", "commission")
			var aspect_name: String = DataDB.weapons["aspects"][aspect_id]["name"]
			draw_rect(Rect2(10, size.y - 58, 250, 36), Color(0.04, 0.035, 0.06, 0.55))
			draw_rect(Rect2(10, size.y - 58, 3, 36), GOLD_DIM)
			draw_string(font, Vector2(20, size.y - 43), "Flaming Sword of Commission", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.86, 0.7, 0.95))
			draw_string(font, Vector2(20, size.y - 28), aspect_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
			# --- blessing gems ---
			if RunState.active:
				var x := 22.0
				for id in RunState.blessings:
					var b := DataDB.blessing_by_id(str(id))
					_diamond(Vector2(x, size.y - 12), 6.0, DataDB.pool_color(str(b.get("pool", ""))))
					_diamond(Vector2(x, size.y - 12), 2.2, Color(1, 1, 1, 0.5))
					x += 17.0
				for id in RunState.relics:
					draw_circle(Vector2(x, size.y - 12), 5.0, Color(0.7, 0.5, 0.9))
					draw_arc(Vector2(x, size.y - 12), 5.0, 0, TAU, 10, Color(0, 0, 0, 0.5), 1.0)
					x += 17.0
		# --- seals, top-right ---
		var seals := int(Game.profile.get("seals", 0))
		var sc := Vector2(size.x - 150, 26)
		draw_circle(sc, 10.0, Color(0.45, 0.3, 0.14))
		draw_circle(sc, 10.0, Color(0.6, 0.42, 0.2, 0.6))
		draw_arc(sc, 10.0, 0, TAU, 18, GOLD, 1.5)
		_diamond(sc, 3.5, GOLD)
		draw_string(font, sc + Vector2(16, 6), "%d Seals" % seals, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.86, 0.7))
		# --- boss bar ---
		var boss = get_tree().get_first_node_in_group("boss")
		if boss != null and is_instance_valid(boss) and not boss.get("dead"):
			var bw := 540.0
			var bx := (size.x - bw) * 0.5
			var frac := clampf(float(boss.get("hp")) / maxf(float(boss.get("max_hp")), 1.0), 0.0, 1.0)
			# ornate plate
			draw_rect(Rect2(bx - 6, 16, bw + 12, 26), INK)
			if frac > 0.0:
				draw_rect(Rect2(bx, 20, bw * frac, 18), Color(0.5, 0.12, 0.1))
				draw_rect(Rect2(bx, 20, bw * frac, 10), Color(0.78, 0.2, 0.15))
				draw_rect(Rect2(bx, 20, bw * frac, 4), Color(0.95, 0.35, 0.25))
			draw_rect(Rect2(bx - 6, 16, bw + 12, 26), GOLD_DIM, false, 1.4)
			# wing flourishes
			for side in [-1.0, 1.0]:
				var wx := bx - 10.0 if side < 0 else bx + bw + 10.0
				for i in 3:
					var fl := 14.0 - i * 4.0
					draw_line(Vector2(wx, 29), Vector2(wx + side * fl, 29 - 8.0 + i * 5.0), GOLD_DIM, 1.6)
			_diamond(Vector2(bx - 10, 29), 5.0, GOLD)
			_diamond(Vector2(bx + bw + 10, 29), 5.0, GOLD)
			var title: String = boss.call("boss_title")
			draw_string(font, Vector2(bx + 4, 12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.86, 0.7))
			var phase := int(boss.get("phase")) if boss.get("phase") != null else 0
			if phase > 0:
				for i in 3:
					var col := Color(0.95, 0.8, 0.45) if i < phase else Color(0.3, 0.28, 0.25)
					_diamond(Vector2(bx + bw - 40 + i * 16, 10), 5.0, col)

	func _ability(pos: Vector2, glyph: String, frac: float, col: Color, font: Font, hint: String) -> void:
		frac = clampf(frac, 0.0, 1.0)
		var c := pos + Vector2(23, 23)
		# plate
		draw_circle(c, 23.0, INK)
		# cooldown sweep
		draw_arc(c, 20.0, 0, TAU, 32, Color(0.25, 0.22, 0.2), 4.5)
		if frac > 0.0:
			var sweep_col := col if frac >= 1.0 else col.darkened(0.25)
			draw_arc(c, 20.0, -PI / 2, -PI / 2 + TAU * frac, 32, sweep_col, 4.5)
		var ready := frac >= 1.0
		var gc := col if ready else Color(0.5, 0.47, 0.42)
		match glyph:
			"dash":
				for i in 2:
					var off := -4.0 + i * 7.0
					draw_polyline(PackedVector2Array([
						c + Vector2(off - 3, -6), c + Vector2(off + 4, 0), c + Vector2(off - 3, 6)]), gc, 2.2)
			"crescent":
				draw_arc(c, 9.0, -PI * 0.75, PI * 0.75, 14, gc, 2.5)
				draw_arc(c + Vector2(-3, 0), 8.0, -PI * 0.55, PI * 0.55, 12, Color(0.04, 0.035, 0.06), 3.0)
			"seal":
				draw_arc(c, 9.0, 0, TAU, 16, gc, 1.8)
				var tri := PackedVector2Array()
				for i in 3:
					tri.append(c + Vector2.from_angle(TAU * i / 3.0 - PI * 0.5) * 6.0)
				draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), gc, 1.5)
		draw_arc(c, 23.0, 0, TAU, 36, GOLD if ready else GOLD_DIM, 1.2)
		draw_string(font, c + Vector2(-14, 38), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.66, 0.6, 0.8))
