class_name CameraManager
extends Node3D

enum CameraStates { WALK, RUN, ACTIVE, FIRE }

@export var mouse_sensitivity: float = 0.0025
@export var transition_speed: float = 8.0

var current_state: CameraStates = CameraStates.WALK

var target_spring_length: float = 2.8
var target_fov: float = 70.0
var target_h_offset: float = 0.0
var target_v_offset: float = 0.0

var pitch: float = -0.1
var yaw: float = 0.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

func _ready() -> void:
	top_level = true
	set_camera_state(CameraStates.WALK)

func _unhandled_input(event: InputEvent) -> void:
	var p = get_parent()
	if p and "is_active_player" in p and not p.is_active_player:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-75.0), deg_to_rad(60.0))
		
		rotation.y = yaw
		spring_arm.rotation.x = pitch

func set_camera_state(new_state: CameraStates) -> void:
	current_state = new_state
	match new_state:
		CameraStates.WALK:
			target_spring_length = 2.8
			target_fov = 70.0
			target_h_offset = 0.0
			target_v_offset = 0.0
		CameraStates.RUN:
			target_spring_length = 3.6
			target_fov = 76.0
			target_h_offset = 0.0
			target_v_offset = 0.0
		CameraStates.ACTIVE:
			target_spring_length = 2.4
			target_fov = 68.0
			target_h_offset = 0.35
			target_v_offset = 0.1
		CameraStates.FIRE:
			target_spring_length = 1.35
			target_fov = 48.0
			target_h_offset = 0.52
			target_v_offset = 0.18

func _process(delta: float) -> void:
	var p = get_parent()
	if p is Node3D:
		global_position = p.global_position + Vector3(0, 1.45, 0)
	if not spring_arm or not camera:
		return
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_spring_length, transition_speed * delta)
	camera.fov = lerp(camera.fov, target_fov, transition_speed * delta)
	camera.h_offset = lerp(camera.h_offset, target_h_offset, transition_speed * delta)
	camera.v_offset = lerp(camera.v_offset, target_v_offset, transition_speed * delta)

func get_camera_3d() -> Camera3D:
	return camera

func set_walk() -> void:
	set_camera_state(CameraStates.WALK)

func set_run() -> void:
	set_camera_state(CameraStates.RUN)

func set_active_state() -> void:
	set_camera_state(CameraStates.ACTIVE)

func set_fire() -> void:
	set_camera_state(CameraStates.FIRE)
