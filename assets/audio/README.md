# Audio — expected files

All audio in the prototype is **synthesized procedurally at startup** by
`scripts/core/audio_manager.gd` (bronze impacts, drums, wind, pads, whispers,
sword fire, roars, drones). **No files are required to run the game.**

To replace the placeholders with real recordings, drop files here and load
them in `AudioMan._build_sfx()` / `_build_music()` instead of the generated
buffers. Expected names (one file per generated sound):

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
| File | Direction |
|---|---|
| hub_theme.ogg | angelic pad, D minor add9, slow tremolo, distant wind |
| desert_combat.ogg | ritual drums + drone, 120 BPM, dry and vast |
| boss_theme.ogg | faster drums over tritone drone, alarm pulse |
