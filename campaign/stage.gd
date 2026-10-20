extends Node3D

@export var stage_id := 0
var game: Node
var definition: Dictionary
var targets: Array[Node] = []
var spawn := Vector3(0, 5.70, 16.5)
var endpoint := Vector3.ZERO
var extent := 35.0
var safe_bounds := Rect2(-15, -25, 30, 50)
var scenery: RefCounted
var thread_guide: Node3D
var encounter:Node3D
const TargetScript = preload("res://campaign/target.gd")
const ScenicCourse = preload("res://campaign/scenic_course.gd")

func build(owner_game: Node, config: Dictionary) -> void:
	game = owner_game; definition = config
	var route: bool = str(definition.get("mode", "precision")) == "ordered"
	var roaming: bool = bool(definition.get("roaming", false))
	var route_length := float(definition.get("route_length", 44 if route else 34))
	var width := 42.0 if roaming else 28.0
	var end_z := spawn.z - route_length - 10.0 if route else spawn.z - maxf(float(definition.get("distance", 15.0)), 22.0) - 9.0
	var length := 25.0 - end_z
	extent = length; safe_bounds = Rect2(-width * .5, end_z, width, length)
	_floor(width, length, end_z)
	scenery = ScenicCourse.new(); scenery.build(self, stage_id, width, end_z, str(definition.get("biome", "meadow")))
	if int(definition.get("chapter_number", 1)) == 5 and stage_id % 5 == 2: _rain(length, end_z)

	var count: int = definition.materials.size()
	var thread_orbs: Array[Node3D] = []

	for i in range(count):
		var target := TargetScript.new(); target.game = game; target.index = i; target.material_kind = str(definition.materials[i])
		target.hits_left = int(definition.get("hits_required", 1)); target.phase = i * 1.7
		var hp_list: Array = definition.get("target_hp", [])
		if i < hp_list.size(): target.hp_override = float(hp_list[i])
		var moving_list: Array = definition.get("moving_targets", [])
		target.moving = i in moving_list if definition.has("moving_targets") else bool(definition.get("moving", false))
		target.motion_style = 1 if stage_id == 17 and not route else (2 if target.material_kind == "pendulum" else 0)

		# Staggered rising target timings
		if target.material_kind in ["rising", "rising_board"]:
			target.rising_timer = 0.4 + i * 1.6
			target.rising_single=true
			var group_size:int=1 if stage_id%5==0 else 2
			target.rising_slot=i/group_size;target.rising_total=ceili(float(count)/group_size)
			target.rising_shuffle=group_size==2;target.rising_seed=stage_id

		if route:
			var z := spawn.z - 8.0 - i * maxf(6.0, (route_length - 8.0) / maxi(1, count - 1))
			var x := sin(z * .058) * 1.8 + (-2.5 if i % 2 == 0 else 2.5)
			if roaming and i == count - 1:
				x = 0; target.final_stone = true; target.approach_distance = float(definition.get("finish_approach_distance", 16))
				target.moving = false; endpoint = Vector3(x, spawn.y, z)
			target.position = Vector3(x, spawn.y + 1.45, z)
		elif int(definition.get("chapter_number", 1)) == 1 and count == 1:
			target.position = spawn + Vector3(0, 1.45, -float(definition.get("distance", 15.0)))
		elif target.material_kind in ["soft_orb", "thread_orb", "hanging_orb"]:
			# Thread Shot lane: align orbs along direct forward line at stepped Z depths
			var lane_x := 0.0
			var orb_idx := thread_orbs.size()
			var z_dist := float(definition.get("distance", 15.0)) + float(orb_idx) * 2.8
			target.position = spawn + Vector3(lane_x, 1.45, -z_dist)
			thread_orbs.append(target)
		else:
			var x:float=(i-(count-1)*.5)*2.6
			if str(definition.get("mechanic",""))=="thread":x=-3.5 if i==0 else 3.5
			target.position=Vector3(x,spawn.y+1.45+(i%2)*.2,spawn.z-float(definition.get("distance",15.0))-(i%2)*2)

		add_child(target); targets.append(target)
		if route: target.set_active(i == 0)
		if not target.material_kind in ["stone", "rune", "master", "rising", "rising_board", "soft_orb", "thread_orb", "hanging_orb", "pendulum", "armor_petals", "core_monolith", "clasp"]:
			_stand(target)

	if not thread_orbs.is_empty():
		_build_thread_lane_guide(thread_orbs)

	if not roaming: endpoint = targets.back().position - Vector3(0, 1.45, 0)
	var line := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(3.5, .02, .12); line.mesh = mesh; line.position = spawn + Vector3(0, 0, -.4)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("e1d6a4"); mesh.material = mat; add_child(line)
	if roaming: _endpoint_marker()
	encounter=preload("res://campaign/course_mechanics.gd").new();add_child(encounter);encounter.setup(self)
	if "profile" in game and game.profile.data.chapter_rewards.has(str(stage_id/5)):
		encounter.restore_landmark()

func mechanic_allows_hit(target:Node3D) -> bool:
	return encounter.allows(target) if is_instance_valid(encounter) else true

