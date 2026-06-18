# THE WATCHERS: FALL OF THE GIANTS
### Isometric action-roguelike — playable vertical slice

You are the **Appointed Witness**, a mortal scribe-warrior commissioned by the
archangels to hunt, bind, expose, and defeat the fallen Watchers, the Nephilim
bloodlines, and the disembodied spirits of the giants. This prototype is a
complete run: hub → commission → the Desert of Azazel → elite → mini-boss →
**Azazel's First Blade** → codex disclosure → return and upgrade.

Everything in this slice — sprites, VFX, rooms, UI, even the music and sound
effects — is **generated procedurally in code**. There are no binary assets,
no paid assets, and no internet access required.

---

## How to play

**In your browser (desktop or mobile):** https://atxgreene.github.io/giants/play/
— no install. On touchscreens a virtual joystick and action buttons appear
automatically, with auto-aim. Every push to `main` redeploys this build.

**Pre-built desktop binaries:** download from the repo's GitHub Releases page
(built automatically for Windows / macOS / Linux on every version tag).

**From source:**
1. Install **Godot 4.3 or newer** (standard build, free): https://godotengine.org/download
   (The project uses `angle_difference` / `rotate_toward`, added in 4.3.)
2. Open Godot → **Import** → select this folder's `project.godot` → **Open**.
3. Press **F5** (Run Project). First launch takes a few seconds while the
   procedural audio is synthesized.

Or from a terminal:

```sh
godot --path /path/to/watchers-fall-of-the-giants
```

Save data is written to `user://watchers_save.json`
(macOS: `~/Library/Application Support/Godot/app_userdata/The Watchers: Fall of the Giants/`).

## Controls

| Action | Keyboard / Mouse | Controller |
|---|---|---|
| Move | WASD / arrows | Left stick |
| Aim | Mouse | Right stick |
| Light attack (3-hit combo) | Left click | X / Square |
| Heavy flame arc | Shift or Middle click | Y / Triangle |
| Crescent of holy fire (special) | Right click | Right trigger |
| Dash (i-frames) | Space | Right shoulder |
| Binding Seal | Q | Left shoulder |
| Michael's Verdict (Ultimate, when charged) | R | B / Circle |
| Interact | E | A / Cross |
| Pause | Esc | Start |

**Touch (mobile browser):** left-thumb virtual joystick (press anywhere on the
lower-left), action buttons on the right (ATK / HVY / CRES / DASH / SEAL /
ULT / E), pause in the top-right corner. Aim is automatic — the Witness
targets the nearest threat.

**Tip:** attack immediately after a dash for the *dash slash*. Bind giant
spirits instead of just killing them — bound kills fill Revelation.

---

## What is implemented (all playable)

