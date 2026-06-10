extends EnemyBase
class_name TrainingDummy
## Bound effigy in the Watchtower. Takes hits, shows numbers, never dies —
## it re-knits itself and politely resets.

func _ready() -> void:
	super()
	unbindable = true
	stunnable = false
	kb_resist = true

func die() -> void:
	# The effigy re-forms instead of dying.
	hp = max_hp
	flash_t = 0.3
	FX.burst(global_position, Color(0.85, 0.72, 0.38), 14, 160.0, 0.5)
	FX.damage_number(global_position + Vector2(0, -30), 0.0, Color(0.85, 0.72, 0.38))
	AudioMan.play("seal")
