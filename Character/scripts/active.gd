class_name ActiveState
extends LimboState

var is_falling: bool = false
var fall_timer: float = 0.0
var equip_timer: float = 0.0

var left_click_held: bool = false
var left_click_press_time: float = 0.0
var aim_activated_by_left_hold: bool = false

func _enter() -> void:
	if agent:
		agent.is_ads_aim = false
		if agent.has_method("set_bow_visible"):
			agent.set_bow_visible(true)
		if agent.camera_manager:
			agent.camera_manager.set_active_state()
		if agent.aim_reticle:
			agent.aim_reticle.set_mode(agent.aim_reticle.ReticleMode.HIP_FIRE)
		if agent.anim_player and agent.anim_player.has_animation("standing idle 01"):
			if agent.shoot_anim_timer <= 0.0:
				agent.anim_player.play("standing idle 01", 0.2)
			
	is_falling = false
	fall_timer = 0.0
	equip_timer = 0.0
	left_click_held = false
	aim_activated_by_left_hold = false

func _exit() -> void:
	left_click_held = false
	aim_activated_by_left_hold = false

func _update(delta: float) -> void:
	if not agent.is_active_player:
		agent.set_velocity_idle(delta)
		return

	check_fall(delta)
	
	if equip_timer > 0.0:
		equip_timer -= delta
		agent.set_velocity_idle(delta)
		return
	
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward")
	if input_dir == Vector2.ZERO:
		var left = 1.0 if (Input.is_key_pressed(KEY_A) or (Input.is_key_pressed(KEY_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))) else 0.0
		var right = 1.0 if (Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) else 0.0
		var fwd = 1.0 if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0
		var bwd = 1.0 if (Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0
		input_dir = Vector2(right - left, bwd - fwd)
	
	var is_sprint = Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT)
	
	if input_dir.length() > 0.001:
		input_dir = input_dir.normalized()
		if is_sprint:
			agent.rotation_based_on_camera(input_dir, delta)
			agent.set_walk_velocity(input_dir, true, delta)
		else:
			agent.face_camera_direction(delta)
			agent.set_strafe_velocity(input_dir, delta)
		
		if agent.camera_manager:
			if is_sprint:
				agent.camera_manager.set_run()
			else:
				agent.camera_manager.set_active_state()
	else:
		agent.set_velocity_idle(delta)
		if agent.camera_manager:
			agent.camera_manager.set_active_state()
			
	agent.update_locomotion_animation(input_dir, is_sprint, delta)
	
	# Left Click & Left Key (shoot/aim):
	# Tap / repeated clicks: Instant shoot without focus aiming
	# Hold for > 2.0 seconds: Focus aim activates!
	var left_btn_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("shoot")
	var left_key_pressed = Input.is_key_pressed(KEY_LEFT)
	var left_input_active = left_btn_pressed or left_key_pressed
	
	if left_input_active:
		if not left_click_held:
			left_click_held = true
			left_click_press_time = Time.get_ticks_msec() / 1000.0
			aim_activated_by_left_hold = false
		else:
			var dur = (Time.get_ticks_msec() / 1000.0) - left_click_press_time
			if dur >= 2.0:
				aim_activated_by_left_hold = true
				var aim_state = agent.aim as AimState
				if aim_state:
					aim_state.entered_by_hold = true
					aim_state.trigger_source = "left_key" if left_key_pressed else "left_mouse"
				agent.change_state(self, "to_aim")
				return
	else:
		if left_click_held:
			left_click_held = false
			if not aim_activated_by_left_hold:
				# Tapped / clicked under 2 seconds: Instant shot with full recoil!
				if agent.has_method("shoot_arrow_instant"):
					agent.shoot_arrow_instant()
	
	# Instant shot keyboard shortcut (F)
	if Input.is_key_pressed(KEY_F):
		if agent.has_method("shoot_arrow_instant"):
			agent.shoot_arrow_instant()
	
	# Direct Focus Aim via Right Click (MOUSE_BUTTON_RIGHT) or Action 'aim'
	var right_mouse_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_action_pressed("aim")
	if right_mouse_pressed:
		var aim_state = agent.aim as AimState
		if aim_state:
			aim_state.entered_by_hold = false
			aim_state.trigger_source = "right_mouse"
		agent.change_state(self, "to_aim")
	elif Input.is_action_just_pressed("equip") or Input.is_key_pressed(KEY_E):
		agent.change_state(self, "to_inactive")

func check_fall(delta: float) -> void:
	if not agent.is_on_floor():
		fall_timer += delta
		if fall_timer > 0.35 and agent.velocity.y < -3.5:
			agent.change_state(self, "to_fall")
	else:
		fall_timer = 0.0
