extends SceneTree

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("FAIL: " + message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://campaign/game.gd").new()
	game.test_mode = true
	game.profile.save_path = "/tmp/archer-engagement-test.json"
	root.size = Vector2i(1280, 720)
	root.add_child(game)
	for i in range(2): await physics_frame

	game._spawn_hero()
	game.start_stage(0, true) # Practice mode
	game.state = "playing"
	game.arrows = 999
	for i in range(3): await physics_frame

	var TargetScript = preload("res://campaign/target.gd")
	var ProjectileScript = preload("res://campaign/projectile.gd")

	print("=== TESTING SIGNATURE MECHANIC 1: WAKING TARGETS (RISING BOARDS) ===")
	game.state = "playing"
	var rising_target = TargetScript.new()
	rising_target.game = game
	rising_target.material_kind = "rising"
	rising_target.index = 10
	game.stage.add_child(rising_target)
	game.stage.targets.append(rising_target)
	for i in range(2): await physics_frame

	check(rising_target.is_rising, "Target recognized as rising target")
	check(is_instance_valid(rising_target.board_pivot), "Board pivot created for rising animation")
	check(is_instance_valid(rising_target.hinge_glow), "Amber hinge glow created")
	check(is_instance_valid(rising_target.cue_icon), "Exclamation cue icon created")

	# 1. Test REST state
	rising_target._set_rising_state(rising_target.RisingState.REST)
	check(not rising_target.active, "Rising target is inactive in REST state")
	check(not rising_target.can_receive_hit(), "Cannot receive hit while resting flat")
	var hit_rest: bool = rising_target.campaign_hit(rising_target.global_position, 10.0, {"shot_id": 101})
	check(not hit_rest, "Hit rejected during REST")
	check(game.message == "Wait for the rise!", "Feedback displays 'Wait for the rise!' on early shot")

	# 2. Test CUE state
	rising_target._set_rising_state(rising_target.RisingState.CUE)
	check(not rising_target.active, "Rising target is inactive during CUE")
	check(rising_target.hinge_glow.visible, "Hinge glow is visible during CUE")
	check(rising_target.cue_icon.visible, "Cue '!' icon is visible during CUE")
	var hit_cue: bool = rising_target.campaign_hit(rising_target.global_position, 10.0, {"shot_id": 102})
	check(not hit_cue, "Hit rejected during CUE warning window")

	# 3. Test EXPOSED state
	rising_target._set_rising_state(rising_target.RisingState.EXPOSED)
	check(rising_target.active, "Rising target is active when fully EXPOSED")
	check(rising_target.can_receive_hit(), "Can receive hit when EXPOSED")
	check(not rising_target.hinge_glow.visible, "Hinge glow turns off when upright")
	check(not rising_target.cue_icon.visible, "Cue icon turns off when upright")

	# 4. Shoot and destroy exposed rising board
	var center_pos: Vector3 = rising_target.global_position + Vector3(0, 0, 0.15)
	var hit_exposed: bool = rising_target.campaign_hit(center_pos, 10.0, {"shot_id": 103})
	check(hit_exposed, "Hit accepted when board is upright")
	check(rising_target.completed, "Rising target completed after hit")
	rising_target.queue_free()
	print("RISING BOARDS PASS")

	print("=== TESTING SIGNATURE MECHANIC 2: THREAD SHOT LANES (PIERCING ORBS) ===")
	game.state = "playing"
	game.arrows = 999
	game.completed = 0
	game.current_definition = {"materials": ["soft_orb", "soft_orb", "soft_orb"], "mode": "precision", "seconds": 60, "chapter": "The Grove"}
	var orbs: Array = []
	for i in range(3):
		var orb = TargetScript.new()
		orb.game = game
		orb.material_kind = "soft_orb"
		orb.index = 20 + i
		# Place orbs directly along negative Z axis in front of spawn
		orb.position = Vector3(0, 7.15, 8.0 - i * 2.5)
		game.stage.add_child(orb)
		game.stage.targets.append(orb)
		orbs.append(orb)
	for i in range(3): await physics_frame

	for orb in orbs:
		check(orb.is_pierceable, "Soft orb recognized as pierceable")
		check(orb.active, "Soft orb starts active")

	# Spawn projectile directly targeting along the line of 3 orbs
	var arrow = ProjectileScript.new()
	arrow.game = game
	arrow.power = 10.0
	arrow.shot_id = 999
	arrow.score_id = "thread_test"
	game.stage.add_child(arrow)
	arrow.global_position = Vector3(0, 7.15, 10.0)
	arrow.velocity = Vector3(0, 0.2, -35.0) # Flat piercing trajectory

	# Simulate physics frames for arrow to travel through all 3 orbs
	for frame in range(50):
		await physics_frame
		if orbs[0].completed and orbs[1].completed and orbs[2].completed:
			break

	check(orbs[0].completed, "First soft orb pierced and destroyed")
	check(orbs[1].completed, "Second soft orb pierced and destroyed")
	check(orbs[2].completed, "Third soft orb pierced and destroyed")
	check(arrow.pierced_count >= 3, "Arrow pierced all 3 orbs in single flight (count=%d)" % arrow.pierced_count)
	for orb in orbs: orb.queue_free()
	if is_instance_valid(arrow): arrow.queue_free()
	print("THREAD SHOT LANES PASS")

	print("=== TESTING SUPPORTING MECHANICS: HANGING PENDULUMS ===")
	game.state = "playing"
	var pendulum = TargetScript.new()
	pendulum.game = game
	pendulum.material_kind = "pendulum"
	pendulum.position = Vector3(0, 5.7, 0.0)
	game.stage.add_child(pendulum)
	game.stage.targets.append(pendulum)
	for i in range(2): await physics_frame

	check(pendulum.is_pendulum, "Recognized as pendulum target")
	check(is_instance_valid(pendulum.suspension_mount), "Pendulum overhead suspension mount built")
	var init_pos: Vector3 = pendulum.position
	for frame in range(30):
		pendulum._physics_process(0.05)
	check(pendulum.position != init_pos, "Pendulum swings dynamically in physics loop")
	pendulum.queue_free()
	print("HANGING PENDULUMS PASS")

	print("=== TESTING SUPPORTING MECHANICS: ARMOR PETALS & MONOLITH ===")
	game.state = "playing"
	var monolith = TargetScript.new()
	monolith.game = game
	monolith.material_kind = "armor_petals"
	monolith.hp_override = 80.0
	game.stage.add_child(monolith)
	game.stage.targets.append(monolith)
	for i in range(2): await physics_frame

	check(monolith.is_armor_petals, "Recognized as multi-phase armor monolith")
	check(monolith.petals.size() == 3, "Monolith spawned with 3 protective armor petals")
	check(monolith.petals_remaining == 3, "3 petals intact initially")
	check(not monolith.core_exposed, "Core sealed behind armor petals")

	# Shatter petal 1
	var p1_pos: Vector3 = monolith.petals[0].global_position
	var hit_p1 := monolith.campaign_hit(p1_pos, 10.0, {"shot_id": 201})
	check(hit_p1, "Petal 1 hit accepted")
	check(monolith.petals_remaining == 2, "Petal 1 shattered, 2 petals remaining")
	check(not monolith.completed, "Monolith not destroyed while petals remain")

	# Shatter petal 2
	var p2_pos: Vector3 = monolith.petals[1].global_position
	var hit_p2 := monolith.campaign_hit(p2_pos, 10.0, {"shot_id": 202})
	check(hit_p2, "Petal 2 hit accepted")
	check(monolith.petals_remaining == 1, "Petal 2 shattered, 1 petal remaining")

	# Shatter petal 3
	var p3_pos: Vector3 = monolith.petals[2].global_position
	var hit_p3 := monolith.campaign_hit(p3_pos, 10.0, {"shot_id": 203})
	check(hit_p3, "Petal 3 hit accepted")
	check(monolith.petals_remaining == 0, "All 3 petals shattered")
	check(monolith.core_exposed, "Inner core exposed!")

	# Destroy exposed core with center shot
	var core_pos: Vector3 = monolith.global_position + Vector3(0, 0.2, 0.35)
	var hit_core := monolith.campaign_hit(core_pos, 80.0, {"shot_id": 204})
	check(hit_core, "Core hit accepted")
	check(monolith.completed, "Monolith completely broken after core hit")
	monolith.queue_free()
	print("ARMOR PETALS & CORE PASS")

	print("=== TESTING LANDSCAPE RESTORATION EVENT ===")
	game.selected_stage = 4 # Stage 5 (Chapter 1 finale)
	# Trigger restoration event directly on the active stage
	game._play_restoration_event(Vector3(0, 5.7, 0))
	await process_frame

	var found_particles := false
	var found_flowers := false
	for child in game.stage.get_children():
		if child is CPUParticles3D:
			found_particles = true
		elif child is MeshInstance3D and child.scale == Vector3.ZERO:
			found_flowers = true
	check(found_particles, "Landscape restoration spawned particles")
	check(found_flowers, "Landscape restoration spawned blooming flowers")
	print("LANDSCAPE RESTORATION PASS")

	game.stop_audio()
	game.queue_free()
	await process_frame

	print("
============================================================")
	print("ALL ENGAGEMENT PROPOSAL MECHANICS: ", "PASS" if failures.is_empty() else failures)
	print("============================================================")
	quit(0 if failures.is_empty() else 1)
