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

Required animation states: `idle`, `walk`, `attack`, `windup`, `hurt`,
`death`, plus any `special` states a character needs. Character keys match the
enemy ids in `data/enemies.json` (`ash_thrall`, `iron_brute`, …), `witness`
for the player, and the boss ids (`first_blade`, `half_buried_giant`).

`Assets.has_character_sprites(id)` returns whether a config exists;
`Assets.animation(id, "walk")` returns that animation's frame data;
`Assets.sheet_texture(id)` returns the texture (or `null` → procedural).

## VFX atlases (assets/vfx/)

Drop `<kind>.png` for any of: `slash`, `holy_fire`, `corruption_pool`,
`revelation_pulse`, `binding_seal`, `boss_phase_transition`.
`Assets.vfx_atlas("slash")` returns the texture or `null` (→ procedural FX).