- Main menu, settings (volumes, damage numbers, screen shake, fullscreen), pause menu, game-over and victory screens
- Hub: **The Watchtower Between Worlds** — Michael, Gabriel, Raphael, Uriel (appears after the boss falls), the Scribe of Dust, weapon altar (3 aspects), training altar (5 persistent upgrades), blessing preview, codex lectern, training dummy, desert gate
- Opening sequence (giants' dream → Gabriel → Michael → the sword)
- One full biome run: 9 rooms from 10 templates (start, small arena, wide arena, forge ambush, bone corridor, elite forge, relic shrine, vision room, mini-boss arena, boss arena)
- Hades-style exit gates with reward previews; reward types: blessing, healing fountain, relic, currency, codex fragment, weapon upgrade, forbidden knowledge
- 16 archangel blessings across 4 pools (Michael / Gabriel / Raphael / Uriel — Uriel unlocks by beating the boss), 5 relics, 3 forbidden powers
- 6 enemy types + elite (Azazel's Smith-Priest) + mini-boss (The Half-Buried Giant) + 3-phase boss (Azazel's First Blade) with the **temptation choice** (Edge of Azazel vs. Seal of Michael)
- Combat feel: dash i-frames, hit-stop, knockback, stagger/poise, screen shake, telegraphs, damage numbers (toggle), slash/burst/ring VFX, boss bar, slow-mo near-dodge (Uriel)
- Corruption meter (forbidden gifts, hound pools; ≥50 empowers enemies, changes hub dialogue) and Revelation meter (elites, bound kills, untouched rooms, refusals, codex; ≥50 grants +10% damage, ≥90 unlocks a hidden codex page)
- The Witness Archive: 13 codex entries, each tagged with a **source tier** (Canonical Scripture / Enochic Tradition / Book of Giants Fragment / Scholarly Reconstruction / Game-Original / Unknown)
- Persistent save: Seals of Witness, codex, aspects, upgrades, flags, settings
- Keyboard/mouse and controller (input map registered in code)
- Procedural audio: 18 SFX + 3 music loops synthesized at startup

## What is stubbed / known limitations

- **Art is procedural placeholder** — readable silhouettes, telegraphs, and VFX, not final hand-painted art. The room floor is fake-isometric (diamond tiles over screen-space movement), not a true projected iso grid.
- Audio is synthesized; replace per `assets/audio/README.md`.
- Single biome; full-corruption ending, Revelation Route, and modern-earth arcs are flagged in save data but not yet scripted (see `ROADMAP.md`).
- Heavy attack is a separate button rather than a hold; no attack-canceling rules beyond the dash window.
- Enemy pathfinding is steering-only (no navmesh); rooms are open arenas by design.
- No rebindable controls UI yet (edit `Game._register_inputs()`).

---

## Implementation roadmap (how to extend)

### How to add a new weapon
1. Add an entry to `data/weapons.json` (copy `flaming_sword`: light combo array, heavy, dash_slash, special, seal, ult).
2. In `scripts/player/player.gd`, `_ready()` picks the weapon — replace the hardcoded `"flaming_sword"` with a profile field (e.g. `Game.profile["weapon"]`).
3. Add a selection row in `scripts/ui/altar_menu.gd` (weapon mode) that sets that field.
4. New attack *behaviors* (not just numbers) go in `player.gd` — `_strike()`, `_fire_crescent()`, `_try_ultimate()` all read the weapon dict.

### How to add a new blessing
1. Add it to a pool in `data/blessings.json` with a `mods` dictionary.
2. If it's a pure stat (`dmg_mult`, `max_hp`, `stagger_mult`, `rev_gain`, …) you are done — `RunState.mod()` stacks it automatically.
3. New *behavioral* hooks: check `RunState.has_mod("your_key")` at the relevant call site (see `dash_spark` in `player.gd:_try_dash` or `seal_heal` in `binding_seal.gd` for the pattern).

### How to add a new enemy
1. Add stats to `data/enemies.json` (hp, speed, dmg, poise, shape, color, attack_range, windup, recover, cd, hit_radius, seals).
2. Create `scripts/enemies/your_enemy.gd` extending `EnemyBase`; override `pick_attack()`, `_attack_begin()`, and optionally `desired_position()` / `_attack_tick()` (see `watcher_hound.gd` for a complete small example).
3. Register the script path in `EnemyBase.SUBCLASS_PATHS`.
4. Add it to wave lists in `data/rooms.json`.

### How to add a new codex entry
1. Add an entry to `data/codex_entries.json` with `title`, `tier` (1–6, see `CodexMan.TIER_LABELS`), `summary`, `unlocked_by`, `relevance`, `mystery`.
2. Call `CodexMan.unlock("your-id")` from the trigger (enemy `on_death()`, room events, boss flow…), or leave it reachable through the random fragment pool — non-tier-6 entries are included automatically.

### How to add a new room template
Add it to `data/rooms.json` (`kind`: combat/shrine/vision/…; `size`; `props`; `waves`) and insert its id into the `seq` array in `run_scene.gd`.

### Next best expansion tasks
See `ROADMAP.md` — short version: second biome (Drowned City of the Bloodlines), second weapon (Censer-Flail of Raphael), full corruption ending, Revelation Route, navmesh pathfinding, hand-painted art pass, real audio pass.

---

## Project structure

```
project.godot              # engine config; autoloads registered here
scenes/main.tscn           # the only scene file — everything else is code-built
scripts/
  core/                    # main router, game/profile manager, run state,
                           # data loader, FX/juice singleton, audio synth, camera
  player/                  # player controller, binding seal
  combat/                  # projectiles, ring + ground hazards
  enemies/                 # EnemyBase state machine + 6 enemy types + elite
  bosses/                  # Half-Buried Giant (mini-boss), First Blade (boss)
  rooms/                   # room builder (floor/props/gates/waves), run orchestrator
  hub/                     # Watchtower, NPCs, training dummy
  ui/                      # UI kit, HUD, menus, dialogue, reward/choice screens
  codex/                   # the Witness Archive manager
  save/                    # JSON save manager
data/                      # all content: weapons, blessings, enemies, rooms,
                           # upgrades, codex entries, dialogue
assets/                    # placeholder notes; everything is procedural for now
```

## Documents

- `CHANGELOG.md` — versioned release notes (semver; current: v0.4.0)
- `DESIGN_BRIEF.md` — pillars, loops, systems reference
- `LORE_BIBLE.md` — cosmology, source-tier methodology, characters, biome bible
- `ROADMAP.md` — expansion plan
- `LAUNCH_PLAN.md` — release engineering, distribution ladder, scaling plan

Pre-built binaries: pushing a version tag builds Windows/macOS/Linux
releases automatically (see `.github/workflows/release.yml` and the
project's GitHub Releases page).

## Content note

This game draws on Genesis 6, Daniel, Jude, 2 Peter, Revelation, 1 Enoch, and
the Book of Giants fragments. The in-game Witness Archive deliberately labels
every entry by source tier — canonical, apocryphal, fragmentary, scholarly
reconstruction, or game invention — and does not present disputed material as
settled fact. All art, names, systems, and text are original to this project.
