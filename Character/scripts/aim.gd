class_name AimState
extends LimboState

var is_falling: bool = false
var can_shoot: bool = true
var fall_timer: float = 0.0
var entered_by_hold: bool = false
var trigger_source: String = "right_mouse" # "left_mouse", "right_mouse", "left_key"
var min_aim_time: float = 0.0
var rmb_press_time: float = 0.0

func _enter() -> void:
	if agent:
		agent.is_ads_aim = true
		if agent.has_method("set_bow_visible"):
			agent.set_bow_visible(true)
		if agent.anim_player:
			if agent.anim_player.has_animation("standing_aim_overdraw_upright"):
				agent.anim_player.play("standing_aim_overdraw_upright", 0.15)
			elif agent.anim_player.has_animation("standing aim overdraw"):
				agent.anim_player.play("standing aim overdraw", 0.15)
		if agent.camera_manager:
			agent.camera_manager.set_fire()
		if agent.aim_reticle:
			agent.aim_reticle.set_mode(agent.aim_reticle.ReticleMode.ADS_AIM)
		if agent.snd_bow_draw and agent.snd_bow_draw.stream:
			agent.snd_bow_draw.pitch_scale = randf_range(0.98, 1.02)
			agent.snd_bow_draw.play()
			
	is_falling = false
	can_shoot = true
	fall_timer = 0.0
	min_aim_time = 0.10
	rmb_press_time = Time.get_ticks_msec() / 1000.0

func _exit() -> void:
	if agent:
		agent.is_ads_aim = false
		if agent.camera_manager:
			agent.camera_manager.set_active_state()
		if agent.aim_reticle:
			agent.aim_reticle.set_mode(agent.aim_reticle.ReticleMode.HIP_FIRE if agent.is_bow_drawn else agent.aim_reticle.ReticleMode.HIDDEN)
		if agent.snd_bow_draw and agent.snd_bow_draw.playing:
			agent.snd_bow_draw.stop()

func _update(delta: float) -> void:
	if not agent.is_active_player:
		agent.set_velocity_idle(delta)
		return

	check_fall(delta)
	
	agent.face_camera_direction(delta * 2.5)
	
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward")
	if input_dir == Vector2.ZERO:
		var left = 1.0 if (Input.is_key_pressed(KEY_A) or (Input.is_key_pressed(KEY_LEFT) and trigger_source != "left_key")) else 0.0
		var right = 1.0 if (Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) else 0.0
		var fwd = 1.0 if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0
		var bwd = 1.0 if (Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0
		input_dir = Vector2(right - left, bwd - fwd)
	
	agent.update_locomotion_animation(input_dir, false, delta)
	
	if input_dir.length() > 0.001:
		agent.set_strafe_velocity(input_dir, delta)
	else:
		agent.set_velocity_idle(delta)
		
	if min_aim_time > 0.0:
		min_aim_time -= delta
		return
	
	# Case 1: Entered by holding Left Mouse Button
	if entered_by_hold or trigger_source == "left_mouse":
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_action_pressed("shoot"):
			if can_shoot:
				can_shoot = false
				if agent.has_method("shoot_arrow"):
					agent.shoot_arrow()
			agent.change_state(self, "to_active")
			return
			
	# Case 2: Entered by holding Left Key (KEY_LEFT)
	elif trigger_source == "left_key":
		if not Input.is_key_pressed(KEY_LEFT):
			if can_shoot:
				can_shoot = false
				if agent.has_method("shoot_arrow"):
					agent.shoot_arrow()
			agent.change_state(self, "to_active")
			return
			
	# Case 3: Right Click (RMB) aim mode
	else:
		# Left Click shoots while in ADS
		if Input.is_action_just_pressed("shoot") or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot):
			if can_shoot:
				can_shoot = false
				if agent.has_method("shoot_arrow"):
					agent.shoot_arrow()
					
				await get_tree().create_timer(0.28).timeout
				if not is_inside_tree():
					return
					
				if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_action_pressed("aim"):
					if agent.anim_player:
						if agent.anim_player.has_animation("standing_aim_overdraw_upright"):
							agent.anim_player.play("standing_aim_overdraw_upright", 0.15)
					if agent.snd_bow_draw and agent.snd_bow_draw.stream:
						agent.snd_bow_draw.pitch_scale = randf_range(0.98, 1.02)
						agent.snd_bow_draw.play()
					can_shoot = true
				else:
					agent.change_state(self, "to_active")
					return
		
		# Right Click release handling:
		var hold_time = (Time.get_ticks_msec() / 1000.0) - rmb_press_time
		if hold_time > 0.22 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_action_pressed("aim"):
			agent.change_state(self, "to_active")
			return
		elif Input.is_action_just_pressed("aim" ) and hold_time > 0.22:
			agent.change_state(self, "to_active")
			return

func check_fall(delta: float) -> void:
	if not agent.is_on_floor():
		fall_timer += delta
		if fall_timer > 0.35 and agent.velocity.y < -3.5:
			agent.change_state(self, "to_fall")
	else:
		fall_timer = 0.0
