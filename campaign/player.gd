extends CharacterBody3D

signal attack_release(power_key:String,quick:bool)

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
var empty_aim_latched:=false
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
var current_hp := 100.0
var max_hp := 100.0
var is_dodging := false
const DODGE_DURATION:=0.40
const DODGE_DISTANCE:=2.60
const DODGE_COOLDOWN:=1.20
const JUMP_SPEED:=6.0
const JUMP_GRAVITY:=18.0
const JUMP_COYOTE_TIME:=0.12
const JUMP_BUFFER_TIME:=0.14
const JUMP_START_DURATION:=0.16
const JUMP_LAND_DURATION:=0.18
var is_jumping:=false
var jump_coyote_left:=0.0
var jump_buffer_left:=0.0
var jump_start_left:=0.0
var jump_land_left:=0.0
var jump_input_held:=false
var controller_jump_held:=false
var last_move_dir:=Vector3.ZERO
var controller_dodge_held:=false
var release_pose_name:="release"
var controller_trigger_held:=false
var quick_release_left:=0.0
var dodge_timer := 0.0
var dodge_cooldown := 0.0
var is_invulnerable := false
var dodge_dir := Vector3.ZERO
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
var arrow_tip_world := Vector3.ZERO
var arrow_direction := Vector3.FORWARD
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
	if not is_instance_valid(anim_player): return
	var draw_t: float = game.profile.draw_time() if (is_instance_valid(game) and "profile" in game and is_instance_valid(game.profile)) else 1.2
	if kind.begins_with("draw") and anim_player.has_animation("shared/"+kind):anim_player.speed_scale=anim_player.get_animation("shared/"+kind).length/draw_t
	elif kind=="dodge" and anim_player.has_animation("shared/dodge"):anim_player.speed_scale=anim_player.get_animation("shared/dodge").length/DODGE_DURATION
	elif kind=="jump_start" and anim_player.has_animation("shared/jump_start"):anim_player.speed_scale=anim_player.get_animation("shared/jump_start").length/JUMP_START_DURATION
	elif kind=="land" and anim_player.has_animation("shared/land"):anim_player.speed_scale=anim_player.get_animation("shared/land").length/JUMP_LAND_DURATION
	else:anim_player.speed_scale=1.0
	if anim_player.has_animation("shared/" + kind):
		anim_player.play("shared/"+kind,.06 if kind=="dodge" or kind.begins_with("release") else .16)

func interact() -> void:
	if not showcase: return
	showcase_timer = 2.2
	draw_elapsed = 0
	drawing = true
	_play_pose("draw")
	game.play_sound("res://sounds/bow_draw.wav")

func set_showcase(value: bool) -> void:
	showcase = value
	last_move_dir=Vector3.ZERO;controller_dodge_held=false;controller_trigger_held=false;controller_drawing=false
	touch_aim=false;empty_aim_latched=false
	quick_release_left=0;is_dodging=false;dodge_timer=0;dodge_cooldown=0;is_invulnerable=false
	_reset_jump_state()
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_Q and game.is_combat():
			start_dodge()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT and not game.power_charge_source.is_empty():return
		if event.button_index==MOUSE_BUTTON_RIGHT:
			if not event.pressed:empty_aim_latched=false
			aim_held=event.pressed and game.arrows>0 and not empty_aim_latched
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if aim_held or touch_aim:_start_draw()
				else:instant_shoot()
			elif drawing: _fire()
			get_viewport().set_input_as_handled()

func _start_draw() -> void:
	if shot_cooldown > 0: return
	if game.arrows<=0 or is_dodging or current_hp<=0:return
	drawing = true; draw_elapsed = 0
	_play_pose("draw")
	game.play_sound("res://sounds/bow_draw.wav")

