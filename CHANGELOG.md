# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); versioning
follows [Semantic Versioning](https://semver.org/) (`0.x` = pre-release:
minor = feature drop, patch = fixes/balance).

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
