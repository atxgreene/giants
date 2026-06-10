extends CanvasLayer
class_name TouchControls
## Mobile touch layer: dynamic virtual joystick on the left, action buttons
## on the right, pause in the corner. Appears only when a touchscreen is
## used (Game.touch_mode). Buttons inject real InputEventAction events so
## both polling (Input.is_action_just_pressed) and _unhandled_input handlers
## respond; movement is read directly by the Player via move_vec.

var move_vec := Vector2.ZERO
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var held := {}              # finger index -> action name
var draw_node: Control

const STICK_RADIUS := 72.0
const BUTTONS := [
	{"action": "attack", "label": "ATK", "off": Vector2(-86, -92), "r": 46.0, "col": Color(1.0, 0.75, 0.35)},
	{"action": "dash", "label": "DASH", "off": Vector2(-198, -60), "r": 36.0, "col": Color(0.9, 0.88, 0.75)},
	{"action": "special", "label": "CRES", "off": Vector2(-96, -206), "r": 34.0, "col": Color(1.0, 0.6, 0.25)},
	{"action": "attack_heavy", "label": "HVY", "off": Vector2(-196, -152), "r": 30.0, "col": Color(0.95, 0.5, 0.3)},
	{"action": "seal", "label": "SEAL", "off": Vector2(-286, -98), "r": 28.0, "col": Color(0.95, 0.85, 0.5)},
	{"action": "ultimate", "label": "ULT", "off": Vector2(-178, -238), "r": 28.0, "col": Color(1.0, 0.92, 0.55)},
	{"action": "interact", "label": "E", "off": Vector2(-62, -288), "r": 26.0, "col": Color(0.6, 0.85, 1.0)}
]

func _ready() -> void:
	layer = 65
	add_to_group("touch_controls")
	process_mode = Node.PROCESS_MODE_ALWAYS
	draw_node = TouchDraw.new()
	draw_node.owner_tc = self
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(draw_node)

func _process(_delta: float) -> void:
	visible = Game.touch_mode and not get_tree().paused
	if not visible and stick_id != -1:
		_reset_stick()

func active() -> bool:
	return visible

func _viewport_size() -> Vector2:
	return draw_node.size

func _button_center(b: Dictionary) -> Vector2:
	var vs := _viewport_size()
	return Vector2(vs.x, vs.y) + (b["off"] as Vector2)

func _pause_center() -> Vector2:
	return Vector2(_viewport_size().x - 36.0, 36.0)

func _reset_stick() -> void:
	stick_id = -1
	move_vec = Vector2.ZERO

func _send_action(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		Game.touch_mode = true
	if not visible:
		return
	var vs := _viewport_size()
	if event is InputEventScreenTouch:
		var idx: int = event.index
		if event.pressed:
			# pause corner
			if event.position.distance_to(_pause_center()) < 34.0:
				_send_action("pause", true)
				_send_action("pause", false)
				return
			# action buttons
			for b in BUTTONS:
				if event.position.distance_to(_button_center(b)) < float(b["r"]) + 12.0:
					held[idx] = b["action"]
					_send_action(str(b["action"]), true)
					return
			# joystick zone: lower-left region, dynamic origin
			if event.position.x < vs.x * 0.45 and event.position.y > vs.y * 0.3 and stick_id == -1:
				stick_id = idx
				stick_origin = event.position
				stick_pos = event.position
				move_vec = Vector2.ZERO
		else:
			if idx == stick_id:
				_reset_stick()
			elif held.has(idx):
				_send_action(str(held[idx]), false)
				held.erase(idx)
	elif event is InputEventScreenDrag:
		if event.index == stick_id:
			stick_pos = event.position
			var v: Vector2 = (stick_pos - stick_origin) / STICK_RADIUS
			move_vec = v.limit_length(1.0)

class TouchDraw extends Control:
	var owner_tc: TouchControls

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if owner_tc == null or not owner_tc.visible:
			return
		var ink := Color(0.04, 0.035, 0.06, 0.4)
		var gold := Color(0.85, 0.72, 0.38, 0.5)
		# joystick
		if owner_tc.stick_id != -1:
			draw_circle(owner_tc.stick_origin, TouchControls.STICK_RADIUS, ink)
			draw_arc(owner_tc.stick_origin, TouchControls.STICK_RADIUS, 0, TAU, 32, gold, 2.0)
			var knob := owner_tc.stick_origin + owner_tc.move_vec * TouchControls.STICK_RADIUS * 0.7
			draw_circle(knob, 26.0, Color(0.85, 0.72, 0.38, 0.55))
			draw_circle(knob, 26.0, Color(1, 1, 1, 0.15))
		else:
			# resting hint ring
			var hint := Vector2(size.x * 0.16, size.y * 0.78)
			draw_arc(hint, 46.0, 0, TAU, 32, Color(0.85, 0.72, 0.38, 0.18), 2.0)
			draw_circle(hint, 10.0, Color(0.85, 0.72, 0.38, 0.15))
		# buttons
		var font := ThemeDB.fallback_font
		var player := get_tree().get_first_node_in_group("player")
		for b in TouchControls.BUTTONS:
			var c: Vector2 = owner_tc._button_center(b)
			var r := float(b["r"])
			var col: Color = b["col"]
			var ready := true
			if player != null:
				match str(b["action"]):
					"dash":
						ready = float(player.get("dash_cd_t")) <= 0.0
					"special":
						ready = float(player.get("special_cd_t")) <= 0.0
					"seal":
						ready = float(player.get("seal_cd_t")) <= 0.0
					"ultimate":
						ready = float(player.get("ult_charge")) >= 100.0
			draw_circle(c, r, ink)
			var ring := col if ready else Color(0.4, 0.38, 0.34, 0.5)
			ring.a = 0.65 if ready else 0.35
			draw_arc(c, r, 0, TAU, 28, ring, 2.5)
			var tcol := Color(1, 1, 1, 0.8 if ready else 0.35)
			var label := str(b["label"])
			draw_string(font, c + Vector2(-label.length() * 4.0, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tcol)
		# pause
		var pc: Vector2 = owner_tc._pause_center()
		draw_circle(pc, 22.0, ink)
		draw_arc(pc, 22.0, 0, TAU, 24, gold, 1.6)
		draw_rect(Rect2(pc + Vector2(-6, -8), Vector2(4, 16)), Color(1, 1, 1, 0.7))
		draw_rect(Rect2(pc + Vector2(2, -8), Vector2(4, 16)), Color(1, 1, 1, 0.7))
