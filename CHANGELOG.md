# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); versioning
follows [Semantic Versioning](https://semver.org/) (`0.x` = pre-release:
minor = feature drop, patch = fixes/balance).

## [0.4.0] — 2026-06-18 — "The Forking Path"

Phase 2.5 — game feel, replayability, and production foundation. The run is
no longer a fixed corridor, the Witness has a second weapon, and CI now
protects build quality instead of just producing builds.

### Added — Run Director v1
- Data-driven, seeded run graph (`data/run_routes.json`,
  `scripts/rooms/run_director.gd`). The old fixed sequence is now just the
  "Pilgrim Road" fallback route.
- Route archetypes: **Judgment** (combat/elite heavy, Michael/Gabriel-biased),
  **Mercy** (shrines, healing, Raphael-biased), **Temptation** (forbidden
  gates, corrupted rooms, enemies that grow stronger late).
- Weighted room rarity, no-repeat rules, boss/miniboss locks, route-preview
  language at the desert gate, and guaranteed content every run (a blessing,
  a heal, a codex/vision room, a miniboss, a boss).
- Corrupted room variants once Corruption ≥ 50; hidden Revelation chambers
  once Revelation ≥ 80; bad-luck protection so exhausted reward pools are
  swapped out.
- Deterministic seeds: the same seed reproduces route order and reward rolls.
  Seed + route are shown in the pause menu and the victory / game-over
  summaries.

### Added — Second weapon: Censer-Flail of Raphael
- A mid-range sweeping chain weapon with lower burst, better crowd control,
  cleanse zones, and a binding-focused identity. Strong against corruption
  pools and hounds, weak against armored brutes until upgraded.
- Cleanse-zone special, overhead cleanse pulse, and the **Wound of the
  World** ultimate (radial cleanse, stagger, corruption scrub, Revelation
  for bound foes).
- Three aspects: **Raphael** (lasting cleanse, binding heals), **Mercy**
  (bound foes take less damage but grant more Revelation), **Dudael**
  (corruption pools convert to safe ash).
- Weapon choice moved out of `Player._ready` into `Game.profile["weapon"]`
  with per-weapon equipped aspects, unlock state, save support, and altar
  selection UI.

### Added — Content
- New elite: the **Hound-Mother** and the Kennels of Azazel room.
- Three corrupted room variants, three hidden Revelation events, a new
  Scribe of Dust dialogue branch, Michael's rebuke (after three forbidden
  gifts) and Raphael's commendation (a clean victory), and seven new codex
  entries — all source-tiered.
- Victory screen now shows a full run summary: route, seed, corruption,
  revelation, bound kills, forbidden gifts accepted/refused, weapon/aspect,
  and codex pages unlocked.

### Added — HD-2D atmosphere pass
- The 2.5D look now reads like a lit miniature diorama (à la the HD-2D
  remakes): real screen-space **bloom** on the gold/fire/holy elements, a
  **tilt-shift** depth blur top and bottom, drifting **light shafts** from the
  Eye, and a warm/cool color grade. Applied to the main menu, hub, and run.
  New "Bloom / HD-2D Glow" setting.
  - Bloom is a `BackBufferCopy` + threshold/blur/add **canvas shader**, so it
    works on EVERY renderer — including the web/mobile GL-Compatibility
    backend, where `WorldEnvironment` 2D glow is unavailable. Placed below the
    HUD so the UI stays crisp.
  - A warm additive **Light2D key-light** follows the Witness for a lit pool
    (cool light for the Censer). Murk (vignette + tilt-shift) toned down and
    the grade warmed so the scene doesn't read cold.
  - **Environment is lit by its own sources**: forges, molten cracks, idols,
    and starfall shards cast flickering colored light pools; north-corner
    braziers light each arena; the hub seal glows steadily and the boss arena
    has a restless forge-glow. Floor tiles gained a subtle bevel (lit upper /
    shadowed lower edges) so the ground reads with height instead of flat.

### Added — Durability & accessibility
- Save versioning (`save_version`, migration table, pre-migration backup,
  field repair). Old saves load; a corrupt save fails visibly instead of
  silently wiping progress.
- New accessibility settings: screen-shake amount, flash intensity, text
  scale, high-contrast / colorblind-safe telegraphs, and a pause-menu
  control map.

### Changed — CI
- `godot --headless --import` no longer ends in `|| true`; parse/compile
  errors fail the build.
- New `ci` workflow: headless smoke test (data integrity, run-graph
  no-softlock + determinism, save migration, live enemy/player
  instantiation), web-export boot check, and a version/changelog/README
  consistency check.

## [0.3.1] — 2026-06-10 — "The Vision"

### Art
- Integrated project-original concept art (`assets/concept/`): key art now
  backs the main menu (with darkening overlay, live embers, and a framed
  menu panel); the player palette matches the Witness concept — deep indigo
  robes, gold filigree script, and the glowing codex tablet carried in the
  off-hand.
