extends RefCounted

# High-Fidelity 3D Colossus Visuals for The Hollow Crown Boss
# Replaces primitive geometric shapes with detailed organic & mechanical architecture.

static var materials: Dictionary = {}

static func get_mat(key: String, hex: String, rough: float = 0.75, glow: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	if materials.has(key): return materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = Color(hex)
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0:
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = glow
	materials[key] = m
	return m

static func part(parent: Node3D, title: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = title
	n.position = pos
	parent.add_child(n)
	return n

static func lathe(profile: Array[Vector2], segments: int = 16, jitter: float = 0.02, smooth: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(profile.size() - 1):
		for i in range(segments):
			var v: Array[Vector3] = []
			for pair in [[ring, i], [ring + 1, i], [ring + 1, i + 1], [ring, i + 1]]:
				var row: int = pair[0]
				var col: int = pair[1]
				var angle: float = TAU * float(col) / float(segments)
				var radial: float = profile[row].x * (1.0 + jitter * sin(float(col) * 7.13 + float(row) * 3.77))
				v.append(Vector3(cos(angle) * radial, profile[row].y, sin(angle) * radial))
			var tint: float = 0.92 + 0.08 * sin(float(i) * 4.77 + float(ring) * 2.77)
			for index in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(tint, tint, tint))
				st.add_vertex(v[index])
	st.generate_normals()
	return st.commit()

static func tube(parent: Node3D, title: String, a: Vector3, b: Vector3, r1: float, r2: float, mat: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r2
	c.bottom_radius = r1
	c.height = a.distance_to(b)
	c.radial_segments = 8
	c.rings = 1
	var n := MeshInstance3D.new()
	n.name = title
	n.mesh = c
	n.position = (a + b) * 0.5
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if (b - a).length_squared() > 0.001:
		var dir := (b - a).normalized()
		var y_up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		n.global_transform = Transform3D(Basis.looking_at(dir, y_up) * Basis(Vector3.RIGHT, PI * 0.5), n.position)
	parent.add_child(n)
	return n

static func roots(parent: Node3D, points: Array[Vector3], radius: float = 0.12) -> void:
	var bark := get_mat("colossus_root", "3e2f21", 0.9)
	for i in range(points.size() - 1):
		var r_a: float = radius * (1.0 - float(i) * 0.12)
		var r_b: float = radius * (1.0 - float(i + 1) * 0.12)
		tube(parent, "RootLimb", points[i], points[i + 1], r_a, r_b, bark)

static func build_colossus(boss: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "HollowCrownMesh"
	boss.add_child(root)

	var mat_granite := get_mat("colossus_granite", "4b4e47", 0.85)
	var mat_bark := get_mat("colossus_dark_bark", "34271c", 0.92)
	var mat_wood := get_mat("colossus_aged_wood", "483827", 0.88)
	var mat_rune := get_mat("colossus_rune", "64e2d4", 0.3, 1.8)
	var mat_shutter := get_mat("colossus_shutter", "2b1f17", 0.78, 0.0, 0.15)
	var mat_shutter_edge := get_mat("colossus_shutter_edge", "d4af37", 0.45, 0.6, 0.4)
	var mat_moss := get_mat("colossus_moss", "5c7a4a", 0.95)

	# 1. Gnarled Petrified Trunk Base with Root Sprawl
	var trunk_profile: Array[Vector2] = [
		Vector2(1.55, 0.0),
		Vector2(1.35, 0.5),
		Vector2(1.15, 1.2),
		Vector2(0.95, 1.9),
		Vector2(1.05, 2.5),
		Vector2(1.20, 2.9),
		Vector2(0.90, 3.4),
		Vector2(0.65, 3.6)
	]
	var trunk_mesh := MeshInstance3D.new()
	trunk_mesh.name = "Trunk"
	trunk_mesh.mesh = lathe(trunk_profile, 24, 0.04)
	trunk_mesh.material_override = mat_bark
	root.add_child(trunk_mesh)

	# Clustered Buttress Roots clutching the ground
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		var r1 := Vector3(cos(a) * 0.95, 0.8, sin(a) * 0.95)
		var r2 := Vector3(cos(a) * 1.55, 0.2, sin(a) * 1.55)
		var r3 := Vector3(cos(a + 0.1) * 2.1, 0.02, sin(a + 0.1) * 2.1)
		roots(root, [r1, r2, r3], 0.22)

	# 2. Chest Armor Plates & Carved Runic Mantle
	var chest_armor := part(root, "ChestArmor", Vector3(0, 2.2, 0))
	for side in [-1, 1]:
		# Armored Pauldron Shoulder Guards
		var pauldron := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(0.65, 0.85, 0.95)
		pauldron.mesh = p_box
		pauldron.position = Vector3(side * 1.35, 0.45, 0.1)
		pauldron.rotation = Vector3(0.1, 0, -side * 0.25)
		pauldron.material_override = mat_granite
		chest_armor.add_child(pauldron)

		# Glowing runic inlay plate on shoulder
		var rune_plate := MeshInstance3D.new()
		var r_box := BoxMesh.new()
		r_box.size = Vector3(0.04, 0.55, 0.65)
		rune_plate.mesh = r_box
		rune_plate.position = Vector3(side * 1.68, 0.50, 0.1)
		rune_plate.material_override = mat_rune
		chest_armor.add_child(rune_plate)

	# 3. Articulated Mechanical Blast Shutters (Vault Doors)
	var shutter_hinge_left := part(chest_armor, "ShutterHingeLeft", Vector3(-0.62, 0.0, 1.35))
	var shutter_hinge_right := part(chest_armor, "ShutterHingeRight", Vector3(0.62, 0.0, 1.35))

	var shutter_left := MeshInstance3D.new()
	var shutter_right := MeshInstance3D.new()
	var s_mesh := BoxMesh.new()
	s_mesh.size = Vector3(0.60, 1.15, 0.16)
	shutter_left.mesh = s_mesh
	shutter_right.mesh = s_mesh
	shutter_left.position = Vector3(0.28, 0.0, 0.08)
	shutter_right.position = Vector3(-0.28, 0.0, 0.08)
	shutter_left.material_override = mat_shutter
	shutter_right.material_override = mat_shutter
	shutter_hinge_left.add_child(shutter_left)
	shutter_hinge_right.add_child(shutter_right)

	# Runic Trim along the shutter seams
	for side in [-1, 1]:
		var seam := MeshInstance3D.new()
		var s_box := BoxMesh.new()
		s_box.size = Vector3(0.08, 1.10, 0.18)
		seam.mesh = s_box
		seam.material_override = mat_shutter_edge
		if side == -1:
			seam.position = Vector3(0.28 + 0.26, 0.0, 0.08)
			shutter_left.add_child(seam)
		else:
			seam.position = Vector3(-0.28 - 0.26, 0.0, 0.08)
			shutter_right.add_child(seam)

	# 4. Volumetric Aurora Heart (The Weak Spot)
	var core_root := part(chest_armor, "CoreRoot", Vector3(0, 0.0, 1.25))
	var core_mesh := MeshInstance3D.new()
	var core_sphere := SphereMesh.new()
	core_sphere.radius = 0.45
	core_sphere.height = 0.90
	core_sphere.radial_segments = 24
	core_sphere.rings = 12
	core_mesh.mesh = core_sphere

	var mat_core := StandardMaterial3D.new()
	mat_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_core.albedo_color = Color(0.9, 0.98, 1.0, 0.95)
	mat_core.emission_enabled = true
	mat_core.emission = Color("a0eeff")
	mat_core.emission_energy_multiplier = 2.8
	core_mesh.material_override = mat_core
	core_root.add_child(core_mesh)

	# Counter-rotating runic gyro rings orbiting inside the heart cavity
	for i in range(2):
		var gyro := MeshInstance3D.new()
		var g_mesh := TorusMesh.new()
		g_mesh.inner_radius = 0.50 + i * 0.08
		g_mesh.outer_radius = 0.54 + i * 0.08
		g_mesh.rings = 24
		g_mesh.ring_segments = 6
		gyro.mesh = g_mesh
		gyro.material_override = mat_rune
		gyro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		core_root.add_child(gyro)

	# Dynamic Heart Light
	var heart_light := OmniLight3D.new()
	heart_light.name = "HeartLight"
	heart_light.light_color = Color("a0eeff")
	heart_light.light_energy = 3.5
	heart_light.omni_range = 6.0
	heart_light.omni_attenuation = 1.4
	core_root.add_child(heart_light)

	# 5. Articulated Colossal Claws (3-Segment Arms)
	var arm_nodes: Array[Node3D] = []
	for side in [-1, 1]:
		var shoulder := part(root, "Shoulder_" + ("L" if side < 0 else "R"), Vector3(side * 1.45, 2.5, 0.1))
		var upper_arm := part(shoulder, "UpperArm")
		tube(upper_arm, "Bicep", Vector3.ZERO, Vector3(side * 0.35, -1.1, 0.2), 0.38, 0.32, mat_bark)

		var elbow := part(upper_arm, "Elbow", Vector3(side * 0.35, -1.1, 0.2))
		tube(elbow, "Forearm", Vector3.ZERO, Vector3(side * 0.2, -1.1, 0.4), 0.34, 0.44, mat_granite)

		# Claws / Talons
		var wrist := part(elbow, "Wrist", Vector3(side * 0.2, -1.1, 0.4))
		for claw_i in range(3):
			var claw_ang: float = float(claw_i - 1) * 0.35
			var c1 := Vector3(sin(claw_ang) * 0.18, 0.0, cos(claw_ang) * 0.15)
			var c2 := Vector3(sin(claw_ang) * 0.35, -0.45, cos(claw_ang) * 0.35)
			tube(wrist, "Talon", c1, c2, 0.09, 0.02, mat_wood)

		arm_nodes.append(shoulder)

	# 6. Majestic Petrified Thorn Antler Crown with Orbiting Wisps
	var crown_root := part(root, "ThornCrown", Vector3(0, 3.5, 0))
	for ang in [0, 45, 90, 135, 180, 225, 270, 315]:
		var rad: float = deg_to_rad(float(ang))
		var dir := Vector3(sin(rad), 0, cos(rad))
		var p0 := dir * 0.65
		var p1 := dir * 1.15 + Vector3(0, 0.65, 0)
		var p2 := dir * 1.65 + Vector3(0, 1.45, 0)
		roots(crown_root, [p0, p1, p2], 0.14)
		if ang % 90 == 0:
			var sub_p := dir * 1.35 + Vector3(0, 1.1, 0)
			var sub_tip := dir * 1.85 + Vector3(0, 1.7, 0) + Vector3(dir.z, 0, -dir.x) * 0.45
			roots(crown_root, [sub_p, sub_tip], 0.08)

	# 4 Orbiting Celestial Wisps hovering above crown
	for i in range(4):
		var wisp_pivot := part(crown_root, "WispOrbit_%d" % i)
		var wisp_mesh := MeshInstance3D.new()
		var w_sphere := SphereMesh.new()
		w_sphere.radius = 0.085
		w_sphere.height = 0.17
		wisp_mesh.mesh = w_sphere
		var mat_wisp := get_mat("wisp_flair_%d" % i, "ffe494", 0.2, 3.2)
		wisp_mesh.material_override = mat_wisp
		wisp_mesh.position = Vector3(cos(float(i) * PI * 0.5) * 1.6, 2.2, sin(float(i) * PI * 0.5) * 1.6)
		wisp_pivot.add_child(wisp_mesh)

	return {
		"body_root": root,
		"core_mesh": core_mesh,
		"core_root": core_root,
		"heart_light": heart_light,
		"shutter_left": shutter_left,
		"shutter_right": shutter_right,
		"shutter_hinge_left": shutter_hinge_left,
		"shutter_hinge_right": shutter_hinge_right,
		"arms": arm_nodes,
		"crown_root": crown_root
	}
