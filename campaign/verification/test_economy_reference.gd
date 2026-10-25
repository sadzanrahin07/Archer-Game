extends SceneTree

func _init() -> void:
	print("--- Running test_economy_reference.gd ---")
	var Catalog = load("res://campaign/catalog.gd")
	if Catalog == null:
		printerr("FAIL: Could not load catalog.gd")
		quit(1)
		return

	# 1. Test upgrade prices at L=99 -> 100
	var bow_99: int = Catalog.upgrade_price("bow", 99)
	var arrow_99: int = Catalog.upgrade_price("arrow", 99)
	var archer_99: int = Catalog.upgrade_price("character", 99)
	
	print("L=99 prices: Bow=%d, Arrow=%d, Archer=%d, Sum=%d" % [bow_99, arrow_99, archer_99, bow_99 + arrow_99 + archer_99])
	if bow_99 != 8685 or arrow_99 != 6510 or archer_99 != 3860:
		printerr("FAIL: L=99 upgrade prices do not match reference (8685, 6510, 3860)")
		quit(1)
		return

	# 2. Test total upgrade cost across 1..99
	var total_bow := 0
	var total_arrow := 0
	var total_archer := 0
	for l in range(1, 100):
		total_bow += Catalog.upgrade_price("bow", l)
		total_arrow += Catalog.upgrade_price("arrow", l)
		total_archer += Catalog.upgrade_price("character", l)
	
	var total_upgrades := total_bow + total_arrow + total_archer
	print("Total upgrades across 3 tracks (1->100): %d (expected 675720)" % total_upgrades)
	if total_upgrades != 675720:
		printerr("FAIL: Total upgrade price %d != 675720" % total_upgrades)
		quit(1)
		return

	# 3. Test stage rewards & total 1-star income
	var total_1star := 0
	var total_2star := 0
	var total_3star := 0
	var wallet := 500 # starting wallet
	var lowest_wallet := 500

	# Track step-by-step wallet balance along 1-star campaign with upgrades
	# Goals: [5,10,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,99,100]
	var goals := [5,10,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,99,100]
	var current_level := 1

	for ch in range(1, 21):
		var n := ch - 1
		var R: int = Catalog.stage_reward_base(ch)
		var expected_R: int = 600 + 180 * n + 36 * n * n
		if R != expected_R:
			printerr("FAIL: Chapter %d reward base %d != expected %d" % [ch, R, expected_R])
			quit(1)
			return

		var clear_1: int = Catalog.stage_clear_reward(ch, 1)
		var clear_2: int = Catalog.stage_clear_reward(ch, 2)
		var clear_3: int = Catalog.stage_clear_reward(ch, 3)
		var bonus: int = Catalog.chapter_clear_bonus(ch)

		total_1star += clear_1 * 5 + bonus
		total_2star += clear_2 * 5 + bonus
		total_3star += clear_3 * 5 + bonus

		# Simulate 5 stages clear
		for s in range(5):
			wallet += clear_1
		wallet += bonus

		# Upgrade to chapter goal
		var target_lvl: int = goals[n]
		while current_level < target_lvl:
			var cost: int = Catalog.upgrade_price("bow", current_level) + Catalog.upgrade_price("arrow", current_level) + Catalog.upgrade_price("character", current_level)
			wallet -= cost
			lowest_wallet = mini(lowest_wallet, wallet)
			current_level += 1

	print("Total 1-star income: %d (expected 810720)" % total_1star)
	if total_1star != 810720:
		printerr("FAIL: Total 1-star income %d != 810720" % total_1star)
		quit(1)
		return

	var final_wallet_1star: int = 500 + total_1star - total_upgrades
	var final_wallet_2star: int = 500 + total_2star - total_upgrades
	var final_wallet_3star: int = 500 + total_3star - total_upgrades

	print("1-star final wallet: %d (expected 135500)" % final_wallet_1star)
	print("2-star final wallet: %d (expected 304400)" % final_wallet_2star)
	print("3-star final wallet: %d (expected 473300)" % final_wallet_3star)
	print("Lowest pre-reward wallet in campaign: %d (reference target 360)" % lowest_wallet)

	if final_wallet_1star != 135500 or final_wallet_2star != 304400 or final_wallet_3star != 473300:
		printerr("FAIL: Final wallet totals mismatch")
		quit(1)
		return

	# 4. Test replay rewards rounded down to multiple of 10
	var rep_ch1_1: int = Catalog.stage_replay_reward(1, 1)
	var rep_ch1_2: int = Catalog.stage_replay_reward(1, 2)
	var rep_ch1_3: int = Catalog.stage_replay_reward(1, 3)
	print("Chapter 1 replays: 1-star=%d, 2-star=%d, 3-star=%d" % [rep_ch1_1, rep_ch1_2, rep_ch1_3])
	if rep_ch1_1 != 210 or rep_ch1_2 != 270 or rep_ch1_3 != 330:
		printerr("FAIL: Replay rewards for Chapter 1 do not match floor_to_10")
		quit(1)
		return

	print("SUCCESS: ALL REFERENCE ECONOMY CHECKS PASSED PERFECTLY!")
	quit(0)
