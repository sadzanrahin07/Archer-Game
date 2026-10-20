extends Node3D
var arrow_id := 0
var mesh_path := "res://models/arrow_mesh.res"
var velocity := Vector3.ZERO
var power := 10.0
var wind := 0.0
var owner_body: CollisionObject3D
var game: Node
var age := 0.0
var flying := true
var shot_id := -1
var score_id := ""
var ability: Dictionary = {"key": "normal", "secondary": 0.0, "chains": 0, "rank": 1}
var vfx: Node3D
var trail_started := false
var pierced_count := 0
var excluded_rids: Array[RID] = []

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var key: String = str(ability.get("key", "normal"))
	if key != "normal":
		# Distinct glowing energy power arrow
		mesh.mesh = load("res://models/arrow_mesh.res")
		var bounds := mesh.mesh.get_aabb(); var width_scale := minf(.8, .095 / maxf(bounds.size.x, bounds.size.z))
		mesh.scale = Vector3(width_scale, 1.0 / bounds.size.y, width_scale); mesh.rotation.x = -PI / 2; mesh.position.z = bounds.end.y * mesh.scale.y; add_child(mesh)
		var power_mat := StandardMaterial3D.new()
		power_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var p_color: Color = {
			"burst": Color("45f5a8"),
			"gale": Color("81eeff"),
			"pressure": Color("b3f7ff"),
			"fire": Color("ff7b39"),
			"lightning": Color("ecfff9"),
			"super_lightning": Color("c59dff"),
			"ultimate": Color("ffedb5")
		}.get(key, Color("a0ede5"))
		power_mat.albedo_color = p_color
		power_mat.emission_enabled = true
		power_mat.emission = p_color
		power_mat.emission_energy_multiplier = 2.2
		mesh.material_override = power_mat
	else:
		mesh.mesh = load(mesh_path)
		preload("res://campaign/catalog.gd").apply_arrow_finish(mesh, arrow_id)
		var bounds := mesh.mesh.get_aabb(); var width_scale := minf(.8, .085 / maxf(bounds.size.x, bounds.size.z))
		mesh.scale = Vector3(width_scale, 1.0 / bounds.size.y, width_scale); mesh.rotation.x = -PI / 2; mesh.position.z = bounds.end.y * mesh.scale.y; add_child(mesh)

	if key in ["lightning", "super_lightning", "ultimate"]: mesh.visible = false
	vfx = preload("res://campaign/power_vfx.gd").new(); vfx.projectile = self; add_child(vfx)

