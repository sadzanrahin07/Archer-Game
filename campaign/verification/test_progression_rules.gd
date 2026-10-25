extends SceneTree

func _init() -> void:
	print("--- Running test_progression_rules.gd ---")
	var ProfileClass = load("res://campaign/profile.gd")
	var Catalog = load("res://campaign/catalog.gd")
	if ProfileClass == null or Catalog == null:
		printerr("FAIL: Could not load profile.gd or catalog.gd")
		quit(1)
		return

	var profile = ProfileClass.new()
	profile.save_path = "/tmp/test_profile_isolated.json"
	profile.data.coins = 500
	profile.data.bow_level = 1
	profile.data.arrow_level = 1
	profile.data.character_level = 1
	profile.data.trial_proofs = {}
	profile.data.purchased_powers = []

	# 1. Test Mastery properties
	if profile.bow_mastery() != 1 or profile.arrow_mastery() != 1 or profile.character_mastery() != 1:
		printerr("FAIL: Initial masteries are not 1")
		quit(1)
		return

	if profile.power_mastery() != 1:
		printerr("FAIL: Initial power mastery M != 1")
		quit(1)
		return

	# 2. Test base damage formula: D = 12 + 0.22(B-1) + 0.18(A-1) + 0.10(C-1)
	# At B=1, A=1, C=1 -> D = 12.0
	var d1: float = profile.base_damage()
	if absf(d1 - 12.0) > 0.001:
		printerr("FAIL: D at 1/1/1 should be 12.0, got: ", d1)
		quit(1)
		return

	# At B=100, A=100, C=100 -> D = 12 + 0.22*99 + 0.18*99 + 0.10*99 = 12 + 0.50*99 = 12 + 49.5 = 61.5
	profile.data.bow_level = 100
	profile.data.arrow_level = 100
	profile.data.character_level = 100
	var d100: float = profile.base_damage()
	if absf(d100 - 61.5) > 0.001:
		printerr("FAIL: D at 100/100/100 should be 61.5, got: ", d100)
		quit(1)
		return

	# 3. Test Player HP: HP = 100 + 0.60(C-1) -> 100 at C1, 159.4 (160) at C100
	profile.data.character_level = 1
	if absf(profile.max_hp() - 100.0) > 0.001:
		printerr("FAIL: HP at C1 should be 100.0")
		quit(1)
		return

	profile.data.character_level = 100
	if absf(profile.max_hp() - 159.4) > 0.001:
		printerr("FAIL: HP at C100 should be 159.4")
		quit(1)
		return

	# 4. Test Power Thresholds and Trials
	# At M=19: no burst
	profile.data.bow_level = 19
	profile.data.arrow_level = 19
	if profile.power_is_unlocked("burst"):
		printerr("FAIL: Burst should not be unlocked at M=19")
		quit(1)
		return

	# At M=20: burst unlocked
	profile.data.bow_level = 20
	profile.data.arrow_level = 20
	if not profile.power_is_unlocked("burst"):
		printerr("FAIL: Burst should be unlocked at M=20")
		quit(1)
		return

	# At M=50: gale unlocked
	profile.data.bow_level = 50
	profile.data.arrow_level = 50
	if not profile.power_is_unlocked("gale") or not profile.power_is_unlocked("burst"):
		printerr("FAIL: Burst & Gale should be unlocked at M=50")
		quit(1)
		return

	# At M=60 without trial proof: pressure is NOT unlocked
	profile.data.bow_level = 60
	profile.data.arrow_level = 60
	if profile.power_is_unlocked("pressure"):
		printerr("FAIL: Pressure requires trial 55 proof at M=60")
		quit(1)
		return

	# Add trial proof 55: pressure unlocks
	profile.grant_trial_proof(55)
	if not profile.power_is_unlocked("pressure"):
		printerr("FAIL: Pressure should unlock with trial 55 proof")
		quit(1)
		return

	# Check that lower powers are STILL available at M=60
	if not profile.power_is_unlocked("burst") or not profile.power_is_unlocked("gale"):
		printerr("FAIL: Higher level should not lock out lower powers")
		quit(1)
		return

	# 5. Test Chapter 20 gate (requires B100, A100, C100)
	profile.data.bow_level = 100
	profile.data.arrow_level = 100
	profile.data.character_level = 99
	if profile.can_enter_chapter_20():
		printerr("FAIL: Chapter 20 requires C100")
		quit(1)
		return

	profile.data.character_level = 100
	if not profile.can_enter_chapter_20():
		printerr("FAIL: Chapter 20 should be accessible at B100/A100/C100")
		quit(1)
		return

	print("SUCCESS: ALL PROGRESSION RULES CHECKS PASSED!")
	quit(0)
