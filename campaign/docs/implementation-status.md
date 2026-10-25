# Arrowglade implementation status — 22 October 2026

## Delivered in the Godot project

This is an integrated playable implementation, with headless verification. It is not yet a visually approved Android release.

### Progression, economy and saved games

- Shared Bow, Arrow and Character mastery runs from 1 to 100. Switching or purchasing equipment does not reset mastery. All four weapon types support level 100; rarity supplies optional traits rather than a campaign requirement.
- Profile schema 5 migrates the highest owned legacy equipment mastery, preserves coins, and retains purchased powers and cleared trial entitlements. Existing saves are not repriced retrospectively.
- Upgrade costs rise with level and round upward to five coins: Bow `50+8L+0.8L²`, Arrow `35+6L+0.6L²`, Character `30+4L+0.35L²`, where L is the current level.
- Chapter base reward is `R=600+180n+36n²` with one-based chapter n. First-clear stage awards are R, 1.25R or 1.5R for 1–3 stars; chapter completion awards R. Replay awards and unpaid star improvements are separately accounted for. Transaction receipts prevent duplicate payments.
- Standard-path upgrades cost 675,720 coins. The real profile upgrade/reward code funds every stage's reference mastery before entry; final wallets are 135,500 / 304,400 / 473,300 coins for all-one / all-two / all-three-star campaigns, including the initial 500. Optional purchases consume this surplus and may require replays.
- Damage is `12+.22(B-1)+.18(A-1)+.10(C-1)` before item traits. HP is `min(160,100+1.5*max(C-60,0))`. Target/enemy HP uses authored reference mastery, rather than scaling upward with the player's upgrades.

### Powers

- Burst unlocks at lower equipped mastery M20; Gale at M50. Pressure M60 + trial ID55, Ember M70 + ID65, Lightning M80 + ID75, Super Lightning M90 + ID85, Aurora B/A/C100 + ID95. Earned entitlements remain available.
- Powers use focus and cooldowns, with two selectable slots. Locked icons show their missing mastery or trial requirement. No coin charge is made per shot.
- Burst consumes one arrow and records one released shot while spawning three bolts. Secondary damage cannot inflate accuracy or focus rewards.
- Pressure splash, Ember damage over time, Lightning distinct-target chains, Gale flight/wind behavior and Aurora are connected to actual projectile impacts. Active damage-over-time effects postpone an empty-quiver result.
- Empty ammunition cancels aiming. Combat supply recovery does not require a kill or a remaining arrow.

### Campaign and combat

- All 100 stable stage IDs have scene/story cards, objectives, target placements, mechanic combinations, scenery selection and restoration information. The initial stages deliberately introduce fewer targets than the earlier planning document: one ring and heart, two carts, two pendulums, then a three-orb chain.
- Static and moving aligned orb chains are physically hittable by one ordinary projectile. Sequential runes and gated restoration hearts use actual target activation.
- Hostiles begin at ID55 (Chapter 12), with mastery 60 required. The first trial introduces one Moss Slime; the five chapter stages increase to five. Enemy encounters contain no archery targets. Later authored waves use Briar Slime, Seed Spitter, Bark Stalker, Mirror Wisp and Root Warden.
- Enemies have collision bodies, navigation agents, fixed reference HP, committed windup aiming, recovery windows and a fair queue allowing one attacker at a time. Pause freezes their attacks and movement. Briar leap damage applies on landing and its movement uses collision sweeps.
- Player combat includes HP, timed dodge invulnerability, aim strafing, health-based stars and recoverable ammunition. Combat timers affect a bonus rather than instantly failing the encounter.
- ID99 creates the Hollow Crown. Thorn shots, ground warnings and expanding rings alternate with announced exposed-core windows. HP gates at 70/35/10 percent discard overflow; ordinary arrows damage the boss but cannot finish it.
- Victory requires a direct, at least 95-percent drawn Aurora hit on the exposed final core with B/A/C100. Missed final windows restore access to ammunition/focus and permit another attempt. The boss does not become permanently unwinnable after an early or missed Aurora.
- Story cards appear before stages, can be skipped, and the final victory includes an epilogue. Saved stage stars light restoration markers.

### Art and controls

- Six original directional enemy atlases remain the art references. Runtime combat now uses six baked reference-led 3D models (`combat/models/*-v2.scn`, with editable GLB siblings) and procedural action rigs. Generation prompts and provenance are recorded in `combat/assets/manifests/generated-enemies-v1.json`.
- The new 3D assets use faceted geometry and separate action pivots. Final painted-texture fidelity remains an art-production task. Existing procedural boss geometry has a core, shutters, crown, arms and feet.
- Quick SHOOT fires on press at the crosshair without zoom; explicit AIM + hold/release charges. Keyboard: movement controls retained; Q dodge, F/E primary power, R secondary. Touch has separate shoot/aim/dodge/power controls. Existing inventory scrolling and normal equipped-arrow lobby preview are retained.