func _build_thread_lane_guide(orbs: Array[Node3D]) -> void:
	thread_guide = Node3D.new(); add_child(thread_guide)
	var first_orb: Node3D = orbs.front()
	var last_orb: Node3D = orbs.back()

	# Alignment guide ring in front of the lane
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.52; tm.outer_radius = 0.56; ring.mesh = tm
	ring.position = Vector3(first_orb.position.x, first_orb.position.y, first_orb.position.z + 1.8)
	ring.rotation.x = PI / 2
	var rmat := StandardMaterial3D.new(); rmat.albedo_color = Color("6ee8d8"); rmat.emission_enabled = true; rmat.emission = Color("42d6c3"); rmat.emission_energy_multiplier = 1.2
	ring.material_override = rmat; thread_guide.add_child(ring)

	# Subtle luminous dashed lane marker along the ground
	var line_len: float = absf(last_orb.position.z - first_orb.position.z) + 4.0
	var lane := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.08, 0.02, line_len); lane.mesh = bm
	lane.position = Vector3(first_orb.position.x, spawn.y + 0.02, (first_orb.position.z + last_orb.position.z) * 0.5)
	var lmat := StandardMaterial3D.new(); lmat.albedo_color = Color(0.43, 0.91, 0.85, 0.4); lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lmat.emission_enabled = true; lmat.emission = Color("38bdae"); lmat.emission_energy_multiplier = 0.6
	lane.material_override = lmat; thread_guide.add_child(lane)

	# Overhead timber beam suspending the orbs
	var beam := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(0.3, 0.3, line_len); beam.mesh = bb
	beam.position = Vector3(first_orb.position.x, spawn.y + 3.1, (first_orb.position.z + last_orb.position.z) * 0.5)
	var bmat := StandardMaterial3D.new(); bmat.albedo_color = Color("543d26"); bmat.roughness = 0.95
	beam.material_override = bmat; thread_guide.add_child(beam)

func _floor(width: float, length: float, end_z: float) -> void:
	var floor_body := StaticBody3D.new(); floor_body.name = "CourseGround"; floor_body.collision_layer = 1; add_child(floor_body)
	var collider := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(width, .35, length)
	collider.shape = box; collider.position = Vector3(0, 5.505, (25.0 + end_z) * .5); floor_body.add_child(collider)
	var floor_mesh := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(width, length); floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0, 5.68, (25.0 + end_z) * .5)
	var material := _ground_material()
	floor_mesh.material_override = material; floor_body.add_child(floor_mesh)
	for side in [-1, 1]:
		var wall := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = Vector3(.22, 4, length); wall.shape = shape
		wall.position = Vector3(side * (width * .5 + .1), 7.6, (25.0 + end_z) * .5); floor_body.add_child(wall)
	for z in [25.0 + .1, end_z - .1]:
		var wall := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = Vector3(width, 4, .22); wall.shape = shape; wall.position = Vector3(0, 7.6, z); floor_body.add_child(wall)

func _ground_material() -> ShaderMaterial:
	var material := ShaderMaterial.new(); material.shader = load("res://campaign/course_ground.gdshader")
	if definition.get("biome", "") in ["ember", "golden"]:
		material.set_shader_parameter("field_color", Color("abb47a")); material.set_shader_parameter("path_color", Color("ad9863"))
	return material

func _stand(target: Node3D) -> void:
	var stand := MeshInstance3D.new(); stand.name = "TargetStand"; var cylinder := CylinderMesh.new(); cylinder.top_radius = .04; cylinder.bottom_radius = .07; cylinder.height = 1.5
	stand.mesh = cylinder; stand.position = Vector3(0, -.9, -.10); var mat := StandardMaterial3D.new(); mat.albedo_color = Color("735c3f"); mat.roughness = 1; stand.material_override = mat; target.add_child(stand)

func _endpoint_marker() -> void:
	var mesh := MeshInstance3D.new(); var ring := TorusMesh.new(); ring.inner_radius = 2.4; ring.outer_radius = 2.5; mesh.mesh = ring
	mesh.position = endpoint + Vector3(0, .025, 0); var mat := StandardMaterial3D.new(); mat.albedo_color = Color("84d9c9"); mat.emission_enabled = true; mat.emission = mat.albedo_color; mat.emission_energy_multiplier = .4; mesh.material_override = mat; add_child(mesh)

func _rain(length: float, end_z: float) -> void:
	var rain := CPUParticles3D.new(); rain.amount = 500; rain.lifetime = 1.2; rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(12, .5, length * .5); rain.position = Vector3(0, 13, (25.0 + end_z) * .5); rain.direction = Vector3(0, -1, 0); rain.spread = 5
	rain.initial_velocity_min = 9; rain.initial_velocity_max = 12; rain.gravity = Vector3(0, -5, 0)
	var drop := BoxMesh.new(); drop.size = Vector3(.014, .22, .014); var mat := StandardMaterial3D.new(); mat.albedo_color = Color("a1bbc9"); drop.material = mat; rain.mesh = drop; add_child(rain)
