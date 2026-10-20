extends Area3D

@export var speed: float = 55.0
@export var gravity_strength: float = 2.4
@export var lifetime: float = 12.0

var velocity: Vector3 = Vector3.ZERO
var is_flying: bool = true
var time_alive: float = 0.0
var shooter: Node = null

@onready var mesh_node: MeshInstance3D = get_node_or_null("ArrowMesh")
@onready var col_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
var snd_hit_2d: AudioStreamPlayer = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Fallback 2D hit player
	snd_hit_2d = AudioStreamPlayer.new()
	snd_hit_2d.name = "SndHit2D"
	var hit_path = "res://sounds/Target hit sound.mp3"
	if not ResourceLoader.exists(hit_path):
		hit_path = "res://sounds/target_hit.mp3"
	if not ResourceLoader.exists(hit_path):
		hit_path = "res://sounds/target_hit.wav"
	if not ResourceLoader.exists(hit_path):
		hit_path = "res://Sound effects/freesound_community-jump-landing-30946.mp3"
	if ResourceLoader.exists(hit_path):
		snd_hit_2d.stream = load(hit_path) as AudioStream
	snd_hit_2d.volume_db = 0.0
	add_child(snd_hit_2d)

func launch(direction: Vector3, start_speed: float = 55.0) -> void:
	speed = start_speed
	velocity = direction.normalized() * speed
	is_flying = true
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.UP)

func _physics_process(delta: float) -> void:
	if not is_flying:
		time_alive += delta
		if time_alive > lifetime:
			if mesh_node:
				var alpha = clampf(1.0 - (time_alive - lifetime), 0.0, 1.0)
				if alpha <= 0.05:
					queue_free()
		return
		
	time_alive += delta
	if time_alive > 12.0:
		queue_free()
		return
		
	# Ballistic gravity drop
	velocity.y -= gravity_strength * delta
	
	# Raycast check ahead for precise continuous collision detection against ALL solid matter
	var space := get_world_3d().direct_space_state
	var move_step := velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + move_step)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	query.collision_mask = 4294967295
	
	var excludes: Array[RID] = [get_rid()]
	if shooter and is_instance_valid(shooter) and shooter is CollisionObject3D:
		excludes.append(shooter.get_rid())
	for p in get_tree().get_nodes_in_group("player_characters"):
		if p is CollisionObject3D:
			excludes.append(p.get_rid())
	query.exclude = excludes
	
	var hit := space.intersect_ray(query)
	if hit:
		global_position = hit.position
		_hit_surface(hit.collider, hit.normal)
	else:
		global_position += move_step
		if velocity.length_squared() > 0.01:
			look_at(global_position + velocity, Vector3.UP)

func _on_body_entered(body: Node) -> void:
	if is_flying and body != self and body != shooter:
		_hit_surface(body, -velocity.normalized())

func _on_area_entered(area: Area3D) -> void:
	if is_flying and area != self and area != shooter:
		_hit_surface(area, -velocity.normalized())

func _hit_surface(target: Node, _normal: Vector3) -> void:
	if not is_flying:
		return
	is_flying = false
	print("[ARROW HIT] collider=", (str(target.name) if target else "null"), " pos=", global_position)
	
	# Embedded penetration (8cm)
	global_position += velocity.normalized() * 0.08
	
	# Trigger target hit reaction if applicable
	if target:
		if target.has_method("on_hit"):
			target.on_hit(global_position, self)
		elif target.get_parent() and target.get_parent().has_method("on_hit"):
			target.get_parent().on_hit(global_position, self)
			
	# Single crisp "arrow hits target" sound effect (target_hit.wav); no extra sound effects
	# Spawned on root so reparenting / arrow destruction never interrupts playback
	var hit_path = "res://sounds/Target hit sound.mp3"
	if not ResourceLoader.exists(hit_path):
		hit_path = "res://sounds/target_hit.mp3"
	if not ResourceLoader.exists(hit_path):
		hit_path = "res://sounds/target_hit.wav"
	if ResourceLoader.exists(hit_path):
		var hit_stream = load(hit_path)
		var hit_player = AudioStreamPlayer.new()
		hit_player.name = "TargetHitAudioOneShot"
		hit_player.stream = hit_stream
		hit_player.volume_db = 2.5
		hit_player.pitch_scale = randf_range(0.98, 1.05)
		if get_tree() and get_tree().root:
			get_tree().root.add_child(hit_player)
			hit_player.play()
			hit_player.finished.connect(hit_player.queue_free)
			# Fallback cleanup timer ensures audio plays once and frees itself
			get_tree().create_timer(0.85).timeout.connect(func():
				if is_instance_valid(hit_player):
					hit_player.queue_free()
			)
	elif snd_hit_2d and snd_hit_2d.stream:
		snd_hit_2d.pitch_scale = randf_range(0.98, 1.05)
		snd_hit_2d.play()
		
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if col_shape:
		col_shape.set_deferred("disabled", true)
		
	if target and is_instance_valid(target) and target is Node3D and target.get_parent():
		_safe_reparent.call_deferred(target, global_transform)

func _safe_reparent(new_parent: Node3D, keep_xform: Transform3D) -> void:
	if is_instance_valid(new_parent) and new_parent.is_inside_tree() and is_inside_tree():
		reparent(new_parent, true)
		global_transform = keep_xform
