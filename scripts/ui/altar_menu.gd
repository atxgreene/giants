extends CanvasLayer
class_name AltarMenu
## Weapon altar (unlock/equip aspects) and blessing preview lectern,
## selected by `mode` ("weapon" or "blessings").

var mode := "weapon"
var rows_box: VBoxContainer

func _ready() -> void:
	layer = 74
	add_child(UIKit.dim_layer())
	var root := UIKit.center()
	add_child(root)
	var panel := UIKit.panel()
	var v := UIKit.vbox(12)
	v.custom_minimum_size = Vector2(620, 0)
	v.add_child(UIKit.title("THE WEAPON ALTAR" if mode == "weapon" else "BLESSING PREVIEW", 26))
	if mode == "weapon":
		var sub := UIKit.label("Choose the weapon you carry into the desert. Each remembers different things.", 14, UIKit.ASH)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sub)
	rows_box = UIKit.vbox(8)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(580, 380)
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rows_box)
	v.add_child(sc)
	var back := UIKit.button("Step back", 16)
	back.pressed.connect(queue_free)
	var bc := CenterContainer.new()
	bc.add_child(back)
	v.add_child(bc)
	panel.add_child(v)
	root.add_child(panel)
	_refresh()

func _refresh() -> void:
	for child in rows_box.get_children():
		child.queue_free()
	if mode == "weapon":
		_build_weapon_rows()
	else:
		_build_blessing_rows()

func _build_weapon_rows() -> void:
	# --- Weapon selection -------------------------------------------------
	rows_box.add_child(UIKit.label("WEAPONS", 17, UIKit.GOLD))
	for w_id in DataDB.weapons:
		if w_id == "aspects":
			continue
		var w: Dictionary = DataDB.weapons[w_id]
		var unlocked: bool = Game.weapon_unlocked(w_id)
		var equipped: bool = Game.current_weapon() == w_id
		var h := UIKit.hbox(10)
		var info := UIKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.label(str(w["name"]) + ("   — EQUIPPED" if equipped else ""), 16, UIKit.GOLD if equipped else UIKit.PARCHMENT))
		var d := UIKit.label(str(w.get("desc", "")), 13, UIKit.ASH.lightened(0.2))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(420, 0)
		info.add_child(d)
		h.add_child(info)
		if equipped:
			pass
		elif unlocked:
			var eq := UIKit.button("Carry", 15)
			eq.pressed.connect(func():
				Game.equip_weapon(w_id)
				AudioMan.play("fire")
				_refresh())
			h.add_child(eq)
		else:
			var wcost := int(w.get("unlock_cost", 120))
			var buy := UIKit.button("Unlock — %d Seals" % wcost, 15)
			buy.disabled = int(Game.profile["seals"]) < wcost
			buy.pressed.connect(func():
				if Game.spend_seals(wcost):
					Game.unlock_weapon(w_id)
					Game.equip_weapon(w_id)
					CodexMan.unlock("censer-flail")
					AudioMan.play("blessing")
					_refresh())
			h.add_child(buy)
		rows_box.add_child(h)
	rows_box.add_child(UIKit.label(" ", 6))
	# --- Aspects for the currently-carried weapon -------------------------
	var cur := Game.current_weapon()
	rows_box.add_child(UIKit.label("ASPECTS OF " + str(DataDB.weapons[cur]["name"]).to_upper(), 17, UIKit.GOLD))
	var aspects: Dictionary = DataDB.weapons["aspects"]
	for a_id in aspects:
		var a: Dictionary = aspects[a_id]
		if str(a.get("weapon", "flaming_sword")) != cur:
			continue
		var owned: bool = a_id in Game.profile["aspects"]
		var equipped2: bool = Game.profile["aspect"] == a_id
		var h2 := UIKit.hbox(10)
		var info2 := UIKit.vbox(2)
		info2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info2.add_child(UIKit.label(str(a["name"]) + ("   — EQUIPPED" if equipped2 else ""), 16, UIKit.GOLD if equipped2 else UIKit.PARCHMENT))
		var d2 := UIKit.label(str(a["desc"]), 13, UIKit.ASH.lightened(0.2))
		d2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d2.custom_minimum_size = Vector2(420, 0)
		info2.add_child(d2)
		h2.add_child(info2)
		if equipped2:
			pass
		elif owned:
			var eq2 := UIKit.button("Equip", 15)
			eq2.pressed.connect(func():
				Game.equip_aspect(a_id)
				AudioMan.play("fire")
				_refresh())
			h2.add_child(eq2)
		else:
			var cost := int(a["cost"])
			var buy2 := UIKit.button("Unlock — %d Seals" % cost, 15)
			buy2.disabled = int(Game.profile["seals"]) < cost
			buy2.pressed.connect(func():
				if Game.spend_seals(cost):
					Game.profile["aspects"].append(a_id)
					Game.save()
					AudioMan.play("blessing")
					_refresh())
			h2.add_child(buy2)
		rows_box.add_child(h2)

func _build_blessing_rows() -> void:
	for pool_key in DataDB.blessings["pools"]:
		var pool: Dictionary = DataDB.blessings["pools"][pool_key]
		var locked: bool = pool_key == "uriel" and not Game.profile.get("uriel_unlocked", false)
		var col := Color(str(pool["color"]))
		rows_box.add_child(UIKit.label(str(pool["name"]).to_upper() + " — " + str(pool["title"]) + ("   [SEALED]" if locked else ""), 17, col))
		for b in pool["blessings"]:
			var txt := "   ◆ " + (str(b["name"]) + " — " + str(b["desc"]) if not locked else "? ? ?")
			var l := UIKit.label(txt, 13, UIKit.PARCHMENT if not locked else UIKit.ASH)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(540, 0)
			rows_box.add_child(l)
		rows_box.add_child(UIKit.label(" ", 6))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		queue_free()
