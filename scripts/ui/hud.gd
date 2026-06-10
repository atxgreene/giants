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
	func _process(_delta: float) -> void:
		queue_redraw()

	func _bar(pos: Vector2, w: float, h: float, frac: float, fill: Color, label_text: String, font: Font) -> void:
		draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(pos, Vector2(w * clampf(frac, 0.0, 1.0), h)), fill)
		draw_rect(Rect2(pos, Vector2(w, h)), Color(0.85, 0.72, 0.38, 0.5), false, 1.0)
		draw_string(font, pos + Vector2(4, h - 3), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.85))

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var player := get_tree().get_first_node_in_group("player")
		if player != null:
			var hp := float(player.get("hp"))
			var max_hp := float(player.get("max_hp"))
			_bar(Vector2(14, 14), 220, 18, hp / maxf(max_hp, 1.0), Color(0.72, 0.16, 0.16), "VITALITY  %d / %d" % [int(maxf(hp, 0)), int(max_hp)], font)
			if RunState.active:
				_bar(Vector2(14, 38), 170, 12, RunState.corruption / 100.0, Color(0.5, 0.15, 0.55), "CORRUPTION", font)
				_bar(Vector2(14, 54), 170, 12, RunState.revelation / 100.0, Color(0.3, 0.55, 0.85), "REVELATION", font)
			# Ability icons bottom-right
			var base := Vector2(size.x - 230, size.y - 64)
			_ability(base, "DASH", 1.0 - float(player.get("dash_cd_t")) / 0.95, Color(0.9, 0.85, 0.7), font)
			_ability(base + Vector2(56, 0), "CRES", 1.0 - float(player.get("special_cd_t")) / 2.2, Color(1.0, 0.6, 0.25), font)
			_ability(base + Vector2(112, 0), "SEAL", 1.0 - float(player.get("seal_cd_t")) / 7.0, Color(0.95, 0.85, 0.5), font)
			# Ultimate radial
			var ult := float(player.get("ult_charge")) / 100.0
			var c := base + Vector2(190, 22)
			draw_arc(c, 20.0, 0, TAU, 32, Color(0, 0, 0, 0.6), 8.0)
			var ult_col := Color(1.0, 0.9, 0.5) if ult >= 1.0 else Color(0.6, 0.55, 0.4)
			draw_arc(c, 20.0, -PI / 2, -PI / 2 + TAU * clampf(ult, 0.0, 1.0), 32, ult_col, 8.0)
			draw_string(font, c + Vector2(-14, 5), "ULT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))
			# Weapon + aspect, bottom-left
			var aspect_id: String = Game.profile.get("aspect", "commission")
			var aspect_name: String = DataDB.weapons["aspects"][aspect_id]["name"]
			draw_string(font, Vector2(14, size.y - 44), "Flaming Sword of Commission", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.86, 0.7, 0.9))
			draw_string(font, Vector2(14, size.y - 28), aspect_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.72, 0.38, 0.8))
			# Blessing icons
			if RunState.active:
				var x := 14.0
				for id in RunState.blessings:
					var b := DataDB.blessing_by_id(str(id))
					var col := DataDB.pool_color(str(b.get("pool", "")))
					draw_rect(Rect2(x, size.y - 18, 14, 14), col)
					draw_rect(Rect2(x, size.y - 18, 14, 14), Color(0, 0, 0, 0.6), false, 1.0)
					x += 18.0
				for id in RunState.relics:
					draw_rect(Rect2(x, size.y - 18, 14, 14), Color(0.7, 0.5, 0.9))
					draw_rect(Rect2(x, size.y - 18, 14, 14), Color(0, 0, 0, 0.6), false, 1.0)
					x += 18.0
		# Seals top-right
		var seals := int(Game.profile.get("seals", 0))
		draw_circle(Vector2(size.x - 140, 26), 9.0, Color(0.6, 0.42, 0.2))
		draw_arc(Vector2(size.x - 140, 26), 9.0, 0, TAU, 16, Color(0.85, 0.72, 0.38), 1.5)
		draw_string(font, Vector2(size.x - 124, 32), "%d Seals" % seals, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.86, 0.7))
		# Boss bar
		var boss = get_tree().get_first_node_in_group("boss")
		if boss != null and is_instance_valid(boss) and not boss.get("dead"):
			var bw := 520.0
			var bx := (size.x - bw) * 0.5
			var frac := float(boss.get("hp")) / maxf(float(boss.get("max_hp")), 1.0)
			draw_rect(Rect2(bx - 3, 17, bw + 6, 24), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(bx, 20, bw * clampf(frac, 0.0, 1.0), 18), Color(0.75, 0.2, 0.15))
			draw_rect(Rect2(bx - 3, 17, bw + 6, 24), Color(0.85, 0.72, 0.38, 0.8), false, 1.5)
			var title: String = boss.call("boss_title")
			draw_string(font, Vector2(bx, 12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.86, 0.7))
			var phase := int(boss.get("phase")) if boss.get("phase") != null else 0
			if phase > 0:
				for i in 3:
					var pc := Color(0.95, 0.8, 0.45) if i < phase else Color(0.3, 0.28, 0.25)
					draw_circle(Vector2(bx + bw + 18 + i * 14, 29), 5.0, pc)

	func _ability(pos: Vector2, txt: String, frac: float, col: Color, font: Font) -> void:
		frac = clampf(frac, 0.0, 1.0)
		var r := Rect2(pos, Vector2(44, 44))
		draw_rect(r, Color(0, 0, 0, 0.6))
		var fill := col
		fill.a = 0.35 + 0.45 * frac
		draw_rect(Rect2(pos + Vector2(0, 44.0 * (1.0 - frac)), Vector2(44, 44.0 * frac)), fill)
		draw_rect(r, Color(0.85, 0.72, 0.38, 0.6 if frac >= 1.0 else 0.25), false, 1.5)
		draw_string(font, pos + Vector2(6, 27), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))
