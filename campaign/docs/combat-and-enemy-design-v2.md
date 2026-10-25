# Arrowglade — enemy identity and combat campaign

22 October 2026 · Design direction, authored encounters and implementation contract

The central experience is **read the creature, evade its committed attack, and earn a clean arrow shot**. The bow remains the player's main weapon. Enemies should feel alive through their movement, preparation, physical attack and reaction to the arrow. Difficulty should come from the decision the player makes, rather than hidden damage, enemies that slide into the player, or an unreadable crowd.

## 1. What changes now, and what remains a production target

Implemented in this revision:

- Six rebuilt, reference-led 3D enemy assets, supplied as Godot scenes and editable GLB meshes. Separate action pivots preserve the fern, buds, muzzle, leaves, tail, crystals and arms. Static detail is batched by material. The original generated images remain the art references.
- Six introduction chapters. Each chapter teaches one family over five stages with total enemy counts **1, 2, 3, 4, 5**. Ranged enemies and heavy guardians use wave caps instead of placing every enemy on screen together.
- Fourteen authored mixed encounters leading to the existing Hollow Crown at stable ID99. All combat stages contain enemies only; no archery-target cleanup is required.
- Reference HP budgets and longer recovery windows. Enemy HP does not rise in response to a player's purchases. Existing mastery, trial unlocks, saved stage IDs and economy remain connected.

Design targets requiring the next implementation and playtest passes:

- Family-specific second attacks, authored arena layouts, optional weak-part break reactions, directional off-screen warnings and the advanced two-lane threat director below.
- Final textured art fidelity and a dedicated Hollow Crown model. The new regular-enemy models are a closer, deliberately faceted reconstruction, not an exact reproduction of the painted concept art. The boss still uses its existing procedural body and combat system.
- Final timing and difficulty validation on a real Android device. Software mesh previews and headless tests verify structure and logic; they do not establish in-game lighting, animation quality or player enjoyment.

## 2. Reference games: the principles to borrow

