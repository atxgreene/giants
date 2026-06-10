extends Camera2D
class_name GameCamera
## Smooth-follow combat camera with trauma-based screen shake.

var trauma := 0.0
var noise_t := 0.0

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 7.0
	make_current()

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func set_limits(rect: Rect2, margin := 220.0) -> void:
	limit_left = int(rect.position.x - margin)
	limit_top = int(rect.position.y - margin)
	limit_right = int(rect.end.x + margin)
	limit_bottom = int(rect.end.y + margin)

func clear_limits() -> void:
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000

func _process(delta: float) -> void:
	noise_t += delta * 60.0
	if trauma > 0.0:
		trauma = maxf(trauma - delta * 1.8, 0.0)
		var amt := trauma * trauma * 14.0
		offset = Vector2(
			sin(noise_t * 1.31) * amt + sin(noise_t * 3.7) * amt * 0.5,
			cos(noise_t * 1.73) * amt + cos(noise_t * 4.1) * amt * 0.5)
	else:
		offset = Vector2.ZERO
