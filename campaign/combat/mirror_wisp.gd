extends "res://campaign/combat/enemy_base.gd"

var central_pearl: Node3D
var facet_left: Node3D
var facet_right: Node3D
var pearl_surface: MeshInstance3D
var pearl_material: StandardMaterial3D

const DartScript = preload("res://campaign/combat/enemy_dart.gd")

func _init() -> void:
	family="mirror_wisp"
	hp = 62.25
	max_hp = 62.25
	attack_damage = 10.0
	move_speed = 2.6
	windup_time = 0.95
	active_time = 0.16
	recovery_time = 1.4
	attack_range = 14.0

func _build_visuals() -> void:
	install_reference_model()
	central_pearl = body_mesh.find_child("CentralPearl",true,false)
	facet_left = body_mesh.find_child("FacetLeft",true,false)
	facet_right = body_mesh.find_child("FacetRight",true,false)
	if is_instance_valid(central_pearl):
		pearl_surface = central_pearl.find_child("BatchedDetail",true,false)
		if is_instance_valid(pearl_surface) and pearl_surface.mesh.get_surface_count()>0:
			pearl_material = pearl_surface.mesh.surface_get_material(0).duplicate()
			pearl_surface.set_surface_override_material(0,pearl_material)

func _physics_process(delta: float) -> void:
	if is_instance_valid(game) and not game.is_playing():return
	super._physics_process(delta)
	# Facets orbit around central pearl
	if is_instance_valid(facet_left) and is_instance_valid(facet_right):
		var angle: float = visual_clock * 2.5
		facet_left.position = Vector3(cos(angle) * 0.60, 1.0 + sin(angle * 2.0) * 0.08, sin(angle) * 0.60)
		facet_right.position = Vector3(cos(angle + PI) * 0.60, 1.0 + sin((angle + PI) * 2.0) * 0.08, sin(angle + PI) * 0.60)

	if is_instance_valid(body_mesh) and current_state != State.DEAD:
		body_mesh.position.y = sin(visual_clock * 2.4) * 0.065
	var charge: float = clampf(1.0-state_timer/maxf(0.01,windup_time),0.0,1.0) if current_state == State.TELEGRAPH else 0.0
	if is_instance_valid(central_pearl):central_pearl.scale = Vector3.ONE * (1.0 + 0.14 * charge)
	if is_instance_valid(pearl_material):pearl_material.emission_energy_multiplier = 0.12 + 0.35 * charge

func _deliver_attack() -> void:
	if not is_instance_valid(target_player):
		return
	var dart = DartScript.new()
	get_parent().add_child(dart)
	var shoot_origin: Vector3 = global_position + Vector3(0, 1.20, 0)
	var shoot_dir: Vector3 = (committed_target + Vector3(0, 0.8, 0)) - shoot_origin
	dart.setup(shoot_origin, shoot_dir, self)