**Horizon Forbidden West:** Guerrilla describes using readable silhouettes, posture, intentions and distinct melee/ranged sounds so players can anticipate an attack; animation timing creates opportunities to respond. Arrowglade should borrow that clarity. A slime's compression and a plant's opening pod must communicate different dangers. [Guerrilla's combat and animation discussion](https://blog.playstation.com/2021/12/06/horizon-forbidden-west-outsmart-your-enemies/)

**Monster Hunter Wilds:** its official guide recommends practicing weapon controls and choosing safe distance for vulnerable actions; Capcom describes Focus Mode as helping positioning, distancing and weak-point attacks. Arrowglade should make spacing and a deliberate shot useful, without importing Monster Hunter's input complexity. [Official starter's guide](https://www.playstation.com/en-us/games/monster-hunter-wilds/monster-hunter-wilds-starters-guide/), [Capcom interview](https://blog.playstation.com/?p=393257)

**Hades:** Supergiant's development notes show the importance of attack/dash timing, responsive bow input, encounter population limits and recovery animation. Arrowglade should retain immediate input while controlling how many threats demand a response at once. [Supergiant's combat update notes](https://www.supergiantgames.com/blog/hades-superstar-update-patch-notes/)

The encounter rules, timings and progression below are original proposals for Arrowglade. These references are design lessons, not claims that their systems or audiences are identical to this game. Their characters, arenas and animations should not be copied.

## 3. Art identity: the model must be recognizable before its HP label appears

| Family | Identity that must survive the 3D conversion | Animation personality |
|---|---|---|
| Moss Slime | Mint teardrop body, dark oval eyes and cheek glints, leafy green/plum inclusions, fern crest, small jelly lobes | Soft wobble at rest, squeeze before movement, visible spring and landing compression; fern follows the motion |
| Briar Slime | Plum jelly, rose belly marking, green collar, **three** woody rose-crystal buds | Heavier compression and a higher arc; buds lag behind the body and settle after landing |
| Seed Spitter | Root feet, layered plant body, two broad leaves, cream petal mouth with visible seeds | Roots anchor; leaves draw back, pod inflates, mouth recoils when the seed launches |
| Bark Stalker | Four-legged cedar fox, tall ears, cream leaf mask, amber eyes, leafy chest and broad layered tail | Feet articulate during approach; low stalking posture, sudden pounce, tail balances the turn |
| Mirror Wisp | Teal/lilac asymmetric crystal shell, visible pearl, two satellites and thin orbit | Continuous gentle hover; satellites gather before a dart, then separate during recovery |
| Root Warden | Broad stone torso and feet, root-wrapped arms, moss shoulders, branch antlers, small mushrooms and gold chest knot | Slow planted steps; arms lift with weight, then strike together and remain low during recovery |

Do not replace a family with an unrelated sphere, cube or icon. Do not make the complete character a billboard that rotates to follow the camera. A sprite can still be used for a portrait, impact flash or particle effect.

The six revised models contain approximately 600–4,700 triangles each. Mesh budget is only a starting constraint: measure draw calls, overdraw, memory and frame time with actual encounter populations. Give the boss its own silhouette rather than simply recoloring a regular Warden.

### Action rig contract

Each actor uses the same combat states: appear → approach/reposition → anticipate → commit → impact/projectile release → recover → react or die. Idle parts should move subtly; locomotion parts must move in rhythm with travel. An actor cannot remain in an idle pose while crossing the arena.

Use a small set of named animation events: `target_commit`, `attack_release`, `damage_window_open`, `damage_window_close`, `recovery_open`, `death_resolved`. Gameplay should drive or consume these events once. A visual shake must never be mistaken for an additional damage event.

## 4. Player actions and why each exists

**Quick shot:** press SHOOT without AIM. One arrow launches immediately toward the current crosshair ray, with no forced aim zoom, draw delay or second arrow on release. Use it to finish a weak opponent, maintain pressure or respond while moving. The current implementation uses normal firing strength; do not add an unexplained damage penalty later.

**Charged shot:** enter AIM, hold SHOOT, then release. The player trades mobility and attention for controlled placement and a deliberate full-draw attack. The final Aurora core finisher requires this intentional draw. Its charging requirement must be visible before the boss's last opening.

**Dodge:** Q/controller B/touch DODGE. Preserve the existing 0.40-second action, 1.20-second cooldown and protected interval from 0.05 to 0.25 seconds. Input must respond promptly. Damage can be avoided by moving clear of a strike, even when the player does not use the protected interval.

**Power:** select/arm the ability, then release the arrow normally. Show focus cost, ready/cooldown state and the equipped ability. A power should solve a recognizable combat problem. Burst rewards a short opening; Pressure rewards a cluster; Ember maintains pressure on a slow creature; Lightning rewards connected groups; Aurora provides a spectacular earned payoff.

**Recovery:** a marked supply position restores ammunition without requiring a kill or a remaining arrow. Do not place it behind a one-way gate, charge coins for each retry, or interrupt an active fight with an advertisement. The final Aurora well restores the focus and ammunition required to repeat a missed final opening.

## 5. Combat direction: a group can feel active without striking unfairly

### Current introductory rule

One enemy owns the attack turn. Others reposition, turn toward the archer, breathe, sway or hop. They do not deal contact damage just because they overlap the player. The active turn includes anticipation, the attack and recovery. A ranged attack retains its turn until its projectile resolves. A creature that cannot reach attack range releases its approach turn after four seconds.

The queue should produce a natural rhythm: a slime lands, the archer retaliates, and another slime starts its warning. It should not produce a simultaneous five-slime collision. A successful early kill may cancel an attack; the player is allowed to feel powerful.

### Proposed advanced rule for Chapters 18–19

Allow one committed melee attack and one ranged/area threat, with their predicted impact moments separated by at least 0.75 seconds. Never allow two point-blank melee hits to arrive together. If an old projectile remains dangerous, do not spend its lane on another identical attack. Boss attack patterns use their own director and do not inherit regular-wave crowd rules.

This advanced two-lane director is **planned, not implemented in this revision**. Ship the readable one-turn version first, then test whether overlap adds useful decisions on a phone.

### Fairness rules

- Record the player's location at a visible commitment event. Do not silently retarget a leap after the player dodges.
- Telegraph shape describes the actual damaging region. A leap uses a landing mark; a slam uses a circle; a projectile uses body/muzzle direction and a distinct charge sound.
- Once the player learns a warning, do not randomly halve its duration to create difficulty. Introduce a visually different elite variant instead.
- Off-screen attackers need an audible and directional warning before they can commit. This directional-warning layer is a next-pass requirement.
- Use separation and navigation so waiting actors do not occupy the same spot or push the archer into a hit. Bake obstacles into navigation and test every supply route.
- A hit has one receipt and one damage application. Pause freezes the attack clock, movement, damage-over-time and projectile life.

## 6. A complete first fight: Chapter 12 Stage 1

**Setting:** a shallow clearing with a fern tunnel ahead, a dry stream on one side and an obvious supply lantern behind the archer. Decorative rocks frame the space but leave a broad escape lane. The arena layout is a production target; the stage currently uses the existing biome scenery.

1. The short entry card says: “Watch it squeeze. Move away from the landing mark, then shoot.” The player can skip it.
2. One Moss Slime emerges facing the archer. Its fern sways, eyes orient toward the player and its feet/lobes compress before the first hop. Give the player room to look and move; do not begin with damage.
3. The slime approaches, compresses for 0.75 seconds, and commits to the archer's position. A landing warning should remain at that position. The current body-centered warning needs this landing-marker upgrade.
4. It makes a physical 0.42-second leap. The archer can strafe or dodge out. Contact/landing damage applies once. It cannot curve toward the player during the leap.
5. The slime compresses on landing and recovers for 1.35 seconds. Its leafy core/face is an inviting arrow opportunity. The archer can fit a charged countershot or use quick shots earlier.
6. At the chapter's reference mastery, it needs about three body hits or two weak-point hits. A well-used existing power may defeat it earlier; do not artificially make the creature immortal to force a tutorial animation.
7. Victory restores a small patch of the world, grants the normal clear reward and Pressure trial proof, and offers the next fight. The next stage contains two slimes, letting the newly earned ability be useful immediately.

Target duration for the first successful fight: roughly 20–40 seconds including observation, not a mandatory timer. If players consistently win in two seconds without noticing any action, adjust approach distance and HP carefully. If they need a minute of repeated identical leaps, reduce repetition.

## 7. Six five-stage teaching chapters

Every family introduction grows from one to five **total** enemies. Count is not the only variable: angle, spacing, terrain and the player's best target priority change as well. Keep base HP consistent within a chapter. The following arena details and optional attack variations are authored design targets; the new counts, family restrictions and wave splits are already in the stage data.

| Chapter | Stage 1 | Stage 2 | Stage 3 | Stage 4 | Stage 5 |
|---|---|---|---|---|---|
| 12 · Mosswake Hollow | 1 slime, single leap lesson | 2 slimes from distinct frontal lanes | 3 slimes, turn and choose the next opening | 4 slimes, dry stream creates two retreat routes | 5 slimes, cluster opportunities for Pressure |
| 13 · Rosebriar Basin | 1 Briar, learn the higher leap | 2 Briars, alternate landing points | 3 Briars, protect a clear retreat lane | 4 Briars around wide rocks; cover must not trap the player | 5 Briars, deliberate power timing between leaps |
| 14 · Seedpod Marsh | 1 Spitter, read the opening mouth | 2 Spitters, learn cross-lane strafing | 3 Spitters, target the next firing pod | 4 total in waves 3+1, change cover side | 5 total in waves 3+2; maintain accuracy as positions change |
| 15 · Cedar Hunt | 1 Stalker, dodge the pounce | 2 Stalkers, turn between two lanes | 3 Stalkers, track the crouching attacker | 4 Stalkers, wider arena supports flanking | 5 Stalkers, prioritize charge tells over nearest enemy |
| 16 · Prism Sanctuary | 1 Wisp, track pearl and dart | 2 Wisps, recognize satellites as parts | 3 Wisps, maintain a clean projectile escape lane | 4 total in waves 3+1, change tracking direction | 5 total in waves 3+2, chain power has an obvious group use |
| 17 · Rootbound Courtyard | 1 Warden, learn arm lift and slam | 2 total in waves 1+1, repeat the lesson with a new position | 3 total in waves 1+2, select the recovering chest knot | 4 total in waves 2+2, manage supplies between waves | 5 total in waves 1+2+2, a heavy-enemy mastery exam |

For stage 4 or 5 variants, change one established behavior at a time. Suggested future variants: Moss Slime's clearly signaled short second hop, Briar's visible seed of a small thorn patch, Spitter's three-seed fan, Stalker's lateral feint, Wisp's rotating front guard and Warden's root-line slam. Each needs a new tell and safe response; none is part of the current single-attack family implementation.

## 8. What each enemy asks the player to do

| Family | Current primary attack | Response | Recommended charged counter | Current HP budget |
|---|---|---|---|---|
| Moss Slime | 0.75s squeeze → 0.42s physical leap → 1.35s recovery | Leave committed landing spot | Face/core during landing recovery | ceil(2.25 × chapter reference damage) |
| Briar Slime | 0.95s flatten → 0.65s high leap → 1.50s recovery | Dodge sideways; do not retreat directly along leap line | Rose belly/face | ceil(3.0 × reference damage) |
| Seed Spitter | 0.90s pod charge → visible seed → 1.45s recovery | Strafe after commitment; use cover | Open mouth | ceil(2.0 × reference damage) |
| Bark Stalker | 0.85s crouch → 0.38s pounce → 1.35s recovery | Cross the pounce line | Leaf mask/head | ceil(2.75 × reference damage) |
| Mirror Wisp | 0.95s charge → visible dart → 1.40s recovery | Track the pearl, strafe the dart | Pearl | ceil(2.0 × reference damage) |
| Root Warden | 1.20s arm lift → 2.5m slam → 1.80s recovery | Leave circle or time the dodge | Gold chest knot | ceil(5.0 × reference damage) |

Reference damage is computed from the authored chapter mastery, currently 60 in Chapter 12 and +5 per later combat chapter, capped at 100. Player upgrades and optional item traits do not increase the enemy's HP. Weak points use the existing 1.25 multiplier. The current weak-point distance test still needs contact-shape review on the finished art; do not use a differently placed glowing feature as a false target.

Ranged attacks must remain visible and collide with terrain. An elite fan is three committed trajectories, not three seeds that all track the archer. A Wisp's guard, if added, reduces front damage instead of making the wrong arrow type completely useless. Every normal encounter remains beatable with the standard equipment path and ordinary arrows.

## 9. Mixed fights and the road to the boss

Chapters 18–20 combine rules already learned. These wave compositions are now authored in the game. New arenas, contextual camera work and advanced attack variants remain to be produced.

| Chapter / stage | Encounter | Waves | Decision |
|---|---|---|---|
| 18 / 1 | Tempest Trial | 1 Warden → 2 Wisp | Break the sentinel, then track two ranged opponents. Earn Super Lightning with the powers already owned. |
| 18 / 2 | Briar Crossfire | 1 Briar + 1 Spitter → 1 Briar + 1 Spitter | Use cover to separate a leaper from a spitter. Turn to the next threat after each recovery. |
| 18 / 3 | Fox and Mirrors | 1 Stalker + 1 Wisp → 1 Stalker + 1 Wisp + 1 Moss | Prioritize the creature about to attack. Keep the pearl in sight between pounces. |
| 18 / 4 | Warden Escort | 1 Warden + 2 Moss → 2 Spitter | Use a group power when creatures gather, then return to precision shots against the plants. |
| 18 / 5 | Tempest Gate | 2 Briar → 1 Stalker + 1 Wisp → 1 Warden | Three short waves test leap timing, target priority and slam spacing. |
| 19 / 1 | The Long Approach | 2 Stalker + 2 Moss | Maintain a clear retreat lane while the pack changes its approach angle. |
| 19 / 2 | Bending Roots | 2 Spitter + 1 Wisp → 2 Briar | Use one cover edge, then leave it before the high leaps arrive. |
| 19 / 3 | Mist Constellation | 2 Wisp → 1 Warden | Alternate crosshair tracking and deliberate weak-point shots. |
| 19 / 4 | Twin Sentinels | 1 Warden + 1 Stalker → 1 Warden + 1 Wisp | Separate the heavy threat from its mobile partner. Keep your supply route open. |
| 19 / 5 | Aurora Threshold | 2 Briar → 1 Stalker + 1 Spitter → 1 Warden + 1 Wisp | A final mixed mastery exam. No new rule is introduced during this fight. |
| 20 / 1 | Aurora Trial | 2 Moss → 2 Briar → 1 Warden | Defeat three familiar waves to earn Aurora. The trial does not require Aurora to win. |
| 20 / 2 | First Aurora | 1 Warden → 1 Warden → 1 Warden | Try Aurora on the first sentinel; ordinary arrows remain sufficient for the later sentinels. |
| 20 / 3 | Starfall Escort | 1 Stalker + 1 Wisp → 2 Briar → 1 Warden | Practice returning to the supply station while threats change between waves. |
| 20 / 4 | Crown Approach | 2 Spitter → 1 Warden + 1 Stalker → 1 Warden | Rehearse committed attacks and recovery shots before the final boss. |

## 10. Hollow Crown: a duel with a changing rhythm

The boss should feel like the creature that has controlled the forest, not a target board with a large health bar. Its visual direction is an ancient stone/root guardian with broken crown branches, expressive heavy arms and a protected Aurora heart. Reuse the regular Warden's material language; commission/build a dedicated larger silhouette and action rig for the production boss.

### Opening

A skippable entrance establishes the core behind bark shutters, one safe supply lantern and a circular movement route. A short demonstration shows a thorn shot hitting a rock. Return control before the first damaging move. Keep the crosshair and movement camera consistent with normal combat.

### Phase 1 · Read the guardian · 100–70%

Teach one thorn projectile and one marked ground strike, then expose the core. Body shots deal reduced damage. The boss's arms and crown show whether it is charging, striking or recovering. A sideways step is decided before the player releases an arrow. The core opening is announced and lasts 4.2 seconds.

### Phase 2 · Reclaim space · 70–35%

The existing fight adds expanding rings. The production encounter should place thorn and ground attacks in a deliberate sequence, requiring a change of direction rather than constant backwards movement. Do not cover the safe movement route with two unavoidable hazards. The transition clears old threats, giving the player a readable reset.

### Phase 3 · Hold your nerve · 35–10%

Use familiar attacks with changed order and a visibly signaled short combination. The player should recognize the individual moves and choose when to stop for a shot. Reduce idle time before adding speed. Keep at least one countershot window after a combination. Additional summons are not needed for the first release; they would obscure the promised duel.

### Final redemption · 10%

Ordinary arrows can reach but cannot cross the final HP floor. Explain the rule immediately: “Aurora can restore its heart. Refill, AIM, draw fully, release into the open core.” The supply well restores sufficient ammunition and 100 focus. After the next readable pattern, expose the core for 4.2 seconds. Require earned Aurora, B/A/C100, a direct core hit and at least 95% draw. Quick Aurora, splash and damage over time cannot trigger the finish.

A miss repeats the combat/rearm cycle; it must not consume the only chance to win. A successful shot cancels all hazards, resolves victory once, and transitions to the restoration. Use a brief camera emphasis after the input succeeds rather than taking the camera away while the player must dodge.

The HP barriers and recoverable finisher already exist. The expanded introduction, dedicated art, combinations and cinematic restoration in this section remain production work.

## 11. Powers, economy and motivation

Preserve stable power gates: Burst M20; Gale M50; Pressure M60 + Chapter 12 Stage 1; Ember M70 + Chapter 14 Stage 1; Lightning M80 + Chapter 16 Stage 1; Super Lightning M90 + Chapter 18 Stage 1; Aurora B/A/C100 + Chapter 20 Stage 1. M is the lower shared Bow/Arrow mastery. No trial may require the power it grants. Existing earned entitlements must survive equipment changes and migration.

Do not increase enemy HP dynamically because a player bought a rare bow. Optional items can change traits and visual identity while the standard set remains sufficient. Required upgrades retain the previously validated campaign coin budget. This revision does not introduce a second upgrade currency or alter the reward ledger.

Each chapter ends with a visible, saved restoration and the promise of the next creature or skill. Repeat stages can offer optional goals such as no damage, two weak-point hits or one well-timed group power. These should reward mastery without preventing the player from completing the story. Do not require a perfect score to unlock the next chapter.

## 12. Arena and feedback production checklist

- Give every arena a clear movement loop, an escape lane at least two player widths across and a reachable supply point. Avoid decorative collisions that catch a dodge.
- Spawn enemies with short non-damaging arrival motion. Show where the next wave will enter before it becomes active.
- Use the actor's body, ground warning and sound together. Color alone is insufficient. Use different shapes and sound envelopes for leap, seed shot and slam.
- Keep health and warning labels readable without covering weak points. Hide distant full labels until relevant; never cover the crosshair with combat narration.
- Use small hit-stop on the enemy's visual rig rather than freezing the player's aim or the entire game. Reduced-motion mode suppresses camera shake and flashes without removing essential warnings.
- Match footsteps to steps, leaf rustle to compression, and impact sound to the damage event. The current reused sounds need dedicated family-specific audio before release.
- Confirm facing and ground contact from front, side and rear. An attractive front pose is not enough for a 3D game.

## 13. Test and tuning plan

1. **Art review:** compare the actual model against its reference at the same angle. Check silhouette, face, palette, signature features, front/back geometry and moving parts. Review the software model board and then the model in Godot lighting. Treat the current models as an iteration, not final art approval.
2. **Animation review:** record idle, movement, windup, attack, recovery, hit and death for every family. Reject any sliding pose, hovering contact attack, disconnected limb or damage before the visible hit.
3. **First slime playtest:** observe at least five new players without explaining controls aloud. Record whether they notice the squeeze, evade once, understand the counter opening and locate supplies. The desired result is understandable cause and effect, not a particular death count.
4. **Progression review:** complete all six introduction chapters with the standard set at reference mastery. Confirm counts 1→5, no unfamiliar family before its introduction, no target actors, no future-power gate and no coin deadlock.
5. **Combat robustness:** test death during windup, simultaneous lethal hits, pause/resume, loss of focus, attack blocked by a wall, supply route obstruction and empty ammunition. Events must resolve once, and the wave must finish after the last enemy.
6. **Boss review:** test phase overflow, normal-arrow floor, early Aurora, three missed final shots, insufficient focus, a valid charged core hit and player/boss lethal events in the same physics tick.
7. **Phone review:** profile maximum authored populations on the lowest supported Android device. Set the minimum frame-rate target after confirming that device. Tune numbers from actual videos and input latency rather than desktop assumptions.

## 14. Recommended implementation order

1. Complete the reference-model review and integrate the six action rigs — this revision starts that work.
2. Finish one highly readable Moss Slime arena: landing marker, arrival, jump/landing sync, hit reaction, death and audio. Use it as the quality bar.
3. Playtest the entire 1→5 slime chapter before adding second attacks.
4. Bring Briar, Spitter, Stalker, Wisp and Warden chapters to the same bar, one family at a time.
5. Add advanced mixed-threat scheduling only after the single-family fights feel good.
6. Produce the dedicated boss asset and finish its camera, combination and restoration presentation.
7. Rebalance from playtests and complete device/release validation.

The immediate goal is a convincing, readable first fight. Strong later encounters grow from that proven foundation.
