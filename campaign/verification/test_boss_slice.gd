extends SceneTree

const HollowCrownScript = preload("res://campaign/combat/hollow_crown.gd")
const ProfileScript = preload("res://campaign/profile.gd")

class MockGame extends Node3D:
	var state := "playing"
	var arrows := 0
	var focus := 0
	var profile: RefCounted
	var hero: CharacterBody3D
	func is_playing() -> bool: return state == "playing"
	func play_sound(_p: String, _pi: float = 1.0, _v: float = 0.0) -> void: pass
	func feedback(_msg: String) -> void: pass
	func finish(_success: bool, _reason: String) -> void: pass

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("=== STARTING BOSS VERTICAL SLICE VERIFICATION (PHASE 6: THE HOLLOW CROWN) ===")
	var failed := false
	var profile = ProfileScript.new()
	profile.save_path="/tmp/arrowglade-legacy-test_boss_slice.json" # Isolated; never read or write the player save.
	profile.data.bow_level = 100
	profile.data.arrow_level = 100
	profile.data.character_level = 100

	var mock_game = MockGame.new()
	root.add_child(mock_game)
	mock_game.profile = profile

	var boss = HollowCrownScript.new()
	boss.game = mock_game
	root.add_child(boss)
	await process_frame

	# ---------------------------------------------------------
	# 1. FIXED HP & INITIAL STATS
	# ---------------------------------------------------------
	print("
--- 1. Testing Fixed HP and Gate Constants ---")
	if absf(boss.hp - 1476.0) > 0.01:
		printerr("FAIL: Boss HP must be exactly 1476.0, got ", boss.hp); failed = true
	if absf(boss.GATE_70 - 1033.2) > 0.01:
		printerr("FAIL: GATE_70 must be exactly 1033.2, got ", boss.GATE_70); failed = true
	if absf(boss.GATE_35 - 516.6) > 0.01:
		printerr("FAIL: GATE_35 must be exactly 516.6, got ", boss.GATE_35); failed = true
	if absf(boss.GATE_10 - 147.6) > 0.01:
		printerr("FAIL: GATE_10 must be exactly 147.6, got ", boss.GATE_10); failed = true
	print("PASS: Fixed HP (1476.0 = 24 * 61.5) and gates (1033.2, 516.6, 147.6) verified.")

	# Advance past INTRO (1.5s)
	boss._physics_process(1.55)
	if boss.current_state != HollowCrownScript.State.P1_CLOSED:
		printerr("FAIL: Boss should be in P1_CLOSED after intro"); failed = true

	# ---------------------------------------------------------
	# 2. PHASE 1 GATE & OVERFLOW CLAMPING (70% = 1033.2)
	# ---------------------------------------------------------
	print("
--- 2. Testing Phase 1 Gate & Overflow Clamping ---")
	# Deal massive 800 damage; body closed multiplier is 0.25 (delivered = 200)
	boss.campaign_hit(boss.global_position, 800.0, {})
	var expected_hp = 1476.0 - 200.0
	if absf(boss.hp - expected_hp) > 0.01:
		printerr("FAIL: Closed body hit damage mismatch. Expected: ", expected_hp, " Got: ", boss.hp); failed = true

	# Now hit with massive overflow damage (10000.0). It must clamp strictly at GATE_70 (1033.2)!
	boss.campaign_hit(boss.global_position, 10000.0, {})
	if absf(boss.hp - 1033.2) > 0.01:
		printerr("FAIL: Overflow damage did not clamp at GATE_70! HP: ", boss.hp); failed = true
	if boss.current_state != HollowCrownScript.State.TRANSITION_70:
		printerr("FAIL: Boss should enter TRANSITION_70 on reaching gate"); failed = true

	# While in TRANSITION_70, damage must be rejected (invulnerable)
	boss.campaign_hit(boss.global_position, 500.0, {})
	if absf(boss.hp - 1033.2) > 0.01:
		printerr("FAIL: Damage taken during transition invulnerability! HP: ", boss.hp); failed = true

	# Advance past TRANSITION_70 (1.0s)
	boss._physics_process(1.05)
	if boss.current_state != HollowCrownScript.State.P2_CLOSED:
		printerr("FAIL: Boss should enter P2_CLOSED after transition"); failed = true
	print("PASS: Phase 1 gate clamped overflow strictly at 1033.2; transition invulnerability verified.")

	# ---------------------------------------------------------
	# 3. PHASE 2 GATE & OVERFLOW CLAMPING (35% = 516.6)
	# ---------------------------------------------------------
	print("
--- 3. Testing Phase 2 Gate & Overflow Clamping ---")
	# Massive overflow damage in Phase 2
	boss.campaign_hit(boss.global_position, 10000.0, {})
	if absf(boss.hp - 516.6) > 0.01:
		printerr("FAIL: Overflow damage did not clamp at GATE_35! HP: ", boss.hp); failed = true
	if boss.current_state != HollowCrownScript.State.TRANSITION_35:
		printerr("FAIL: Boss should enter TRANSITION_35 on reaching gate"); failed = true

	# Advance past TRANSITION_35 (1.0s)
	boss._physics_process(1.05)
	if boss.current_state != HollowCrownScript.State.P3_CLOSED:
		printerr("FAIL: Boss should enter P3_CLOSED after transition"); failed = true
	print("PASS: Phase 2 gate clamped overflow strictly at 516.6.")

	# ---------------------------------------------------------
	# 4. PHASE 3 GATE (10% = 147.6) & NON-LETHAL RESISTANCE
	# ---------------------------------------------------------
	print("
--- 4. Testing Phase 3 Gate (147.6) and Non-Lethal Resistance ---")
	boss.campaign_hit(boss.global_position, 10000.0, {})
	if absf(boss.hp - 147.6) > 0.01:
		printerr("FAIL: Overflow damage did not clamp at GATE_10! HP: ", boss.hp); failed = true
	if boss.current_state != HollowCrownScript.State.FINAL_REARM:
		printerr("FAIL: Boss should enter FINAL_REARM at 10%"); failed = true

	# Advance into FINAL_OPEN
	boss._physics_process(2.05)
	if boss.current_state != HollowCrownScript.State.FINAL_OPEN or not boss.is_core_exposed:
		printerr("FAIL: Boss should enter FINAL_OPEN with exposed core"); failed = true

	# Non-lethal tests at 10%:
	# 1. Normal arrows
	boss.campaign_hit(boss.core_col.global_position, 500.0, {"power_key": "normal", "draw_ratio": 1.0})
	if absf(boss.hp - 147.6) > 0.01:
		printerr("FAIL: Normal arrow reduced HP below 147.6! HP: ", boss.hp); failed = true

	# 2. Burn / secondary tick
	boss.campaign_hit(boss.core_col.global_position, 300.0, {"power_key": "fire", "secondary": true})
	if absf(boss.hp - 147.6) > 0.01:
		printerr("FAIL: Burn tick reduced HP below 147.6! HP: ", boss.hp); failed = true

	# 3. Aurora body hit (not core)
	boss.campaign_hit(boss.global_position, 800.0, {"power_key": "aurora", "draw_ratio": 1.0})
	if absf(boss.hp - 147.6) > 0.01:
		printerr("FAIL: Aurora body hit reduced HP below 147.6! HP: ", boss.hp); failed = true

	# 4. Aurora AOE hit
	boss.campaign_hit(boss.core_col.global_position, 800.0, {"power_key": "aurora", "draw_ratio": 1.0, "aoe": true})
	if absf(boss.hp - 147.6) > 0.01:
		printerr("FAIL: Aurora AOE reduced HP below 147.6! HP: ", boss.hp); failed = true

	# 5. Aurora partial draw (draw_ratio = 0.80 < 0.95)
	boss.campaign_hit(boss.core_col.global_position, 800.0, {"power_key": "aurora", "draw_ratio": 0.80})
	if absf(boss.hp - 147.6) > 0.01:
		printerr("FAIL: Aurora partial draw (< 0.95) reduced HP below 147.6! HP: ", boss.hp); failed = true

	print("PASS: Normal arrows, burns, body hits, AOE, and partial draws cannot kill at 10% (HP remains clamped at 147.6).")

	# ---------------------------------------------------------
	# 5. THREE MISSED FINISHERS & REARM WELL RECOVERY
	# ---------------------------------------------------------
	print("
--- 5. Testing 3 Missed Finishers and Rearm Well Recovery ---")
	for miss in range(3):
		# Let exposure time (4.2s) expire
		boss._physics_process(4.25)
		if boss.is_core_exposed:
			printerr("FAIL: Core should close after 4.2s"); failed = true
		if not boss.rearm_well_active:
			printerr("FAIL: Rearm well must be active after missed final opening"); failed = true
		
		# Collect rearm well (raises arrows to 6, focus to 100)
		mock_game.arrows = 0
		mock_game.focus = 0
		boss.collect_rearm_well(mock_game.hero)
		if mock_game.arrows < 6:
			printerr("FAIL: Rearm well must raise quiver to at least 6 arrows"); failed = true
		if mock_game.focus != 100:
			printerr("FAIL: Rearm well must grant 100 focus"); failed = true
		
		# Advance through rearm cycle to next FINAL_OPEN
		boss._physics_process(2.05)
		if boss.current_state != HollowCrownScript.State.FINAL_OPEN:
			printerr("FAIL: Boss should return to FINAL_OPEN after recovery cycle"); failed = true

	if boss.missed_openings < 3:
		printerr("FAIL: Should record 3 missed openings, got ", boss.missed_openings); failed = true
	print("PASS: 3 missed final openings recovered via safe rearm well without restarting or payment.")

	# ---------------------------------------------------------
	# 6. VALID FINAL DIRECT AURORA FINISHER
	# ---------------------------------------------------------
	print("
--- 6. Testing Valid Final Direct Aurora Finisher ---")
	var defeated_signal_received := [false]
	boss.boss_defeated.connect(func(): defeated_signal_received[0] = true)

	# Direct full-draw Aurora hit on exposed core
	var hit_accepted = boss.campaign_hit(boss.core_col.global_position, 184.5, {
		"power_key": "aurora",
		"draw_ratio": 1.0,
		"direct": true
	})

	if not hit_accepted:
		printerr("FAIL: Finisher hit was rejected"); failed = true
	if absf(boss.hp - 0.0) > 0.001:
		printerr("FAIL: Boss HP should be 0.0 after valid finisher! HP: ", boss.hp); failed = true
	if boss.current_state != HollowCrownScript.State.DEAD:
		printerr("FAIL: Boss state should be DEAD after finisher"); failed = true
	if not defeated_signal_received[0]:
		printerr("FAIL: boss_defeated signal was not emitted!"); failed = true

	print("PASS: Direct full-draw Aurora on exposed core successfully finished The Hollow Crown!")

	# Clean up
	boss.queue_free()
	mock_game.queue_free()

	if failed:
		printerr("
>>> BOSS VERTICAL SLICE VERIFICATION FAILED <<<")
		quit(1)
	else:
		print("
>>> ALL BOSS VERTICAL SLICE TESTS PASSED SUCCESSFULLY! <<<")
		quit(0)
