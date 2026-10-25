extends CharacterBody3D

signal enemy_defeated(enemy: Node)

enum State { SPAWN, APPROACH, TELEGRAPH, ATTACK, RECOVER, STAGGER, DEAD }

var game:Node
var family:="moss_slime"
var completed:=false
var committed_target:=Vector3.ZERO
var hit_receipts:Dictionary={}
var pending_projectiles:=0
var visual_clock:=0.0
var combat_visuals_mode:="reference_3d_v2"
var action_limbs:Array[Node3D]=[]
var nav_clock:=0.0
var direction_sprite:Sprite3D
var hp_label:Label3D
var current_state := State.SPAWN
var hp := 41.5
var max_hp := 41.5
var attack_damage := 12.0
var move_speed := 2.4
var windup_time := 0.75
var active_time := 0.16
var recovery_time := 0.85
var attack_range := 1.8
var state_timer := 0.5

var threat_director: RefCounted
var target_player: Node3D
var nav_agent: NavigationAgent3D
var body_mesh: Node3D
var telegraph_mesh: MeshInstance3D
var vital_shape: CollisionShape3D
var attack_delivered := false
var attack_origin:=Vector3.ZERO
var attack_destination:=Vector3.ZERO
var leap_active:=false
var leap_blocked:=false
var leap_falling:=false
var leap_elapsed:=0.0
var leap_hit_radius:=1.1
var leap_height:=.75
var leap_mask_before:=3
var leap_cached_origin:=Vector3.ZERO
var hurt_left:=0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready() -> void:
	_ensure_setup()
	if is_instance_valid(target_player):
		var facing:Vector3=target_player.global_position-global_position;facing.y=0
		if facing.length()>.01:look_at(global_position+facing,Vector3.UP)

func _ensure_setup() -> void:
	if nav_agent != null:
		return
	collision_layer = 8 # Layer 4 (enemies)
	collision_mask = 1 | 2 # Layer 1 (terrain) | Layer 2 (player)
	
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 1.0
	add_child(nav_agent)

	_build_visuals()
	_build_telegraph()
	_build_directional_sprite()

func _build_visuals() -> void:
	install_reference_model()

func install_reference_model() -> void:
	var path:String="res://campaign/combat/models/%s-v2.scn"%family
	body_mesh=load(path).instantiate();add_child(body_mesh)
	var dimensions:Dictionary={"moss_slime":Vector2(.45,.90),"briar_slime":Vector2(.48,1.05),"seed_spitter":Vector2(.43,1.2),"bark_stalker":Vector2(.38,1.1),"mirror_wisp":Vector2(.43,.9),"root_warden":Vector2(.6,1.9)}
	var dimensions_value:Vector2=dimensions[family]
	var col:=CollisionShape3D.new();var shape:=CapsuleShape3D.new();shape.radius=dimensions_value.x;shape.height=maxf(dimensions_value.y,dimensions_value.x*2)
	col.shape=shape;col.position.y=dimensions_value.y*.5 if family!="mirror_wisp" else 1.0;add_child(col)
	vital_shape=CollisionShape3D.new();var vital:=SphereShape3D.new();vital.radius=.20 if family!="root_warden" else .28
	vital_shape.shape=vital
	vital_shape.position={"moss_slime":Vector3(0,.43,-.40),"briar_slime":Vector3(0,.35,-.4),"seed_spitter":Vector3(0,.82,-.50),"bark_stalker":Vector3(0,.8,-.5),"mirror_wisp":Vector3(0,1,-.25),"root_warden":Vector3(0,1.23,-.44)}[family]
	add_child(vital_shape)
	for node in body_mesh.find_children("Leg*","Node3D",true,false):action_limbs.append(node)

func _is_slime() -> bool:
	return family in ["moss_slime","briar_slime"]

func _build_telegraph() -> void:
	telegraph_mesh=MeshInstance3D.new()
	if _is_slime():
		var ring:=TorusMesh.new();ring.inner_radius=leap_hit_radius-.055;ring.outer_radius=leap_hit_radius
		ring.rings=40;ring.ring_segments=6;telegraph_mesh.mesh=ring
		telegraph_mesh.top_level=true
	else:
		var cylinder:=CylinderMesh.new();cylinder.top_radius=attack_range;cylinder.bottom_radius=attack_range;cylinder.height=.04
		telegraph_mesh.mesh=cylinder
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.95,.65,.15,.65)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled=true;mat.emission=Color("f5a623");mat.emission_energy_multiplier=1.1
	telegraph_mesh.material_override=mat;telegraph_mesh.visible=false;add_child(telegraph_mesh)

