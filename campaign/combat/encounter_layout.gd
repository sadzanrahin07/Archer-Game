extends RefCounted

# Authored terrain and entrances. No stat scaling, random spawns or extra enemies.
# Every coordinate is relative to the player's stage spawn, facing forward (-Z).
const FAMILY_PATTERNS := [
	["fern_lesson", "split_ferns", "moss_fork", "brook_relay", "moss_crescent"],
	["rose_lesson", "twin_landings", "briar_triangle", "briar_switchback", "roseguard_gates"],
	["seed_lesson", "crossing_lanes", "three_gardeners", "cover_relay", "seedpod_barrage"],
	["stalker_lesson", "twin_hunters", "pincer_path", "fallen_bough", "cedar_pack"],
	["wisp_lesson", "twin_orbits", "three_reflections", "prism_relay", "shattered_chorus"],
	["warden_lesson", "stone_and_root", "three_oaths", "warden_relay", "five_guardians"]
]
const MIXED_PATTERNS := ["sentinel_break", "briar_crossfire", "fox_and_mirrors", "warden_escort", "tempest_gate", "long_approach", "bending_roots", "mist_constellation", "twin_sentinels", "aurora_threshold", "aurora_trial", "three_sentinel_gates", "starfall_escort", "crown_approach"]

var pattern := ""
var title := ""
var hint := ""
var covers: Array = []
var cover_bodies: Array[StaticBody3D] = []
var navigation_region: NavigationRegion3D

func configure(stage_id: int) -> void:
	if stage_id < 55 or stage_id >= 99: return
	if stage_id < 85:
		var chapter: int = (stage_id - 55) / 5
		var chapter_step: int = (stage_id - 55) % 5
		pattern = FAMILY_PATTERNS[chapter][chapter_step]
	else:
		pattern = MIXED_PATTERNS[stage_id - 85]
	title = pattern.replace("_", " ").capitalize()
	var step: int = (stage_id - 55) % 5
	if stage_id < 85:
		match step:
			0: hint = "Read the first attack. Step clear of its warning, then shoot during recovery."
			1: hint = "Two entrances, two angles. Keep both in view and leave room to dodge sideways."
			2:
				covers = [_cover(0, -7.3, 1.15)]
				hint = "A root pillar divides the clearing. Circle its sides to find a clear shot."
			3:
				covers = [_cover(-2.7, -7.7, 1.0), _cover(3.2, -12.0, 1.0)]
				hint = "Entrances alternate across the clearing. Watch the marked gate and change lanes."
			4:
				covers = [_cover(-3.0, -7.5, .9), _cover(3.0, -7.5, .9)]
				hint = "Wide flanks and a delayed rear gate. Use the open middle to keep the group in front."
		if stage_id in [65, 66, 67, 68, 69]:
			hint = ["Watch the pod open. Strafe across the seed's flight, then return a shot.", "Seedpods cover opposite lanes. Move sideways between their shots.", "Use the central root as cover, then peek around either side to shoot.", "Clear one seedpod lane before the next marked entrance opens.", "The last pair takes the opposite lane. Use roots to break a seed's flight."][step]
		elif stage_id in [80, 81, 82, 83, 84]:
			hint = ["Lure the guardian's slam, step out of its circle, then shoot its golden knot.", "The next guardian enters across the clearing. Turn toward the marked gate.", "A root splits the approach. Let the guardian round it before its slam.", "The guardian relay changes sides. Keep a route through the middle.", "Five guardians arrive in three groups. Use the gaps between roots to reset your spacing."][step]
	else:
		match stage_id:
			85:
				covers = [_cover(0, -8, 1.1)]
				hint = "Draw the sentinel around the root. The next wave opens from both sides."
			86:
				covers = [_cover(-2.7, -7, .95), _cover(3, -10, .95)]
				hint = "Briar advances first; the seedpod's gate follows. Break its lane with a root."
			87:
				covers = [_cover(2.5, -7.8, 1.05)]
				hint = "The hunter closes from one side while a wisp guards the other. Keep a sideways exit."
			88:
				covers = [_cover(-3.2, -9.5, .9), _cover(3.2, -9.5, .9)]
				hint = "Slimes enter around a guardian; seedpods take the far lanes after the escort falls."
			89:
				covers = [_cover(0, -8, 1.25)]
				hint = "Three different waves use the same fork. Change sides between the leaps, hunter and slam."
			90:
				covers = [_cover(-2.6, -9.4, 1.0), _cover(3.5, -13, 1.0)]
				hint = "Slimes hold the near lane; hunters arrive from the far flanks. Keep space behind you."
			91:
				covers = [_cover(-3.1, -6.8, .95), _cover(3.1, -6.8, .95)]
				hint = "Roots break the opening ranged lanes. The next wave leaps through the gaps."
			92:
				covers = [_cover(0, -7.4, 1.2)]
				hint = "Wisps open wide around the root. A guardian follows from the center gate."
			93:
				covers = [_cover(-2.5, -8, .9), _cover(3.2, -11.6, .9)]
				hint = "Each sentinel has a different escort. Read the escort's lane before approaching the slam."
			94:
				covers = [_cover(-3, -8.3, 1.0), _cover(3, -8.3, 1.0)]
				hint = "Leap, pursuit, then ranged escort: three waves demand a fresh position each time."
			95:
				covers = [_cover(-5, -9.8, .9), _cover(5, -9.8, .9)]
				hint = "The first pairs enter close together. A grouped power shot can open the guardian's lane."
			96:
				covers = [_cover(0, -8.5, 1.15)]
				hint = "Three sentinel gates open left, right, then center. Reposition between slams."
			97:
				covers = [_cover(2.7, -8.3, 1.0), _cover(-3, -12, .9)]
				hint = "A ranged escort follows the hunter. Later gates switch from leaps to a guardian."
			98:
				covers = [_cover(-3.2, -7.5, 1.0), _cover(3.2, -11, 1.0)]
				hint = "Cross the seed lanes, separate the hunter from its guardian, then face the final gate."

