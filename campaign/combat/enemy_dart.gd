extends Node3D

var speed: float = 11.0
var damage: float = 10.0
var direction := Vector3.FORWARD
var age := 0.0
var max_life := 4.0
var owner_enemy: Node3D

func setup(origin: Vector3, dir: Vector3, shooter: Node3D) -> void:
	global_position = origin
	direction = dir.normalized()
	owner_enemy = shooter
	if shooter.get("pending_projectiles")!=null:shooter.pending_projectiles+=1
	look_at(global_position + direction, Vector3.UP)

func _ready() -> void:
	var mesh_inst := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.08, 0.45, 0.08)
	mesh_inst.mesh = prism
	mesh_inst.rotation.x = -PI / 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.70, 0.60, 0.95) # Lilac prism dart
	mat.emission_enabled = true
	mat.emission = Color(0.80, 0.70, 1.0)
	mat.emission_energy_multiplier = 1.8
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func _physics_process(delta: float) -> void:
	if is_instance_valid(owner_enemy) and is_instance_valid(owner_enemy.game) and not owner_enemy.game.is_playing():return
	if not is_instance_valid(owner_enemy) or owner_enemy.completed:queue_free();return
	age += delta
	if age > max_life:
		queue_free()
		return
	
	var next_pos := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next_pos, 1 | 2) # Terrain | Player
	if is_instance_valid(owner_enemy):
		query.exclude = [owner_enemy.get_rid()]
	
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var col = hit.collider
		if is_instance_valid(col) and col.has_method("take_player_damage"):
			col.take_player_damage(damage, self)
		queue_free()
		return
	
	global_position = next_pos

func _exit_tree() -> void:
	if is_instance_valid(owner_enemy) and owner_enemy.get("pending_projectiles")!=null:owner_enemy.pending_projectiles=maxi(0,owner_enemy.pending_projectiles-1)
