# Arrowglade — Combat revision 4

24 October 2026 · Godot 4.7.2 · Project version 0.8.0

Project: `/Users/sadzanrahin/Documents/Game/Archer Game`

This revision fixes the reported core-hit, empty-quiver movement and jump problems and adds a direct hold-and-release power input. Run the project again; Settings and the console should say **Combat revision 4**. An installed Android build needs a fresh export and install to include these source changes.

## What changed

### Core hits and the final seal

The heart mesh moved with the boss’s chest animation while its collision stayed fixed. The core collision now follows the visible heart, and a real arrow carries its actual collision-shape result into damage resolution. Trunk contacts cannot become weak-point hits through a generous distance test.

The boss reports actual HP lost rather than incoming damage. Normal core hits deal full damage during exposure; armor contacts deal 25%. Its existing 70%, 35% and 10% phase gates remain. A phase gate can limit a shot’s actual damage.

The final 10% is the planned Aurora seal. A direct Aurora / ultimate arrow, charged until READY (at least 95% draw), must strike the exposed gold heart at Bow, Arrow and Archer mastery 100. Normal arrows and undercharged powers cannot finish this phase. Blocked shots now explain the reason, and the combat HUD shows the seal objective, the exposure countdown, charge readiness and actual damage or blocked-hit text.

Consumed shot IDs are checked before any final-finisher logic. Replaying a receipt cannot bypass the seal or score a second hit. Splash, secondary effects and indirect attacks cannot redeem the boss.

The final opening still follows two resolved attack patterns and lasts 4.2 seconds. The boss stays stationary while exposed. Players who already have an unused Aurora, 100 Focus and ammunition can continue toward an opening without an unnecessary well visit. After a spent attempt, the Aurora Well restores at least six arrows, 100 Focus, the ultimate allowance and its cooldown/global lock. A missed opening can be retried.

### Empty arrows and moving bow actions

Repeated empty-quiver checks used to restart idle every physics tick, suppressing walking. They now cancel an active bow state once and leave ordinary locomotion running. Empty arrows also exit aim and reject stale release input.

Moving draw and fully drawn aim combine the bow action with walking legs. Moving release continues to use walk/run legs. Animation retiming rebuilds keys from an untouched source instead of changing key times in place, which could reorder or merge leg keys.

### Jump and dodge

Jump now applies a real vertical impulse and gravity, rather than only defining an input action. It has grounded landing, a short input buffer and coyote window, and no repeated jumping from holding the button. Authored takeoff, airborne and landing clips are retargeted onto all four character rigs. Foot grounding correction no longer pulls an airborne character back toward the floor.

A well-timed jump clears the low expanding root wave. Marked ground strikes still require moving out or dodging. Dodge remains a directional roll with its existing timed immunity; it cancels held power without releasing an arrow. Pause and death clear queued input and reject late fire events.

### Normal and power shooting

- **Normal:** tap SHOOT / left mouse / gamepad RT without AIM for one immediate crosshair shot and no forced aim zoom.
- **Aimed normal:** use AIM / right mouse / LT, hold SHOOT / left mouse / RT, then release.
- **Primary power:** hold its touch circle, **F** (E also works), or gamepad **X**. Release to fire.
- **Secondary power:** hold its touch circle, **R**, or gamepad **Y**. Release to fire.
- **Jump:** touch **JUMP**, **Space**, or gamepad **A**.
- **Dodge:** touch **DODGE**, **Q**, or gamepad **B**.

A held power owns its draw until release or cancellation. Another SHOOT finger, mouse trigger or gamepad trigger cannot steal that draw. Arrows and Focus are spent when a volley is committed, not while charging. Canceled touch, dodge, pause, empty ammunition and fatal damage cannot leave a delayed shot behind.

A very short power tap retains the earlier arm-next-shot behavior. For the final boss, use the held charge and release at READY. The desktop button now says HOLD POWER. Settings include the revised controls and wrap correctly on narrow landscape viewports.

## Verification

Assertions passed using isolated test profiles; the real campaign save was not loaded or overwritten.

| Check | Result |
| --- | --- |
| Actual equipped bow → ballistic projectile → physical core, six lean/angle combinations | PASS |
| Armor damage, deduplication, normal/partial Aurora rejection, well reset, held Aurora victory | PASS |
| Empty-quiver movement and advancing gait; physical Space/touch jump, landing, held-input prevention | PASS |
| Four rigs: jump clips and actual leg articulation during moving draw/aim | PASS |
| Primary/secondary held touch and gamepad powers; interference and cancellation cases | PASS |
| Existing roll, instantaneous fire and moving-release regression | PASS |
| Slime/melee commitment, dodge immunity, pause and instant touch-shoot safety | PASS |
| Boss attack choice, warning, evasion, recovery and final rearm regression | PASS |
| All 100 connected stages; no targets in enemy fights; supply and real final projectile | PASS |
| Bow charge/release events, cancellation, reduced motion and four character rigs | PASS |
| Eight landscape layouts, character/skin UI and multi-touch input | PASS |
| Core script compilation and native-review script parse | PASS |

Logs are beside this handoff in the Codex output folder. Some headless tests report a macOS certificate lookup error and resource cleanup warnings at shutdown; assertion success does not mean those engine diagnostics were absent.

## Visual review and remaining limits

The supplied [Magick Archer versus Griffin reference](https://www.youtube.com/shorts/f3SUYxTvp-8) was inspected in the browser for draw/release contrast, magical launch readability and movement under pressure. These fixes apply those principles to Arrowglade’s existing third-person combat.

**Native visual approval remains incomplete.** The attempted graphical compatibility-renderer review exited with code 134 before opening a window. Headless checks establish behavior, collision and layout bounds; they do not establish final animation appearance, lighting, device performance or fight enjoyment. Disk space was also very low during this work. Only agent-created temporary test/render caches were removed; user game assets and saves were preserved.

The isolated `campaign/verification/combat_review_v4.tscn` is ready for F6 in the editor and captures the final-core HUD, Aurora READY, release, jump and empty-quiver walk. It uses a temporary test profile. Actual-device playtesting and the previously noted detailed enemy/boss art work remain outstanding.

## Playtest this revision

1. Restart with F5 and confirm **Combat revision 4** in Settings.
2. Spend the quiver, move and jump. The character should continue stepping and leave aim immediately.
3. Hold POWER while moving/looking. A second SHOOT press should not interrupt it. Release once for one volley; cancel with dodge or pause for no shot.
4. In stage 100, shoot the cyan core during an ordinary exposure and compare actual damage with armor. At 10%, wait for the gold opening, hold AURORA until READY and release into the core.
5. Spend or miss Aurora, collect the well, and try another opening. Judge the tell timing, launch/impact readability and movement on the target phone.

Existing equipment ownership, economy, mastery requirements, stage IDs and campaign progress were preserved.