func _cover(x: float, z: float, radius: float) -> Dictionary:
	return {"pos": Vector3(x, 0, z), "radius": radius, "height": 2.25}

func entrance(stage_id: int, wave: int, index: int, _count: int, family: String) -> Dictionary:
	var positions: Array = []
	var delay := 0.0
	var after_kills := 0
	var step: int = (stage_id - 55) % 5
	if stage_id < 85:
		match step:
			0: positions = [Vector2(-2.5 if stage_id % 2 == 0 else 1.5, -10)]
			1: positions = [Vector2(-5.7, -9), Vector2(5.7, -10.5)]; delay = 1.8 * index
			2: positions = [Vector2(-6.2, -9.5), Vector2(6.2, -9.5), Vector2(0, -12.5)]; delay = .8 * index
			3:
				positions = [Vector2(-6.3, -9), Vector2(6.5, -10.5), Vector2(-5.5, -13), Vector2(6, -13.2)]
				delay = 1.8 * index
				if family in ["moss_slime", "briar_slime", "bark_stalker"]: after_kills = maxi(0, index - 1)
			4:
				positions = [Vector2(-7.8, -9.3), Vector2(7.8, -9.3), Vector2(-5.4, -12), Vector2(5.4, -12), Vector2(0, -13)]
				delay = 1.1 * index
				if family in ["moss_slime", "briar_slime", "bark_stalker"]: after_kills = 1 if index >= 3 else 0
		if after_kills > 0: delay = 1.0
		# A rooted seed must start within its 14-metre firing range.
		var point: Vector2 = positions[index % positions.size()]
		if wave % 2 == 1: point.x = -point.x
		if family == "seed_spitter" and point.length() > 12.8: point = point.normalized() * 12.8
		return {"pos": Vector3(point.x, .03, point.y), "delay": delay, "after_kills": after_kills}
	match stage_id:
		85: positions = [[Vector2(-5, -9)], [Vector2(-7, -10.5), Vector2(7, -10.5)]][wave]
		86: positions = [[Vector2(-5.8, -8.5), Vector2(6.4, -10.5)], [Vector2(5.8, -8.5), Vector2(-6.4, -10.5)]][wave]; delay = 1.8 * index
		87: positions = [[Vector2(-6, -9.5), Vector2(6.7, -11)], [Vector2(6.2, -9.2), Vector2(-6.7, -11), Vector2(0, -12.5)]][wave]; delay = 1.5 * index
		88: positions = [[Vector2(0, -10.5), Vector2(-6, -8), Vector2(6, -8)], [Vector2(-7, -10.5), Vector2(7, -10.5)]][wave]; delay = .9 * index
		89: positions = [[Vector2(-6.4, -10), Vector2(6.4, -10)], [Vector2(6.5, -9), Vector2(-6.5, -11)], [Vector2(-4.8, -11)]][wave]; delay = 1.2 * index
		90: positions = [Vector2(-6.6, -12.8), Vector2(6.6, -12.8), Vector2(-4.7, -7.7), Vector2(4.7, -7.7)]; delay = [2.0, 3.8, 0.0, 1.0][index]
		91: positions = [[Vector2(-7, -10), Vector2(7, -10), Vector2(0, -12)], [Vector2(-5.8, -9.5), Vector2(5.8, -9.5)]][wave]; delay = 1.2 * index
		92: positions = [[Vector2(-7.7, -9.3), Vector2(7.7, -9.3)], [Vector2(4.4, -11)]][wave]; delay = 1.8 * index
		93: positions = [[Vector2(-5.4, -10), Vector2(6.6, -8.8)], [Vector2(5.4, -10), Vector2(-6.8, -11)]][wave]; delay = 1.7 * index
		94: positions = [[Vector2(-6, -10), Vector2(6, -10)], [Vector2(-6.2, -8.7), Vector2(6.2, -10.7)], [Vector2(0, -11.7), Vector2(-6.7, -11)]][wave]; delay = 1.5 * index
		95: positions = [[Vector2(-1.5, -9), Vector2(1.5, -9)], [Vector2(-2, -12), Vector2(2, -12)], [Vector2(0, -11.5)]][wave]
		96: positions = [[Vector2(-6.3, -10)], [Vector2(6.3, -10)], [Vector2(0, -12.5)]][wave]
		97: positions = [[Vector2(-6.5, -9), Vector2(6.7, -11)], [Vector2(5.8, -10), Vector2(-6, -10.5)], [Vector2(-6, -12)]][wave]; delay = 1.6 * index
		98: positions = [[Vector2(-6.9, -10.4), Vector2(6.9, -10.4)], [Vector2(5.7, -10.5), Vector2(-6.4, -9.2)], [Vector2(0, -13)]][wave]; delay = 1.6 * index
	var point: Vector2 = positions[index % positions.size()]
	return {"pos": Vector3(point.x, .03, point.y), "delay": delay, "after_kills": after_kills}

