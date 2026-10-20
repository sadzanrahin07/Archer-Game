extends CharacterBody3D

const Catalog = preload("res://campaign/catalog.gd")
const Projectile = preload("res://campaign/projectile.gd")
var game: Node
var model_path := "res://campaign/characters/Enola.tscn"
var bone_names: Dictionary = {}
var character_id := 0
var showcase := true
var stationary := false
var spawn_point := Vector3.ZERO
var drawing := false
var aim_held := false
var draw_elapsed := 0.0
var shot_cooldown := 0.0
var showcase_timer := 0.0
var yaw := 0.0
var pitch := 0.0
var sway_time := 0.0
var aim_blend := 0.0
var last_pose := ""
var step_time := 0.0
var rig_height := 1.6
var controller_drawing := false
var visuals: Node3D
var char_model: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var aim_modifier: SkeletonModifier3D
var touch_move := Vector2.ZERO
var touch_sprint := false
var touch_aim := false
var bow_hand_node: MeshInstance3D
var bow_string_node: MeshInstance3D
var bow_arrow_node: MeshInstance3D
var maki_retarget:Dictionary={}
var palm_binding := Basis.IDENTITY
var arrow_mesh_scale := Vector3.ONE*0.8
var bow_tip_top := Vector3(0,0.85,-0.269)
var bow_tip_bot := Vector3(0,-0.83,-0.269)
var bow_string_rest := Vector3(0,0,-0.269)
var solved_left := Vector3.ZERO
var solved_right := Vector3.ZERO
var nock_world := Vector3.ZERO
var left_hand := -1
var right_hand := -1
var right_finger := -1

func _ready() -> void:
	collision_layer = 2; collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(55)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28; capsule.height = 1.55
	shape.shape = capsule; shape.position.y = 0.775
	add_child(shape)
	visuals = Node3D.new(); visuals.name = "Visuals"; add_child(visuals)
	char_model = load(model_path).instantiate()
	visuals.add_child(char_model)
	char_model.rotation.y = PI if character_id == 2 else 0.0
	skeleton = char_model.find_child("GeneralSkeleton",true,false)
	if not skeleton: skeleton = char_model.find_child("Skeleton3D",true,false)
	anim_player = char_model.find_child("AnimationPlayer",true,false)
	if skeleton.name == "GeneralSkeleton":
		skeleton.reset_bone_poses()
		for key in bone_names.keys():
			bone_names[key] = str(key).left(1).to_upper()+str(key).substr(1)
		if character_id==2:_prepare_maki_retarget()
		_setup_user_animations()
	left_hand = skeleton.find_bone(bone_names.get("leftHand","J_Bip_L_Hand"))
	right_hand = skeleton.find_bone(bone_names.get("rightHand","J_Bip_R_Hand"))
	right_finger = skeleton.find_bone(bone_names.get("rightIndexIntermediate","J_Bip_R_Index2"))
	_calibrate_palm_binding()
	var head := skeleton.find_bone(bone_names.get("head","J_Bip_C_Head"))
	if head >= 0: rig_height = clampf(skeleton.get_bone_global_rest(head).origin.y + 0.15,1.4,1.85)
	camera_pivot = Node3D.new(); add_child(camera_pivot)
	spring_arm = SpringArm3D.new(); spring_arm.spring_length = 3.5; spring_arm.collision_mask = 1; camera_pivot.add_child(spring_arm)
	spring_arm.add_excluded_object(get_rid())
	camera = Camera3D.new(); camera.near = 0.03; camera.fov = 65; spring_arm.add_child(camera)
	aim_modifier = preload("res://campaign/archery_aim.gd").new()
	aim_modifier.player = self
	skeleton.add_child(aim_modifier)
	bow_hand_node = MeshInstance3D.new(); bow_hand_node.mesh = load(Catalog.BOWS[int(game.profile.data.equipped_bow)].mesh); add_child(bow_hand_node)
	bow_string_node = MeshInstance3D.new(); bow_hand_node.add_child(bow_string_node)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("ebe8d6"); bow_string_node.material_override = mat
	bow_arrow_node = MeshInstance3D.new(); bow_arrow_node.mesh = load(Catalog.ARROWS[int(game.profile.data.equipped_arrow)].mesh); add_child(bow_arrow_node)
	Catalog.apply_arrow_finish(bow_arrow_node,int(game.profile.data.equipped_arrow))
	var arrow_bounds:=bow_arrow_node.mesh.get_aabb()
	var width_scale:=minf(0.8,0.085/maxf(arrow_bounds.size.x,arrow_bounds.size.z))
	arrow_mesh_scale=Vector3(width_scale,1.0/arrow_bounds.size.y,width_scale)
	var geometry_id: String=Catalog.BOWS[int(game.profile.data.equipped_bow)].geometry
	if geometry_id!="standard":
		var definition:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://campaign/equipment/geometry.json"))[geometry_id]
		bow_tip_top=Vector3(definition.top[0],definition.top[1],definition.top[2])
		bow_tip_bot=Vector3(definition.bottom[0],definition.bottom[1],definition.bottom[2])
		bow_string_rest=(bow_tip_top+bow_tip_bot)*0.5
	aim_modifier.modification_processed.connect(_update_equipment)
	var charge=preload("res://campaign/power_charge.gd").new();charge.player=self;add_child(charge)
	_play_pose("idle")
	set_showcase(true)