func _ground_at(point:Vector3,max_drop:float=4.0) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.35,point-Vector3.UP*max_drop,1)
	query.exclude=[get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func _commit_attack() -> void:
	current_state=State.TELEGRAPH;state_timer=windup_time;attack_delivered=false
	committed_target=target_player.global_position;attack_origin=global_position
	attack_destination=committed_target;attack_destination.y=attack_origin.y
	if _is_slime():
		var ground:Dictionary=_ground_at(committed_target)
		if not ground.is_empty() and ground.normal.y>.55:attack_destination.y=float(ground.position.y)+.02
		leap_active=false;leap_blocked=false;leap_falling=false;leap_elapsed=0
	var facing:Vector3=committed_target-global_position;facing.y=0
	if facing.length()>.01:look_at(global_position+facing,Vector3.UP)
	if is_instance_valid(telegraph_mesh):
		telegraph_mesh.visible=true;telegraph_mesh.scale=Vector3.ONE
		if _is_slime():telegraph_mesh.global_position=attack_destination+Vector3.UP*.025

func _begin_slime_leap() -> void:
	leap_active=true;leap_blocked=false;leap_falling=false;leap_elapsed=0
	leap_cached_origin=attack_origin;leap_mask_before=collision_mask
	# The landing event handles player damage; terrain still blocks the moving body.
	collision_mask=1;velocity=Vector3.ZERO

func _step_slime_leap(delta:float) -> void:
	if not leap_active or leap_cached_origin.distance_to(attack_origin)>.01:_begin_slime_leap()
	leap_elapsed+=delta
	var progress:float=clampf(1-state_timer/maxf(.01,active_time),0,1)
	if not leap_falling:
		var destination:Vector3=attack_origin.lerp(attack_destination,progress)
		destination.y+=sin(progress*PI)*leap_height
		var motion:Vector3=destination-global_position
		var pieces:int=maxi(1,ceili(motion.length()/.12))
		for i in range(pieces):
			var collision:KinematicCollision3D=move_and_collide(motion/float(pieces),false,.001)
			if collision:
				if collision.get_normal().y>.55 and progress>.45:_land_slime();return
				leap_blocked=true;leap_falling=true;velocity=Vector3.ZERO;break
		if not leap_falling and progress>=1:
			if _has_ground_contact():_land_slime();return
			leap_falling=true
	if leap_falling:
		velocity=Vector3(0,velocity.y-gravity*delta,0)
		var collision:KinematicCollision3D=move_and_collide(velocity*delta,false,.001)
		if collision and collision.get_normal().y>.55:_land_slime();return
		if _has_ground_contact():_land_slime();return
		if leap_elapsed>active_time+2 or global_position.y<attack_origin.y-3:
			# Invalid terrain must not hold an attack turn forever or create a remote hit.
			global_position=attack_origin;_end_slime_leap();current_state=State.RECOVER;state_timer=recovery_time

func _has_ground_contact() -> bool:
	var ground:Dictionary=_ground_at(global_position,.20)
	return not ground.is_empty() and ground.normal.y>.55 and global_position.y-float(ground.position.y)<=.14

func _end_slime_leap() -> void:
	if leap_active:collision_mask=leap_mask_before
	leap_active=false;leap_falling=false;velocity=Vector3.ZERO
	if is_instance_valid(telegraph_mesh):telegraph_mesh.visible=false

func _land_slime() -> void:
	if attack_delivered:return
	attack_delivered=true;_end_slime_leap();_deliver_attack()
	current_state=State.RECOVER;state_timer=recovery_time

func _apply_slime_contact_damage() -> void:
	if not _has_ground_contact() or not is_instance_valid(target_player):return
	var offset:Vector3=target_player.global_position-global_position
	if absf(offset.y)>.85:return
	offset.y=0
	if offset.length()>leap_hit_radius:return
	var from:Vector3=global_position+Vector3.UP*.35
	var to:Vector3=target_player.global_position+Vector3.UP*.35
	var query:=PhysicsRayQueryParameters3D.create(from,to,1);query.exclude=[get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():return
	if target_player.has_method("take_player_damage"):target_player.take_player_damage(attack_damage,self)

func _physics_process(delta: float) -> void:
	_ensure_setup()
	if is_instance_valid(game) and not game.is_playing():return
	if current_state == State.DEAD:
		return

	visual_clock+=delta
	hurt_left=maxf(0,hurt_left-delta)
	_animate_combat_body(delta)
	_update_directional_sprite()
	# Apply gravity
	if not is_on_floor() and not (_is_slime() and current_state==State.ATTACK):
		velocity.y -= gravity * delta

	match current_state:
		State.SPAWN:
			state_timer -= delta
			if state_timer <= 0:
				current_state = State.APPROACH

		State.APPROACH:
			if is_instance_valid(telegraph_mesh): telegraph_mesh.visible = false
			if is_instance_valid(target_player):
				var dist: float = global_position.distance_to(target_player.global_position)
				var has_turn:bool=threat_director==null or threat_director.reserve_attack(self)
				if dist <= attack_range and has_turn:
					velocity.x = 0
					velocity.z = 0
					_commit_attack()
				else:
					# Approach player
					var destination:Vector3=target_player.global_position if has_turn else threat_director.staging_position(self,target_player)
					if move_speed<=0 and has_turn:return
					if NavigationServer3D.map_get_iteration_id(nav_agent.get_navigation_map())>0:
						nav_clock-=delta
						if nav_clock<=0:nav_agent.target_position=destination;nav_clock=.3
						if not nav_agent.is_navigation_finished():destination=nav_agent.get_next_path_position()
					var dir := (destination - global_position)
					dir.y = 0
					if dir.length() > 0.01:
						dir = dir.normalized()
						var travel_speed:float=move_speed if has_turn else minf(move_speed,1.3)
						if _is_slime():travel_speed*=1.6*absf(sin(visual_clock*8))
						velocity.x = dir.x * travel_speed
						velocity.z = dir.z * travel_speed
						look_at(global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)
					move_and_slide()

		State.TELEGRAPH:
			state_timer -= delta
			# Amber ground telegraph pulses
			if is_instance_valid(telegraph_mesh): telegraph_mesh.visible = true
			var pulse := 1.0 + 0.12 * sin((windup_time - state_timer) * 8.0)
			if is_instance_valid(telegraph_mesh):
				telegraph_mesh.scale=Vector3.ONE if _is_slime() else Vector3(pulse,1,pulse)
				if _is_slime():
					var marker_material:StandardMaterial3D=telegraph_mesh.material_override
					marker_material.emission_energy_multiplier=1.0+clampf(1-state_timer/maxf(.01,windup_time),0,1)*.8
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			if state_timer <= 0:
				current_state = State.ATTACK
				if family in ["moss_slime","briar_slime","bark_stalker"] and is_instance_valid(game):game.play_sound("res://sounds/roll.wav",.85,-18)
				state_timer = active_time
				if _is_slime():_begin_slime_leap()
				elif is_instance_valid(telegraph_mesh):telegraph_mesh.visible=false

		State.ATTACK:
			state_timer-=delta
			if _is_slime():
				_step_slime_leap(delta)
			else:
				if is_instance_valid(telegraph_mesh):telegraph_mesh.visible=false
				if family=="bark_stalker":
					var progress:float=clampf(1-state_timer/maxf(.01,active_time),0,1)
					var destination:Vector3=attack_origin.lerp(attack_destination,progress)
					destination.y+=sin(progress*PI)*.35
					move_and_collide(destination-global_position)
					if state_timer<=0 and not attack_delivered:attack_delivered=true;_deliver_attack()
				else:
					if not attack_delivered:attack_delivered=true;_deliver_attack()
					move_and_slide()
				if state_timer<=0:current_state=State.RECOVER;state_timer=recovery_time

		State.RECOVER:
			state_timer -= delta
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			if state_timer<=0 and pending_projectiles==0:
				if threat_director != null:
					threat_director.release_attack(self)
				current_state = State.APPROACH

		State.STAGGER:
			state_timer -= delta
			velocity.x = lerpf(velocity.x, 0.0, minf(1.0, delta * 9.0))
			velocity.z = lerpf(velocity.z, 0.0, minf(1.0, delta * 9.0))
			move_and_slide()
			if state_timer <= 0.0:
				current_state = State.APPROACH

func _deliver_attack() -> void:
	if not is_instance_valid(target_player):
		return
	impact_effect(leap_hit_radius if _is_slime() else (1.4 if family!="root_warden" else 2.5))
	if is_instance_valid(game):game.play_sound("res://sounds/step_stone_2.wav",.7,-12)
	if family=="root_warden":
		var slam=preload("res://campaign/combat/boss_hazard.gd").new();slam.game=game;slam.radius=2.5;slam.damage=attack_damage;slam.warning=0;slam.position=global_position+Vector3(0,.04,0);get_parent().add_child(slam)
		return
	if _is_slime():
		_apply_slime_contact_damage();return
	var dist:float=committed_target.distance_to(target_player.global_position)
	if dist<=1.4 and global_position.distance_to(target_player.global_position)<=attack_range+.6:
		if target_player.has_method("take_player_damage"):
			target_player.take_player_damage(attack_damage, self)

func campaign_hit(hit_pos: Vector3, damage: float, shot_context: Dictionary = {}) -> bool:
	if current_state == State.DEAD or (is_instance_valid(game) and not game.is_playing()):
		return false
	var receipt:String=str(shot_context.get("event_id",shot_context.get("shot_id",-1)))
	if receipt!="-1" and hit_receipts.has(receipt):return false
	if receipt!="-1":hit_receipts[receipt]=true
	
	# Check vital head/core hit
	var is_vital := false
	if is_instance_valid(vital_shape):
		var vital_dist: float = vital_shape.global_position.distance_to(hit_pos)
		if vital_dist <= (vital_shape.shape.radius if vital_shape.shape is SphereShape3D else .25)+.025:
			is_vital = true
	
	var final_damage: float = damage * (1.25 if is_vital else 1.0)
	hp = maxf(0.0, hp - final_damage)
	
	var power_key := str(shot_context.get("power_key", "normal"))
	if is_instance_valid(game):
		game.target_scored(3 if is_vital else 2,final_damage,true)
		if is_instance_valid(game.combat_hud) and game.combat_hud.has_method("popup_damage"):
			game.combat_hud.popup_damage(hit_pos, final_damage, is_vital, power_key)
	_play_hurt_effect(is_vital)
	_spawn_hit_sparks(hit_pos, is_vital)

	# Action combat intensity: Stagger and physical knockback
	var is_heavy := power_key != "normal" or is_vital or final_damage >= 20.0
	if is_heavy and current_state != State.DEAD:
		current_state = State.STAGGER
		state_timer = 0.42 if power_key != "normal" else 0.32
		var hit_dir := (global_position - hit_pos).normalized()
		hit_dir.y = 0.16
		var power_mult: float = 1.45 if power_key != "normal" else 1.0
		var impulse := ((7.0 if is_vital else 5.2) if family != "root_warden" else (3.2 if is_vital else 2.0)) * power_mult
		velocity = hit_dir * impulse
		if is_instance_valid(game) and is_instance_valid(game.hero) and game.hero.has_method("apply_shockwave_shake"):
			game.hero.apply_shockwave_shake(0.24 if power_key != "normal" else (0.14 if is_vital else 0.07))
	
	if hp <= 0.001:
		_die()
	return true

func _spawn_hit_sparks(pos: Vector3, vital: bool) -> void:
	var parent_stage = get_parent()
	if not is_instance_valid(parent_stage): return
	var spark_color := Color("ffe082") if vital else Color("81eeff")
	if family in ["moss_slime", "briar_slime"]: spark_color = Color("9ceba2") if family == "moss_slime" else Color("ff98c8")
	elif family == "bark_stalker": spark_color = Color("ffb066")
	elif family == "root_warden": spark_color = Color("d4c5a9")
	
	for i in range(6 if vital else 4):
		var spark := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.07
		spark.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = spark_color
		mat.emission_enabled = true
		mat.emission = spark_color
		mat.emission_energy_multiplier = 3.0
		spark.material_override = mat
		parent_stage.add_child(spark)
		spark.global_position = pos
		var spread := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized() * randf_range(0.8, 1.8)
		var tw := spark.create_tween()
		if tw:
			tw.set_parallel(true)
			tw.tween_property(spark, "global_position", pos + spread, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(spark, "scale", Vector3.ZERO, 0.28)
			tw.chain().tween_callback(spark.queue_free)

func _play_hurt_effect(vital: bool) -> void:
	if _is_slime():hurt_left=.16 if vital else .11;return
	if is_instance_valid(body_mesh):
		var tween := create_tween()
		tween.tween_property(body_mesh, "scale", Vector3.ONE * (0.85 if vital else 0.92), 0.05)
		tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.10)

func _die() -> void:
	_end_slime_leap()
	current_state = State.DEAD
	completed=true
	velocity=Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if threat_director != null:
		threat_director.release_attack(self)
	_death_effect()
	emit_signal("enemy_defeated", self)
	if is_inside_tree() and get_tree() != null:
		await get_tree().create_timer(0.45).timeout
	queue_free()

func _death_effect() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(body_mesh):
		var collapse:=create_tween();collapse.tween_property(body_mesh,"scale",Vector3(.2,.05,.2),.32)
	# Clean non-gory dispersal into leaves and light motes
	for i in range(10):
		var mote := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = randf_range(0.05, 0.12)
		sm.height = sm.radius * 2
		mote.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.95, 0.65, 0.8)
		mat.emission_enabled = true
		mat.emission = Color("7ae89d")
		mat.emission_energy_multiplier = 1.6
		mote.material_override = mat
		add_child(mote)
		var dest := Vector3(randf_range(-1.2, 1.2), randf_range(0.2, 1.5), randf_range(-1.2, 1.2))
		var tw := create_tween()
		if tw:
			tw.set_parallel(true)
			tw.tween_property(mote, "position", dest, 0.4)
			tw.tween_property(mote, "scale", Vector3.ZERO, 0.4)

func can_receive_hit() -> bool:
	return not completed

func campaign_secondary_hit(damage:float,event_id:int) -> bool:
	return campaign_hit(global_position+Vector3(0,.4,0),damage,{"shot_id":event_id,"secondary":true})

func _build_directional_sprite() -> void:
	var path:String="res://campaign/combat/assets/enemies/%s-directions-v1.png"%family
	if not ResourceLoader.exists(path):return
	var texture:Texture2D=load(path)
	var height:float={"moss_slime":1.30,"briar_slime":1.45,"seed_spitter":1.4,"bark_stalker":1.5,"mirror_wisp":1.8,"root_warden":2.25}.get(family,1.2)
	direction_sprite=Sprite3D.new();direction_sprite.texture=texture;direction_sprite.hframes=4;direction_sprite.vframes=2
	direction_sprite.pixel_size=height/(texture.get_height()/2.0)
	direction_sprite.position.y=height*.5
	direction_sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	direction_sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	body_mesh.rotation.y=PI
	direction_sprite.visible=false
	_build_action_limbs()
	body_mesh.add_child(direction_sprite)
	hp_label=Label3D.new();hp_label.position.y=height+.3;hp_label.font_size=30;hp_label.pixel_size=.006;hp_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(hp_label)

func _update_directional_sprite() -> void:
	if not is_instance_valid(direction_sprite):return
	var camera:Camera3D=get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		var offset:Vector3=camera.global_position-global_position;offset.y=0
		var forward:Vector3=-global_basis.z
		var angle:float=forward.signed_angle_to(offset.normalized(),Vector3.UP)
		direction_sprite.frame=posmod(roundi(angle/TAU*8),8)
	var stretch:float=1.0
	if current_state==State.TELEGRAPH:stretch=lerpf(1.0,.78,1-state_timer/maxf(.01,windup_time))
	elif current_state==State.ATTACK:stretch=1.13
	elif current_state==State.APPROACH:stretch=1.0+.04*sin(visual_clock*10)
	direction_sprite.scale=Vector3(1.0/maxf(.75,stretch),stretch,1)
	direction_sprite.modulate=Color("ffe0a1") if current_state==State.TELEGRAPH else Color.WHITE
	if is_instance_valid(hp_label):hp_label.text="%s · %d HP%s"%[family.replace("_"," ").capitalize(),ceili(hp)," · ATTACK INCOMING" if current_state==State.TELEGRAPH else (" · RECOVERING" if current_state==State.RECOVER else "")]

func _build_action_limbs() -> void:
	if combat_visuals_mode=="reference_3d_v2":return
	if family not in ["bark_stalker","root_warden"]:return
	for i in range(4 if family=="bark_stalker" else 2):
		var joint:=Node3D.new();joint.position=Vector3((-.2 if i%2==0 else .2),.35,(-.25 if i<2 else .25) if family=="bark_stalker" else 0)
		var leg:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=.07;shape.bottom_radius=.10;shape.height=.38
		leg.mesh=shape;leg.position.y=-.17
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color("51472e");leg.material_override=mat
		joint.add_child(leg);body_mesh.add_child(joint);action_limbs.append(joint)

func _animate_combat_body(delta:float) -> void:
	if not is_instance_valid(body_mesh) or completed:return
	var tail:Node3D=body_mesh.find_child("Tail",true,false)
	if is_instance_valid(tail):tail.rotation.y=sin(visual_clock*4)*.22
	var head:Node3D=body_mesh.find_child("Head",true,false)
	if is_instance_valid(head):head.rotation.z=sin(visual_clock*2)*.025
	var moving:bool=current_state==State.APPROACH and Vector2(velocity.x,velocity.z).length()>.2
	var charge:float=clampf(1-state_timer/maxf(.01,windup_time),0,1) if current_state==State.TELEGRAPH else 0
	if _is_slime():_animate_slime_pose(moving,charge)
	if family not in ["moss_slime","briar_slime"]:
		body_mesh.position.y=absf(sin(visual_clock*9))*.06 if moving else 0
		body_mesh.rotation.x=lerpf(body_mesh.rotation.x,-.3*charge if current_state!=State.ATTACK else .35,minf(1,delta*16))
	for i in range(action_limbs.size()):action_limbs[i].rotation.x=sin(visual_clock*11+i*PI)*.65 if moving else 0
	if family=="seed_spitter":
		get("pod_muzzle").scale=Vector3.ONE*(1+.35*charge)
		get("leaf_left").rotation.z=-charge*.35;get("leaf_right").rotation.z=charge*.35
	if family=="root_warden":
		get("arm_left").rotation.x=-2.3*charge if current_state!=State.ATTACK else .8
		get("arm_right").rotation.x=-2.3*charge if current_state!=State.ATTACK else .8
		get("chest_knot").scale=Vector3.ONE*(1+.18*charge)

func impact_effect(radius:float=1.0,color:Color=Color("a9ef78")) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.7
	mesh.outer_radius = radius
	mesh.rings = 24
	mesh.ring_segments = 8
	ring.mesh = mesh
	ring.position = global_position + Vector3(0, 0.08, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	ring.material_override = mat
	get_parent().add_child(ring)
	ring.scale = Vector3.ONE * 0.1
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)

func _animate_slime_pose(moving:bool,charge:float) -> void:
	var height:float=1+sin(visual_clock*2.6)*.025
	var lift:float=0
	if moving:
		var hop:float=absf(sin(visual_clock*8));lift=pow(hop,1.3)*.14;height=lerpf(.88,1.08,hop)
	if current_state==State.TELEGRAPH:height=1-.38*smoothstep(0,1,charge)
	elif current_state==State.ATTACK:
		var progress:float=clampf(1-state_timer/maxf(.01,active_time),0,1)
		height=1.05+.20*sin(progress*PI);lift=0
	elif current_state==State.RECOVER:
		var elapsed:float=recovery_time-state_timer
		height=1-.42*exp(-elapsed*11)*cos(elapsed*23);lift=0
	if hurt_left>0:height*=.93
	var width:float=1/sqrt(maxf(.4,height))
	body_mesh.scale=Vector3(width,height,width);body_mesh.position.y=lift
	var fern:Node3D=body_mesh.find_child("Fern",true,false)
	if is_instance_valid(fern):fern.rotation.x=charge*.48 if current_state==State.TELEGRAPH else sin(visual_clock*8)*.10*(1 if moving else .25)
	for bud in body_mesh.find_children("ThornBud*","Node3D",true,false):
		bud.rotation.x=charge*.16 if current_state==State.TELEGRAPH else sin(visual_clock*6)*.035
