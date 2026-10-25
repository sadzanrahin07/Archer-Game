# Arrowglade combat revision 3

Implementation handoff · 24 October 2026

Godot project: `/Users/sadzanrahin/Documents/Game/Archer Game`
Build identity: Settings → **Arrowglade · 0.8.0 · Combat revision 3**.

## Combat changes applied

The combat loop is now built around reading a committed attack, moving or rolling clear, and using the recovery to land a deliberate shot. Quick fire and aimed charge remain separate inputs. The campaign economy, existing progression IDs, equipment mastery, power trials and saved ownership are preserved.

### Player action and bow

- Dodge plays the existing authored skeletal Roll clip, retargeted onto the current characters. The 0.40-second roll moves about 2.6 metres, has a 1.2-second cooldown, and grants immunity from 0.05 through 0.25 seconds. Movement input determines its direction; idle dodge uses the last movement direction or a backward retreat. Camera yaw and pitch remain independent.
- Dodge cancels draw, explicit aim, touch aim and armed power. All shooting paths reject a shot during the roll. Pause freezes duration and cooldown together.
- Quick SHOOT commits an arrow on press toward the crosshair. It has no aim zoom and no second shot on button release. Release is sampled at the actual bow, removing the previous one-metre muzzle jump. The quick-shot cooldown is bounded at 0.42 seconds.
- Moving fire blends upper-body release with walking/running legs so locomotion cannot immediately erase the firing action.
- Combat free view stays at 65° and explicit aim at 40°. Late chapters or Aurora no longer force 24° sniper framing during combat. Stationary non-combat challenges retain the narrow view.
- Power charge illuminates the actual bow and gathers small rings/sparks at the nock. The release flash listens to a successful projectile event, so canceled draw never displays a false release. Effects are limited in size, pause safely, honor reduced motion and stay hidden in menus. Power-flight accents are capped; Burst gives only its leading bolt the full launch effect. Impact geometry and camera shake are suppressed under Reduced Motion while the hit sprite remains readable.

### Slimes and enemy identity

- Moss and Briar attacks show their committed landing area in world space. Windup compression leads into an actual swept leap, followed by landing compression and a recovery window.
- Leap sweeps ignore the player collision body while respecting terrain. Damage is applied once near the actual grounded contact, with a line-of-sight check. A blocked leap cannot damage a player remotely at the old intended endpoint.
- Motion uses the combat clock, so pause freezes body action and orbit cues.
- Slime meshes are rounder, with jelly clearcoat. Mirror Wisp has thick intertwined teal/lilac geometry, crown, pendant, visible pearl aperture and separate satellite pivots. Its pearl emission is reduced so the shell can remain visible.
- Six native Godot enemy scenes plus editable GLB siblings are supplied. Their geometry budgets are 1,208–4,686 triangles. These remain simplified 3D interpretations of the painted concepts; painted texture fidelity, detailed skinning and a dedicated final boss sculpt remain art work.

### Encounters and challenge

The 44 regular enemy encounters use authored formations and entrance schedules. Each introduction chapter retains its 1 → 2 → 3 → 4 → 5 enemy curriculum. The five formats introduce a single read, split entrances, a central fork, alternating relays and wide flanks. Later mixed encounters combine enemy roles across different waves.

Cover is physical terrain that blocks projectiles; navigation routes around it. Entrance rings announce delayed arrivals. Kill-conditioned relays prevent all enemies from piling into the opening. Every entrance, including a zero-delay first entrant in a new wave, waits if the player occupies it. Victory waits for all future entrants. The supply route stays open, and the existing fair attacker queue remains in effect. Combat stages contain no archery targets.

This is encounter variety using formations, timing, cover and enemy roles. It is not a claim of 44 completely different environment maps or a completed open world.

### Hollow Crown