func _play_pose(kind: String) -> void:
	if last_pose == kind: return
	last_pose = kind
	anim_player.speed_scale = anim_player.get_animation("shared/draw").length/game.profile.draw_time() if kind=="draw" else 1.0
	anim_player.play("shared/"+kind,0.16)

func interact() -> void:
	if not showcase: return
	showcase_timer = 2.2
	draw_elapsed = 0
	drawing = true
	_play_pose("draw")
	game.play_sound("res://sounds/bow_draw.wav")

func set_showcase(value: bool) -> void:
	showcase = value
	velocity = Vector3.ZERO; drawing = false; aim_held = false; draw_elapsed = 0; shot_cooldown = 0
	camera.current = not value
	yaw = 0; pitch = 0
	aim_blend = 0
	visuals.rotation.y = PI if value else 0.0
	camera_pivot.position = Vector3(0.47,rig_height*0.86,0)
	camera_pivot.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	spring_arm.spring_length = 3.5
	camera.fov = 65
	spring_arm.rotation.x = 0
	_update_goals(1.0/60.0,false)
	_play_pose("idle")

func _unhandled_input(event: InputEvent) -> void:
	if showcase or not game.is_playing(): return
	if game.touch_enabled(): return
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * 0.0025 * float(game.profile.data.settings.get("sensitivity",1.0))
		pitch = clampf(pitch - event.relative.y * 0.0025,-0.9,0.9)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: aim_held = event.pressed
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _start_draw()
			elif drawing: _fire()
			get_viewport().set_input_as_handled()

func _start_draw() -> void:
	if shot_cooldown > 0: return
	if not game.power_armed and game.arrows <= 0: return
	drawing = true; draw_elapsed = 0
	_play_pose("draw")
	game.play_sound("res://sounds/bow_draw.wav")

