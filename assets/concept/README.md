# Concept art

Project-original concept art supplied by the project owner (June 2026).
These set the visual target for the hand-painted pass (ROADMAP Phase 2)
and drive the current procedural palette.

| File | Subject | Used where |
|---|---|---|
| key-art.jpg | The Flaming Sword of Commission, the Eye of Revelation, the binding chains, the giants on the horizon | Main menu backdrop (`assets/sprites/key_art.jpg`), website hero + gallery |
| witness-concept.jpg | The Appointed Witness — dark indigo robes, gold filigree, glowing codex tablet in the off-hand | Player palette + off-hand codex; website gallery |
| iron-brute-concept.jpg | Iron-Taught armor doctrine — runic plate, chains, horned helm | Enemy art direction; website gallery |
| first-blade-concept.jpg | Azazel's First Blade — rune-scribed body, chain wings, burning scimitar | Boss art direction; website gallery |
| witness-animation-reference.jpg | Witness move-set sheet (idle/walk/light/heavy/special/dash) | **Reference only** — irregular grid + opaque background; the production sprite sheets should follow this layout on transparent, fixed-cell grids |
| boss-animation-reference.jpg | Boss state sheet (idle/walk/attack/special/hurt/phase) | Reference only, same note |

To ship the animation sheets in-engine they need: transparent background,
uniform cell size per row, and consistent pivot — then they drop into
AnimatedSprite2D/SpriteFrames replacing the procedural `_draw` bodies.