- Website: key art behind the hero, new "The Vision" concept gallery
  (Witness, Iron-Taught, Azazel's First Blade).
- Animation-reference sheets archived in `assets/concept/` with notes on
  what the production sprite sheets need (transparent fixed-grid cells)
  before they can replace the procedural bodies.

### Fixes
- macOS and Web exports: enabled ETC2/ASTC texture import (required for
  universal macOS binaries and mobile-targeted web texture compression) —
  this un-blocks the remaining two CI export targets.

## [0.3.0] — 2026-06-10 — "The Witness Goes Anywhere"

### Web & mobile
- **Playable in the browser**: single-threaded WASM export (no special
  headers required — works on GitHub Pages, iOS Safari, and Android
  browsers). Live at the project site under `/play/`.
- **Touch controls**: dynamic virtual joystick (lower-left), action buttons
  (attack, heavy, crescent, dash, seal, ultimate, interact) with cooldown
  rings, and a corner pause button. Appears automatically on touchscreens;
  desktops never see it.
- **Touch auto-aim**: on touch devices the Witness aims at the nearest
  living enemy, falling back to movement direction; Binding Seal casts at
  fixed range.
- Landscape orientation lock on handhelds; shorter hub-music loop on web
  for faster WASM startup; dialogue tap-debounce for touch.

### Infrastructure
- **Continuous web deployment**: every push to `main` exports the web build
  in CI and deploys landing page + game to GitHub Pages (Vercel-style
  push-to-deploy, on GitHub's free tier).
- Fixed the v0.2.0 release pipeline (export templates path under Actions'
  HOME override; removed Windows rcedit-dependent metadata). Desktop
  binaries now build correctly on version tags.

## [0.2.0] — 2026-06-10 — "The Illuminated Desert"

### Graphics & feel
- **2.5D environment pass**: walls with real height, brickwork faces, lit
  caps, merlons, and corner braziers; edge ambient occlusion; floor lighting
  that falls off toward the walls; glowing molten fissures with layered heat;
  scattered decals (pebbles, bone chips, sand drifts); per-room floor inlays
  (Watchtower great seal, boss arena ring, vision circle).
- **Layered horizon**: distant basalt mountain range and moonlit dune bands
  around desert rooms; star void with drifting rock shards around the hub.
- **Global sun**: one directional light convention — every entity and prop
  now casts a coherent soft directional shadow plus contact shadow.
- **Atmosphere**: drifting ash-storm particles in the desert, golden dust
  motes in the Watchtower, plus a screen-space vignette grade.
- **Player model rebuilt**: layered robe with animated hem, hood, shoulder
  mantle and pauldron, belt with scroll case, walk-cycle boots, movement
  lean, idle breathing, orbiting witness-halo marks; proper tapered flaming
  blade with cross-guard, climbing flame tongues, and heat glow; sword-trail
  ribbon on swings; dash afterimage ghosts.
- **Enemy readability pass**: crisp dark outlines, ember eye glows, spawn
  rise-from-the-sand animation, hit-reaction scale punch, white anticipation
  flash in the final moments of every windup, elite rune-ring auras; per-type
  details (brute rivets, bloodling bone spurs, hound ember mane, priest anvil
  emblem).
- **Boss pass**: translucent wing membranes on Azazel's First Blade;
  outlined stone torso, skin cracks, and under-sand molten glow on the
  Half-Buried Giant.
- **HUD overhaul**: witness-eye sigil portrait with low-health and
  ult-ready states; framed gradient bars with tick marks and end-cap
  diamonds; drawn ability glyphs with radial cooldown sweeps and input
  hints; ultimate ring with sword glyph; weapon plate; blessing gems;
  ornate boss bar with wing flourishes and phase diamonds.
- **Main menu**: layered night-sky backdrop with twinkling stars, script
  ring on the great seal, dune horizon with a half-buried colossus, molten
  foreground cracks, and rising embers. Version stamp added.

### Infrastructure
- Semantic versioning adopted (`Game.VERSION`, git tags, this changelog).
- GitHub Actions release pipeline: pushing a `v*` tag builds Windows,
  macOS, and Linux binaries and attaches them to a GitHub Release.
- Export presets for all three desktop platforms.
- `LAUNCH_PLAN.md`: distribution, release engineering, and scaling plan.

## [0.1.0] — 2026-06-10

Initial playable vertical slice: hub (Watchtower Between Worlds), full
Desert of Azazel run (9 rooms / 10 templates), 6 enemy types + elite +
mini-boss + 3-phase boss with the temptation choice, 16 blessings across
4 archangel pools, relics, forbidden knowledge, corruption + revelation
meters, 14-entry source-tiered codex, persistent upgrades and save,
procedural art/VFX/audio, keyboard/mouse + controller support.