func _physics_process(delta: float) -> void:
	shot_cooldown = maxf(0,shot_cooldown-delta)
	sway_time += delta
	if showcase:
		showcase_timer = maxf(0,showcase_timer-delta)
		if showcase_timer > 0:
			draw_elapsed += delta
			drawing = true
			if draw_elapsed > game.profile.draw_time(): _play_pose("aim")
		else: drawing = false; _play_pose("idle")
		_update_goals(delta,drawing)
		if game.profile.data.settings.get("reduced_motion",false) and not drawing: anim_player.speed_scale = 0
		return
	if not game.is_playing(): return
	if not Input.get_connected_joypads().is_empty():
		var joy: int = Input.get_connected_joypads()[0]
		var look := Vector2(Input.get_joy_axis(joy,JOY_AXIS_RIGHT_X),Input.get_joy_axis(joy,JOY_AXIS_RIGHT_Y))
		if look.length() > 0.15: yaw -= look.x*delta*2.4; pitch = clampf(pitch-look.y*delta*1.8,-0.9,0.9)
		var trigger := Input.get_joy_axis(joy,JOY_AXIS_TRIGGER_RIGHT) > 0.35
		aim_held = Input.get_joy_axis(joy,JOY_AXIS_TRIGGER_LEFT) > 0.35
		if trigger and not drawing: _start_draw(); controller_drawing = drawing
		if not trigger and controller_drawing: controller_drawing = false; _fire()
	var aiming := drawing or aim_held or touch_aim or shot_cooldown > 0.0
	if drawing: draw_elapsed += delta
	game.draw_amount = clampf(draw_elapsed/game.profile.draw_time(),0,1) if drawing else 0
	var stability: float = game.profile.stability()
	var sway: float = 0.0028 * stability * (1+maxf(0,draw_elapsed-2)) if drawing else 0
	camera_pivot.rotation.y = yaw + sin(sway_time*1.6)*sway
	spring_arm.rotation.x = pitch + cos(sway_time*1.3)*sway
	camera_pivot.position = camera_pivot.position.lerp(Vector3(0.47,rig_height*0.86,0),1-exp(-10*delta))
	spring_arm.spring_length = lerpf(spring_arm.spring_length,0.82 if aiming else 3.5,1-exp(-8*delta))
	camera.fov = lerpf(camera.fov,40 if aiming else 65,1-exp(-8*delta))
	var input_dir := Input.get_vector("move_left","move_right","move_forward","move_backward")
	if touch_move.length()>0.05:input_dir=touch_move
	if not Input.get_connected_joypads().is_empty():
		var joy: int = Input.get_connected_joypads()[0]
		var stick := Vector2(Input.get_joy_axis(joy,JOY_AXIS_LEFT_X),Input.get_joy_axis(joy,JOY_AXIS_LEFT_Y))
		if stick.length() > 0.18: input_dir = stick.limit_length()
	# Aiming plants the feet. No root-motion or movement can drift the archer.
	var move := Vector3.ZERO if aiming or stationary else Vector3(input_dir.x,0,input_dir.y).rotated(Vector3.UP,yaw)
	var sprinting := (Input.is_action_pressed("sprint") or touch_sprint) and not aiming
	var speed := 6.8 if sprinting else 2.8
	velocity.x = move.x*speed; velocity.z = move.z*speed
	velocity.y = -0.2 if is_on_floor() else velocity.y-9.8*delta
	move_and_slide()
	if aiming:
		visuals.rotation.y = yaw
		if shot_cooldown > 0: _play_pose("release")
		elif drawing and draw_elapsed < game.profile.draw_time(): _play_pose("draw")
		else: _play_pose("aim")
	elif move.length() > 0.1:
		visuals.rotation.y = lerp_angle(visuals.rotation.y,atan2(-move.x,-move.z),1-exp(-12*delta))
		_play_pose("run" if sprinting else "walk")
	else: _play_pose("idle")
	_update_goals(delta,aiming)
	step_time -= delta
	if move.length() > 0.1 and step_time <= 0 and is_on_floor():
		step_time = 0.28 if sprinting else 0.46
		game.play_sound("res://sounds/step_grass_%d.wav" % (1+randi()%3))
	RenderingServer.global_shader_parameter_set("player_pos",global_position)
	if global_position.y < 3 or not game.stage.safe_bounds.grow(2).has_point(Vector2(global_position.x,global_position.z)):
		global_position = spawn_point; velocity = Vector3.ZERO
		game.time_left = maxf(0,game.time_left-3); game.feedback("Returned to the course · 3 second penalty")

func _update_goals(delta: float, aiming: bool) -> void:
	# The supplied X bow clips drive the complete archery stance and both hands.
	aim_blend = move_toward(aim_blend,1 if aiming else 0,delta*6)

func apply_touch_look(relative: Vector2) -> void:
	if showcase or not game.is_playing(): return
	var sensitivity: float = float(game.profile.data.settings.get("sensitivity",1.0))
	yaw -= relative.x*0.0035*sensitivity
	pitch = clampf(pitch-relative.y*0.0035*sensitivity,-0.85,0.85)

