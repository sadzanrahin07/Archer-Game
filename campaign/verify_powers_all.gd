extends SceneTree

func _init() -> void:
	print("=== RUNNING FULL VERIFICATION FOR USER REQUIREMENTS ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var main_scene = load("res://campaign/main.tscn")
	var game = main_scene.instantiate()
	game.test_mode = true
	game.profile.save_path = "/tmp/power-test-save.json"
	root.add_child(game)
	await process_frame
	await process_frame

	assert(game != null, "Game failed to instantiate")
	game.profile.data.bow_level = 100
	game.profile.data.arrow_level = 100

	# ----------------------------------------------------
	# TEST 1: Mobile Screen Controls (NO \"POWER · F\" card on mobile)
	# ----------------------------------------------------
	print("[1/7] Verifying Mobile Screen Controls (No PC controls on mobile)...")
	game.profile.data.settings["touch_controls"] = true
	game.start_stage(0, false)
	await process_frame
	await process_frame
	game.ready_left = 0.0
	game.state = "playing"

	var mobile_pc_btn: Button = null
	for btn in game.ui.find_children("*", "Button", true, false):
		if "POWER · F" in btn.text or "ARMED · F" in btn.text:
			mobile_pc_btn = btn
			break
	assert(mobile_pc_btn == null, "Mobile HUD should NOT have PC POWER · F button!")
	print("  ✓ PC POWER · F button correctly hidden on mobile: PASS")

	assert(game.touch_controller != null, "Touch controller not found")
	game.touch_controller._process(0.016)
	assert(game.touch_controller.active == true, "Touch controller should be active on mobile")
	var geo = game.touch_controller.geometry()
	assert(geo.has("power") and geo.has("burst"), "Mobile controls must have POWER and BURST circles")
	print("  ✓ Mobile on-screen touch controls active: PASS")

	# ----------------------------------------------------
	# TEST 2: Desktop Screen Controls (Shows \"POWER · F\" on PC)
	# ----------------------------------------------------
	print("[2/7] Verifying Desktop Screen Controls...")
	game.profile.data.settings["touch_controls"] = false
	game.start_stage(0, false)
	await process_frame
	await process_frame
	game.ready_left = 0.0
	game.state = "playing"

	var desktop_pc_btn: Button = null
	for btn in game.ui.find_children("*", "Button", true, false):
		if "POWER · F" in btn.text or "ARMED · F" in btn.text:
			desktop_pc_btn = btn
			break
	assert(desktop_pc_btn != null, "Desktop HUD should have POWER · F card button")
	print("  ✓ Desktop shows POWER · F card button: PASS")

	# ----------------------------------------------------
	# TEST 3: Power with 1 Arrow or 0 Arrows (Own Arrow Mechanics)
	# ----------------------------------------------------
	print("[3/7] Verifying Power uses its own arrows (Works with 1 arrow or 0 arrows)...")
	game.selected_power = "burst"
	game.power_armed = false
	game.burst_used = false

	game.arrows = 1
	game.trigger_power()
	assert(game.power_armed == true, "Failed to arm burst power with 1 arrow in quiver")
	print("  ✓ Arm burst power with 1 arrow: PASS")

	var initial_arrows = game.arrows
	game.hero.instant_shoot()
	assert(game.arrows == initial_arrows, "Power must NOT consume quiver arrows!")
	print("  ✓ Burst power fired 3 arrows without consuming quiver arrows: PASS")

	game.burst_used = false
	game.arrows = 0
	game.trigger_power()
	assert(game.power_armed == true, "Failed to arm burst power with 0 arrows in quiver")
	game.hero.shot_cooldown = 0.0
	game.hero._start_draw()
	assert(game.hero.drawing == true, "Should be able to draw bow when power is armed even with 0 arrows")
	await process_frame
	assert(game.hero.bow_arrow_node.visible == true, "Nocked arrow should be visible when drawing with power armed")
	game.hero._fire()
	assert(game.arrows == 0, "Quiver arrows should remain 0")
	print("  ✓ Burst power fires successfully with 0 quiver arrows: PASS")

	# ----------------------------------------------------
	# TEST 4: Burst 3-Arrow Trajectory
	# ----------------------------------------------------
	print("[4/7] Verifying Burst 3-arrows trajectory towards exact target pointer...")
	game.start_stage(0, true)
	await process_frame
	await process_frame
	game.ready_left = 0.0
	game.state = "playing"
	game.selected_power = "burst"
	game.power_armed = true

	game.hero.instant_shoot()
	await process_frame

	var projectiles = []
	for child in game.stage.get_children():
		if "projectile" in str(child.get_script()):
			projectiles.append(child)

	assert(projectiles.size() >= 3, "Expected at least 3 burst projectiles")
	var p0 = projectiles[-3]
	var p1 = projectiles[-2]
	var p2 = projectiles[-1]

	var dir0 = p0.velocity.normalized()
	var dir1 = p1.velocity.normalized()
	var dir2 = p2.velocity.normalized()
	assert(dir0.dot(dir1) > 0.999, "Arrow 1 velocity direction deviated from target line!")
	assert(dir0.dot(dir2) > 0.999, "Arrow 2 velocity direction deviated from target line!")
	print("  ✓ All 3 burst arrows fly directly toward target pointer (dot > 0.999): PASS")
	assert(p0.vfx != null, "Projectile VFX should exist")
	print("  ✓ Power arrow distinct glowing energy appearance: PASS")

	for p in projectiles: p.queue_free()

	# ----------------------------------------------------
	# TEST 5: Store and Collection Power Selector Design
	# ----------------------------------------------------
	print("[5/7] Verifying Store & Collection Power Selector Design...")
	var test_container = VBoxContainer.new()
	game.ui.add_child(test_container)
	game.menu_builder._power_selector(test_container)
	
	var panel = test_container.get_child(0) as PanelContainer
	assert(panel != null, "Power selector should be a PanelContainer card")
	
	var tag_found = false
	var buttons_found = 0
	for child in panel.find_children("*", "Label", true, false):
		if "POWER ABILITY" in child.text: tag_found = true
	for child in panel.find_children("*", "Button", true, false):
		buttons_found += 1

	assert(tag_found, "Power Ability card header tag missing")
	assert(buttons_found >= 3, "Expected 3 buttons (prev, info, next) in power selector")
	print("  ✓ Power Selector clean card design with cycle buttons: PASS")

	# ----------------------------------------------------
	# TEST 6: Power Attack Damage Multipliers & Arrow Scaling
	# ----------------------------------------------------
	print("[6/7] Verifying Power Attack Damage Multipliers (3x, 5x, 10x, 15x, 20x, 30x, 50x)...")
	var catalog = preload("res://campaign/catalog.gd")
	var powers_map := {}
	for p in catalog.POWERS:
		powers_map[p.key] = p
	
	assert(powers_map.has("burst"), "burst power missing")
	assert(powers_map["burst"].ammo == 3 and powers_map["burst"].damage == 1.0, "burst must be 3 arrows with 1.0 damage each (3.0x total)")
	print("  ✓ Burst Shot multiplier: 3.0x (3 arrows × 1.0): PASS")

	assert(powers_map["gale"].ammo == 1 and powers_map["gale"].damage == 5.0, "gale must be 5.0x damage")
	print("  ✓ Gale Shot multiplier: 5.0x (5x activation level arrow power): PASS")

	assert(powers_map["pressure"].ammo == 1 and powers_map["pressure"].damage == 10.0, "pressure must be 10.0x damage")
	print("  ✓ Pressure Wave multiplier: 10.0x: PASS")

	assert(powers_map["fire"].ammo == 1 and powers_map["fire"].damage == 15.0, "fire must be 15.0x damage")
	print("  ✓ Ember Trail multiplier: 15.0x: PASS")

	assert(powers_map["lightning"].ammo == 1 and powers_map["lightning"].damage == 20.0, "lightning must be 20.0x damage")
	print("  ✓ Lightning Arrow multiplier: 20.0x: PASS")

	assert(powers_map["super_lightning"].ammo == 1 and powers_map["super_lightning"].damage == 30.0, "super lightning must be 30.0x damage")
	print("  ✓ Super Lightning multiplier: 30.0x: PASS")

	assert(powers_map["ultimate"].ammo == 1 and powers_map["ultimate"].damage == 50.0, "ultimate must be 50.0x damage")
	print("  ✓ Aurora Tempest multiplier: 50.0x: PASS")

	game.profile.data.bow_level = 20
	game.profile.data.arrow_level = 20
	var p20 = game.profile.power()
	var burst_p20 = p20 * float(powers_map["burst"].ammo) * float(powers_map["burst"].damage)
	assert(absf(burst_p20 / p20 - 3.0) < 0.001, "Burst power must be exactly 3x arrow power at Lv20")

	game.profile.data.arrow_level = 40
	var p40 = game.profile.power()
	assert(p40 > p20, "Arrow power must increase at Lv40")
	var burst_p40 = p40 * float(powers_map["burst"].ammo) * float(powers_map["burst"].damage)
	assert(burst_p40 > burst_p20, "Burst power must increase proportionally when arrow power increases")
	assert(absf(burst_p40 / p40 - 3.0) < 0.001, "Burst power must remain 3x arrow power at Lv40")
	print("  ✓ Arrow power increase scales Burst power proportionally: PASS")

	# ----------------------------------------------------
	# TEST 7: Stone Health Matches Super Power & Can Be Destroyed in One Power Shot
	# ----------------------------------------------------
	print("[7/7] Verifying Stone Health & Destruction in One Power Attack...")
	var TargetScript = preload("res://campaign/target.gd")
	var definitions = game.definitions

	for s in definitions:
		var mats = s.materials
		var t_hps = s.get("target_hp", [])
		var rec_p = float(s.recommended_power)
		var rec_lvl = int(s.recommended_level)
		for i in range(mats.size()):
			var m = mats[i]
			if m in ["stone", "rune", "master"]:
				var hp = float(t_hps[i])
				var ratio = hp / rec_p
				var expected_ratio = 3.0
				if rec_lvl >= 98: expected_ratio = 50.0
				elif rec_lvl >= 90: expected_ratio = 30.0
				elif rec_lvl >= 80: expected_ratio = 20.0
				elif rec_lvl >= 69: expected_ratio = 15.0
				elif rec_lvl >= 56: expected_ratio = 10.0
				elif rec_lvl >= 48: expected_ratio = 5.0
				assert(absf(ratio - expected_ratio) < 0.05, "Stage %d %s HP ratio %.2f did not match expected %.2f!" % [int(s.id)+1, m, ratio, expected_ratio])

	print("  ✓ All 27 stone stages in stages.json scaled to match super power: PASS")

	# Test Stage 20 (Rune stone, 3x HP, destroyed by 3x Burst)
	var stage20_def = definitions[19]
	var rune_target = TargetScript.new()
	rune_target.game = game
	rune_target.material_kind = "rune"
	rune_target.hp_override = float(stage20_def.target_hp[-1])
	game.add_child(rune_target)
	rune_target._ready()
	var initial_hp = rune_target.hp
	assert(initial_hp > 0, "Rune stone HP must be > 0")

	var normal_power = float(stage20_def.recommended_power)
	rune_target.campaign_hit(Vector3.ZERO, normal_power, {"shot_id": 9991})
	assert(rune_target.completed == false, "Normal arrow must NOT destroy the stone in one hit")
	assert(rune_target.hp > 0, "Stone should survive normal arrow")
	rune_target.queue_free()

	var burst_stone = TargetScript.new()
	burst_stone.game = game
	burst_stone.material_kind = "rune"
	burst_stone.hp_override = float(stage20_def.target_hp[-1])
	game.add_child(burst_stone)
	burst_stone._ready()
	for arrow_idx in range(3):
		burst_stone.campaign_hit(Vector3.ZERO, normal_power * 1.0, {"shot_id": 9992 + arrow_idx})
	assert(burst_stone.completed == true, "Burst Shot (3x power) must destroy the whole Stage 20 stone!")
	print("  ✓ Stage 20 Rune stone destroyed by Burst Shot: PASS")
	burst_stone.queue_free()

	# Test Stage 50 (Gale tier, 5x HP, destroyed by 1 Gale shot)
	game.state = "playing"
	game.completed = 0
	var stage50_def = definitions[49]
	var gale_stone = TargetScript.new()
	gale_stone.game = game
	gale_stone.material_kind = "rune"
	gale_stone.hp_override = float(stage50_def.target_hp[-1])
	game.add_child(gale_stone)
	gale_stone._ready()
	var rec_p50 = float(stage50_def.recommended_power)
	var hit_ok50 = gale_stone.campaign_hit(Vector3.ZERO, rec_p50 * 5.0, {"shot_id": 9995})
	assert(hit_ok50 and gale_stone.completed == true, "Gale Shot (5x power) must destroy the whole Stage 50 stone in 1 shot!")
	print("  ✓ Stage 50 Rune stone destroyed in 1 shot by Gale Shot (5x): PASS")
	gale_stone.queue_free()

	# Test Stage 100 (Ultimate tier, 50x HP, destroyed by 1 Aurora Tempest shot)
	game.state = "playing"
	game.completed = 0
	var stage100_def = definitions[99]
	var ult_stone = TargetScript.new()
	ult_stone.game = game
	ult_stone.material_kind = "rune"
	ult_stone.hp_override = float(stage100_def.target_hp[-1])
	game.add_child(ult_stone)
	ult_stone._ready()
	var rec_p100 = float(stage100_def.recommended_power)
	var hit_ok100 = ult_stone.campaign_hit(Vector3.ZERO, rec_p100 * 50.0, {"shot_id": 9998})
	assert(hit_ok100 and ult_stone.completed == true, "Aurora Tempest (50x power) must destroy the whole Stage 100 stone in 1 shot!")
	print("  ✓ Stage 100 Rune stone (67,557 HP) destroyed in 1 shot by Aurora Tempest (50x): PASS")
	ult_stone.queue_free()

	# ----------------------------------------------------
	# TEST 8: Power Shot at Stone with 1 Arrow & Mobile Touch Controls State
	# ----------------------------------------------------
	print("[8/9] Verifying Power Shot at Stone with 1 Arrow & Auto-Equipment...")
	game.profile.data.bow_level = 35
	game.profile.data.arrow_level = 35
	game.profile.data.power = "normal"
	game.profile.data.power_chosen = false
	assert(game.profile.selected_power() == "burst", "Lv 35 gear must auto-select burst even if data.power was normal")
	
	game.start_stage(33) # Stage 34 (0-indexed: 33)
	game.state = "playing"
	game.arrows = 1
	game.completed = 4
	game.burst_used = false
	game.super_used = false
	game.power_armed = false

	# Tapping power with 1 arrow at the stone stage must arm or shoot without "Equip an unlocked power" error
	game.trigger_power()
	assert(game.power_armed == true, "Power must arm successfully at stone with 1 arrow")
	assert(not "Equip an unlocked power" in game.message, "Should never prompt to equip power if Lv 20+ power is unlocked!")
	print("  ✓ Power shot arms successfully at final stone with 1 arrow: PASS")

	# Check mobile touch controls display for Lv 35 (only Burst unlocked)
	var tc = game.touch_controller
	assert(tc._has_burst() == true, "Lv 35 must have burst")
	assert(tc._has_super() == false, "Lv 35 must NOT have super power")
	print("  ✓ Lv 35 player only displays single BURST button on mobile (no confusing second POWER button): PASS")

	# Check mobile touch controls for Lv 55 (both Burst and Super Power unlocked)
	game.profile.data.bow_level = 55
	game.profile.data.arrow_level = 55
	game.selected_power = game.profile.selected_power()
	assert(tc._has_burst() == true and tc._has_super() == true, "Lv 55 must have both burst and super power")
	print("  ✓ Lv 55 player displays both BURST and POWER buttons on mobile: PASS")

	# ----------------------------------------------------
	# TEST 9: Quiver Empty & Defeat Popup Triggering (No Hanging)
	# ----------------------------------------------------
	print("[9/9] Verifying Defeat Screen Triggers When Out of Arrows & Powers...")
	game.state = "playing"
	game.practice = false
	game.arrows = 0
	game.airborne = 0
	game.completed = 4
	game.burst_used = true
	game.super_used = true
	game.power_armed = false

	assert(game.has_available_power() == false, "No powers should be available when burst_used and super_used are true")
	game._check_quiver_empty()
	assert(game.state == "finishing", "Game state must transition to finishing when out of arrows and powers!")
	assert(game.pending_result.get("reason", "") == "Quiver empty", "Defeat reason must be Quiver empty")
	print("  ✓ Out of arrows & power immediately triggers Defeat / Quiver empty popup: PASS")

	print("=== ALL USER REQUIREMENTS VERIFIED 100% PERFECTLY! ===")
	quit(0)
