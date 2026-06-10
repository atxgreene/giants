# DESIGN BRIEF — The Watchers: Fall of the Giants

## Pillars

1. **Readable, fast isometric combat.** Hades-style camera and cadence:
   short attacks, generous dash with i-frames, every enemy intention
   telegraphed in red before it lands. If the player dies, they saw it coming.
2. **Sacred apocalyptic tone.** Bronze-age war against things that taught
   humanity to love its own violence. Gold against rust; choirs against
   whispers. Power always has a moral texture.
3. **Disclosure as progression.** The loot is knowledge. The codex is not
   flavor — Revelation is a meter, the Archive is a system, and the game's
   honesty about its own sources (the tier system) is a feature.
4. **Diablo-flavored pressure.** Enemy density, pack behavior (hounds),
   support enemies (Smith-Priest buffs), ground hazards, and loot cadence
   tuned so something drops or unlocks every few rooms.

## Core loop

Hub → receive commission → enter the Desert of Azazel → clear rooms →
choose gates (blessing / relic / heal / seals / codex / weapon / forbidden) →
elite or shrine → mini-boss → boss with a moral choice → codex + currency →
return → spend Seals of Witness on permanent upgrades and weapon aspects →
repeat stronger and more *seen*.

## The two meters

- **Corruption** (0–100). Sources: forbidden gifts (+20–25), hound pools.
  Reduced by Raphael. At 50+: enemies +20% hp/dmg, player takes +15%,
  hub dialogue changes (Raphael and the Scribe intervene). At 100: the
  `full_corruption` flag is set — reserved for the bad ending route.
- **Revelation** (0–100). Sources: elites (+10), bound kills (+3), untouched
  rooms (+8), refusing forbidden gifts (+10), codex unlocks (+8), visions
  (+10). At 50: +10% damage against the fallen. At 90: unlocks the hidden
  "Final Revelation" codex page. Reserved: the Revelation Route.

The two meters are deliberately asymmetric: Corruption buys immediate power
for long-term consequence; Revelation pays slowly for playing like a witness
(seeing, sparing, refusing) rather than a butcher.

## Combat reference

| Move | Damage | Notes |
|---|---|---|
| Light combo | 11 / 13 / 20 | 3rd hit launches, big knockback |
| Heavy arc | 32 | 170° sweep, 3.2 stagger |
| Dash slash | 17 | within 0.28s after dash |
| Crescent (special) | 23 | 2.2s cd; pierces/splits/marks via mods |
| Binding Seal | 3 + bind | 7s cd; 2.7s bind; bound kills → Revelation |
| Michael's Verdict (ult) | 75 radial + 55 beam | charged by damage dealt |

Stagger: every hit adds stagger vs. enemy poise ×0.1; crossing it stuns 0.65s.
Brutes (poise 80) shrug off lights; Michael's aspect (+50% stagger, +30% vs
armored) is the counter-pick the slice teaches.

## Enemy roster (slice)

| Enemy | Role | Signature |
|---|---|---|
| Ash Thrall | fodder | telegraphed line charge |
| Iron-Taught Brute | armor wall | overhead slam circle, high poise |
| Star-Sick Archer | ranged | keeps 230–400 range, star bolts |
| Nephilim Bloodling | skirmisher | tracking leap; enrages < 30% hp |
| Bound Giant Spirit | zoner | radial scream → expanding ring (dash through) |
| Watcher-Forged Hound | pack | orbits, lunges, leaves corruption pools |
| Smith-Priest (ELITE) | support | shard volleys, ally buff, fire cone + pools |
| Half-Buried Giant (MINI-BOSS) | stationary siege | fist slams → weak-point windows, rings, summons |
| Azazel's First Blade (BOSS) | duelist | 3 phases, blade halo, fire lanes, the temptation |

## Architecture map

| System (spec) | File |
|---|---|
| GameManager | scripts/core/game_manager.gd (autoload `Game`) |
| RunManager | scripts/core/run_manager.gd (autoload `RunState`) |
| RoomManager | scripts/rooms/run_scene.gd + scripts/rooms/room.gd |
| SaveManager | scripts/save/save_manager.gd (autoload `SaveMan`) |
| PlayerController / CombatController | scripts/player/player.gd |
| Health/Hitbox/Hurtbox | folded into Player/EnemyBase `take_hit` contracts (distance/arc checks; physics bodies only for movement) |
| EnemyAIBase | scripts/enemies/enemy_base.gd |
| BossController | scripts/bosses/*.gd |
| BlessingManager / RewardManager | RunState mods + run_scene reward flow + reward_screen.gd |
| CodexManager | scripts/codex/codex_manager.gd (autoload `CodexMan`) |
| DialogueManager | scripts/ui/dialogue_box.gd + data/dialogue.json |
| UIManager | scripts/ui/* (HUD + modal screens) |
| AudioManager | scripts/core/audio_manager.gd (autoload `AudioMan`) |
| FX/Juice | scripts/core/fx.gd (autoload `FX`) |

Design rationale for the non-physics hit detection: with one player and <20
enemies per room, distance + arc checks are simpler, deterministic, cheaper,
and far easier to tune than Area2D layers — and they make the
"melee hits exactly what the slash shows" guarantee trivial.

## UI / palette

Gold `#d9b861`, obsidian `#121017`, crimson `#9e2121`, lapis `#33528f`,
ash `#8c8580`, bronze `#996b33`, starfire `#73bfff`, parchment `#ebdbb2`.
HUD: vitality / corruption / revelation top-left; weapon + blessings bottom-left;
dash/special/seal/ult bottom-right; seals + room top-right; boss bar top-center;
toasts under the boss bar; interact prompt above the player's feet.
