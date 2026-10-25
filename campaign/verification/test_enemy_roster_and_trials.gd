extends SceneTree

const ThreatDirectorScript = preload("res://campaign/combat/threat_director.gd")
const EnemyBaseScript = preload("res://campaign/combat/enemy_base.gd")
const MossSlimeScript = preload("res://campaign/combat/moss_slime.gd")
const BriarSlimeScript = preload("res://campaign/combat/briar_slime.gd")
const SeedSpitterScript = preload("res://campaign/combat/seed_spitter.gd")
const BarkStalkerScript = preload("res://campaign/combat/bark_stalker.gd")
const MirrorWispScript = preload("res://campaign/combat/mirror_wisp.gd")
const RootWardenScript = preload("res://campaign/combat/root_warden.gd")
const SeedScript = preload("res://campaign/combat/enemy_seed.gd")
const DartScript = preload("res://campaign/combat/enemy_dart.gd")
const ProfileScript = preload("res://campaign/profile.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("=== STARTING ENEMY ROSTER AND TRIALS VERIFICATION (PHASE 5) ===")
	var failed := false
	var td = ThreatDirectorScript.new()

	# ---------------------------------------------------------
	# 1. VERIFY ALL 6 ENEMY FAMILIES
	# ---------------------------------------------------------
	print("
--- 1. Testing Roster Stats, FSM and Vitals ---")
	var roster = [
		{"name": "Moss Slime", "script": MossSlimeScript, "hp": 41.5, "dmg": 12.0, "speed": 2.4, "range": 1.8},
		{"name": "Briar Slime", "script": BriarSlimeScript, "hp": 62.25, "dmg": 18.0, "speed": 2.0, "range": 4.0},
		{"name": "Seed Spitter", "script": SeedSpitterScript, "hp": 62.25, "dmg": 12.0, "speed": 0.0, "range": 14.0},
		{"name": "Bark Stalker", "script": BarkStalkerScript, "hp": 83.0, "dmg": 16.0, "speed": 3.8, "range": 1.8},
		{"name": "Mirror Wisp", "script": MirrorWispScript, "hp": 62.25, "dmg": 10.0, "speed": 2.6, "range": 14.0},
		{"name": "Root Warden", "script": RootWardenScript, "hp": 166.0, "dmg": 22.0, "speed": 1.8, "range": 2.5}
	]

	for entry in roster:
		var enemy = entry["script"].new()
		root.add_child(enemy)
		await process_frame
		
		# Check stats
		if absf(enemy.hp - entry["hp"]) > 0.01:
			printerr("FAIL: %s HP mismatch. Expected: %.2f, Got: %.2f" % [entry["name"], entry["hp"], enemy.hp]); failed = true
		if absf(enemy.attack_damage - entry["dmg"]) > 0.01:
			printerr("FAIL: %s dmg mismatch. Expected: %.2f, Got: %.2f" % [entry["name"], entry["dmg"], enemy.attack_damage]); failed = true
		if absf(enemy.move_speed - entry["speed"]) > 0.01:
			printerr("FAIL: %s speed mismatch. Expected: %.2f, Got: %.2f" % [entry["name"], entry["speed"], enemy.move_speed]); failed = true
		if absf(enemy.attack_range - entry["range"]) > 0.01:
			printerr("FAIL: %s range mismatch. Expected: %.2f, Got: %.2f" % [entry["name"], entry["range"], enemy.attack_range]); failed = true
		
		# Check vital shape exists
		if not is_instance_valid(enemy.vital_shape):
			printerr("FAIL: %s missing vital_shape" % entry["name"]); failed = true
		else:
			# Verify vital hit deals 1.25x damage
			var pre_hp = enemy.hp
			enemy.campaign_hit(enemy.vital_shape.global_position, 10.0, {})
			var expected_hp = pre_hp - 12.5
			if absf(enemy.hp - expected_hp) > 0.01:
				printerr("FAIL: %s vital multiplier mismatch. Expected: %.2f, Got: %.2f" % [entry["name"], expected_hp, enemy.hp]); failed = true

		enemy.queue_free()
	print("PASS: All 6 enemy families instantiated with exact canonical HP, damage, speed, range, and vital multiplier.")

	# ---------------------------------------------------------
	# 2. ENEMY PROJECTILES
	# ---------------------------------------------------------
	print("
--- 2. Testing Enemy Projectiles ---")
	var seed = SeedScript.new()
	if absf(seed.speed - 9.0) > 0.01 or absf(seed.damage - 12.0) > 0.01:
		printerr("FAIL: Seed projectile speed (9 m/s) or damage (12.0) mismatch"); failed = true
	seed.free()

	var dart = DartScript.new()
	if absf(dart.speed - 11.0) > 0.01 or absf(dart.damage - 10.0) > 0.01:
		printerr("FAIL: Dart projectile speed (11 m/s) or damage (10.0) mismatch"); failed = true
	dart.free()
	print("PASS: Enemy seed (9 m/s, 12 dmg) and dart (11 m/s, 10 dmg) verified.")

	# ---------------------------------------------------------
	# 3. LATER TRIALS PROGRESSION (65, 75, 85, 95)
	# ---------------------------------------------------------
	print("
--- 3. Testing Later Trials Gates & Rewards ---")
	var profile = ProfileScript.new()
	profile.save_path="/tmp/arrowglade-legacy-test_enemy_roster_and_trials.json" # Isolated; never read or write the player save.
	# Clear stars & proofs
	profile.data.stars = {}
	profile.data.trial_proofs = {}
	for i in range(100):
		profile.data.stars[str(i)] = 1

	# Trial 65 (Ember Trail, M >= 70)
	profile.data.bow_level = 69
	profile.data.arrow_level = 69
	profile.data.character_level = 69
	if profile.stage_ready(65):
		printerr("FAIL: Stage 65 should be locked at M=69"); failed = true
	profile.data.bow_level = 70
	profile.data.arrow_level = 70
	profile.data.character_level = 70
	if not profile.stage_ready(65):
		printerr("FAIL: Stage 65 should be ready at M=70"); failed = true
	if profile.power_is_unlocked("fire"):
		printerr("FAIL: Ember should not be unlocked without trial proof 65"); failed = true
	profile.grant_trial_proof(65)
	if not profile.power_is_unlocked("fire") or not profile.power_is_unlocked("ember"):
		printerr("FAIL: Ember must be unlocked after trial proof 65"); failed = true

	# Trial 75 (Lightning Arrow, M >= 80)
	profile.data.bow_level = 79
	profile.data.arrow_level = 79
	profile.data.character_level = 79
	if profile.stage_ready(75):
		printerr("FAIL: Stage 75 should be locked at M=79"); failed = true
	profile.data.bow_level = 80
	profile.data.arrow_level = 80
	profile.data.character_level = 80
	if not profile.stage_ready(75):
		printerr("FAIL: Stage 75 should be ready at M=80"); failed = true
	if profile.power_is_unlocked("lightning"):
		printerr("FAIL: Lightning should not be unlocked without trial proof 75"); failed = true
	profile.grant_trial_proof(75)
	if not profile.power_is_unlocked("lightning"):
		printerr("FAIL: Lightning must be unlocked after trial proof 75"); failed = true

	# Trial 85 (Super Lightning, M >= 90)
	profile.data.bow_level = 89
	profile.data.arrow_level = 89
	profile.data.character_level = 89
	if profile.stage_ready(85):
		printerr("FAIL: Stage 85 should be locked at M=89"); failed = true
	profile.data.bow_level = 90
	profile.data.arrow_level = 90
	profile.data.character_level = 90
	if not profile.stage_ready(85):
		printerr("FAIL: Stage 85 should be ready at M=90"); failed = true
	if profile.power_is_unlocked("super") or profile.power_is_unlocked("super_lightning"):
		printerr("FAIL: Super Lightning should not be unlocked without trial proof 85"); failed = true
	profile.grant_trial_proof(85)
	if not profile.power_is_unlocked("super") and not profile.power_is_unlocked("super_lightning"):
		printerr("FAIL: Super Lightning must be unlocked after trial proof 85"); failed = true

	# Trial 95 (Aurora Tempest, all masteries == 100)
	profile.data.bow_level = 99
	profile.data.arrow_level = 99
	profile.data.character_level = 99
	if profile.stage_ready(95):
		printerr("FAIL: Stage 95 should be locked at M=99"); failed = true
	profile.data.bow_level = 100
	profile.data.arrow_level = 100
	profile.data.character_level = 100
	if not profile.stage_ready(95):
		printerr("FAIL: Stage 95 should be ready at M=100"); failed = true
	if profile.power_is_unlocked("ultimate") or profile.power_is_unlocked("aurora"):
		printerr("FAIL: Aurora should not be unlocked without trial proof 95"); failed = true
	profile.grant_trial_proof(95)
	if not profile.power_is_unlocked("ultimate") and not profile.power_is_unlocked("aurora"):
		printerr("FAIL: Aurora must be unlocked after trial proof 95"); failed = true

	print("PASS: All four later trials (65, 75, 85, 95) verified with exact gates and permanent power unlocks.")

	if failed:
		printerr("
>>> ENEMY ROSTER AND TRIALS VERIFICATION FAILED <<<")
		quit(1)
	else:
		print("
>>> ALL ENEMY ROSTER AND TRIALS TESTS PASSED SUCCESSFULLY! <<<")
		quit(0)
