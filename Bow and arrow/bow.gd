extends Node3D

enum BowStates { DRAW, RELEASE, IDLE }

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var bow_model: Node3D = $bow

func _ready() -> void:
	if animation_tree:
		animation_tree.active = true
	change_bow_state(BowStates.IDLE)

func change_bow_state(to_state: BowStates) -> void:
	if not animation_tree:
		return
	var state_name = get_bow_state_name(to_state)
	animation_tree.set("parameters/transition/transition_request", state_name)

func get_bow_state_name(to_state: BowStates) -> String:
	match to_state:
		BowStates.DRAW:
			return "draw"
		BowStates.RELEASE:
			return "release"
		_:
			return "idle"

func show_hide_bow(p_visible: bool) -> void:
	visible = p_visible

func align_arrow_to_bow(arrow_instance: Node3D) -> void:
	if not arrow_instance:
		return
	arrow_instance.position = Vector3(0.0, 0.05, 0.15)
	arrow_instance.rotation_degrees = Vector3(0, 0, 0)
