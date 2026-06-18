# ROADMAP — from vertical slice to full game

## Phase 1 — Slice hardening (done)
- [x] Hub, full Desert of Azazel run, elite, mini-boss, boss, temptation
- [x] Blessings ×16, relics ×5, forbidden ×3, aspects ×3, upgrades ×5
- [x] Codex with source tiers; corruption + revelation meters
- [x] Balance pass on Brute poise + boss phase 2 lane density (Phase 2.5)
- [x] Lightweight obstacle-aware enemy navigation (props) (Phase 2.5)

## Phase 2 — Depth (done in Phase 2.5)
- [x] Second weapon: **Censer-Flail of Raphael** (mid-range arcs, cleanse zones)
- [x] Weapon select at the altar; aspects per weapon
- [x] 4 more relics (9 total), 6 Duo-blessings (two patrons)
- [x] Hidden Revelation rooms gated by Revelation ≥ 80
- [ ] Real hand-painted sprite pass — *pipeline ready* (`Assets` registry +
  procedural fallback); art itself still to be produced
- [ ] Recorded audio pass — *pipeline ready* (external override + fallback);
  recordings still to be produced

## Phase 2.5 — Game feel, replayability, production foundation (done)
- [x] Run Director v1: seeded, route-flavoured run graph (Judgment / Mercy /
  Temptation), weighted rooms, no-repeat, corrupted variants, bad-luck
  protection, route guarantees, deterministic seeds shown in UI
- [x] Combat feel: input buffering, cancel windows, heavy charge, hit-pause
  table, hurt grace, near-miss feedback, F3 debug overlay
- [x] Save versioning + migration + backup + repair
- [x] CI quality gate: failing import, headless smoke test, web boot check,
  version/changelog/README consistency
- [x] Accessibility: shake/flash sliders, text scale, high-contrast +
  colorblind telegraphs, hold-to-dash, control map
- [ ] Full NavigationRegion2D / NavigationAgent2D pathfinding (deferred; the
  lightweight steering layer ships now)
- [ ] Rebindable controls UI (control map ships now; live rebinding deferred)

## Phase 3 — Second biome
- **The Drowned City of the Bloodlines**: flood-scarred ziggurats, water
  hazards, Nephilim nobility, mini-boss "The Mother of Renown",
  boss "Shemihazah's Herald"
- Biome selection at the desert gate; depth scaling across biomes

## Phase 4 — Routes and endings
- Full-corruption **bad ending** (flag already saved): the Witness becomes
  a Watcher's instrument; Michael's final dialogue branch
- **Revelation Route**: sustained high Revelation opens the Archive's empty
  shelf and a pacifist-leaning binding playstyle (seals scale, kills don't)
- Scribe of Dust identity questline (Enoch reveal — or refusal to reveal)

## Phase 5 — The long game
- Third biome: **The Iron Heavens** (corrupted pre-flood sky-technology)
- Modern-earth epilogue arc: occult infiltration of the present day,
  disclosure-fiction framing; the Archive gains a seventh source tier:
  "Contemporary Testimony"
- Azazel himself — not as a damage sponge, but as the final temptation
