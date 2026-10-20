class_name FallState
extends LimboState

var next_state_name: String = "Inactive fall"

func _enter() -> void:
	var prev = agent.get_previous_state()
	if prev == "inactive" or prev == "Inactive":
		next_state_name = "Inactive fall"
	else:
		next_state_name = "Active fall"
	if agent.animation_tree:
		agent.animation_tree.state_transition(next_state_name)

func _exit() -> void:
	pass

func _update(delta: float) -> void:
	if not agent.is_on_floor():
		agent.velocity.y -= 19.6 * delta
	else:
		agent.velocity.y = 0.0
	agent.move_and_slide()
	
	if agent.is_on_floor():
		if next_state_name == "Inactive fall":
			agent.change_state(self, "to_inactive")
		else:
			agent.change_state(self, "to_active")
