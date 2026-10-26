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
	mesh.name = "ArrowModel"
	mesh.mesh = load(mesh_path)
	preload("res://campaign/catalog.gd").apply_arrow_finish(mesh, arrow_id)
	var bounds := mesh.mesh.get_aabb()
	var width_scale := minf(.8, .085 / maxf(bounds.size.x, bounds.size.z))
	mesh.scale = Vector3(width_scale, .72 / bounds.size.y, width_scale)
	mesh.rotation.x = -PI / 2
	# Physics traces the leading tip; the shaft extends back to the released nock.
	mesh.position.z = bounds.end.y * mesh.scale.y
	add_child(mesh)
	# Keep the equipped arrow visible; its elemental light comes from the VFX.
	vfx = preload("res://campaign/power_vfx.gd").new(); vfx.projectile = self; add_child(vfx)

func _physics_process(delta: float) -> void:
	if not flying: return
	if game.state not in ["playing", "finishing"]: return
	age += delta
	if age > 8: _resolve(); return
	wind = game.current_wind()*(.5 if str(ability.get("key","normal"))=="gale" else 1.0)
	var acceleration := Vector3(wind, -9.8, 0)
	var next: Vector3 = global_position + velocity * delta + .5 * acceleration * delta * delta
	velocity += acceleration * delta

	# Predict the final contact along the same trajectory for presentation only.
	if not trail_started:
		var prediction := PhysicsRayQueryParameters3D.create(global_position, global_position + velocity * .40 + .5 * acceleration * .16, 1 | 4 | 8)
		prediction.exclude = ([owner_body.get_rid()] if is_instance_valid(owner_body) else []) + excluded_rids
		var ahead: Dictionary = get_world_3d().direct_space_state.intersect_ray(prediction)
		if not ahead.is_empty() and ahead.collider.has_method("would_be_destroyed"):
			game.maybe_follow_final(self, ahead.collider, ahead.position)
			trail_started = game.final_director.is_active()

	var query := PhysicsRayQueryParameters3D.create(global_position, next, 1 | 4 | 8); query.hit_from_inside = true
	query.exclude = ([owner_body.get_rid()] if is_instance_valid(owner_body) else []) + excluded_rids

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	while not hit.is_empty():
		var col = hit.collider
		if col.has_method("campaign_hit") and col.get("is_pierceable")==true:
			# Soft orb / Thread Shot target pierced!
			pierced_count += 1
			game.max_thread_chain=maxi(game.max_thread_chain,pierced_count)
			excluded_rids.append(col.get_rid())
			game.current_hit_actor_id=col.get_instance_id();game.current_shot_id = score_id
			game.last_hit_position = hit.position
			var accepted: bool = col.campaign_hit(hit.position, power, {"shot_id": shot_id, "pierce": true, "pierced_count": pierced_count, "power_key":str(ability.get("key","normal")), "draw_ratio":float(ability.get("draw_ratio",1)), "direct":true, "hit_shape":int(hit.get("shape",-1))})

			# Ascending chime pitch for consecutive threaded hits: C, E, G, C
			var pitch: float = 1.0 + float(pierced_count - 1) * 0.25
			if game.has_method("play_stream"):
				game.play_stream("res://campaign/audio/crystal_orb.wav", pitch)
			elif game.has_method("play_sound"):
				game.play_sound("res://campaign/audio/crystal_orb.wav", pitch)

			if accepted:
				if is_instance_valid(vfx): vfx.impact(hit.position, game.stage)
				_apply_secondary(col, hit.position)
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
				game.current_hit_actor_id=col.get_instance_id();game.current_shot_id = score_id; game.last_hit_position = hit.position
				var accepted: bool = col.campaign_hit(hit.position, power, {"shot_id":shot_id,"pierced_count":pierced_count,"power_key":str(ability.get("key","normal")),"draw_ratio":float(ability.get("draw_ratio",1)),"direct":true,"hit_shape":int(hit.get("shape",-1))})
				var p_key := str(ability.get("key", "normal"))
				if p_key=="normal" or not accepted:game.play_impact_sound()
				if p_key != "normal" and accepted and game.has_method("play_power_impact_sound"):
					game.play_power_impact_sound(p_key)
				if not accepted:
					if is_instance_valid(game) and is_instance_valid(game.stage): for target in game.stage.targets: if is_instance_valid(target): target.center_streak = 0
				if accepted:
					if is_instance_valid(vfx): vfx.impact(hit.position, game.stage)
					_apply_secondary(col, hit.position)
			else:
				if is_instance_valid(game) and is_instance_valid(game.stage): for target in game.stage.targets: if is_instance_valid(target): target.center_streak = 0
				var p_key := str(ability.get("key", "normal"))
				if p_key != "normal":
					if is_instance_valid(vfx): vfx.impact(hit.position, game.stage)
					if game.has_method("play_power_impact_sound"): game.play_power_impact_sound(p_key)
			game.arrow_resolved(); get_tree().create_timer(1.5).timeout.connect(queue_free)
			return

	global_position = next
	if velocity.length_squared() > .01:
		var v_dir: Vector3 = velocity.normalized()
		var up_vec: Vector3 = Vector3.FORWARD if absf(v_dir.dot(Vector3.UP)) > 0.98 else Vector3.UP
		look_at(global_position + velocity, up_vec)

