# Arrowglade combat action plan and implemented controls

Revision: 22 October 2026. This revision supersedes mixed target/enemy encounters in the previous campaign plan.

## Encounter contract

An archery puzzle has targets and no monsters. An enemy encounter has monsters and no target boards, hanging orbs, rune targets or target-based exit condition. Enemy stages end when the authored waves are defeated. Story restoration happens after victory; the player never needs to search for a leftover target during combat. The final stage ends only on the boss's valid redemption finish.

The first combat trial, Chapter 12 Stage 1 / ID55, starts with a group of three Moss Slimes. They approach and stage around the archer. One creature at a time owns the attack turn. The others reposition instead of all striking together. The turn lasts through windup, attack and recovery; ranged creatures keep it until their projectile resolves. Waiting creatures receive turns in queue order. An approach turn expires after four seconds if its owner cannot reach range, so an inaccessible creature cannot freeze the group's attacks.

Later groups combine the families below. Enemy HP is authored from chapter reference mastery, not dynamically raised to match upgrades. A beginner's first encounter teaches one committed leap; subsequent encounters combine melee and ranged attack choices without removing readable tells.

## Attack actions

| Creature | Visible charge | Physical attack | Counterplay |
|---|---|---|---|
| Moss Slime | Jelly compresses, ground warning pulses for 0.75 seconds | Collision body springs in an arc toward the position recorded at windup; 0.42-second leap, 12 damage on landing | Move sideways or dodge; shoot during 0.85-second recovery |
| Briar Slime | Thorn body flattens for 0.95 seconds | Higher, longer collision-swept leap over 0.65 seconds; 18 damage on landing | Evade its committed landing point; punish 1.10-second recovery |
| Seed Spitter | Leaves spread and pod inflates for 0.90 seconds | A visible ochre seed flies toward the committed position; actual terrain/player collision | Strafe after the tell; shoot the exposed pod |
| Bark Stalker | Body crouches for 0.85 seconds; legs stop running | Short 0.38-second physical pounce, 16 damage | Dodge the pounce and retaliate during 1.10-second recovery |
| Mirror Wisp | Orbiting facets and pearl prepare for 0.95 seconds | A visible lilac dart travels toward the committed position | Leave the projected line; aim at the pearl |
| Root Warden | Both arms rise and chest knot expands for 1.20 seconds | Arms slam; a real 2.5-metre area deals 22 damage with an impact ring | Leave the circle or time dodge protection; hit chest during 1.50-second recovery |

Enemies now display animated procedural 3D bodies, not the previously generated flat directional cards. The directional atlases remain available as source art. Slimes hop and deform; stalker/warden legs articulate; plant leaves and muzzle animate; wisp facets orbit; hit reactions and landing rings provide action feedback. These are procedural rigs rather than newly generated full skeletal character assets.

## Player interaction

- Without AIM: mouse-left, touch SHOOT or a fresh controller trigger press immediately launches one release toward the current crosshair ray. The camera does not enter aim mode or zoom just because a release animation is playing. Releasing the button never fires a second arrow.
- With AIM: hold SHOOT to draw, release to fire a charged arrow. Right mouse/left controller trigger holds AIM; touch AIM toggles it. Moving, looking and shooting have separate touch IDs.
- Q, controller B or touch DODGE initiates the existing 0.40-second dodge, with the protected interval from 0.05 to 0.25 seconds and a 1.20-second cooldown.
- Power buttons arm the selected ability. The next release consumes its focus/cooldown and one quiver arrow. Burst is one release containing three bolts.
- A quick arrow has instant normal firing strength, but is recorded as uncharged for mechanics requiring deliberate draw. It cannot bypass the final boss's fully charged Aurora condition.
- Empty ammunition exits aiming. A marked supply station restores six arrows when the quiver is low. Combat cannot become unwinnable solely because all arrows were used.

## Hollow Crown combat

The boss participates in combat through visible arm/body windups, precommitted physical sidesteps, thorn projectiles, marked ground strikes and expanding shock rings. It performs two patterns and waits for active hazards to resolve before announcing an exposed-core opportunity. Its core remains exposed for 4.2 seconds. Movement is decided before the player's release rather than reading the arrow input and teleporting afterward.

Normal attacks can damage the boss, with reduced shell damage. Phase barriers at 70, 35 and 10 percent prevent burst overflow from skipping the fight. At ten percent, recover arrows and focus at the Aurora well, evade the next patterns, deliberately AIM and draw Aurora, then hit the exposed core. B/A/C100 and earned Aurora are required. Instant Aurora, splash, burn and normal arrows cannot finish. Missing a window reopens the recovery cycle instead of ending the run.

## Acceptance evidence and remaining review

Headless integration checks cover all 100 scene entries, zero target actors in enemy encounters, the three-slime group, one-attacker queue, committed attacks, collision-body leap movement, landing-only damage, timed dodge protection, paused movement/damage, instant touch firing, no forced zoom, no duplicate release and a physical charged Aurora/core victory. The eight-size landscape/multitouch suite uses the new explicit AIM-to-charge interaction.

The native editor can be reached, but reliable rendered capture and a full hands-on battle review remain pending. Headless checks cannot establish visual polish, fun, Android frame rate or final difficulty. Perform those checks on the actual Android build before release. Existing shutdown resource-retention warnings also remain under investigation.