func cancel_draw() -> void:
	drawing=false;aim_held=false;touch_aim=false;draw_elapsed=0;controller_drawing=false
	game.draw_amount=0
	if is_instance_valid(anim_player):_play_pose("idle")

func _bone_world(bone: int) -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone)

func _update_equipment() -> void:
	if not is_inside_tree() or not skeleton.is_inside_tree(): return
	if left_hand < 0 or right_hand < 0 or not is_instance_valid(bow_hand_node): return
	skeleton.force_update_bone_child_transform(left_hand)
	skeleton.force_update_bone_child_transform(right_hand)
	var left := _bone_world(left_hand)
	solved_left = left.origin
	solved_right = _bone_world(right_hand).origin
	var right := _bone_world(right_finger if right_finger >= 0 else right_hand)
	var middle := skeleton.find_bone(bone_names.get("leftMiddleProximal","J_Bip_L_Middle1"))
	if middle >= 0: left.origin = left.origin.lerp(_bone_world(middle).origin,0.55)
	var scale_value := 0.68
	var basis := (left.basis.orthonormalized()*palm_binding).scaled(Vector3.ONE*scale_value)
	bow_hand_node.global_transform = Transform3D(basis,left.origin)
	var pull := bow_string_rest
	if drawing or aim_held or touch_aim: pull = bow_hand_node.to_local(right.origin)
	bow_string_node.mesh = _build_bowstring_mesh(bow_tip_top,pull,bow_tip_bot)
	nock_world = bow_hand_node.to_global(pull)
	bow_arrow_node.visible = (drawing or aim_held or touch_aim) and shot_cooldown <= 0 and (showcase or game.arrows > 0 or game.power_armed)
	var shelf := bow_hand_node.global_position + Vector3.UP*0.035
	var direction := (shelf-nock_world).normalized() if nock_world.distance_to(bow_hand_node.global_position)>0.15 else -visuals.global_basis.z
	var y_axis := direction.normalized(); var x_axis := y_axis.cross(Vector3.UP).normalized(); var z_axis := x_axis.cross(y_axis).normalized()
	bow_arrow_node.global_transform = Transform3D(Basis(x_axis*arrow_mesh_scale.x,y_axis*arrow_mesh_scale.y,z_axis*arrow_mesh_scale.z),nock_world+direction*(-bow_arrow_node.mesh.get_aabb().position.y*arrow_mesh_scale.y))

func _build_bowstring_mesh(top: Vector3, pull: Vector3, bottom: Vector3, _radius: float = 0.003) -> ArrayMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(top); mesh.surface_add_vertex(pull); mesh.surface_add_vertex(pull); mesh.surface_add_vertex(bottom)
	mesh.surface_end()
	var arrays := mesh.surface_get_arrays(0)
	var result := ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,arrays)
	return result

func instant_shoot() -> void:
	if not game.is_playing() or shot_cooldown > 0: return
	if not game.power_armed and game.arrows <= 0: return
	draw_elapsed=game.profile.draw_time()
	_fire()

