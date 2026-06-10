# LAUNCH & SCALING PLAN — The Watchers: Fall of the Giants

A pragmatic path from open prototype to commercial-grade release, sized for
a small team. Each stage has explicit gates so scope can't silently creep.

---

## 1. Release engineering (in place as of v0.2.0)

**Versioning.** Semantic versioning on git tags. `0.MINOR.PATCH` while
pre-release: minor = feature drop, patch = fix/balance. `Game.VERSION` is the
single in-code source of truth and is shown on the main menu. Every release
gets a `CHANGELOG.md` entry — players should never have to diff builds to
learn what changed.

**Branching.** Trunk-based with short-lived feature branches
(`feat/…`, `fix/…`) merged to `main` via `--no-ff` so each feature is one
revertable merge. `main` is always shippable; tags are cut from `main` only.

**Automated builds.** `.github/workflows/release.yml`: pushing a `v*` tag
exports Windows / macOS / Linux builds in CI (godot-ci container) and
attaches them to a GitHub Release. No hand-built binaries, ever — if the
pipeline can't build it, it doesn't ship.

**Quality gates per release.**
1. Headless import: zero parse/compile errors.
2. Automated full-loop smoke test (hub → run → boss → victory) passes.
3. A rendered pass (the same test, windowed) to exercise all `_draw` code.
4. Manual 10-minute feel check on at least one platform.
5. Save-compatibility check (see §4).

## 2. Distribution ladder

| Stage | Channel | Gate to advance |
|---|---|---|
| Now | GitHub repo + Pages site; players run from source | — |
| Next | **GitHub Releases** binaries (already automated on tag) | first `v0.2.x` tag |
| Then | **itch.io** page (free), butler push wired into CI | 30+ unique players, crash-free sessions |
| Then | **Steam** page ("Coming Soon" wishlist build) | art pass complete (Phase 2 of ROADMAP) + trailer |
| 1.0 | Steam Early Access | 3 biomes, 2 weapons, both ending routes |

Rationale: each rung is cheap, reversible, and grows the feedback pool
before the next investment. Steam's wishlist machinery only works once the
game *looks* like its final art, so the Pages site + itch carry early growth.

## 3. Marketing beats (low-cost, honest)

- The **disclosure hook is the marketing**: short clips framed as Archive
  entries ("SOURCE: Enochic Tradition") — the source-tier system is unique
  and screenshots well.
- Devlog cadence: one post per minor version (the changelog already writes
  half of it). Cross-post to itch devlogs + a thread account.
- The Pages site is the canonical link hub; add a presskit page before the
  Steam stage (logo, GIFs, fact sheet, contact).
- Community: GitHub Discussions first (zero moderation overhead), Discord
  only after itch traction proves demand.

## 4. Scaling the game safely

**Save migration policy.** Saves carry no version yet → add `"save_version"`
at the next save-touching change. Rule: loaders migrate forward forever;
never wipe a player's profile. A failed migration must fail loudly, not
silently reset.

**Content scaling.** All content is data-driven (`data/*.json`); biomes,
enemies, blessings, and codex entries scale by adding files + one registry
entry. Hard rule from DESIGN_BRIEF: every enemy attack stays telegraphed —
density scales, readability doesn't degrade.

**Performance budgets** (enforced by feel check, then by profiler once
violated): ≤ 2 ms/frame in `_draw` aggregate per room, ≤ 80 live particles
ambient, ≤ 30 enemies alive. The procedural renderer is immediate-mode; if
room draw cost grows past budget, bake floor layers to a ViewportTexture
once per room build (drop-in optimization, no art change).

**Tech debt watchlist** (acceptable now, scheduled for Phase 2–3):
- Steering-only enemy movement → navmesh when rooms gain interior walls.
- `user://` JSON save → versioned save with migrations (above).
- Single input map → rebindable controls UI.
- Procedural audio → recorded audio behind the same AudioMan API.

## 5. Risk register

| Risk | Mitigation |
|---|---|
| CI export breaks on Godot upgrade | Pin engine version in workflow; upgrade engine in its own PR with full gate run |
| Religious-themes controversy | The source-tier honesty system *is* the mitigation — keep the content note prominent on site + store pages |
| Scope creep toward Phase 5 | ROADMAP gates; nothing ships from a later phase while an earlier phase has open items |
| Solo bus factor | Everything in-repo (no local-only assets); docs current; CI is the build machine |

## 6. Definition of "launched"

Early Access ships when: 3 biomes, 2 weapons, both ending routes, hand-made
art + audio passes, rebindable controls, save migrations, localization-ready
strings, and 50 consecutive crash-free automated full-loop runs across all
three platforms.
