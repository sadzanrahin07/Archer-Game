class_name InactiveState
extends LimboState

var is_falling: bool = false
var fall_timer: float = 0.0

func _enter() -> void:
	if agent and agent.has_method("set_bow_visible"):
		agent.set_bow_visible(false)
	is_falling = false
	fall_timer = 0.0
	if agent and agent.camera_manager:
		agent.camera_manager.set_walk()

func _exit() -> void:
	pass

func _update(delta: float) -> void:
	if not agent.is_active_player:
		agent.set_velocity_idle(delta)
		return

	check_fall(delta)
	
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward")
	if input_dir == Vector2.ZERO:
		var left = 1.0 if (Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)) else 0.0
		var right = 1.0 if (Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) else 0.0
		var fwd = 1.0 if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0
		var bwd = 1.0 if (Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0
		input_dir = Vector2(right - left, bwd - fwd)
	
	var is_sprint = Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT)
	
	if input_dir.length() > 0.001:
		input_dir = input_dir.normalized()
		agent.rotation_based_on_camera(input_dir, delta)
		agent.set_walk_velocity(input_dir, is_sprint, delta)
		agent.update_locomotion_animation(input_dir, is_sprint, delta)
		
		if agent.camera_manager:
			if is_sprint:
				agent.camera_manager.set_run()
			else:
				agent.camera_manager.set_walk()
	else:
		agent.set_velocity_idle(delta)
		agent.update_locomotion_animation(Vector2.ZERO, false, delta)
		if agent.camera_manager:
			agent.camera_manager.set_walk()
	
	if Input.is_action_just_pressed("equip") or Input.is_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_F):
		agent.change_state(self, "to_active")

func check_fall(delta: float) -> void:
	if not agent.is_on_floor():
		fall_timer += delta
		if fall_timer > 0.35 and agent.velocity.y < -3.5:
			agent.change_state(self, "to_fall")
	else:
		fall_timer = 0.0