func _fire() -> void:
	drawing=false
	var ability:Dictionary=game.begin_volley()
	if ability.is_empty():return
	var fraction:float=clampf(draw_elapsed/game.profile.draw_time(),0.4,1)
	var from:Vector3=camera.project_ray_origin(get_viewport().get_visible_rect().size*0.5)
	var direction:Vector3=camera.project_ray_normal(get_viewport().get_visible_rect().size*0.5)
	var query:=PhysicsRayQueryParameters3D.create(from,from+direction*200,1|4);query.exclude=[get_rid()]
	var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	var target:Vector3=hit.position if not hit.is_empty() else from+direction*80
	var spawn:Vector3=nock_world+direction
	if spawn.distance_to(global_position)>3:spawn=global_position+Vector3(0,1.4,0)
	var is_power_shot: bool = (str(ability.get("key", "normal")) != "normal")
	for arrow_index in range(int(ability.ammo)):
		if not is_power_shot:
			if not game.consume_arrow(): break
		else:
			game.shots += 1
			game.airborne += 1
		var projectile:=Projectile.new();projectile.owner_body=self;projectile.game=game
		projectile.arrow_id=int(game.profile.data.equipped_arrow)
		projectile.mesh_path=Catalog.ARROWS[projectile.arrow_id].mesh
		projectile.power=game.profile.power()*fraction*float(ability.damage);projectile.wind=game.current_wind()
		projectile.ability=ability.duplicate(true);projectile.shot_id=game.shot_serial*10+arrow_index
		projectile.score_id=str(ability.volley_id)+":arrow:"+str(arrow_index)
		game.stage.add_child(projectile)

		# Spawn multi-arrows in a tight line directly aligned toward the target pointer
		var arrow_spawn: Vector3 = spawn - direction * (float(arrow_index) * 0.40)
		projectile.global_position = arrow_spawn
		var speed:float=game.profile.flight_speed()*float(ability.speed)*lerpf(0.65,1,fraction)
		var acceleration:=Vector3(projectile.wind,-9.8,0)
		var offset:Vector3=target-arrow_spawn
		var shot_velocity:Vector3=offset.normalized()*speed
		if bool(game.profile.data.settings.get("assist",true)):
			var a:float=0.25*acceleration.length_squared();var b:float=-(offset.dot(acceleration)+speed*speed)
			var discriminant:float=b*b-4*a*offset.length_squared()
			if discriminant>=0:
				var flight_time:float=sqrt((-b-sqrt(discriminant))/(2*a))
				if flight_time>0.001:shot_velocity=offset/flight_time-0.5*acceleration*flight_time
		projectile.velocity=shot_velocity
		var v_dir: Vector3 = shot_velocity.normalized()
		var up_vec: Vector3 = Vector3.FORWARD if absf(v_dir.dot(Vector3.UP)) > 0.98 else Vector3.UP
		projectile.look_at(arrow_spawn+shot_velocity, up_vec)
	shot_cooldown=anim_player.get_animation("shared/release").length;_play_pose("release")
	game.play_sound("res://sounds/bow_release.wav");game.play_sound("res://sounds/arrow_swoosh.wav")

func _setup_user_animations() -> void:
	var common := AnimationLibrary.new()
	var skeleton_path := str(char_model.get_path_to(skeleton))
	var a1: AnimationLibrary = load("res://A1.fbx")
	var a2: AnimationLibrary = load("res://A2.fbx")
	for pair in [["idle","Idle",a1],["walk","Walk",a1],["jog","Jog_Fwd",a1],["run","Sprint",a2]]:
		for source_name in pair[2].get_animation_list():
			if not str(source_name).ends_with("|"+str(pair[1])): continue
			var animation: Animation = pair[2].get_animation(source_name).duplicate(true)
			var track := 0
			while track < animation.get_track_count():
				var bone_name := str(animation.track_get_path(track)).get_slice(":",1)
				if skeleton.find_bone(bone_name)<0:
					animation.remove_track(track);continue
				if animation.track_get_type(track)==Animation.TYPE_SCALE_3D:
					animation.remove_track(track);continue
				if animation.track_get_type(track)==Animation.TYPE_ROTATION_3D and character_id==2:
					_retarget_maki_rotation(animation,track)
				if animation.track_get_type(track)==Animation.TYPE_POSITION_3D:
					if bone_name!="Hips":animation.remove_track(track);continue
					_normalize_hip_track(animation,track)
				animation.track_set_path(track,NodePath(skeleton_path+":"+bone_name));track+=1
			animation.loop_mode=Animation.LOOP_LINEAR
			common.add_animation(pair[0],animation)
			break
	var archery: AnimationLibrary = load("res://Archer/X bow.fbx")
	for pair in [["idle","Armature|mixamo_com_007"],["draw","Armature|mixamo_com_006"],["aim","Armature|mixamo_com"],["release","Armature|mixamo_com_001"]]:
		var animation: Animation = archery.get_animation(pair[1]).duplicate(true)
		var track := 0
		while track < animation.get_track_count():
			var bone_name := str(animation.track_get_path(track)).get_slice(":",1)
			if skeleton.find_bone(bone_name)<0:
				animation.remove_track(track);continue
			if animation.track_get_type(track)==Animation.TYPE_SCALE_3D:
				animation.remove_track(track);continue
			if animation.track_get_type(track)==Animation.TYPE_ROTATION_3D and character_id==2:
				_retarget_maki_rotation(animation,track)
			if animation.track_get_type(track)==Animation.TYPE_POSITION_3D:
				if bone_name!="Hips":animation.remove_track(track);continue
				_normalize_hip_track(animation,track)
			animation.track_set_path(track,NodePath(skeleton_path+":"+bone_name));track+=1
		animation.loop_mode=Animation.LOOP_LINEAR if pair[0] in ["idle","aim"] else Animation.LOOP_NONE
		animation.resource_name="X bow · "+pair[0]
		if common.has_animation(pair[0]):common.remove_animation(pair[0])
		common.add_animation(pair[0],animation)
	if anim_player.has_animation_library("shared"):anim_player.remove_animation_library("shared")
	anim_player.add_animation_library("shared",common)
	# Retain the user-attached libraries, but remove unresolved Armature tracks
	# from instance copies so previews and runtime generate no warning spam.
	for library_name in anim_player.get_animation_library_list():
		if library_name=="shared":continue
		anim_player.remove_animation_library(library_name)

