extends "res://campaign/combat/enemy_base.gd"

var squash_mesh: Node3D
var eye_left: MeshInstance3D
var eye_right: MeshInstance3D
var moss_cap: MeshInstance3D
var fern_tuft: Node3D

func _init() -> void:
	family="moss_slime"
	hp = 41.5
	max_hp = 41.5
	attack_damage = 12.0
	move_speed = 2.4
	windup_time = 0.75
	active_time = .42
	recovery_time = 1.35
	attack_range = 3.2
	leap_hit_radius=1.1
	leap_height=.75

func _build_visuals() -> void:
	install_reference_model()
	squash_mesh = body_mesh
	fern_tuft = body_mesh.find_child("Fern",true,false)

