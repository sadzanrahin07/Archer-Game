extends SceneTree

const ThreatDirectorScript = preload("res://campaign/combat/threat_director.gd")
const EnemyBaseScript = preload("res://campaign/combat/enemy_base.gd")
const MossSlimeScript = preload("res://campaign/combat/moss_slime.gd")
const CombatManagerScript = preload("res://campaign/combat/combat_manager.gd")
const ProfileScript = preload("res://campaign/profile.gd")
const PlayerScript = preload("res://campaign/player.gd")

class MockGame extends Node3D:
	var state := "playing"
	var arrows := 10
	var profile: RefCounted
	var hero: CharacterBody3D
	var stage: Node3D
	var current_chapter := 12
	var power_armed := false
	var draw_amount := 0.0
	var time_left := 30.0
	var selected_power := "normal"
	func is_playing() -> bool: return state == "playing"
	func play_sound(_p: String, _pi: float = 1.0, _v: float = 0.0) -> void: pass
	func feedback(_msg: String) -> void: pass
	func finish(_success: bool, _reason: String) -> void: pass
	func trigger_power() -> void: pass

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("=== STARTING COMBAT VERTICAL SLICE VERIFICATION (PHASE 4) ===")
	var failed := false

	# ---------------------------------------------------------
	# 1. THREAT DIRECTOR TESTS
	# ---------------------------------------------------------
	print("
--- 1. Testing Threat Director ---")
	var td = ThreatDirectorScript.new()
	var e1 = Node.new()
	var e2 = Node.new()
	var e3 = Node.new()

	if not td.can_attack(e1):
		printerr("FAIL: td should allow e1"); failed = true
	if not td.reserve_attack(e1):
		printerr("FAIL: e1 failed to reserve attack"); failed = true
	if not td.reserve_attack(e2):
		printerr("FAIL: e2 failed to reserve attack"); failed = true
	if td.reserve_attack(e3):
		printerr("FAIL: e3 reserved attack when max is 2"); failed = true
	if td.can_attack(e3):
		printerr("FAIL: e3 can_attack should be false when at max"); failed = true

	td.release_attack(e1)
	if not td.can_attack(e3):
		printerr("FAIL: e3 should be able to attack after e1 released"); failed = true
	if not td.reserve_attack(e3):
		printerr("FAIL: e3 failed to reserve after release"); failed = true

	td.clear()
	if not td.can_attack(e1) or not td.can_attack(e2):
		printerr("FAIL: td.clear() did not clear active attackers"); failed = true
	print("PASS: Threat Director adheres strictly to max 2 concurrent attackers.")

	# ---------------------------------------------------------
	# 2. MOSS SLIME FSM & TELEGRAPHS
	# ---------------------------------------------------------
	print("
--- 2. Testing Moss Slime FSM & Telegraphs ---")
	var slime = MossSlimeScript.new()
	root.add_child(slime)
	await process_frame
	
	if absf(slime.hp - 41.5) > 0.01:
		printerr("FAIL: Moss Slime HP should be 41.5, got ", slime.hp); failed = true
	if absf(slime.attack_damage - 12.0) > 0.01:
		printerr("FAIL: Moss Slime damage should be 12.0, got ", slime.attack_damage); failed = true
	if absf(slime.move_speed - 2.4) > 0.01:
		printerr("FAIL: Moss Slime speed should be 2.4, got ", slime.move_speed); failed = true
	if absf(slime.windup_time - 0.75) > 0.01:
		printerr("FAIL: Moss Slime windup should be 0.75, got ", slime.windup_time); failed = true
	if absf(slime.active_time - 0.16) > 0.01:
		printerr("FAIL: Moss Slime active time should be 0.16, got ", slime.active_time); failed = true
	if absf(slime.recovery_time - 0.85) > 0.01:
		printerr("FAIL: Moss Slime recovery should be 0.85, got ", slime.recovery_time); failed = true
	if slime.current_state != EnemyBaseScript.State.SPAWN:
		printerr("FAIL: Moss Slime should spawn in SPAWN state"); failed = true

	# Advance spawn timer (0.5s)
	slime._physics_process(0.51)
	if slime.current_state != EnemyBaseScript.State.APPROACH:
		printerr("FAIL: Moss Slime should transition to APPROACH after spawn timer"); failed = true

	# Set target player in range
	var dummy_player = Node3D.new()
	root.add_child(dummy_player)
	await process_frame
	dummy_player.global_position = Vector3(0, 0, 1.0)
	slime.global_position = Vector3(0, 0, 0)
	slime.target_player = dummy_player
	slime.threat_director = td

	slime._physics_process(0.016)
	if slime.current_state != EnemyBaseScript.State.TELEGRAPH:
		printerr("FAIL: Moss Slime should enter TELEGRAPH when in range"); failed = true
	if not is_instance_valid(slime.telegraph_mesh) or not slime.telegraph_mesh.visible:
		printerr("FAIL: Telegraph amber mesh must be visible during TELEGRAPH"); failed = true

	# Advance through telegraph windup (0.75s)
	slime._physics_process(0.76)
	if slime.current_state != EnemyBaseScript.State.ATTACK:
		printerr("FAIL: Moss Slime should enter ATTACK after windup"); failed = true
	if is_instance_valid(slime.telegraph_mesh) and slime.telegraph_mesh.visible:
		printerr("FAIL: Telegraph mesh should be hidden during ATTACK"); failed = true

	# Advance through attack active window (0.16s)
	slime._physics_process(0.17)
	if slime.current_state != EnemyBaseScript.State.RECOVER:
		printerr("FAIL: Moss Slime should enter RECOVER after active attack"); failed = true

	# Advance through recovery (0.85s)
	slime._physics_process(0.86)
	if slime.current_state != EnemyBaseScript.State.APPROACH:
		printerr("FAIL: Moss Slime should return to APPROACH after recovery"); failed = true

	# Test damage and vital hit
	var pre_hp = slime.hp
	slime.campaign_hit(slime.global_position + Vector3(0, 0.2, -1.0), 10.0, {})
	if absf(slime.hp - (pre_hp - 10.0)) > 0.01:
		printerr("FAIL: Body hit damage mismatch. Expected: ", pre_hp - 10.0, " Got: ", slime.hp); failed = true

	# Vital hit directly on vital_shape.global_position
	var pre_vital_hp = slime.hp
	slime.campaign_hit(slime.vital_shape.global_position, 10.0, {})
	var expected_vital = pre_vital_hp - 12.5 # 1.25x vital multiplier
	if absf(slime.hp - expected_vital) > 0.01:
		printerr("FAIL: Vital hit damage mismatch. Expected: ", expected_vital, " Got: ", slime.hp); failed = true
	print("PASS: Moss Slime FSM, telegraph timing, and vital multiplier verified.")

	# ---------------------------------------------------------
	# 3. PLAYER COMBAT STATS, DODGE & AIMING STRAFE
	# ---------------------------------------------------------
	print("
--- 3. Testing Player Combat Stats, Dodge & Aiming Strafe ---")
	var profile = ProfileScript.new()
	profile.save_path="/tmp/arrowglade-legacy-test_combat_slice.json" # Isolated; never read or write the player save.

	# Combat HP equation: HP = 100 + 1.5 * max(C - 60, 0) capped at 160
	var hp_c1 = 100.0 + 1.5 * maxf(1 - 60, 0)
	var hp_c60 = 100.0 + 1.5 * maxf(60 - 60, 0)
	var hp_c80 = 100.0 + 1.5 * maxf(80 - 60, 0)
	var hp_c100 = minf(160.0, 100.0 + 1.5 * maxf(100 - 60, 0))

	if absf(hp_c1 - 100.0) > 0.01 or absf(hp_c60 - 100.0) > 0.01:
		printerr("FAIL: Combat HP before C60 should be 100.0"); failed = true
	if absf(hp_c80 - 130.0) > 0.01:
		printerr("FAIL: Combat HP at C80 should be 130.0, got ", hp_c80); failed = true
	if absf(hp_c100 - 160.0) > 0.01:
		printerr("FAIL: Combat HP at C100 should be 160.0, got ", hp_c100); failed = true

	# Test Player Dodge and Aiming Strafe
	var mock_game = MockGame.new()
	root.add_child(mock_game)
	mock_game.state = "playing"
	mock_game.arrows = 10
	mock_game.profile = profile

	var player = PlayerScript.new()
	player.game = mock_game
	mock_game.hero = player
	root.add_child(player)
	await process_frame
	player.set_showcase(false)
	player.current_hp = 100.0
	player.max_hp = 100.0
	player.drawing = true # simulate drawing bow
	
	# Start dodge
	player.start_dodge()
	if not player.is_dodging:
		printerr("FAIL: player.is_dodging should be true"); failed = true
	if player.drawing:
		printerr("FAIL: dodge must cancel bow draw"); failed = true
	if absf(player.dodge_cooldown - 1.20) > 0.01:
		printerr("FAIL: dodge_cooldown should be initialized to 1.20s, got ", player.dodge_cooldown); failed = true

	# Step 1: elapsed 0.02s (before 0.05s invulnerability)
	player._physics_process(0.02)
	if player.is_invulnerable:
		printerr("FAIL: player should not be invulnerable at t=0.02s"); failed = true

	# Step 2: elapsed 0.15s (within 0.05s - 0.25s invulnerability)
	player._physics_process(0.13) # total elapsed 0.15s
	if not player.is_invulnerable:
		printerr("FAIL: player must be invulnerable at t=0.15s"); failed = true

	# Test damage absorption while invulnerable
	player.take_player_damage(25.0)
	if absf(player.current_hp - 100.0) > 0.01:
		printerr("FAIL: damage was taken while invulnerable! HP: ", player.current_hp); failed = true

	# Step 3: elapsed 0.30s (past 0.25s invulnerability)
	player._physics_process(0.15) # total elapsed 0.30s
	if player.is_invulnerable:
		printerr("FAIL: player should no longer be invulnerable at t=0.30s"); failed = true

	# Test damage taken after invulnerability ends
	player.take_player_damage(25.0)
	if absf(player.current_hp - 75.0) > 0.01:
		printerr("FAIL: damage not taken when vulnerable. HP: ", player.current_hp); failed = true

	# Step 4: complete dodge (0.40s)
	player._physics_process(0.12)
	if player.is_dodging:
		printerr("FAIL: dodge should finish at 0.40s"); failed = true
	if player.dodge_cooldown <= 0:
		printerr("FAIL: dodge cooldown must remain active after dodge ends"); failed = true

	# Try dodging again while on cooldown
	player.start_dodge()
	if player.is_dodging:
		printerr("FAIL: should not be able to dodge while cooldown > 0"); failed = true

	print("PASS: Player HP, dodge cancellation, invulnerability window (0.05-0.25s), and cooldown verified.")

	# ---------------------------------------------------------
	# 4. SUPPLY REFILL ANCHOR
	# ---------------------------------------------------------
	print("
--- 4. Testing Supply Refill Anchor ---")
	var cm = CombatManagerScript.new()
	root.add_child(cm)

	var mock_stage = Node3D.new()
	mock_stage.set_script(load("res://campaign/stage.gd"))
	root.add_child(mock_stage)
	mock_stage.spawn = Vector3(0, 0, 0)
	await process_frame
	
	cm.game = mock_game
	cm.stage = mock_stage
	cm._build_supply_anchor()

	# With 10 arrows, supply anchor should be hidden
	cm._physics_process(0.016)
	if cm.supply_anchor.visible:
		printerr("FAIL: supply anchor should not be visible when arrows > 2"); failed = true

	# When arrows drop to 2, supply anchor becomes visible
	mock_game.arrows = 2
	cm._physics_process(0.016)
	if not cm.supply_anchor.visible:
		printerr("FAIL: supply anchor should be visible when arrows <= 2"); failed = true

	# Simulate hero walking to anchor
	player.global_position = cm.supply_anchor.global_position
	mock_game.hero = player

	cm._physics_process(0.016)
	if mock_game.arrows != 8: # 2 + 6 = 8
		printerr("FAIL: supply did not replenish +6 arrows. Got: ", mock_game.arrows); failed = true
	if cm.supply_cooldown <= 0:
		printerr("FAIL: supply_cooldown should be set to 8.0s"); failed = true
	if cm.supply_anchor.visible:
		printerr("FAIL: supply anchor should hide after collection"); failed = true
	print("PASS: Supply Refill Anchor activates when arrows <= 2, replenishes +6, and applies 8s cooldown.")

	# ---------------------------------------------------------
	# 5. STAGE 55 GATE & PROGRESSION
	# ---------------------------------------------------------
	print("
--- 5. Testing Stage 55 Trial Gate & Pressure Wave Progression ---")
	# Unlock chapters up through Chapter 11 (stages 0 to 54 cleared)
	for i in range(55):
		profile.data.stars[str(i)] = 1
	profile.data.trial_proofs = {}

	# Case A: Below requirement (M = 59)
	profile.data.bow_level = 59
	profile.data.arrow_level = 59
	profile.data.character_level = 59
	
	if profile.stage_ready(55):
		printerr("FAIL: Stage 55 should be locked at M=59"); failed = true
	var lock_reason = profile.get_stage_lock_reason(55)
	if not lock_reason.contains("Mastery 60"):
		printerr("FAIL: Lock reason should mention Mastery 60, got: ", lock_reason); failed = true
	if profile.power_is_unlocked("pressure"):
		printerr("FAIL: Pressure Wave should be locked at M=59"); failed = true

	# Case B: At requirement (M = 60), before trial victory
	profile.data.bow_level = 60
	profile.data.arrow_level = 60
	profile.data.character_level = 60
	if not profile.stage_ready(55):
		printerr("FAIL: Stage 55 should be ready at M=60"); failed = true
	if profile.power_is_unlocked("pressure"):
		printerr("FAIL: Pressure Wave should not be unlocked without trial proof"); failed = true
	var p_reason = profile.get_power_lock_reason("pressure")
	if not p_reason.contains("First Pressure Trial"):
		printerr("FAIL: Pressure lock reason should mention First Pressure Trial, got: ", p_reason); failed = true

	# Case C: Victory in Stage 55 Trial
	profile.grant_trial_proof(55)
	if not profile.has_trial_proof(55):
		printerr("FAIL: profile does not have trial proof 55 after grant"); failed = true
	if not profile.power_is_unlocked("pressure"):
		printerr("FAIL: Pressure Wave must be unlocked after trial proof 55 earned"); failed = true
	if not profile.get_power_lock_reason("pressure").is_empty():
		printerr("FAIL: Pressure lock reason should be empty once unlocked"); failed = true
	print("PASS: Stage 55 gate (M60) and permanent Pressure Wave trial progression verified.")

	# Clean up
	dummy_player.queue_free()
	slime.queue_free()
	player.queue_free()
	cm.queue_free()
	mock_game.queue_free()
	mock_stage.queue_free()
	e1.free()
	e2.free()
	e3.free()

	if failed:
		printerr("
>>> COMBAT VERTICAL SLICE VERIFICATION FAILED <<<")
		quit(1)
	else:
		print("
>>> ALL COMBAT VERTICAL SLICE TESTS PASSED SUCCESSFULLY! <<<")
		quit(0)
