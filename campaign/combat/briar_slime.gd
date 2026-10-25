extends "res://campaign/combat/enemy_base.gd"

var squash_mesh: Node3D
var thorn_buds: Array[MeshInstance3D] = []
var leap_start: Vector3
var leap_target: Vector3

func _init() -> void:
	family="briar_slime"
	hp = 62.25
	max_hp = 62.25
	attack_damage = 18.0
	move_speed = 2.0
	windup_time = 0.95
	active_time = .65
	recovery_time = 1.5
	attack_range = 4.4
	leap_hit_radius=1.35
	leap_height=1.25

func _build_visuals() -> void:
	install_reference_model()
	squash_mesh = body_mesh
