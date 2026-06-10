extends Node2D
class_name Hub
## The Watchtower Between Worlds. Archangel NPCs, the Scribe of Dust,
## weapon altar, upgrade altar, blessing preview, codex lectern, training
## dummy, and the gate into the Desert of Azazel. Hosts the opening sequence.

var room: RoomNode
var player: Player
var cam: GameCamera
var hud: HUD
var overlay_open := false

func _ready() -> void:
	room = RoomNode.new()
	room.build("hub")
	add_child(room)
	player = Player.new()
	player.position = Vector2(-420, 80)
	cam = GameCamera.new()
	player.add_child(cam)
	room.add_child(player)
	FX.world = room
	FX.camera = cam
	cam.set_limits(room.bounds)
	hud = HUD.new()
	add_child(hud)
	FX.attach_vignette(self)
	hud.set_room_label("The Watchtower Between Worlds", 0, 0)
	_populate()
	AudioMan.music("hub")
	if not Game.profile.get("intro_seen", false):
		_play_intro()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not overlay_open:
		add_child(PauseMenu.new())

# --------------------------------------------------------------- population

func _npc(npc_id: String, pos: Vector2, display: String, prompt: String, style: String, accent: Color, cb: Callable) -> void:
	var n := NPCNode.new()
	n.npc_id = npc_id
	n.position = pos
	n.display_name = display
	n.prompt = prompt
	n.style = style
	n.accent = accent
	n.callback = cb
	room.add_child(n)

func _populate() -> void:
	_npc("michael", Vector2(-190, -200), "Michael", "Speak with Michael", "angel",
		Color(0.95, 0.85, 0.5), _talk_michael)
	_npc("gabriel", Vector2(190, -200), "Gabriel", "Speak with Gabriel", "angel",
		Color(0.45, 0.75, 1.0), _talk_gabriel)
	_npc("raphael", Vector2(-360, -40), "Raphael", "Speak with Raphael", "angel",
		Color(0.5, 0.9, 0.6), _talk_raphael)
	if Game.profile.get("uriel_unlocked", false):
		_npc("uriel", Vector2(360, -40), "Uriel", "Speak with Uriel", "angel",
			Color(1.0, 0.55, 0.2), _talk_uriel)
	_npc("scribe", Vector2(-60, -290), "The Scribe of Dust", "Speak with the Scribe", "scribe",
		Color(0.8, 0.75, 0.65), _talk_scribe)
	_npc("archive", Vector2(60, -290), "Witness Archive", "Read the Witness Archive", "lectern",
		Color(0.45, 0.75, 1.0), func(): _open_overlay(CodexMenu.new()))
	_npc("weapon_altar", Vector2(-140, 180), "Weapon Altar", "Attend the Weapon Altar", "altar",
		Color(1.0, 0.55, 0.2), func():
			var m := AltarMenu.new()
			m.mode = "weapon"
			_open_overlay(m))
	_npc("blessing_lectern", Vector2(20, 180), "Blessing Preview", "Study the blessings", "lectern",
		Color(0.95, 0.85, 0.5), func():
			var m := AltarMenu.new()
			m.mode = "blessings"
			_open_overlay(m))
	_npc("upgrade_altar", Vector2(-300, -200), "Training Altar", "Train with the Host", "altar",
		Color(0.95, 0.85, 0.5), func(): _open_overlay(UpgradeMenu.new()))
	_npc("run_gate", Vector2(540, 0), "The Desert Gate", "Enter the Desert of Azazel", "gate",
		Color(0.95, 0.85, 0.5), _start_run)
	var dummy := EnemyBase.create("training_dummy")
	dummy.position = Vector2(380, -240)
	room.add_child(dummy)

func _open_overlay(menu: Node) -> void:
	overlay_open = true
	player.input_locked = true
	menu.tree_exited.connect(func():
		overlay_open = false
		if is_instance_valid(player):
			player.input_locked = false)
	add_child(menu)

func _start_run() -> void:
	AudioMan.play("gate")
	Game.goto("run")

# --------------------------------------------------------------- dialogue

func _say(lines: Array, cb := Callable()) -> void:
	var db := DialogueBox.new()
	add_child(db)
	db.play(lines, cb)

func _one_of(key: String) -> Array:
	var lines := DataDB.dialogue_lines(key)
	if lines.is_empty():
		return []
	return [lines[randi() % lines.size()]]

func _talk_michael() -> void:
	if Game.profile.get("michael_disapproves", false) and not Game.profile.get("michael_acknowledged", false):
		Game.profile["michael_acknowledged"] = true
		Game.save()
		_say(DataDB.dialogue_lines("michael_disapprove"))
	elif Game.profile.get("boss_defeated", false):
		_say(_one_of("michael_postboss"))
	else:
		_say(_one_of("michael_default"))

func _talk_gabriel() -> void:
	if Game.profile.get("boss_defeated", false):
		_say(_one_of("gabriel_postboss"))
	else:
		_say(_one_of("gabriel_default"))

func _talk_raphael() -> void:
	if float(Game.profile.get("last_corruption", 0.0)) >= 50.0:
		_say(DataDB.dialogue_lines("raphael_corrupt"))
	else:
		_say(_one_of("raphael_default"))

func _talk_uriel() -> void:
	_say(_one_of("uriel_default"))

func _talk_scribe() -> void:
	if float(Game.profile.get("last_corruption", 0.0)) >= 50.0:
		_say(DataDB.dialogue_lines("scribe_corrupt"))
	else:
		_say(_one_of("scribe_default"))

# --------------------------------------------------------------- intro

func _play_intro() -> void:
	player.input_locked = true
	var layer := CanvasLayer.new()
	layer.layer = 85
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	var text := UIKit.title("", 24, UIKit.PARCHMENT)
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.position = Vector2(-460, -40)
	text.size = Vector2(920, 80)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(text)
	add_child(layer)
	var tw := create_tween()
	tw.tween_callback(func():
		text.text = "The giants dreamed before the flood. Their dreams were judgments."
		text.modulate.a = 0.0)
	tw.tween_property(text, "modulate:a", 1.0, 1.2)
	tw.tween_interval(2.2)
	tw.tween_property(text, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func():
		text.text = "You wake on cold stone, in a tower that stands between the world and what watches it.")
	tw.tween_property(text, "modulate:a", 1.0, 1.0)
	tw.tween_interval(2.0)
	tw.tween_property(text, "modulate:a", 0.0, 0.8)
	tw.tween_property(black, "color:a", 0.0, 1.2)
	tw.tween_callback(func():
		layer.queue_free()
		_say(DataDB.dialogue_lines("intro_gabriel"), func():
			_say(DataDB.dialogue_lines("intro_michael"), func():
				Game.toast("Received: THE FLAMING SWORD OF COMMISSION", Color(1.0, 0.7, 0.3))
				AudioMan.play("blessing")
				FX.flash_screen(Color(1.0, 0.85, 0.5, 0.25), 0.5)
				Game.profile["intro_seen"] = true
				Game.save())))
