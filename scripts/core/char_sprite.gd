extends Sprite2D
class_name CharSprite
## Plays a sprite-sheet animation for a character described by
## assets/sprites/<character>.json (see assets/sprites/README.md). One animation
## per sheet row, frames left-to-right. Drives state-based playback (idle/walk/
## attack/windup/hurt/death/special) with graceful fallbacks.
##
## Normal-map lighting: if a sibling sheet "<sheet>_n.png" exists, it is wired
## through a CanvasTexture so the project's Light2D pools light the sprite in
## 3D relief — the core HD-2D effect.
##
## try_make() returns null when no sheet exists, so Player/EnemyBase keep their
## procedural rendering. Nothing here is required to run the game.

var cfg: Dictionary = {}
var fw := 64.0
var fh := 64.0
var fps := 12.0
var sheet_w := 0.0
var sheet_h := 0.0
var rows := 0          # >0 → per-row layout: each row's frames fill the width
var anims: Dictionary = {}
var cur := ""
var frame_i := 0
var frame_t := 0.0
var done := false      # non-looping anim finished (e.g. death holds last frame)

static func try_make(character: String) -> CharSprite:
	if not Assets.has_character_sprites(character):
		return null
	var s := CharSprite.new()
	if not s._setup(character):
		s.free()
		return null
	return s

func _setup(character: String) -> bool:
	cfg = Assets.config_for(character)
	var diffuse: Texture2D = Assets.sheet_texture(character)
	if diffuse == null:
		return false
	fps = float(cfg.get("fps", 12))
	anims = cfg.get("animations", {})
	sheet_w = float(diffuse.get_width())
	sheet_h = float(diffuse.get_height())
	# Per-row layout: each row holds one animation whose frames fill the full
	# sheet width (so a 6-frame row and a 7-frame row have different cell
	# widths). This is how the AI sheets are packed, and avoids the horizontal
	# "slide" you get from assuming a single uniform column pitch.
	rows = int(cfg.get("rows", 0))
	if rows > 0:
		fh = sheet_h / float(rows)
		fw = sheet_w  # per-frame width is computed per animation in _apply()
	else:
		var fsz: Array = cfg.get("frame_size", [64, 64])
		fw = float(fsz[0])
		fh = float(fsz[1])
	var base := str(cfg.get("sheet", character + ".png")).get_basename()
	var norm: Texture2D = Assets.texture(Assets.SPRITE_DIR + base + "_n.png")
	if bool(cfg.get("chroma_key", false)):
		# The sheet has no alpha (flat background): key out the desaturated
		# background in a shader, sparing the saturated gold/blue/fire pixels.
		# (A transparent re-export looks better and restores normal-map relief.)
		texture = diffuse
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = CHROMA_SHADER
		mat.shader = sh
		mat.set_shader_parameter("luma_min", float(cfg.get("chroma_luma", 0.80)))
		mat.set_shader_parameter("sat_max", float(cfg.get("chroma_sat", 0.13)))
		material = mat
	elif norm != null:
		# Optional normal map for lit 3D-relief shading under Light2D.
		var ct := CanvasTexture.new()
		ct.diffuse_texture = diffuse
		ct.normal_texture = norm
		texture = ct
	else:
		texture = diffuse
	region_enabled = true
	centered = true
	# Feet at the node origin by default; override with "offset":[x,y] in config.
	var off: Array = cfg.get("offset", [0, -fh / 2.0])
	offset = Vector2(float(off[0]), float(off[1]))
	# Display scale: art is authored larger than the ~64px gameplay scale.
	var s := float(cfg.get("scale", 1.0))
	scale = Vector2(s, s)
	play("idle")
	return true

func play(anim_name: String) -> void:
	if anim_name == cur:
		return
	var resolved := anim_name
	if not anims.has(resolved):
		resolved = _fallback(resolved)
	if not anims.has(resolved):
		return
	cur = resolved
	frame_i = 0
	frame_t = 0.0
	done = false
	_apply()

func _fallback(anim_name: String) -> String:
	match anim_name:
		"walk":
			return "idle"
		"charge", "windup":
			return "attack" if anims.has("attack") else "idle"
		"dash":
			return "walk" if anims.has("walk") else "idle"
		"hurt":
			return "idle"
		"death":
			return "hurt" if anims.has("hurt") else "idle"
		_:
			return "idle"

func _process(delta: float) -> void:
	if cur == "" or done:
		return
	var a: Dictionary = anims[cur]
	var frames := int(a.get("frames", 1))
	if frames <= 1:
		return
	frame_t += delta
	if frame_t >= 1.0 / maxf(fps, 1.0):
		frame_t = 0.0
		frame_i += 1
		if frame_i >= frames:
			if bool(a.get("loop", true)):
				frame_i = 0
			else:
				frame_i = frames - 1
				done = true
		_apply()

func _apply() -> void:
	var a: Dictionary = anims[cur]
	var row := int(a.get("row", 0))
	if rows > 0:
		# Cell width = full sheet width / the row's true column count ("cols").
		# "frames" is how many of those columns to actually play, so a pose can
		# be held as a single clean frame without resizing the crop.
		var cols := maxi(int(a.get("cols", a.get("frames", 1))), 1)
		var cw := sheet_w / float(cols)
		region_rect = Rect2(frame_i * cw, row * fh, cw, fh)
	else:
		region_rect = Rect2(frame_i * fw, row * fh, fw, fh)

const CHROMA_SHADER := "\
shader_type canvas_item;\n\
uniform float luma_min = 0.80;\n\
uniform float sat_max = 0.13;\n\
void fragment() {\n\
	vec4 c = texture(TEXTURE, UV);\n\
	float mx = max(c.r, max(c.g, c.b));\n\
	float mn = min(c.r, min(c.g, c.b));\n\
	if (mx > luma_min && (mx - mn) < sat_max) {\n\
		c.a = 0.0;\n\
	}\n\
	COLOR = c;\n\
}\n"