func _physics_process(delta: float) -> void:
	if not flying: return
	if game.state not in ["playing", "finishing"]: return
	age += delta
	if age > 8: _resolve(); return
	wind = game.current_wind()
	var acceleration := Vector3(wind, -9.8, 0)
	var next: Vector3 = global_position + velocity * delta + .5 * acceleration * delta * delta
	velocity += acceleration * delta

	# Predict the final contact along the same trajectory for presentation only.
	if not trail_started:
		var prediction := PhysicsRayQueryParameters3D.create(global_position, global_position + velocity * .40 + .5 * acceleration * .16, 1 | 4)
		prediction.exclude = ([owner_body.get_rid()] if is_instance_valid(owner_body) else []) + excluded_rids
		var ahead: Dictionary = get_world_3d().direct_space_state.intersect_ray(prediction)
		if not ahead.is_empty() and ahead.collider.has_method("would_be_destroyed"):
			game.maybe_follow_final(self, ahead.collider, ahead.position)
			trail_started = game.final_director.is_active()

	var query := PhysicsRayQueryParameters3D.create(global_position, next, 1 | 4); query.hit_from_inside = true
	query.exclude = ([owner_body.get_rid()] if is_instance_valid(owner_body) else []) + excluded_rids

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	while not hit.is_empty():
		var col = hit.collider
		if col.has_method("campaign_hit") and bool(col.get("is_pierceable")):
			# Soft orb / Thread Shot target pierced!
			pierced_count += 1
			game.max_thread_chain=maxi(game.max_thread_chain,pierced_count)
			excluded_rids.append(col.get_rid())
			game.current_shot_id = score_id
			game.last_hit_position = hit.position
			var accepted: bool = col.campaign_hit(hit.position, power, {"shot_id": shot_id, "pierce": true, "pierced_count": pierced_count})

			# Ascending chime pitch for consecutive threaded hits: C, E, G, C
			var pitch: float = 1.0 + float(pierced_count - 1) * 0.25
			if game.has_method("play_stream"):
				game.play_stream("res://campaign/audio/crystal_orb.wav", pitch)
			elif game.has_method("play_sound"):
				game.play_sound("res://campaign/audio/crystal_orb.wav", pitch)

			if is_instance_valid(vfx): vfx.impact(hit.position, game.stage)
			if pierced_count >= 2:
				game.feedback("★ Thread Shot · %d in 1 Arrow!" % pierced_count)

			# Advance past this target and continue raycast towards next
			var advance_origin: Vector3 = hit.position + velocity.normalized() * 0.35
			global_position = advance_origin
			if advance_origin.distance_to(next) < 0.15:
				break
			query.from = advance_origin
			query.to = next
			query.exclude = ([owner_body.get_rid()] if is_instance_valid(owner_body) else []) + excluded_rids
			hit = get_world_3d().direct_space_state.intersect_ray(query)
		else:
			# Solid obstacle, standard target or terrain
			global_position = hit.position; flying = false
			if col.has_method("campaign_hit"):
				game.current_shot_id = score_id; game.last_hit_position = hit.position
				var accepted: bool = col.campaign_hit(hit.position, power, {"shot_id": shot_id, "pierced_count": pierced_count})
				game.play_impact_sound()
				if not accepted:
					if is_instance_valid(game) and is_instance_valid(game.stage): for target in game.stage.targets: if is_instance_valid(target): target.center_streak = 0
				if accepted:
					if is_instance_valid(vfx): vfx.impact(hit.position, game.stage)
					_apply_secondary(col, hit.position)
			else:
				if is_instance_valid(game) and is_instance_valid(game.stage): for target in game.stage.targets: if is_instance_valid(target): target.center_streak = 0
			game.arrow_resolved(); get_tree().create_timer(1.5).timeout.connect(queue_free)
			return

	global_position = next
	if velocity.length_squared() > .01:
		var v_dir: Vector3 = velocity.normalized()
		var up_vec: Vector3 = Vector3.FORWARD if absf(v_dir.dot(Vector3.UP)) > 0.98 else Vector3.UP
		look_at(global_position + velocity, up_vec)

func _apply_secondary(primary: Node3D, point: Vector3) -> void:
	var key: String = str(ability.get("key", "normal"))
	if key == "fire" and not primary.completed:
		for tick in range(2):
			get_tree().create_timer(.5 * (tick + 1)).timeout.connect(func():
				if is_instance_valid(primary) and not primary.completed and game.is_playing(): primary.campaign_secondary_hit(power * .12, shot_id + 100000 + tick * 10000))
	if game.current_definition.mode in ["precision", "ordered"]: return
	var amount: float = float(ability.get("secondary", 0)); var limit: int = int(ability.get("chains", 0))
	if key in ["pressure", "ultimate"]: limit = 3
	if amount <= 0 or limit <= 0: return
	var candidates: Array = []
	for target in game.stage.targets:
		if target == primary or target.completed or not target.can_receive_hit(): continue
		if target.global_position.distance_to(point) > 4.5: continue
		if key in ["pressure", "ultimate"]:
			var forward: Vector3 = velocity.normalized(); var offset: Vector3 = target.global_position - point
			if forward.dot(offset.normalized()) < .25: continue
		candidates.append(target)
	candidates.sort_custom(func(a, b): return a.global_position.distance_squared_to(point) < b.global_position.distance_squared_to(point))
	for i in range(mini(limit, candidates.size())):
		var other: Node3D = candidates[i]
		var query := PhysicsRayQueryParameters3D.create(point + velocity.normalized() * .2, other.global_position, 1 | 4); query.exclude = [primary.get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == other: other.campaign_secondary_hit(power * amount, shot_id)

func _resolve() -> void:
	if not flying: return
	flying = false
	if is_instance_valid(game) and is_instance_valid(game.stage): for target in game.stage.targets: if is_instance_valid(target): target.center_streak = 0
	game.arrow_resolved(); get_tree().create_timer(.3).timeout.connect(queue_free)
