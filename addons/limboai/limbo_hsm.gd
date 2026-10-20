class_name LimboHSM
extends LimboState

signal state_changed(current: LimboState, previous: LimboState)

var active_state: LimboState = null
var previous_active_state: LimboState = null
var is_active: bool = false
var _transitions: Array = []

func initialize(p_agent: Node) -> void:
	agent = p_agent
	_init_children_agent(self, p_agent)

func _init_children_agent(node: Node, p_agent: Node) -> void:
	for child in node.get_children():
		if child is LimboState:
			child.agent = p_agent
			_init_children_agent(child, p_agent)

func set_active(p_active: bool) -> void:
	is_active = p_active

func change_active_state(new_state: LimboState) -> void:
	if active_state == new_state:
		return
	var prev = active_state
	if active_state:
		active_state._exit()
	previous_active_state = prev
	active_state = new_state
	if active_state:
		active_state._enter()
	state_changed.emit(active_state, previous_active_state)

func add_transition(from_state: LimboState, to_state: LimboState, event: StringName) -> void:
	_transitions.append({
		"from": from_state,
		"to": to_state,
		"event": event
	})

func dispatch(event: StringName) -> bool:
	for t in _transitions:
		if t["from"] == active_state and t["event"] == event:
			change_active_state(t["to"])
			return true
	return false

func get_previous_active_state() -> LimboState:
	return previous_active_state

func get_active_state() -> LimboState:
	return active_state

func _physics_process(delta: float) -> void:
	if is_active and active_state:
		active_state._update(delta)