func _apply_secondary(primary:Node3D,point:Vector3) -> void:
	var key:String=str(ability.get("key","normal"))
	var baseline:float=power * 0.85
	if key=="fire" and not primary.completed:
		for old in game.stage.get_children():
			if old.get_script()==preload("res://campaign/combat/burn_effect.gd") and old.target==primary:old.queue_free()
		var burn=preload("res://campaign/combat/burn_effect.gd").new()
		burn.game=game;burn.target=primary;burn.encounter=game.stage;burn.damage=baseline*.35;burn.event_id=shot_id*10000+1000000
		game.stage.add_child(burn)
	var amounts:Array=[]
	var radius:=3.2
	if key=="pressure":amounts=[.75,.75,.75];radius=4.0
	elif key=="lightning":amounts=[.85,.65];radius=5.5
	elif key=="super_lightning":amounts=[1.0,.85,.70];radius=7.0
	elif key=="ultimate":amounts=[1.2,1.2,1.2,1.2];radius=5.5
	var actors:Array=game.stage.targets.duplicate()
	if game.is_combat():
		actors.append_array(game.stage.combat_manager.enemies_alive)
		if is_instance_valid(game.stage.combat_manager.boss):actors.append(game.stage.combat_manager.boss)
	var visited:Array=[primary]
	var origin:Vector3=point
	for multiplier in amounts:
		var candidates:Array=[]
		for actor in actors:
			if not is_instance_valid(actor) or visited.has(actor) or actor.completed:continue
			if actor.global_position.distance_to(origin)>radius:continue
			candidates.append(actor)
		candidates.sort_custom(func(a,b):
			var da:float=a.global_position.distance_squared_to(origin);var db:float=b.global_position.distance_squared_to(origin)
			return a.get_instance_id()<b.get_instance_id() if is_equal_approx(da,db) else da<db)
		var chosen:Node3D
		for actor in candidates:
			var query:=PhysicsRayQueryParameters3D.create(origin+Vector3(0,.15,0),actor.global_position+Vector3(0,.4,0),13)
			var chain_exclusions: Array[RID] = []
			for previous in visited:
				if is_instance_valid(previous): chain_exclusions.append(previous.get_rid())
			query.exclude = chain_exclusions
			var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider==actor:chosen=actor;break
		if not is_instance_valid(chosen):break
		game.secondary_damage=true;chosen.campaign_secondary_hit(baseline*float(multiplier),shot_id*1000+visited.size());game.secondary_damage=false
		if is_instance_valid(vfx):
			vfx.chain(origin, chosen.global_position + Vector3(0,.4,0), game.stage)
			vfx.impact(chosen.global_position + Vector3(0,.4,0), game.stage)
		visited.append(chosen)
		if key in ["lightning","super_lightning"]:origin=chosen.global_position+Vector3(0,.4,0)

func _resolve() -> void:
	if not flying: return
	flying = false
	if is_instance_valid(game) and is_instance_valid(game.stage): for target in game.stage.targets: if is_instance_valid(target): target.center_streak = 0
	game.arrow_resolved(); get_tree().create_timer(.3).timeout.connect(queue_free)