func _physics_process(delta: float) -> void:
	if not showcase and is_instance_valid(game) and not game.is_playing():
		reset_jump_input()
		return
	if not showcase and current_hp<=0:
		_reset_jump_state();is_dodging=false;is_invulnerable=false;velocity=Vector3.ZERO
		return
	shot_cooldown = maxf(0,shot_cooldown-delta)
	quick_release_left=maxf(0,quick_release_left-delta)
	if dodge_cooldown > 0:
		dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	sway_time += delta
	if showcase:
		showcase_timer = maxf(0,showcase_timer-delta)
		var draw_t: float = game.profile.draw_time() if (is_instance_valid(game) and "profile" in game and is_instance_valid(game.profile)) else 1.2
		if showcase_timer > 0:
			draw_elapsed += delta
			drawing = true
			if draw_elapsed > draw_t: _play_pose("aim")
		else: drawing = false; _play_pose("idle")
		_update_goals(delta,drawing)
		if is_instance_valid(game) and "profile" in game and is_instance_valid(game.profile) and game.profile.data.settings.get("reduced_motion",false) and not drawing and is_instance_valid(anim_player): anim_player.speed_scale = 0
		return
	if is_instance_valid(game) and not game.is_playing(): return
	var jump_pressed:bool=Input.is_action_pressed("jump")
	if jump_pressed and not jump_input_held:request_jump()
	jump_input_held=jump_pressed
	if not Input.get_connected_joypads().is_empty():
		var joy: int = Input.get_connected_joypads()[0]
		var look := Vector2(Input.get_joy_axis(joy,JOY_AXIS_RIGHT_X),Input.get_joy_axis(joy,JOY_AXIS_RIGHT_Y))
		if look.length() > 0.15: yaw -= look.x*delta*2.4; pitch = clampf(pitch-look.y*delta*1.8,-0.9,0.9)
		var trigger := Input.get_joy_axis(joy,JOY_AXIS_TRIGGER_RIGHT) > 0.35
		var left_held:bool=Input.get_joy_axis(joy,JOY_AXIS_TRIGGER_LEFT)>.35
		if not left_held:empty_aim_latched=false
		aim_held=left_held and not empty_aim_latched and game.arrows>0
		var dodge_pressed:bool=Input.is_joy_button_pressed(joy,JOY_BUTTON_B)
		if game.is_combat() and dodge_pressed and not controller_dodge_held:start_dodge()
		controller_dodge_held=dodge_pressed
		var jump_button:bool=Input.is_joy_button_pressed(joy,JOY_BUTTON_A)
		if jump_button and not controller_jump_held:request_jump()
		controller_jump_held=jump_button
		if trigger and not controller_trigger_held and game.power_charge_source.is_empty():
			if aim_held:_start_draw();controller_drawing=drawing
			else:instant_shoot()
		controller_trigger_held=trigger
		if not trigger and controller_drawing: controller_drawing = false; _fire()
	else:controller_jump_held=false
	if game.arrows<=0:clear_empty_aim()
	var aiming:bool=not is_dodging and game.arrows>0 and (drawing or aim_held or touch_aim)
	if drawing: draw_elapsed += delta
	var draw_t: float = game.profile.draw_time() if (is_instance_valid(game) and "profile" in game and is_instance_valid(game.profile)) else 1.2
	if is_instance_valid(game): game.draw_amount = clampf(draw_elapsed/draw_t,0,1) if drawing else 0
	var stability: float = game.profile.stability() if (is_instance_valid(game) and "profile" in game and is_instance_valid(game.profile)) else 1.0
	var sway: float = 0.0028 * stability * (1+maxf(0,draw_elapsed-2)) if drawing else 0
	if is_instance_valid(camera_pivot):
		camera_pivot.rotation.y = yaw + sin(sway_time*1.6)*sway
		camera_pivot.position = camera_pivot.position.lerp(Vector3(0.47,rig_height*0.86,0),1-exp(-10*delta))
	if is_instance_valid(spring_arm):
		spring_arm.rotation.x = pitch + cos(sway_time*1.3)*sway
	var is_power_charging: bool = is_instance_valid(game) and game.power_armed and drawing and game.selected_power != "normal"
	var is_sniper:bool=stationary and not game.is_combat()
	var target_fov: float = ((44.0 if game.draw_amount >= 0.95 else 50.0) if is_power_charging else (24.0 if (aiming and is_sniper) else (40.0 if aiming else 65.0)))
	var target_arm: float = (1.25 if is_power_charging else (0.58 if (aiming and is_sniper) else (0.82 if aiming else 3.5)))
	if is_instance_valid(spring_arm): spring_arm.spring_length = lerpf(spring_arm.spring_length, target_arm, 1-exp(-10*delta))
	if is_instance_valid(camera): camera.fov = lerpf(camera.fov, target_fov, 1-exp(-10*delta))
	var move := Vector3.ZERO
	var sprinting := false
	var was_grounded:bool=is_on_floor()
	jump_start_left=maxf(0,jump_start_left-delta)
	jump_land_left=maxf(0,jump_land_left-delta)
	jump_coyote_left=JUMP_COYOTE_TIME if was_grounded and not is_jumping and not is_dodging else maxf(0,jump_coyote_left-delta)
	if jump_buffer_left>0 and jump_coyote_left>0 and not is_dodging and not is_jumping:
		velocity.y=JUMP_SPEED
		is_jumping=true;jump_start_left=JUMP_START_DURATION;jump_land_left=0
		jump_buffer_left=0;jump_coyote_left=0
		game.play_sound("res://sounds/jump.wav",1,-14)
	elif was_grounded and velocity.y<=0:velocity.y=-0.2
	else:velocity.y-=JUMP_GRAVITY*delta
	jump_buffer_left=maxf(0,jump_buffer_left-delta)
	if is_dodging:
		dodge_timer = maxf(0.0, dodge_timer - delta)
		var elapsed_dodge:float=DODGE_DURATION-dodge_timer
		is_invulnerable=(elapsed_dodge>=.05 and elapsed_dodge<=.25)
		var speed:float=(DODGE_DISTANCE/DODGE_DURATION)*(1.35-.70*clampf(elapsed_dodge/DODGE_DURATION,0,1))
		velocity.x=dodge_dir.x*speed
		velocity.z=dodge_dir.z*speed
		move_and_slide()
		if dodge_timer <= 0:
			is_dodging = false
			is_invulnerable = false
	else:
		var input_dir:Vector2=_movement_input()
		if input_dir.length()>.1:last_move_dir=Vector3(input_dir.x,0,input_dir.y).rotated(Vector3.UP,yaw).normalized()
		if (stationary or aiming) and not game.is_combat():
			velocity.x = 0; velocity.z = 0
		elif aiming:
			# 2.0 m/s aiming strafe (Combat contract)
			move = Vector3(input_dir.x,0,input_dir.y).rotated(Vector3.UP,yaw)
			velocity.x = move.x * 2.0; velocity.z = move.z * 2.0
		else:
			sprinting = (Input.is_action_pressed("sprint") or touch_sprint)
			var speed := 6.8 if sprinting else 4.5
			move = Vector3(input_dir.x,0,input_dir.y).rotated(Vector3.UP,yaw)
			velocity.x = move.x * speed; velocity.z = move.z * speed
		move_and_slide()
	if is_on_floor() and (is_jumping or not was_grounded):
		is_jumping=false;jump_start_left=0;jump_land_left=JUMP_LAND_DURATION
		game.play_sound("res://sounds/land.wav",1,-16)
	if is_dodging:
		visuals.rotation.y=atan2(-dodge_dir.x,-dodge_dir.z)
		_play_pose("dodge")
	elif not is_on_floor():
		if aiming or quick_release_left>0:visuals.rotation.y=lerp_angle(visuals.rotation.y,yaw,1-exp(-24*delta))
		elif move.length()>.1:visuals.rotation.y=lerp_angle(visuals.rotation.y,atan2(-move.x,-move.z),1-exp(-12*delta))
		_play_pose("jump_start" if jump_start_left>0 else ("jump" if velocity.y>0 else "fall"))
	elif jump_land_left>0:
		_play_pose("land")
	elif quick_release_left>0:
		visuals.rotation.y=lerp_angle(visuals.rotation.y,yaw,1-exp(-24*delta))
		var moving:bool=_movement_input().length()>.1
		release_pose_name="release_run" if moving and (Input.is_action_pressed("sprint") or touch_sprint) else ("release_walk" if moving else "release")
		var release_time:float=anim_player.current_animation_position
		var switching_release:bool=last_pose!=release_pose_name and last_pose.begins_with("release")
		_play_pose(release_pose_name)
		if switching_release:anim_player.seek(release_time,true)
	elif aiming:
		visuals.rotation.y = yaw
		if shot_cooldown > 0: _play_pose("release")
		elif drawing and draw_elapsed < game.profile.draw_time(): _play_pose("draw_walk" if move.length()>.1 else "draw")
		else: _play_pose("aim_walk" if move.length()>.1 else "aim")
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
		_reset_jump_state();is_dodging=false;is_invulnerable=false;dodge_timer=0
		game.time_left = maxf(0,game.time_left-3); game.feedback("Returned to the course · 3 second penalty")

