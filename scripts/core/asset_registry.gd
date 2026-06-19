extends Node
## Production art path with a procedural fallback (Phase 2.5).
##
## The vertical slice renders the Witness, enemies, boss, and VFX entirely in
## code. This registry lets final sprite sheets and VFX atlases be dropped into
## assets/ one character at a time WITHOUT touching combat code: a renderer asks
## the registry for a character's animation config or a VFX atlas, and if the
## asset is absent the caller keeps drawing procedurally.
##
## Nothing here requires any binary asset to exist — every lookup degrades to
## "use the procedural renderer".
##
## Per-character config: assets/sprites/<character>.json — the sprite contract
## read by CharSprite (see assets/sprites/README.md). Uniform grid; cell size is
## derived from grid x the actual texture; `indices` pick columns; `mode` is
## "pose" (hold indices[0]) or "sequence" (step indices). e.g.:
## {
##   "sheet": "witness_clean.png",
##   "normal": "witness_clean_n.png",     # optional -> Light2D relief
##   "frame_size": [160, 160],            # contract hint; grid wins for cropping
##   "grid": { "cols": 8, "rows": 7 },
##   "fps": 12,
##   "offset": [0, -80], "pivot": "bottom_center",
##   "scale": 0.42,                       # display scale to ~64px gameplay size
##   "chroma_key": false,                 # true keys a flat bg (no-alpha sheets)
##   "inset": 0,                          # crop margin to avoid edge bleed
##   "animations": {
##     "idle":   { "row": 0, "indices": [0],       "mode": "pose",     "loop": true },
##     "walk":   { "row": 1, "indices": [3],       "mode": "pose",     "loop": true },
##     "attack": { "row": 2, "indices": [2,3,4],   "mode": "sequence", "loop": false },
##     "death":  { "row": 5, "indices": [0,1,2,3], "mode": "sequence", "loop": false }
##   }
## }
## Coherent per-action strips (enemies) can use "sequence" for idle/walk too.

const SPRITE_DIR := "res://assets/sprites/"
const VFX_DIR := "res://assets/vfx/"
const PROP_DIR := "res://assets/props/"
const FLOOR_DIR := "res://assets/floors/"

const VFX_KINDS := ["slash", "holy_fire", "corruption_pool", "revelation_pulse",
	"binding_seal", "boss_phase_transition"]

var _tex_cache: Dictionary = {}
var _config_cache: Dictionary = {}

# ---------------------------------------------------------------- characters

func has_character_sprites(character: String) -> bool:
	return not config_for(character).is_empty()

func config_for(character: String) -> Dictionary:
	if _config_cache.has(character):
		return _config_cache[character]
	var cfg: Dictionary = {}
	var path := SPRITE_DIR + character + ".json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			cfg = parsed
	_config_cache[character] = cfg
	return cfg

func animation(character: String, anim: String) -> Dictionary:
	return config_for(character).get("animations", {}).get(anim, {})

func sheet_texture(character: String) -> Texture2D:
	var cfg := config_for(character)
	if cfg.is_empty():
		return null
	return texture(SPRITE_DIR + str(cfg.get("sheet", character + ".png")))

# ---------------------------------------------------------------- props / floors

## Drop-in environment art: assets/props/<kind>.png and assets/floors/<room_kind>.png.
## Return null when absent so rooms keep drawing procedurally.
func prop_texture(kind: String) -> Texture2D:
	return texture(PROP_DIR + kind + ".png")

func floor_texture(room_kind: String) -> Texture2D:
	return texture(FLOOR_DIR + room_kind + ".png")

# ---------------------------------------------------------------- vfx

func has_vfx(kind: String) -> bool:
	return vfx_atlas(kind) != null

func vfx_atlas(kind: String) -> Texture2D:
	return texture(VFX_DIR + kind + ".png")

# ---------------------------------------------------------------- textures

func texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is Texture2D:
			tex = res
	elif FileAccess.file_exists(path):
		# Raw-dropped image (not yet imported): load it directly.
		var img := Image.new()
		if img.load(path) == OK:
			tex = ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex
