extends SceneTree

const GameScene = preload("res://campaign/main.tscn")
const BossScript = preload("res://campaign/combat/hollow_crown.gd")
const ProjectileScript = preload("res://campaign/projectile.gd")
var failures: Array[String] = []
var game: Node3D
var boss: CharacterBody3D
var hero: CharacterBody3D
var boss_origin := Vector3.ZERO
var shot_sequence := 8000

func _init() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

# Advance the real actor and real hazard scripts with one deterministic clock.
# No await/timer is used by combat decisions, and no player save is loaded.
func step(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.00001:
		var delta := minf(0.025, remaining)
		boss._physics_process(delta)
		for hazard in boss.danger_nodes.duplicate():
			if is_instance_valid(hazard) and not hazard.is_queued_for_deletion():
				hazard.set_physics_process(false)
				hazard._physics_process(delta)
		remaining -= delta

func face_boss() -> void:
	hero.camera.global_position = hero.global_position + Vector3(0, 1.6, 1.0)
	hero.camera.look_at(boss.global_position + Vector3(0, 2.2, 0))
	hero.camera.fov = 40.0

func reset_closed(phase: int, health: float, offset: Vector3) -> void:
	boss._clear_danger()
	boss.global_position = boss_origin
	hero.global_position = boss_origin + offset
	hero.current_hp = 160.0
	hero.is_invulnerable = false
	hero.is_dodging = false
	boss.hp = health
	boss.recent_attacks.clear()
	boss.attack_cooldowns = {"thorn": 0.0, "ground": 0.0, "ring": 0.0}
	boss.dodge_cooldown = 0.0
	boss._enter_state(phase)
	face_boss()

func fire_at(point: Vector3, power_key: String, draw: float) -> void:
	shot_sequence += 1
	var arrow = ProjectileScript.new()
	arrow.game = game
	arrow.owner_body = hero
	arrow.shot_id = shot_sequence
	arrow.score_id = "boss-v3-%d" % shot_sequence
	arrow.power = 10000.0
	arrow.ability = {"key": power_key, "draw_ratio": draw, "damage": 1.0}
	game.stage.add_child(arrow)
	arrow.set_physics_process(false)
	arrow.global_position = point + Vector3(0, 0, 3)
	arrow.velocity = Vector3(0, 0, -70)
	arrow._physics_process(0.06)
	check(not arrow.flying, "Actual swept arrow must contact the boss collision")
	arrow.queue_free()

func run() -> void:
	root.size = Vector2i(1280, 720)
	game = GameScene.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.profile.data.bow_level = 100
	game.profile.data.arrow_level = 100
	game.profile.data.character_level = 100
	game.start_stage(99, true)
	await process_frame
	game.state = "playing"
	game.set_process(false)
	hero = game.hero
	hero.set_physics_process(false)
	boss = game.stage.combat_manager.boss
	boss.set_physics_process(false)
	boss_origin = boss.global_position
	check(game.profile.save_path.begins_with("/tmp/"), "Integration test uses an isolated profile path")
	check(is_equal_approx(boss.max_hp, 1476.0), "Boss keeps authored HP rather than inflating difficulty")

	reset_closed(BossScript.State.P1_CLOSED, 1476.0, Vector3(0, 0, 14))
	await physics_frame
	step(0.725)
	check(boss.attack_kind == "thorn" and boss.attack_phase == "telegraph", "Distant player receives a committed ranged tell")
	check(boss.intent_label.visible and "STEPS" in boss.intent_label.text, "Lateral evasion announces its direction above the boss")
	var start_x: float = boss.global_position.x
	var goal: float = boss.dodge_goal_x
	var committed: Vector3 = boss.attack_target
	boss.campaign_hit(boss.global_position, 1.0, {"shot_id": 67001})
	check(boss.global_position.x == start_x and boss.dodge_goal_x == goal, "An incoming hit cannot trigger an instant evade or change its chosen lane")
	step(0.2)
	check(is_equal_approx(boss.global_position.x, start_x), "Crown stays planted through its evade warning")
	var warning: float = boss.dodge_warning_remaining
	var attack_clock: float = boss.attack_clock
	var cooldown: float = boss.dodge_cooldown
	game.state = "paused"
	step(1.0)
	check(boss.dodge_warning_remaining == warning and boss.attack_clock == attack_clock and boss.dodge_cooldown == cooldown and boss.global_position.x == start_x, "Pause freezes intent, movement, and cooldown clocks")
	game.state = "playing"
	step(0.2)
	check(is_equal_approx(boss.global_position.x, start_x), "At least 0.4 seconds of announced warning precedes movement")
	hero.global_position.x += 5.0
	step(0.4)
	check(absf(boss.global_position.x - start_x) > 0.5 and absf(boss.global_position.x - start_x) <= 1.56, "Announced evade physically traverses a bounded lateral step")
	check(boss.attack_target == committed, "Moving during the tell does not drag the attack target")
	step(0.3)
	check(boss.attack_phase == "recover" and boss.danger_nodes.size() == 1, "Windup releases a real projectile before recovery")
	if not boss.danger_nodes.is_empty():
		var thorn = boss.danger_nodes[0]
		check(thorn.get_script() == preload("res://campaign/combat/enemy_seed.gd") and thorn.damage == 18, "Ranged pattern creates the authored damaging seed")

	# Returning to a closed state cannot bypass the evade's five-second budget.
	boss._clear_danger()
	boss.recent_attacks.clear()
	boss.attack_cooldowns["thorn"] = 0.0
	boss._enter_state(BossScript.State.P1_CLOSED)
	face_boss()
	step(0.725)
	check(boss.attack_kind == "thorn" and boss.dodge_time_remaining == 0.0, "A second ranged tell respects the active evade cooldown")
	boss._clear_danger()
	boss._enter_state(BossScript.State.P1_OPEN)
	var open_position: Vector3 = boss.global_position
	step(1.0)
	check(boss.is_core_exposed and boss.global_position == open_position and boss.dodge_time_remaining == 0.0 and boss.danger_nodes.is_empty(), "Core opening stays stationary and cannot spawn attacks or evades")

	# Range and recent behavior must change actual emitted patterns.
	reset_closed(BossScript.State.P2_CLOSED, boss.GATE_70, Vector3(0, 0, 4))
	await physics_frame
	step(0.725)
	check(boss.attack_kind == "ring", "Closing to melee range selects the phase-two root wave")
	check(boss.danger_nodes.size() == 1 and boss.intent_label.visible and "DODGE" in boss.intent_label.text, "Root wave has a visible direction-independent dodge tell")
	check(hero.camera.is_position_in_frustum(boss.intent_label.global_position), "Close-range intent remains inside the narrow aimed camera")
	var ring = boss.danger_nodes[0]
	check(ring.warning >= 1.3 and ring.kind == "ring", "Ring receives a readable warning before its real expanding hit")
	step(2.3)
	check(hero.current_hp == 140.0, "Real expanding ring hits a stationary nearby player exactly once for 20")
	check(boss.attack_phase == "wait" and boss.danger_nodes.size() == 1, "A live wave blocks the next attack rather than stacking hazards")
	for _i in range(70):
		if boss.attack_kind == "ground" and boss.attack_phase == "telegraph":
			break
		step(0.05)
	check(boss.attack_kind == "ground" and boss.attack_phase == "telegraph", "Recent ring repetition changes the next close-range attack to marked roots")
	var ground = boss.danger_nodes[0]
	var marked_position: Vector3 = ground.global_position
	hero.global_position.x += 4.0
	face_boss()
	step(1.6)
	check(ground.is_queued_for_deletion() and hero.current_hp == 140.0 and marked_position.x != hero.global_position.x, "Leaving the marked roots avoids their real 22-damage strike")
	for _i in range(80):
		if boss.is_core_exposed:
			break
		step(0.1)
	check(boss.current_state == BossScript.State.P2_OPEN and boss.recoveries_completed == 2 and boss.danger_nodes.is_empty(), "Two resolved patterns guarantee a clear core opening")
	open_position = boss.global_position
	step(3.9)
	check(boss.is_core_exposed and boss.global_position == open_position, "Full authored core window remains available for aimed bow shots")

	# Long-range patterns must reach legal arena positions, and a rim cannot force an offscreen sidestep.
	reset_closed(BossScript.State.P2_CLOSED, boss.GATE_70, Vector3(15, 0, 20))
	boss.dodge_cooldown = 5.0
	await physics_frame
	step(0.725)
	check(boss.attack_kind == "thorn", "Far range selects a reachable projectile instead of an inert short ring")
	step(1.1)
	var distant_thorn = boss.danger_nodes[0]
	check(distant_thorn.max_life > 2.5 and distant_thorn.max_life <= 4.5, "Distant thorn lifetime reaches its target with a bounded active duration")
	step(2.6)
	check(hero.current_hp == 142.0, "Real distant thorn travels through the arena and damages the player")
	reset_closed(BossScript.State.P1_CLOSED, 1476.0, Vector3(0, 0, 14))
	boss.global_position.x = boss.lateral_limits.y - 0.05
	face_boss()
	step(0.725)
	check(boss.dodge_goal_x >= boss.lateral_limits.x and boss.dodge_goal_x <= boss.lateral_limits.y, "Edge evasion commits inside arena and local lateral bounds")
	if boss.dodge_time_remaining > 0.0:
		var endpoint := Vector3(boss.dodge_goal_x, boss.global_position.y + 2.2, boss.global_position.z)
		var projected: Vector2 = hero.camera.unproject_position(endpoint)
		check(hero.camera.get_viewport().get_visible_rect().grow(-56).has_point(projected), "Evade destination remains visible through the narrow aimed camera")
	step(0.9)
	check(boss.global_position.x >= boss.lateral_limits.x and boss.global_position.x <= boss.lateral_limits.y and is_equal_approx(boss.global_position.z, boss_origin.z), "Real edge sidestep keeps the boss inside its collision-safe lane")
	reset_closed(BossScript.State.P1_CLOSED, 1476.0, Vector3(0, 0, 14))
	hero.camera.look_at(hero.camera.global_position + Vector3(0, 0, 5))
	step(1.0)
	check(boss.attack_phase == "telegraph" and boss.intent_label.visible, "Turning the camera cannot freeze the boss; fixed HUD receives its warned attack intent")
	face_boss()
	step(0.2)
	check(boss.attack_phase == "telegraph", "Camera reorientation preserves the active warning instead of resetting it")

	# Existing gates, safe rearm, and direct fully-drawn Aurora finisher remain live.
	reset_closed(BossScript.State.P1_CLOSED, 1476.0, Vector3(0, 0, 14))
	await physics_frame
	fire_at(boss.global_position + Vector3(0, 0.8, 0), "normal", 1.0)
	check(is_equal_approx(boss.hp, boss.GATE_70) and boss.current_state == BossScript.State.TRANSITION_70, "Real overflow arrow clamps at 70 percent")
	step(1.05)
	fire_at(boss.global_position + Vector3(0, 0.8, 0), "normal", 1.0)
	check(is_equal_approx(boss.hp, boss.GATE_35), "Real overflow arrow clamps at 35 percent")
	step(1.05)
	fire_at(boss.global_position + Vector3(0, 0.8, 0), "normal", 1.0)
	check(is_equal_approx(boss.hp, boss.GATE_10) and boss.rearm_well_active, "Real overflow arrow preserves the 10-percent rearm gate")
	game.arrows = 0
	game.focus_meter = 0
	step(2.0)
	check(boss.danger_nodes.is_empty() and boss.pattern_count == 0, "Active rearm well stays safe while the player refills")
	check(boss.collect_rearm_well(hero) and game.arrows >= 6 and game.focus_meter == 100, "Final rearm safely restores arrows and Focus")
	face_boss()
	for _i in range(400):
		if boss.current_state == BossScript.State.FINAL_OPEN:
			break
		step(0.1)
	check(boss.current_state == BossScript.State.FINAL_OPEN and boss.recoveries_completed == 2, "Final rearm earns its real clear opening through two resolved patterns")
	await physics_frame
	fire_at(boss.core_col.global_position, "normal", 1.0)
	check(is_equal_approx(boss.hp, boss.GATE_10), "Actual normal core arrow cannot finish the final gate")
	fire_at(boss.core_col.global_position, "ultimate", 0.8)
	check(is_equal_approx(boss.hp, boss.GATE_10), "Actual partial-draw Aurora cannot finish the final gate")
	for mastery in ["bow_level", "arrow_level", "character_level"]:
		game.profile.data[mastery] = 99
		fire_at(boss.core_col.global_position, "ultimate", 1.0)
		check(is_equal_approx(boss.hp, boss.GATE_10), "Actual Aurora requires mastery 100 for " + mastery)
		game.profile.data[mastery] = 100
	step(4.25)
	check(boss.current_state == BossScript.State.FINAL_REARM and boss.rearm_well_active and boss.missed_openings == 1, "Missed final opening returns to the safe rearm cycle")
	boss.collect_rearm_well(hero)
	for _i in range(400):
		if boss.current_state == BossScript.State.FINAL_OPEN:
			break
		step(0.1)
	await physics_frame
	fire_at(boss.core_col.global_position, "ultimate", 1.0)
	check(boss.completed and boss.hp == 0.0 and boss.current_state == BossScript.State.DEAD, "Actual direct charged Aurora projectile redeems the boss at B=A=C=100")
	print("BOSS INTELLIGENCE V3: ", "PASS" if failures.is_empty() else failures)
	game.stop_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