func _update_goals(delta: float, aiming: bool) -> void:
	# The supplied X bow clips drive the complete archery stance and both hands.
	aim_blend=move_toward(aim_blend,1 if aiming or quick_release_left>0 else 0,delta*10)

func apply_touch_look(relative: Vector2) -> void:
	if showcase or not game.is_playing(): return
	var sensitivity: float = float(game.profile.data.settings.get("sensitivity",1.0))
	yaw -= relative.x*0.0035*sensitivity
	pitch = clampf(pitch-relative.y*0.0035*sensitivity,-0.85,0.85)

func cancel_draw() -> void:
	drawing=false;aim_held=false;touch_aim=false;draw_elapsed=0;controller_drawing=false
	if is_instance_valid(game): game.draw_amount=0;game.clear_power_hold()
	if is_instance_valid(anim_player) and (last_pose.begins_with("draw") or last_pose.begins_with("aim")):_play_pose("idle")

func request_jump() -> void:
	# All input devices submit one press; landing can consume it within this short window.
	if showcase or current_hp<=0 or is_dodging or not is_instance_valid(game) or not game.is_playing():return
	jump_buffer_left=JUMP_BUFFER_TIME

func reset_jump_input() -> void:
	jump_buffer_left=0;jump_coyote_left=0
	jump_input_held=Input.is_action_pressed("jump")
	controller_jump_held=false
	if not Input.get_connected_joypads().is_empty():
		controller_jump_held=Input.is_joy_button_pressed(Input.get_connected_joypads()[0],JOY_BUTTON_A)

