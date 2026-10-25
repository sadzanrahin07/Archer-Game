extends "res://campaign/combat/enemy_base.gd"

var torso_mesh: MeshInstance3D
var tail_mesh: Node3D

func _init() -> void:
	family="bark_stalker"
	hp = 83.0
	max_hp = 83.0
	attack_damage = 16.0
	move_speed = 3.8
	windup_time = 0.85
	active_time = .38
	recovery_time = 1.35
	attack_range = 1.8

func _build_visuals() -> void:
	install_reference_model()
	tail_mesh = body_mesh.find_child("Tail",true,false)
