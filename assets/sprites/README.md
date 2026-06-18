# Sprites — production art path (with procedural fallback)

The vertical slice draws the Witness, every enemy, the boss, and all VFX
**procedurally in code**. **No image files are required to run the game.**

`scripts/core/asset_registry.gd` (autoload `Assets`) is the production art
path. Drop final art here and characters can migrate to sprites one at a time
without changing any combat code — if an asset is missing, the renderer keeps
drawing procedurally.

## Per-character sprite sheets

1. Drop a sprite sheet, e.g. `witness.png` (a fixed grid: one animation per
   row, frames left-to-right).
2. Add a config `witness.json` next to it:

```json
{
  "sheet": "witness.png",
  "frame_size": [64, 64],
  "fps": 12,
  "animations": {
    "idle":    {"row": 0, "frames": 4, "loop": true},
    "walk":    {"row": 1, "frames": 6, "loop": true},
    "attack":  {"row": 2, "frames": 5, "loop": false},
    "windup":  {"row": 3, "frames": 3, "loop": false},
    "hurt":    {"row": 4, "frames": 2, "loop": false},
    "death":   {"row": 5, "frames": 6, "loop": false},
    "special": {"row": 6, "frames": 5, "loop": false}
  }
}
```

Required animation rows: `idle`, `walk`, `attack`, `windup`, `hurt`,
`death`. Optional: `charge` (held heavy) and any `special`. Missing rows fall
back gracefully (e.g. `walk`→`idle`, `windup`→`attack`, `death`→`hurt`), so a
minimal sheet with just `idle`/`attack`/`death` already works.

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