func _reset_jump_state() -> void:
	reset_jump_input()
	is_jumping=false;jump_start_left=0;jump_land_left=0

func _bone_world(bone: int) -> Transform3D:
	if bone < 0 or not is_instance_valid(skeleton) or bone >= skeleton.get_bone_count():
		return Transform3D.IDENTITY
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
	arrow_direction = direction
	arrow_tip_world = nock_world + direction * 0.72
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
	if game.arrows<=0 or is_dodging or current_hp<=0 or not game.power_charge_source.is_empty():return
	draw_elapsed=game.profile.draw_time()
	_fire(true)

func _fire(quick:bool=false) -> void:
	if not game.is_playing() or current_hp<=0 or is_dodging or game.arrows<=0 or shot_cooldown>0 or not game.power_charge_source.is_empty():return
	if not quick and not drawing:return
	drawing=false
	var ability:Dictionary=game.begin_volley()
	if ability.is_empty():return
	var move_input:Vector2=_movement_input()
	release_pose_name="release_run" if move_input.length()>.1 and (Input.is_action_pressed("sprint") or touch_sprint) else ("release_walk" if move_input.length()>.1 else "release")
	visuals.rotation.y=yaw
	_play_pose(release_pose_name)
	# Quick input commits now; apply the authored bow pose before sampling its muzzle.
	anim_player.seek(0,true)
	skeleton.force_update_all_bone_transforms()
	_update_equipment()
	var fraction:float=clampf(draw_elapsed/game.profile.draw_time(),0.4,1)
	var from:Vector3=camera.project_ray_origin(get_viewport().get_visible_rect().size*0.5)
	var direction:Vector3=camera.project_ray_normal(get_viewport().get_visible_rect().size*0.5)
	var query:=PhysicsRayQueryParameters3D.create(from,from+direction*200,1|4|8);query.exclude=[get_rid()]
	var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	var target:Vector3=hit.position if not hit.is_empty() else from+direction*80
	var spawn:Vector3=nock_world+direction*.12
	if spawn.distance_to(global_position)>3:spawn=global_position+Vector3(0,1.4,0)
	var is_power_shot: bool = (str(ability.get("key", "normal")) != "normal")
	for arrow_index in range(int(ability.ammo)):
		var projectile:=Projectile.new();projectile.owner_body=self;projectile.game=game
		projectile.arrow_id=int(game.profile.data.equipped_arrow)
		projectile.mesh_path=Catalog.ARROWS[projectile.arrow_id].mesh
		var charge_mult: float = 1.35 if (is_power_shot and fraction >= 0.95) else 1.0
		projectile.power=game.profile.power()*fraction*float(ability.damage)*charge_mult;projectile.wind=game.current_wind()*(.5 if str(ability.key)=="gale" else 1.0)
		projectile.ability=ability.duplicate(true);projectile.ability.vfx_primary=arrow_index==0;projectile.ability.draw_ratio=0.0 if quick else fraction;projectile.shot_id=game.shot_serial*10+arrow_index
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
	var release_length:float=anim_player.get_animation("shared/release").length
	shot_cooldown=minf(.42 if quick else .50,release_length)
	quick_release_left=minf(.48,release_length)
	_play_pose(release_pose_name)
	game.play_sound("res://sounds/bow_release.wav",1,-12)
	if not is_power_shot:game.play_sound("res://sounds/arrow_swoosh.wav",1,-12)
	if is_power_shot:
		var kick_dir := direction.normalized()
		kick_dir.y = 0.0
		velocity -= kick_dir * (5.5 if fraction >= 0.95 else 2.5)
		if game.has_method("play_power_sound"):
			game.play_power_sound(str(ability.get("key", "normal")))
		if not game.profile.data.settings.get("reduced_motion",false):
			apply_shockwave_shake(0.12 if fraction >= 0.95 else 0.08)
	attack_release.emit(str(ability.get("key","normal")),quick)

