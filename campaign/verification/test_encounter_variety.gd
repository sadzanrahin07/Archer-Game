extends SceneTree

const GameScene = preload("res://campaign/main.tscn")
var failures: Array[String] = []
var path_checks := 0

func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)

func _init() -> void: run.call_deferred()

func _segment_hits_hole(from: Vector2, to: Vector2, hole: Rect2) -> bool:
	var inside := hole.grow(-.025)
	if inside.has_point(from) or inside.has_point(to): return true
	var corners: Array[Vector2] = [inside.position, Vector2(inside.end.x, inside.position.y), inside.end, Vector2(inside.position.x, inside.end.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(from, to, corners[i], corners[(i + 1) % 4]) != null: return true
	return false

func _verify_path(stage: Node3D, from: Vector3, to: Vector3, label: String) -> void:
	var map: RID = stage.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	path_checks += 1
	check(path.size() >= 2 and path[path.size() - 1].distance_to(to) < .25, label + " has a complete walkable path")
	var distance := 0.0
	for i in range(path.size() - 1):
		distance += path[i].distance_to(path[i + 1])
		for hole in stage.combat_manager.encounter_layout.cover_bounds(stage):
			check(not _segment_hits_hole(Vector2(path[i].x, path[i].z), Vector2(path[i + 1].x, path[i + 1].z), hole), label + " routes around physical cover")
	check(distance <= from.distance_to(to) * 2.25 + 8.0, label + " uses a practical route without a distant boundary detour")

func _freeze(game: Node) -> void:
	game.set_process(false); game.hero.set_physics_process(false)
	game.stage.combat_manager.set_physics_process(false)
	for enemy in game.stage.combat_manager.enemies_alive: enemy.set_physics_process(false)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game = GameScene.instantiate(); game.test_mode = true; root.add_child(game)
	await process_frame
	game.profile.data.bow_level = 100; game.profile.data.arrow_level = 100; game.profile.data.character_level = 100
	var patterns := {}
	for id in range(55, 99):
		game.start_stage(id, true); _freeze(game)
		await process_frame; await physics_frame; await physics_frame
		var map: RID = game.stage.get_world_3d().navigation_map
		var region_rid: RID = game.stage.combat_manager.encounter_layout.navigation_region.get_rid()
		for sync_frame in range(30):
			if NavigationServer3D.map_get_closest_point_owner(map, game.stage.spawn) == region_rid: break
			await physics_frame
		check(NavigationServer3D.map_get_closest_point_owner(map, game.stage.spawn) == region_rid, "ID%d current region synchronized" % id)
		var stage = game.stage; var manager = stage.combat_manager
		check(stage.targets.is_empty(), "ID%d remains enemy only" % id)
		check(not patterns.has(manager.encounter_layout.pattern), "ID%d has a distinct authored pattern" % id)
		patterns[manager.encounter_layout.pattern] = true
		var expected := 0
		for wave in stage.definition.enemy_waves: expected += wave.size()
		check(manager.total_enemies_expected == expected, "ID%d preserves authored population" % id)
		check(manager.enemies_alive.size() + manager.pending_arrivals.size() == stage.definition.enemy_waves[0].size(), "ID%d queues every first-wave enemy exactly once" % id)
		if id < 85: check(expected == (id - 55) % 5 + 1, "ID%d family progression remains one through five" % id)
		var supply: Vector3 = manager.supply_anchor.global_position
		_verify_path(stage, stage.spawn, supply, "ID%d spawn-to-supply" % id)
		for w in range(manager.authored_waves.size()):
			for e in range(manager.authored_waves[w].size()):
				var entrance: Vector3 = stage.spawn + manager.authored_waves[w][e].pos; entrance.y = stage.spawn.y
				_verify_path(stage, entrance, supply, "ID%d entrance%d/%d-to-supply" % [id, w, e])
				_verify_path(stage, entrance, stage.spawn + Vector3(0, 0, -18), "ID%d entrance%d/%d-to-far-lane" % [id, w, e])
		for body in manager.encounter_layout.cover_bodies:
			var origin: Vector3 = body.global_position + Vector3(-3, 1, 0)
			var end: Vector3 = body.global_position + Vector3(3, 1, 0)
			var hit: Dictionary = stage.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 1))
			check(not hit.is_empty() and hit.collider == body, "ID%d root cover blocks real terrain rays" % id)
	# Exercise a live staged entrance and the exact manager used by the scenes.
	game.start_stage(56, true); _freeze(game); await process_frame
	var manager = game.stage.combat_manager
	check(manager.enemies_alive.size() == 1 and manager.pending_arrivals.size() == 1, "Split entrance initially shows one creature and one marked gate")
	var record: Dictionary = manager.pending_arrivals[0]
	check(record.marker.get_node("Countdown").text.contains("1.8s"), "Entrance has a readable countdown before activation")
	var delay: float = record.delay
	game.state = "paused"; manager._physics_process(5)
	check(manager.pending_arrivals.size() == 1 and is_equal_approx(manager.pending_arrivals[0].delay, delay), "Pause freezes entrance countdown and population")
	game.state = "playing"; manager._physics_process(.8)
	check(manager.pending_arrivals.size() == 1 and is_equal_approx(manager.pending_arrivals[0].delay, 1.0), "Playing advances the visible entrance clock")
	game.hero.global_position = record.marker.global_position; manager._physics_process(1.1)
	check(manager.pending_arrivals.size() == 1 and record.marker.get_node("Countdown").text.contains("STEP CLEAR"), "Gate does not materialize a creature on the player")
	game.hero.position = game.stage.spawn; manager._physics_process(.01)
	check(manager.enemies_alive.size() == 2 and manager.pending_arrivals.is_empty(), "Cleared marked gate produces its exact authored creature")
	for enemy in manager.enemies_alive: enemy.set_physics_process(false)
	# Finishing visible creatures cannot finish a stage with future entrances.
	game.start_stage(58, true); _freeze(game); await process_frame; game.state = "playing"
	manager = game.stage.combat_manager
	var first = manager.enemies_alive[0]
	first.campaign_hit(first.global_position, 99999, {})
	check(not manager.completed and manager.wave_wait == 0 and manager.pending_arrivals.size() == 3, "Relay cannot win or advance while three marked arrivals remain")
	var guard := 0
	while not manager.completed and guard < 40:
		guard += 1; manager._physics_process(1)
		for enemy in manager.enemies_alive.duplicate():
			enemy.set_physics_process(false); enemy.campaign_hit(enemy.global_position, 99999, {})
		await process_frame
	check(manager.completed and manager.enemies_killed == 4 and manager.pending_arrivals.is_empty(), "Relay completes exactly after all four real creatures are defeated")
	# The first zero-delay entrance of a new wave must obey the same clearance rule.
	game.start_stage(85, true); _freeze(game); await process_frame; game.state = "playing"
	manager = game.stage.combat_manager
	var next_entrance: Vector3 = game.stage.spawn + manager.authored_waves[1][0].pos
	game.hero.global_position = next_entrance
	for enemy in manager.enemies_alive.duplicate(): enemy.campaign_hit(enemy.global_position, 99999, {})
	manager._physics_process(1.21)
	var held_immediate := false
	for arrival in manager.pending_arrivals:
		if arrival.marker.global_position.is_equal_approx(next_entrance):
			held_immediate = arrival.marker.get_node("Countdown").text.contains("STEP CLEAR")
	check(manager.wave_index == 2 and held_immediate, "A new wave's zero-delay entrance waits when occupied by the player")
	for enemy in manager.enemies_alive:
		check(enemy.global_position.distance_to(game.hero.global_position) >= 2.5, "A new wave never materializes on the hero")
	game.hero.global_position = game.stage.spawn; manager._physics_process(.01)
	var released_immediate := false
	for enemy in manager.enemies_alive:
		enemy.set_physics_process(false)
		if enemy.global_position.is_equal_approx(next_entrance): released_immediate = true
	check(released_immediate, "Stepping clear releases the held zero-delay entrance once")
	check(patterns.size() == 44, "All 44 regular combat encounters are authored")
	print("ENCOUNTER VARIETY CHECKS: ", "PASS" if failures.is_empty() else failures, " · walkable paths: ", path_checks)
	game.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
