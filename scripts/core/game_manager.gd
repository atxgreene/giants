extends Node
## Meta-progression, settings, screen routing, and input map registration.
## The input map is built in code so keyboard/mouse and controller both
## work without hand-edited project.godot serialization.

signal seals_changed(value: int)

const VERSION := "0.3.1"

var main: Node = null
var profile: Dictionary = {}
var touch_mode := false
var load_warning := ""

const DEFAULT_PROFILE := {
	"save_version": SaveManager.CURRENT_SAVE_VERSION,
	"seals": 0,
	"codex": ["appointed-witness", "michael", "gabriel"],
	"aspects": ["commission"],
	"aspect": "commission",
	"weapon": "flaming_sword",
	"weapons_unlocked": ["flaming_sword"],
	"weapon_aspects": {"flaming_sword": "commission"},
	"upgrades": {},
	"boss_defeated": false,
	"edge_of_azazel": false,
	"seal_of_michael": false,
	"michael_disapproves": false,
	"michael_acknowledged": false,
	"michael_rebuke_seen": false,
	"raphael_clean_seen": false,
	"uriel_unlocked": false,
	"intro_seen": false,
	"full_corruption": false,
	"last_corruption": 0.0,
	"runs": 0,
	"deaths": 0,
	"wins": 0,
	"settings": {
		"music": 0.8, "sfx": 0.8,
		"damage_numbers": true, "screenshake": true, "fullscreen": false,
		"screenshake_amount": 1.0, "flash_amount": 1.0, "text_scale": 1.0,
		"high_contrast": false, "colorblind_telegraphs": false,
		"hold_to_dash": false, "auto_aim_assist": true
	}
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	profile = SaveMan.load_profile(DEFAULT_PROFILE)
	load_warning = SaveMan.last_load_warning
	if load_warning != "":
		push_warning("[save] " + load_warning)
	apply_settings()
	if DisplayServer.is_touchscreen_available():
		touch_mode = true

func _input(event: InputEvent) -> void:
	# A real finger means a touch device; mouse emulated from touch never
	# arrives as InputEventScreenTouch, so desktops are unaffected.
	if event is InputEventScreenTouch:
		touch_mode = true

func goto(screen: String, args: Dictionary = {}) -> void:
	if main:
		main.call("show_screen", screen, args)

func save() -> void:
	SaveMan.save_profile(profile)

func new_game() -> void:
	SaveMan.wipe()
	profile = DEFAULT_PROFILE.duplicate(true)
	save()

func setting(key: String):
	return profile["settings"].get(key, DEFAULT_PROFILE["settings"].get(key))

func set_setting(key: String, value) -> void:
	profile["settings"][key] = value
	apply_settings()
	save()

func apply_settings() -> void:
	AudioMan.set_volumes(setting("music"), setting("sfx"))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if setting("fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)

func add_seals(n: int) -> void:
	profile["seals"] = int(profile["seals"]) + n
	seals_changed.emit(int(profile["seals"]))
	save()

func spend_seals(n: int) -> bool:
	if int(profile["seals"]) < n:
		return false
	profile["seals"] = int(profile["seals"]) - n
	seals_changed.emit(int(profile["seals"]))
	save()
	return true

func upgrade_level(id: String) -> int:
	return int(profile["upgrades"].get(id, 0))

# ----------------------------------------------------------------- weapons

const DEFAULT_ASPECT := {"flaming_sword": "commission", "censer_flail": "raphael_aspect"}

func weapon_unlocked(weapon_id: String) -> bool:
	return weapon_id in profile.get("weapons_unlocked", ["flaming_sword"])

func unlock_weapon(weapon_id: String) -> void:
	if not weapon_unlocked(weapon_id):
		profile["weapons_unlocked"].append(weapon_id)
	# Give the weapon its free starting aspect if it has none recorded.
	var aspects: Dictionary = profile.get("weapon_aspects", {})
	if not aspects.has(weapon_id):
		aspects[weapon_id] = DEFAULT_ASPECT.get(weapon_id, "commission")
		profile["weapon_aspects"] = aspects
	# Grant the free aspect so it shows as owned.
	var free_aspect: String = DEFAULT_ASPECT.get(weapon_id, "")
	if free_aspect != "" and not (free_aspect in profile["aspects"]):
		profile["aspects"].append(free_aspect)
	save()

func current_weapon() -> String:
	return str(profile.get("weapon", "flaming_sword"))

func current_weapon_aspect() -> String:
	var aspects: Dictionary = profile.get("weapon_aspects", {})
	return str(aspects.get(current_weapon(), DEFAULT_ASPECT.get(current_weapon(), "commission")))

func equip_weapon(weapon_id: String) -> void:
	if not weapon_unlocked(weapon_id):
		return
	profile["weapon"] = weapon_id
	profile["aspect"] = current_weapon_aspect()
	save()
	RunState.rebuild_mods()

func equip_aspect(aspect_id: String) -> void:
	var aspects: Dictionary = profile.get("weapon_aspects", {})
	aspects[current_weapon()] = aspect_id
	profile["weapon_aspects"] = aspects
	profile["aspect"] = aspect_id
	save()
	RunState.rebuild_mods()

func toast(text: String, color: Color = Color(0.92, 0.86, 0.7)) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.call("show_toast", text, color)
	else:
		print("[toast] ", text)

# ------------------------------------------------------------------ input map

func _register_inputs() -> void:
	_act("move_up", [_key(KEY_W), _key(KEY_UP), _jm(JOY_AXIS_LEFT_Y, -1.0)])
	_act("move_down", [_key(KEY_S), _key(KEY_DOWN), _jm(JOY_AXIS_LEFT_Y, 1.0)])
	_act("move_left", [_key(KEY_A), _key(KEY_LEFT), _jm(JOY_AXIS_LEFT_X, -1.0)])
	_act("move_right", [_key(KEY_D), _key(KEY_RIGHT), _jm(JOY_AXIS_LEFT_X, 1.0)])
	_act("aim_up", [_jm(JOY_AXIS_RIGHT_Y, -1.0)])
	_act("aim_down", [_jm(JOY_AXIS_RIGHT_Y, 1.0)])
	_act("aim_left", [_jm(JOY_AXIS_RIGHT_X, -1.0)])
	_act("aim_right", [_jm(JOY_AXIS_RIGHT_X, 1.0)])
	_act("attack", [_mb(MOUSE_BUTTON_LEFT), _jb(JOY_BUTTON_X)])
	_act("attack_heavy", [_key(KEY_SHIFT), _mb(MOUSE_BUTTON_MIDDLE), _jb(JOY_BUTTON_Y)])
	_act("special", [_mb(MOUSE_BUTTON_RIGHT), _jm(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_act("dash", [_key(KEY_SPACE), _jb(JOY_BUTTON_RIGHT_SHOULDER)])
	_act("seal", [_key(KEY_Q), _jb(JOY_BUTTON_LEFT_SHOULDER)])
	_act("interact", [_key(KEY_E), _jb(JOY_BUTTON_A)])
	_act("ultimate", [_key(KEY_R), _jb(JOY_BUTTON_B)])
	_act("pause", [_key(KEY_ESCAPE), _jb(JOY_BUTTON_START)])

func _act(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.3)
	for ev in events:
		InputMap.action_add_event(action, ev)

func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code as Key
	return ev

func _mb(idx: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = idx as MouseButton
	return ev

func _jb(idx: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = idx as JoyButton
	return ev

func _jm(axis: int, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis as JoyAxis
	ev.axis_value = value
	return ev