func build(stage: Node3D, manager: Node3D) -> void:
	var holder := Node3D.new(); holder.name = "EncounterTerrain"; stage.add_child(holder)
	for i in range(covers.size()):
		var record: Dictionary = covers[i]
		var body := StaticBody3D.new(); body.name = "LivingCover%d" % i; body.collision_layer = 1; body.collision_mask = 0
		body.position = stage.spawn + record.pos; holder.add_child(body); cover_bodies.append(body)
		var collision := CollisionShape3D.new(); var shape := CylinderShape3D.new()
		shape.radius = record.radius; shape.height = record.height; collision.shape = shape; collision.position.y = record.height * .5; body.add_child(collision)
		var mesh := MeshInstance3D.new(); var stump := CylinderMesh.new()
		stump.top_radius = record.radius * .88; stump.bottom_radius = record.radius * 1.05; stump.height = record.height; stump.radial_segments = 24
		mesh.mesh = stump; mesh.position.y = record.height * .5; body.add_child(mesh)
		var bark := StandardMaterial3D.new(); bark.albedo_color = Color("414a3e"); bark.roughness = .85; mesh.material_override = bark
		var crown := MeshInstance3D.new(); var moss := CylinderMesh.new()
		moss.top_radius = record.radius * .90; moss.bottom_radius = record.radius * .92; moss.height = .18; moss.radial_segments = 24
		crown.mesh = moss; crown.position.y = record.height; body.add_child(crown)
		var leaves := StandardMaterial3D.new(); leaves.albedo_color = Color("5c7d52"); leaves.roughness = .9; crown.material_override = leaves
		# Ancient glowing runic ring on monolith
		var rune_ring := MeshInstance3D.new(); var tm := TorusMesh.new()
		tm.inner_radius = record.radius * .89; tm.outer_radius = record.radius * .93; tm.rings = 24; tm.ring_segments = 8
		rune_ring.mesh = tm; rune_ring.position.y = record.height * .75; rune_ring.rotation.x = 0.08; body.add_child(rune_ring)
		var rune_mat := StandardMaterial3D.new(); rune_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rune_mat.albedo_color = Color("70e6c5"); rune_mat.emission_enabled = true; rune_mat.emission = Color("70e6c5"); rune_mat.emission_energy_multiplier = 2.2
		rune_ring.material_override = rune_mat
	_build_navigation(stage, manager)

