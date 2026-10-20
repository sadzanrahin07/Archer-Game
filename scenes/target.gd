class_name TargetDummy
extends StaticBody3D

@export var upper_limit: float = 0.0
@export var lower_limit: float = 5.0
@export var duration: float = 3.0
@export var move_node: bool = false
@export var move_vertical: bool = true

var start_pos: Vector3
var target_tween: Tween

func _ready() -> void:
	add_to_group("target")
	add_to_group("ArcheryTarget")
	start_pos = position
	if move_node:
		start_movement()

func start_movement() -> void:
	if target_tween and target_tween.is_valid():
		target_tween.kill()
	target_tween = create_tween().set_loops()
	var end_offset = Vector3(0, upper_limit - lower_limit, 0) if move_vertical else Vector3(upper_limit - lower_limit, 0, 0)
	target_tween.tween_property(self, "position", start_pos + end_offset, duration).set_trans(Tween.TRANS_SINE)
	target_tween.tween_property(self, "position", start_pos, duration).set_trans(Tween.TRANS_SINE)

func on_hit(hit_pos: Vector3, _arrow = null) -> void:
	print("Target hit at position: ", hit_pos)
