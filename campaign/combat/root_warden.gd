extends "res://campaign/combat/enemy_base.gd"

var torso_mesh: MeshInstance3D
var chest_knot: Node3D
var arm_left: Node3D
var arm_right: Node3D

func _init() -> void:
	family="root_warden"
	hp = 166.0 # Miniboss HP
	max_hp = 166.0
	attack_damage = 22.0
	move_speed = 1.8
	windup_time = 1.20
	active_time = 0.20
	recovery_time = 1.8
	attack_range = 2.5

func _build_visuals() -> void:
	install_reference_model()
	chest_knot = body_mesh.find_child("ChestKnot",true,false)
	arm_left = body_mesh.find_child("ArmLeft",true,false)
	arm_right = body_mesh.find_child("ArmRight",true,false)

func _build_telegraph() -> void:
	# Root Warden has a 2.5m ground slam warning radius
	telegraph_mesh = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.5
	cylinder.bottom_radius = 2.5
	cylinder.height = 0.05
	telegraph_mesh.mesh = cylinder
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.45, 0.15, 0.5) # Intense amber/orange warning
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color("f57c00")
	mat.emission_energy_multiplier = 1.8
	telegraph_mesh.material_override = mat
	telegraph_mesh.visible = false
	add_child(telegraph_mesh)