func cover_bounds(stage: Node3D, padding: float = .9) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for record in covers:
		var p: Vector3 = stage.spawn + record.pos
		var half: float = float(record.radius) + padding
		result.append(Rect2(Vector2(p.x - half, p.z - half), Vector2.ONE * half * 2))
	return result

func _build_navigation(stage: Node3D, manager: Node3D) -> void:
	# Shared cell vertices make one connected navigation surface. Omitted cells
	# are generous, agent-sized holes around the physical root pillars.
	var bounds: Rect2 = stage.safe_bounds.grow(-1.5)
	var holes: Array[Rect2] = cover_bounds(stage)
	var xs: Array[float] = [bounds.position.x, bounds.end.x]
	var zs: Array[float] = [bounds.position.y, bounds.end.y]
	# Balanced cells keep the pathfinder from choosing a distant corner of an
	# arena-wide polygon when rounding a nearby pillar.
	for x in range(ceili(bounds.position.x / 3.0), ceili(bounds.end.x / 3.0)): xs.append(float(x) * 3.0)
	for z in range(ceili(bounds.position.y / 3.0), ceili(bounds.end.y / 3.0)): zs.append(float(z) * 3.0)
	for hole in holes:
		xs.append(snappedf(hole.position.x, .001)); xs.append(snappedf(hole.end.x, .001)); zs.append(snappedf(hole.position.y, .001)); zs.append(snappedf(hole.end.y, .001))
	xs.sort(); zs.sort()
	var vertices: Array[Vector3] = []
	var lookup := {}
	var polygons: Array[PackedInt32Array] = []
	for x in range(xs.size() - 1):
		for z in range(zs.size() - 1):
			if xs[x + 1] - xs[x] < .001 or zs[z + 1] - zs[z] < .001: continue
			var center := Vector2((xs[x] + xs[x + 1]) * .5, (zs[z] + zs[z + 1]) * .5)
			var blocked := false
			for hole in holes:
				if hole.has_point(center): blocked = true; break
			if blocked: continue
			var polygon := PackedInt32Array()
			for point in [Vector2(xs[x], zs[z]), Vector2(xs[x], zs[z + 1]), Vector2(xs[x + 1], zs[z + 1]), Vector2(xs[x + 1], zs[z])]:
				if not lookup.has(point): lookup[point] = vertices.size(); vertices.append(Vector3(point.x, stage.spawn.y, point.y))
				polygon.append(lookup[point])
			polygons.append(polygon)
	var mesh := NavigationMesh.new(); mesh.vertices = PackedVector3Array(vertices)
	for polygon in polygons: mesh.add_polygon(polygon)
	navigation_region = NavigationRegion3D.new(); navigation_region.name = "EncounterNavigation"; navigation_region.navigation_mesh = mesh; manager.add_child(navigation_region)
