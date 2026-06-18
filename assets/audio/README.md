# Audio — expected files

All audio in the prototype is **synthesized procedurally at startup** by
`scripts/core/audio_manager.gd` (bronze impacts, drums, wind, pads, whispers,
sword fire, roars, drones). **No files are required to run the game.**

**Lookup order (Phase 2.5):** at startup `AudioMan` generates every buffer,
then checks `assets/audio/` and `assets/music/` and **overrides** any sound
or track for which a real file exists. So you can drop in real audio
incrementally — one file at a time — with no code change and no crash on
missing files. SFX files are `.wav`; music files are `.ogg`.

Expected names (one file per generated sound):

## SFX (assets/audio/)
| File | Direction |
|---|---|
| swing.wav | sword whoosh, airy |
| hit.wav / hit_heavy.wav | bronze-on-flesh impacts |
| bronze.wav | ringing bronze strike |
| dash.wav | cloth + sand whoosh |
| hurt.wav / death.wav | Witness pain / fall |
| edeath.wav | enemy unmaking |
| pickup.wav / blessing.wav | chime / angelic triad |
| ui.wav | manuscript-page blip |
| seal.wav | bell + resonance (binding sigil) |
| ult.wav | Michael's Verdict — sub boom + choir burst |
| roar.wav | giant roar, low and wet |
| whisper.wav | distorted corruption whispers |
| fire.wav | sword fire / forge burst |
| bolt.wav | star bolt release |
| gate.wav | three ascending bronze tones |
| revelation.wav | rising bell arpeggio sting |
| sting_death.wav | descending death/return sting |

## Music (assets/music/)

Each music *state* maps to an external `.ogg` (if present) or a generated
fallback. Only `hub_theme`, `desert_combat`, and `boss_theme` have bespoke
generators today; the other states fall back to the nearest generator until a
real file is dropped in.

| File | State | Direction |
|---|---|---|
| hub_theme.ogg | hub | angelic pad, D minor add9, slow tremolo, distant wind |
| desert_combat.ogg | desert | ritual drums + drone, 120 BPM, dry and vast |
| desert_calm.ogg | desert_calm | sparse drone + wind, pre-combat |
| combat_low.ogg | combat_low | tense low layer |
| combat_high.ogg | combat_high | full combat intensity |
| elite.ogg | elite | elite encounter |
| miniboss.ogg | miniboss | the Half-Buried Giant |
| boss_theme.ogg | boss | faster drums over tritone drone, alarm pulse |
| boss_phase_1.ogg / boss_phase_2.ogg / boss_phase_3.ogg | boss_p1/p2/p3 | escalating boss phases |
| victory.ogg | victory | resolution |
| death.ogg | death | the Witness falls |