func apply_shockwave_shake(trauma: float = 0.5) -> void:
	if not is_instance_valid(camera): return
	var tw := create_tween()
	var orig_fov: float = camera.fov
	tw.tween_property(camera, "fov", orig_fov - trauma * 3.5, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera, "fov", orig_fov, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var rot_tw := create_tween()
	var rot_offset := randf_range(-0.02, 0.02) * trauma
	rot_tw.tween_property(camera, "rotation:z", rot_offset, 0.04)
	rot_tw.tween_property(camera, "rotation:z", 0.0, 0.18)

func _setup_user_animations() -> void:
	var common := AnimationLibrary.new()
	var skeleton_path := str(char_model.get_path_to(skeleton))
	var a1: AnimationLibrary = load("res://A1.fbx")
	var a2: AnimationLibrary = load("res://A2.fbx")
	for pair in [["idle","Idle",a1],["walk","Walk",a1],["jog","Jog_Fwd",a1],["run","Sprint",a2],["dodge","Roll",a1],["jump_start","Jump_Start",a1],["jump","Jump",a1],["fall","Jump",a1],["land","Jump_Land",a1]]:
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
			animation.loop_mode=Animation.LOOP_NONE if pair[0] in ["dodge","jump_start","land"] else Animation.LOOP_LINEAR
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
	_build_release_locomotion(common)
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
	var target_vec: Vector3 = left.origin - right.origin
	if target_vec.length_squared() < 0.0001:
		skeleton.reset_bone_poses()
		return
	var ideal:=Basis.looking_at(target_vec.normalized(),Vector3.UP)*Basis(Vector3.UP,PI)
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

func _movement_input() -> Vector2:
	var direction:Vector2=Input.get_vector("move_left","move_right","move_forward","move_backward")
	if touch_move.length()>.05:direction=touch_move.limit_length()
	if not Input.get_connected_joypads().is_empty():
		var joy:int=Input.get_connected_joypads()[0]
		var stick:=Vector2(Input.get_joy_axis(joy,JOY_AXIS_LEFT_X),Input.get_joy_axis(joy,JOY_AXIS_LEFT_Y))
		if stick.length()>.18:direction=stick.limit_length()
	return direction

func _lower_body_bone(name:String) -> bool:
	return name in ["Hips","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot","LeftToes","RightToes"]

func _build_release_locomotion(library:AnimationLibrary) -> void:
	# Keep the authored bow action in the upper body while the legs continue a real step.
	for pair in [["release","walk"],["release","run"],["draw","walk"],["aim","walk"]]:
		var pose:String=pair[0]
		var gait:String=pair[1]
		if not library.has_animation(pose) or not library.has_animation(gait):continue
		var composite:Animation=library.get_animation(pose).duplicate(true)
		var index:int=0
		while index<composite.get_track_count():
			var bone:String=str(composite.track_get_path(index)).get_slice(":",1)
			if _lower_body_bone(bone):composite.remove_track(index)
			else:index+=1
		var locomotion:Animation=library.get_animation(gait)
		for track in range(locomotion.get_track_count()):
			var bone:String=str(locomotion.track_get_path(track)).get_slice(":",1)
			if not _lower_body_bone(bone):continue
			locomotion.copy_track(track,composite)
			var destination:int=composite.get_track_count()-1
			# Reinsert from the untouched gait; changing key times in place merges/reorders keys.
			for key in range(composite.track_get_key_count(destination)-1,-1,-1):composite.track_remove_key(destination,key)
			for key in range(locomotion.track_get_key_count(track)):
				var at:float=locomotion.track_get_key_time(track,key)/maxf(.001,locomotion.length)*composite.length
				composite.track_insert_key(destination,at,locomotion.track_get_key_value(track,key),locomotion.track_get_key_transition(track,key))
		composite.resource_name="Bow "+pose+" with "+gait
		library.add_animation(pose+"_"+gait,composite)

func start_dodge() -> void:
	if is_dodging or is_jumping or dodge_cooldown>0 or showcase or current_hp<=0 or not game.is_combat():return
	if not game.is_playing():return
	reset_jump_input();jump_start_left=0;jump_land_left=0
	cancel_draw();quick_release_left=0
	game.power_armed=false
	if is_instance_valid(game.touch_controller):game.touch_controller.aim=false
	is_dodging=true;dodge_timer=DODGE_DURATION;dodge_cooldown=DODGE_COOLDOWN;is_invulnerable=false
	var input_dir:Vector2=_movement_input()
	if input_dir.length()>.1:dodge_dir=Vector3(input_dir.x,0,input_dir.y).rotated(Vector3.UP,yaw).normalized()
	elif last_move_dir.length()>.1:dodge_dir=last_move_dir.normalized()
	else:dodge_dir=Vector3(sin(yaw),0,cos(yaw)).normalized()
	visuals.rotation.y=atan2(-dodge_dir.x,-dodge_dir.z)
	_play_pose("dodge")
	if game.has_method("play_sound"):game.play_sound("res://sounds/roll.wav")
	if game.has_method("feedback"):game.feedback("Dodge!")

func take_player_damage(amount: float, _source: Node3D = null) -> void:
	if is_invulnerable or current_hp<=0:
		return
	if is_instance_valid(game) and not game.is_playing():
		return
	current_hp = maxf(0.0, current_hp - amount)
	if is_instance_valid(game):
		if game.has_method("play_sound"): game.play_sound("res://sounds/body_hit.wav")
		if game.has_method("feedback"): game.feedback("💥 Took %.0f damage! HP: %.0f / %.0f" % [amount, current_hp, max_hp])
	if is_instance_valid(visuals) and is_inside_tree():
		var tween := create_tween()
		if tween:
			tween.tween_property(visuals, "scale", Vector3(1.08, 0.92, 1.08), 0.06)
			tween.tween_property(visuals, "scale", Vector3.ONE, 0.12)
	if current_hp <= 0.001 and is_instance_valid(game) and game.has_method("finish"):
		_reset_jump_state();is_dodging=false;is_invulnerable=false;dodge_timer=0
		cancel_draw();game.power_armed=false
		_resolve_fatal_damage.call_deferred()

func clear_empty_aim() -> void:
	empty_aim_latched=true
	# Empty quivers are checked every physics tick; only an active bow state needs cancelling.
	if drawing or aim_held or touch_aim or controller_drawing or draw_elapsed>0:cancel_draw()
	game.power_armed=false;game.clear_power_hold()
	if is_instance_valid(game.touch_controller):game.touch_controller.aim=false

func _resolve_fatal_damage() -> void:
	if current_hp<=0 and game.is_playing():game.finish(false,"Fallen in combat")