func _normalize_hip_track(animation:Animation,track:int) -> void:
	# Keep vertical knee/stance movement while removing all forward root motion.
	var rest:Vector3=skeleton.get_bone_rest(skeleton.find_bone("Hips")).origin
	for key in range(animation.track_get_key_count(track)):
		var original:Vector3=animation.track_get_key_value(track,key)
		animation.track_set_key_value(track,key,Vector3(rest.x,original.y*rest.y,rest.z))

func _calibrate_palm_binding() -> void:
	var animation:Animation=anim_player.get_animation("shared/aim")
	skeleton.reset_bone_poses()
	for track in range(animation.get_track_count()):
		var bone:=skeleton.find_bone(str(animation.track_get_path(track)).get_slice(":",1))
		if bone<0:continue
		if animation.track_get_type(track)==Animation.TYPE_ROTATION_3D:skeleton.set_bone_pose_rotation(bone,animation.rotation_track_interpolate(track,0))
		elif animation.track_get_type(track)==Animation.TYPE_POSITION_3D:skeleton.set_bone_pose_position(bone,animation.position_track_interpolate(track,0))
	skeleton.force_update_all_bone_transforms()
	var left:=_bone_world(left_hand)
	var right:=_bone_world(right_finger if right_finger>=0 else right_hand)
	var ideal:=Basis.looking_at((left.origin-right.origin).normalized(),Vector3.UP)*Basis(Vector3.UP,PI)
	palm_binding=left.basis.orthonormalized().inverse()*ideal
	skeleton.reset_bone_poses()


func _prepare_maki_retarget() -> void:
	var reference:Node3D=load("res://campaign/characters/Enola.tscn").instantiate()
	var standard:Skeleton3D=reference.find_child("GeneralSkeleton",true,false)
	var facing:=Basis(Vector3.UP,PI)
	for index in range(skeleton.get_bone_count()):
		var name:String=skeleton.get_bone_name(index)
		var source:int=standard.find_bone(name)
		if source<0:continue
		maki_retarget[name]=(standard.get_bone_global_rest(source).basis.inverse()*facing*skeleton.get_bone_global_rest(index).basis).get_rotation_quaternion()
	reference.free()

func _retarget_maki_rotation(animation:Animation,track:int) -> void:
	var name:String=str(animation.track_get_path(track)).get_slice(":",1)
	var bone:int=skeleton.find_bone(name)
	if bone<0 or not maki_retarget.has(name):return
	var parent:int=skeleton.get_bone_parent(bone)
	var parent_turn:Quaternion=maki_retarget.get(skeleton.get_bone_name(parent),Quaternion(Vector3.UP,PI)) if parent>=0 else Quaternion(Vector3.UP,PI)
	var bone_turn:Quaternion=maki_retarget[name]
	for key in range(animation.track_get_key_count(track)):
		var rotation:Quaternion=animation.track_get_key_value(track,key)
		animation.track_set_key_value(track,key,(parent_turn.inverse()*rotation*bone_turn).normalized())
