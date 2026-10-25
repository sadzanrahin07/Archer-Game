extends "res://campaign/combat/enemy_base.gd"

var stem_mesh: MeshInstance3D
var pod_muzzle: Node3D
var leaf_left: Node3D
var leaf_right: Node3D

const SeedScript = preload("res://campaign/combat/enemy_seed.gd")

func _init() -> void:
	family="seed_spitter"
	hp = 62.25
	max_hp = 62.25
	attack_damage = 12.0
	move_speed = 0.0 # Stationary rooted plant
	windup_time = 0.90
	active_time = 0.20
	recovery_time = 1.45
	attack_range = 14.0

func _build_visuals() -> void:
	install_reference_model()
	pod_muzzle = body_mesh.find_child("PodMuzzle",true,false)
	leaf_left = body_mesh.find_child("LeafLeft",true,false)
	leaf_right = body_mesh.find_child("LeafRight",true,false)

func _deliver_attack() -> void:
	if not is_instance_valid(target_player):
		return
	var seed_proj = SeedScript.new()
	get_parent().add_child(seed_proj)
	var shoot_origin: Vector3 = global_position + Vector3(0, 0.85, 0.35)
	var shoot_dir: Vector3 = (committed_target + Vector3(0, 0.8, 0)) - shoot_origin
	seed_proj.setup(shoot_origin, shoot_dir, self)
