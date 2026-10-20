# Archer Game — current build

Godot 4.7.2. Open `res://campaign/main.tscn` and use Play Project (Cmd+B on this Mac). If the editor reports changes outside Godot, choose Reload. Play Current Scene can run an open character instead of the game.

The build has 20 chapters / 100 stages, Erin's dark kimono starter with six portrait skins, separate Enola/Maki/Jacky characters, corrected Maki retargeting, independent mastery, coin/XP upgrades, four gear rarities and seven powers unlocked from skin levels 20–100. Later chapters are roaming courses ending at a rune stone. Failure or explicit Restart returns to Stage 1 of the current chapter, keeping banked rewards. Practice does not award coins or change campaign Continue.

WASD move; Shift run; mouse look; right mouse aim; hold left mouse draw, release shoot; E arms the selected power; Escape pause. Mobile is landscape with the same menus and touch controls. Play stays bottom right. Background music starts at 28 seconds in Home/pause/results; music and game sounds have separate settings. Final-hit results wait 1.30 seconds, after the target camera close-up.

The illustrated implementation report, current prices, power rules, stage tables and verification notes are at `/Users/sadzanrahin/Documents/Codex/2026-10-13/i-x20/outputs/Archer-Game-Build-2026-10-15.md`. Current exact stage data lives in `campaign/stages.json`.

Player save: `user://archer_campaign.json`, with `.bak`; paid legacy ownership and coins are preserved. QA profiles are separate. Never use QA files as the player profile.

## Verification

From the project folder, run:

```sh
"/Users/sadzanrahin/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://campaign/verify_build.gd
```

Substitute `verify_progression.gd`, `verify_landscape_ui.gd`, `verify_result_regressions.gd`, `verify_scenery.gd`, `verify_stage_budgets.gd`, `verify_campaign_economy.gd` or `verify_roaming.gd` for the other checks. Full 100-scene completion smoke:

```sh
"/Users/sadzanrahin/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . -- --campaign-test
```

Each check prints an explicit PASS marker. `verify_current.gd` and `verify_mobile_ui.gd` forward to the current build/layout checks. Native visuals have been checked on this Mac; physical mobile devices and physical gamepad testing remain outstanding. A macOS certificate lookup diagnostic occurs only on headless engine startup.
