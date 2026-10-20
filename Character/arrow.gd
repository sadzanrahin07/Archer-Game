class_name Arrow
extends RigidBody3D

@export var speed: float = 85.0
@export var damage: float = 25.0

var last_position: Vector3
var start_simulation: bool = false
var has_hit: bool = false
var shooter_ref: CollisionObject3D = null

func _ready() -> void:
	last_position = global_position
	freeze = true
	set_physics_process(false)

func shoot(target_position: Vector3, custom_speed: float = 85.0, shooter: CollisionObject3D = null) -> void:
	shooter_ref = shooter
	freeze = false
	speed = custom_speed
	set_as_top_level(true)
	
	var dir = (target_position - global_position).normalized()
	if dir.length() > 0.001:
		look_at(global_position + dir, Vector3.UP)
	
	linear_velocity = Vector3.ZERO
	apply_impulse(dir * speed, Vector3.ZERO)
	
	last_position = global_position
	set_physics_process(true)
	
	await get_tree().create_timer(0.02).timeout
	start_simulation = true
	
	await get_tree().create_timer(10.0).timeout
	if is_instance_valid(self) and not has_hit:
		queue_free()

func _physics_process(delta: float) -> void:
	if not start_simulation or has_hit:
		return
	
	var current_position = global_position
	var movement = current_position - last_position
	
	if linear_velocity.length() > 1.0:
		var forward_dir = linear_velocity.normalized()
		look_at(global_position + forward_dir, Vector3.UP)
	
	if movement.length() > 0.001:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(last_position, current_position)
		var excl: Array[RID] = [get_rid()]
		if shooter_ref and is_instance_valid(shooter_ref):
			excl.append(shooter_ref.get_rid())
		query.exclude = excl
		var hit_result = space_state.intersect_ray(query)
		
		if not hit_result.is_empty():
			_on_hit(hit_result)
			return
	
	last_position = current_position

func _on_hit(hit: Dictionary) -> void:
	has_hit = true
	freeze = true
	global_position = hit.position
	
	var collider = hit.collider
	if collider:
		if collider.has_method("on_hit"):
			collider.on_hit(hit.position, self)
		elif collider.has_method("hit"):
			collider.hit()
		elif collider.has_method("take_damage"):
			collider.take_damage(damage)
		
		var parent_node = collider
		if parent_node and is_instance_valid(parent_node) and parent_node.is_inside_tree():
			var cur_transform = global_transform
			if get_parent():
				get_parent().remove_child(self)
			parent_node.add_child(self)
			global_transform = cur_transform
	
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		queue_free()