## Verification

Authoritative integration tests for this revision:

1. `verification/test_connected_upgrade.gd`: PASS. Actual save/reward/upgrade transactions, three complete economic paths, duplicate receipts, migration, stable item IDs and existing resource paths.
2. `verification/test_connected_scenes.gd`: PASS. All 100 scenes through real game entry, real projectiles through static/moving chains, trial wiring, Burst accounting, empty aim/supply recovery, natural boss attack-to-core cycle, phase clamps, three missed finisher recoveries and real Aurora projectile/core victory.
3. `verification/test_combat_safety.gd`: PASS. Committed melee windup/dodge avoidance, correct damage, dodge protection, paused movement/damage, paused Briar leap, landing-only damage and director capacity.

4. `verify_landscape_ui.gd`: PASS. Eight landscape viewport sizes, page bounds, character/skin selection and real multitouch move/look/draw/release/cancel/pause. Drawing remains planted in archery-only stages and allows strafing in combat.

Tests use isolated `/tmp` profiles. No real player save was used. Older narrow verification scripts may contain obsolete stage counts or pre-schema-5 assumptions; they are not evidence for this revision unless updated.

## Remaining acceptance work

- Native Godot rendering currently crashes at launch on this host; connector launch also exits. Headless scene loading is not visual approval. The six sprite images themselves were inspected, but their in-game scale/lighting, the boss presentation and small-screen HUD still need a running-window review.
- Run real Android device playtests for aiming feel, touch overlap, combat difficulty, navigation around scenery, audio balance, performance and a complete boss fight. No claim of Android performance or release readiness is made.
- Navigation currently uses an arena region and physical collision. Obstacle-aware navigation baking/path recovery needs real encounter review, particularly crowded scenery.
- Story/landmark presentation and full action-frame animation remain polish work; do not describe the entire cinematic art brief as complete.
- Headless tests exit successfully but still report ObjectDB instances and resources retained at shutdown (counts vary with the test). Investigate resource lifecycle before release. macOS also prints a system certificate diagnostic.

## Combat presentation follow-up

See `combat-action-plan.md` for the revised encounter rules, physical attacks, one-at-a-time group behavior and immediate shooting controls. This document supersedes earlier mixed target/enemy scene objectives.

## Reference-model and fight-curriculum revision

- Six rebuilt native models replace the rough sphere/box bodies; source is `combat/enemy_visuals.gd`. Static detail is batched per material and action pivots remain separate. Triangle budgets range from roughly 600 to 4,700 per enemy.
- Chapters 12–17 teach Moss, Briar, Spitter, Stalker, Wisp and Warden separately. Each grows from one to five total enemies, with smaller heavy/ranged waves. Chapters 18–20 then use fourteen authored mixed encounters before the existing boss at ID99.
- All 45 stages from ID55 onward are enemy-only. Stable stage IDs and trial power gates remain unchanged.
- HP multipliers against fixed chapter reference damage are 2.25 / 3 / 2 / 2.75 / 2 / 5. Recovery windows are 1.35 / 1.50 / 1.45 / 1.35 / 1.40 / 1.80 seconds respectively. The standard path and normal arrows remain sufficient for regular fights.
- Actors face the player on arrival. Weak-point collision checks now use the actual sphere radius, fixing a Warden core boundary that could reject a valid weak-point hit.
- `verification/test_reference_models.gd` checks model resources, family identity, geometry/color preservation, the six 1→5 curricula, no target actors and real weak-point projectiles. See `combat-and-enemy-design-v2.md` for the complete researched combat plan and the distinction between implemented logic and future animation/arena/audio production.


## Combat revision 3 — 24 October 2026

See [combat-revision-3.md](combat-revision-3.md) for the current implementation and validation limits. Added authored player roll, layered moving release, committed physical slime landings, compact HP/Focus HUD, bow-local charge/release events, 44 authored encounter formations/entrances with real cover and navigation, revised enemy assets and distance-aware Hollow Crown patterns with warned evasion. This supersedes the earlier notes that arena layouts and off-screen attack markers were still unimplemented. Final concept-art texture fidelity, native visual/device approval and advanced multi-lane threat concurrency remain unfinished.


## Combat revision 4 — 24 October 2026

See [combat-revision-4.md](combat-revision-4.md). Corrected animated-core collision/contact classification, explicit final-seal feedback and rearm eligibility; restored empty-quiver gait and physical jumping; added direct held powers with input ownership, four-rig moving bow/leg animation and wrapped controls help. Isolated behavior and layout suites pass. Native graphical review still aborts before opening; device and visual approval remain outstanding.
