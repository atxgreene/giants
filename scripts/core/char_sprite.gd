extends Sprite2D
class_name CharSprite
## Plays a character defined by assets/sprites/<id>.json against the shared
## sprite-sheet contract:
##
## {
##   "sheet": "x.png", "normal": "x_n.png",        # normal optional
##   "frame_size": [160,160],                       # contract hint
##   "grid": {"cols": 8, "rows": 7},                # the real atlas grid
##   "fps": 12, "offset": [0,-80], "pivot": "bottom_center",
##   "scale": 0.42,                                 # engine display scale
##   "animations": {
##     "idle":  {"row":0, "indices":[0],       "mode":"pose",     "loop":true},
##     "walk":  {"row":1, "indices":[3],       "mode":"pose",     "loop":true},
##     "attack":{"row":2, "indices":[2,3,4],   "mode":"sequence", "loop":false},
##     "death": {"row":5, "indices":[0,1,2,3,4,5,6,7], "mode":"sequence", "loop":false}
##   }
## }
##
## - "pose" rows hold a single chosen frame (the AI sheets aren't frame-coherent
##   enough to play whole rows); "sequence" rows step through the hand-picked
##   `indices` only.
## - Cell size is derived from `grid` × the actual texture so it stays accurate
##   even if the export isn't exactly frame_size.
## - Optional `<sheet>_n.png` normal map → lit 3D relief under Light2D. If the
##   diffuse has no alpha, set "chroma_key": true (keys the flat background;
##   renders flat-lit until a transparent sheet replaces it).
##
## try_make() returns null when no config exists, so callers fall back to the
## procedural body. Nothing here is required to run the game.

var cfg: Dictionary = {}
var fw := 64.0
var fh := 64.0
var fps := 12.0
var anims: Dictionary = {}
var cur := ""
var frame_i := 0      # index into the current animation's `indices`
var frame_t := 0.0
var done := false

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
	var sheet_w := float(diffuse.get_width())
	var sheet_h := float(diffuse.get_height())
	# Cell size: prefer the atlas grid (derived from the real texture so it is
	# pixel-accurate); fall back to an explicit frame_size; else a single cell.
	var grid: Dictionary = cfg.get("grid", {})
	if grid.has("cols") and grid.has("rows"):
		fw = sheet_w / float(maxi(int(grid["cols"]), 1))
		fh = sheet_h / float(maxi(int(grid["rows"]), 1))
	elif cfg.has("frame_size"):
		var fsz: Array = cfg["frame_size"]
		fw = float(fsz[0])
		fh = float(fsz[1])
	else:
		fw = sheet_w
		fh = sheet_h
	_setup_texture(diffuse, character)
	region_enabled = true
	centered = true
	# Pivot → where the node origin sits on the cell. bottom_center puts feet
	# at the origin; an explicit "offset" overrides.
	var off_y := -fh / 2.0 if str(cfg.get("pivot", "bottom_center")) == "bottom_center" else 0.0
	if cfg.has("offset"):
		var off: Array = cfg["offset"]
		offset = Vector2(float(off[0]), float(off[1]))
	else:
		offset = Vector2(0, off_y)
	var s := float(cfg.get("scale", 1.0))
	scale = Vector2(s, s)
	play("idle")
	return true

func _setup_texture(diffuse: Texture2D, character: String) -> void:
	var norm_name := str(cfg.get("normal", str(cfg.get("sheet", character + ".png")).get_basename() + "_n.png"))
	var norm: Texture2D = Assets.texture(Assets.SPRITE_DIR + norm_name)
	if bool(cfg.get("chroma_key", false)):
		# Flat-background sheet: key the desaturated background in-shader. Renders
		# flat-lit (no normal relief) — a transparent re-export restores that.
		texture = diffuse
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = CHROMA_SHADER
		mat.shader = sh
		mat.set_shader_parameter("luma_min", float(cfg.get("chroma_luma", 0.80)))
		mat.set_shader_parameter("sat_max", float(cfg.get("chroma_sat", 0.13)))
		material = mat
	elif norm != null:
		var ct := CanvasTexture.new()
		ct.diffuse_texture = diffuse
		ct.normal_texture = norm
		texture = ct
	else:
		texture = diffuse

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

func _frame_count() -> int:
	var a: Dictionary = anims[cur]
	if a.has("indices"):
		return (a["indices"] as Array).size()
	return int(a.get("frames", 1))

func _process(delta: float) -> void:
	if cur == "" or done:
		return
	var a: Dictionary = anims[cur]
	if str(a.get("mode", "sequence")) == "pose":
		return
	var count := _frame_count()
	if count <= 1:
		return
	frame_t += delta
	if frame_t >= 1.0 / maxf(fps, 1.0):
		frame_t = 0.0
		frame_i += 1
		if frame_i >= count:
			if bool(a.get("loop", true)):
				frame_i = 0
			else:
				frame_i = count - 1
				done = true
		_apply()

func _apply() -> void:
	var a: Dictionary = anims[cur]
	var row := int(a.get("row", 0))
	var col := frame_i
	if a.has("indices"):
		var idx: Array = a["indices"]
		col = int(idx[clampi(frame_i, 0, idx.size() - 1)])
	region_rect = Rect2(col * fw, row * fh, fw, fh)

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
