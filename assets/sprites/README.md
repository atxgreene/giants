# Sprites — production art path (with procedural fallback)

The vertical slice draws the Witness, every enemy, the boss, and all VFX
**procedurally in code**. **No image files are required to run the game.**

`scripts/core/asset_registry.gd` (autoload `Assets`) is the production art
path. Drop final art here and characters can migrate to sprites one at a time
without changing any combat code — if an asset is missing, the renderer keeps
drawing procedurally.

## Asset contract (the format `CharSprite` reads)

One sheet on a **uniform `grid` (cols × rows)**, one row per state. Each
animation names its `row`, an `indices` list of columns to use, and a `mode`:

- `mode: "pose"` — hold one frame (`indices[0]`). Use this for `idle`, `walk`,
  `windup`, `hurt`, `special`. (AI sheets are distinct poses, not coherent
  in-betweens, so playing whole rows flickers — pose-swap reads as intentional.)
- `mode: "sequence"` — step through the listed `indices` only. Use for the
  genuinely sequential rows: `attack` (best 3–5 frame slash) and `death`.

```json
{
  "sheet": "witness.png",
  "normal": "witness_n.png",
  "frame_size": [160, 160],
  "grid": { "cols": 8, "rows": 7 },
  "fps": 12,
  "offset": [0, -84],
  "pivot": "bottom_center",
  "scale": 0.42,
  "animations": {
    "idle":   { "row": 0, "indices": [0],                "mode": "pose",     "loop": true },
    "walk":   { "row": 1, "indices": [3],                "mode": "pose",     "loop": true },
    "attack": { "row": 2, "indices": [2, 3, 4],          "mode": "sequence", "loop": false },
    "windup": { "row": 3, "indices": [1],                "mode": "pose",     "loop": false },
    "hurt":   { "row": 4, "indices": [1],                "mode": "pose",     "loop": false },
    "death":  { "row": 5, "indices": [0,1,2,3,4,5,6,7],  "mode": "sequence", "loop": false },
    "special":{ "row": 6, "indices": [3],                "mode": "pose",     "loop": false }
  }
}
```

Notes:
- **Cell size** is derived from `grid` × the actual texture (so an export that
  lands at 1341×1173 on an 8×7 grid still crops accurately at ~167px). `frame_size`
  is the intended/contract value; `grid` wins for cropping.
- **`scale`** is an engine display scale (art is authored larger than the ~64px
  gameplay scale); **`pivot: "bottom_center"`** puts feet at the origin, with
  `offset` as the explicit nudge.
- Required rows: `idle`, `walk`, `attack`, `windup`, `hurt`, `death`. Optional:
  `charge` (held heavy), `special`. Missing rows fall back
  (`walk`→`idle`, `windup`/`charge`→`attack`, `death`→`hurt`).

### Clean runtime atlas (avoid fractional crops)
Runtime cropping must use an **exact-grid** atlas, or fractional cells bleed
neighbour pixels during movement. If a generated sheet isn't power-of-two/exact
(e.g. the Witness came out 1341×1173), repack it:

```
python3 scripts/tools/repack_atlas.py   # witness.png[+_n] -> *_clean.png (1280x1120, 160px cells, true alpha)
```

The repacker resamples to an exact grid and keys the flat background to real
alpha (so `chroma_key` can be off and the normal map lights the sprite). Point
the manifest at the `*_clean.png` / `*_clean_n.png` outputs.

### Verifying the live web build
CI stamps `assets/build_info.json` with the commit SHA on each deploy; the main
menu shows it (`v0.4.0 · build <sha>`). If the menu SHA doesn't match the latest
commit, the browser is on a cached build — hard-refresh. (The web export's PWA
service worker is disabled, so a hard refresh always pulls fresh.)

### Generating sheets that animate well
Don't ask the model for one giant seven-row multi-action sheet when you want
smooth motion — it won't be frame-coherent. Generate **one action at a time**,
then assemble into the atlas above:
1. `idle` — 4-frame breathing loop
2. `walk` — 8-frame true walk cycle
3. `attack` — 4–6-frame swing
4. `death` — 6–8-frame collapse

With coherent per-action frames you can switch those rows from `pose` to
`sequence` and they'll play as real animation.

**This is now live.** `Player` and `EnemyBase` call `CharSprite.try_make(id)`
at spawn: if a config exists the sheet renders (and is state-driven —
idle/walk/attack/windup/hurt/death/charge); if not, they keep the procedural
body. No combat code changes when you add art.

**Character ids** (the `<character>.json` / sheet basename):
- `witness` — the player
- enemies (match `data/enemies.json`): `ash_thrall`, `iron_brute`,
  `star_archer`, `nephilim_bloodling`, `bound_giant_spirit`, `watcher_hound`,
  `pack_alpha`, `smith_priest`
- bosses: `half_buried_giant`, `first_blade`

**Facing**: author **right-facing** art only — left is auto-flipped (`flip_h`).

**Pivot**: feet sit at the node origin by default (`offset = [0, -frame_h/2]`).
Override per character with `"offset": [x, y]` in the config if your art needs
it.

### Backgrounds / transparency
Sheets should be **PNG with a transparent (alpha) background**. If a sheet is
flattened onto a flat background (no alpha), set `"chroma_key": true` in its
config to key out the desaturated background in-shader (tune with
`"chroma_luma"` / `"chroma_sat"`). This is a stopgap — a real transparent
export looks better around glows/fire and re-enables normal-map relief (the
chroma-key path renders flat-lit, not normal-mapped).

### Normal maps (the HD-2D lighting payoff)
Drop a second sheet named `<sheet>_n.png` (same grid) — e.g. `witness_n.png`
beside `witness.png`. It's wired through a `CanvasTexture`, so the game's
`Light2D` pools (the Witness key-light, forges, braziers, impact flashes) light
the sprite in real 3-D relief. Strongly recommended — this is what pushes the
look past flat 2D.

`Assets.has_character_sprites(id)` reports whether a config exists;
`Assets.sheet_texture(id)` returns the texture (or `null` → procedural).

## VFX atlases (assets/vfx/)

Drop `<kind>.png` for any of: `slash`, `holy_fire`, `corruption_pool`,
`revelation_pulse`, `binding_seal`, `boss_phase_transition`.
`Assets.vfx_atlas("slash")` returns the texture or `null` (→ procedural FX).