- Chooses thorn, marked-root and expanding-wave attacks using actual distance, cooldowns and recent attack repetition.
- Announces a bounded lateral sidestep before moving. An incoming arrow cannot cause an instantaneous reactive evade. The endpoint must be visible and inside its arena lane.
- Commits attack targets during the tell. Hazards resolve before the next pattern or core opening.
- Two resolved patterns earn a clear, stationary core window. The boss cannot evade or begin another attack while its core is open.
- Turning the camera away does not freeze its AI. Attack intent is repeated under the fixed boss HP bar, with a directional marker for an off-screen attack.
- Existing 70/35/10% HP gates and the direct, fully charged Aurora finisher remain. B/A/C mastery 100 is still required. The rearm well provides safe recovery after a missed final window; later attempts remain possible.

### Combat UI

The large bottom help/ammo cards are replaced by a compact player HP gauge, a damage trail, Focus gauge and ammunition count. Enemy health bars sit near the actors. The boss gets a central health bar, fixed intent text and core-opening prompt. Off-screen active threats receive a direction marker. Dodge shows its cooldown on touch. Controls continue to support simultaneous movement, looking, aim and shooting.

## Reference observations

The supplied videos were opened in the browser and gameplay frames inspected. The shared principles used here are a readable physical bow, clear draw/release phases, movement while managing enemy distance, cover and visible health. The new two clips are Skyrim and Chivalry 2 examples, so the current third-person character/camera is retained alongside the earlier Genshin direction.

- [Skyrim combat archer reference](https://www.youtube.com/shorts/iQyhNr09UCw)
- [Chivalry 2 archery reference](https://www.youtube.com/shorts/GPFxsp-_4bA)
- [Earlier Genshin flying-slime reference](https://www.youtube.com/shorts/QByfYW_7It8)
- [Earlier Genshin Dendro-slime reference](https://www.youtube.com/shorts/YbkE2OV4ZrY)

The timings, enemy designs, encounter layouts and boss rules above are Arrowglade implementations. We have not reproduced those games' entire combat systems or established superiority over them.

## Verification and limits

Focused runtime checks cover authored roll articulation and four character rigs; instantaneous shooting; charge cancellation/release events; pause; real slime collision/landing damage; safe wave arrivals; actual boss hazards, evasion and Aurora finisher; and all 100 campaign scene entries. Navigation verification checks 348 complete, practical routes around physical cover. The six model assets pass 162 geometry/material/pivot checks.

Eight landscape viewport configurations exercise page bounds, the combat HUD and touch controls. Final verification results and logs in the Codex output folder are included beside this handoff. All listed assertion suites pass; known engine diagnostics are retained in the logs.

Native in-game visual approval is **not complete**. Standalone graphical launches abort in this environment; the running editor showed an exclusive-child-window error and did not reliably run the capture scene. Headless behavior tests and the software mesh board cannot verify final lighting, motion appearance, performance or enjoyment. Some headless shutdowns also report resource cleanup warnings; these are recorded in the logs instead of calling the run error-free.

The prepared `campaign/verification/combat_review_scene.tscn` uses an isolated test profile and captures representative native stages, charge and roll poses when run successfully in the editor. It does not overwrite the real player profile.

## Playtest the current source

1. Run the project with F5 and check the build label in Settings. An already installed mobile build does not update when these source files change; re-export and reinstall it to review this revision. Your screenshot's old stage title is absent from the current stage data, so this check matters.
2. Try Moss stages 56–60 for first read, split entrances, cover, relay and flanks. Try Wisp stages 76–80 to judge shell visibility and dart readability. Try the mixed encounters 86–99 for role combinations and cover.
3. In combat, tap SHOOT without AIM: one immediate arrow, no zoom. Toggle AIM, hold SHOOT, and release for a charge. Roll during the draw: no arrow and no false release flash. Spend the quiver: aiming must stop and supply must remain reachable.
4. Fight stage 100 at max mastery. Check warned sidesteps, close/far attack choices, recovery windows, the stationary exposed core and recovery after a missed Aurora. Test both landscape touch and desktop input.
5. Judge animation quality, readable threat colors in bright grass, device frame time, and whether the boss is exciting rather than merely survivable. These judgments require actual play sessions and should drive the next balance pass.
