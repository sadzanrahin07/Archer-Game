extends StaticBody3D

var game: Node
var index := 0
var material_kind := "ring"
var hp := 1.0
var max_hp := 1.0
var hp_override := 0.0
var hits_left := 1
var center_streak := 0
var completed := false
var active := true
var route_enabled := true
var moving := false
var final_stone := false
var approach_distance := 0.0
var phase := 0.0
var base_position := Vector3.ZERO
var elapsed := 0.0
var motion_style := 0
var required_range := 0.0
var zone_radius := .67
var body_mesh: MeshInstance3D
var stone_visual: Node3D
var marker: Label3D
var cracks: Array[MeshInstance3D] = []
var rings: Array[MeshInstance3D] = []
var resolved_shots: Array[int] = []

# New Mechanics
var is_pierceable := false
var is_rising := false
var is_pendulum := false
var is_armor_petals := false
var is_clasp := false

enum RisingState { REST, CUE, EXPOSED, RETRACT }
var rising_state := RisingState.REST
var rising_timer := 0.0
var rising_cue_time := 0.8
var rising_exposed_time := 2.5
var rising_retract_time := 0.4
var rising_rest_time := 3.2
var board_pivot: Node3D
var board_collider:CollisionShape3D
var rising_single:=false
var rising_slot:=0
var rising_total:=1
var rising_shuffle:=false
var rising_seed:=0
var hinge_glow: MeshInstance3D
var cue_icon: Label3D
var base_mount: Node3D

var pendulum_length := 3.2
var swing_speed := 1.5
var swing_amplitude := 0.42
var suspension_mount: Node3D
var rope_left: MeshInstance3D
var rope_right: MeshInstance3D

var petals: Array[MeshInstance3D] = []
var petals_remaining := 3
var core_mesh: MeshInstance3D
var core_exposed := false

var hp_values := {
	"ring": 1.0, "glass": 10.0, "clay": 20.0, "wood": 35.0,
	"crate": 45.0, "panel": 55.0, "stone": 80.0, "rune": 100.0, "master": 140.0,
	"rising": 10.0, "rising_board": 10.0, "soft_orb": 10.0, "thread_orb": 10.0,
	"hanging_orb": 10.0, "pendulum": 10.0, "armor_petals": 80.0, "core_monolith": 80.0,
	"clasp": 5.0
}
const StoneVisual = preload("res://campaign/rune_stone.gd")

func _ready() -> void:
	collision_layer = 4; collision_mask = 0
	max_hp = hp_override if hp_override > 0 else float(hp_values.get(material_kind, 80))
	hp = max_hp
	var shape := CollisionShape3D.new()

	if material_kind in ["rising", "rising_board"]:
		is_rising = true
	elif material_kind in ["soft_orb", "thread_orb", "hanging_orb"]:
		is_pierceable = true
	elif material_kind in ["pendulum"]:
		is_pendulum = true
	elif material_kind in ["armor_petals", "core_monolith"]:
		is_armor_petals = true
	elif material_kind == "clasp":
		is_clasp = true

	if motion_style == 2:
		is_pendulum = true
	elif motion_style == 3:
		is_rising = true

	if material_kind in ["stone", "rune", "master"] or is_armor_petals:
		stone_visual = StoneVisual.new(); add_child(stone_visual)
		body_mesh = stone_visual.build("stone" if is_armor_petals else material_kind, index + int(phase * 100))
		var convex := ConvexPolygonShape3D.new(); convex.points = PackedVector3Array(stone_visual.facets); shape.shape = convex
		zone_radius = .85
		if is_armor_petals:
			_build_armor_petals()
	elif is_pierceable:
		_build_soft_orb(shape)
	elif is_clasp:
		_build_clasp(shape)
	elif is_rising:
		_build_rising_board(shape)
	else:
		_build_standard_board(shape)

	add_child(shape)
	if is_pendulum:
		_build_pendulum_suspension()

	marker = Label3D.new()
	marker.position.y = 2.2 if stone_visual else (1.2 if not is_pierceable else 0.75)
	marker.font_size = 40; marker.pixel_size = .008
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED; marker.outline_size = 8; marker.no_depth_test = true
	add_child(marker)
	base_position = position

	if is_rising:
		_set_rising_state(RisingState.REST)
		rising_timer=.3+fmod(phase,1.6)

	_refresh()

func _build_standard_board(shape: CollisionShape3D) -> void:
	var box := BoxShape3D.new(); box.size = Vector3(1.35, 1.35, .24); shape.shape = box
	body_mesh = MeshInstance3D.new()
	if material_kind in ["glass", "clay"]:
		var bottle := CylinderMesh.new(); bottle.top_radius = .18; bottle.bottom_radius = .35; bottle.height = 1.2
		body_mesh.mesh = bottle; zone_radius = .32
		var cylinder := CylinderShape3D.new(); cylinder.radius = .35; cylinder.height = 1.2; shape.shape = cylinder
	else:
		var board := BoxMesh.new(); board.size = Vector3(1.4, 1.4, .18) if material_kind == "ring" else box.size; body_mesh.mesh = board
	var colors := {"ring": Color("806342"), "glass": Color("73bcb5"), "clay": Color("bd754e"), "wood": Color("8e623a"), "crate": Color("a47742"), "panel": Color("646e75"), "pendulum": Color("806342")}
	var mat := StandardMaterial3D.new(); mat.albedo_color = colors.get(material_kind, Color("6b746b")); mat.roughness = .87
	body_mesh.material_override = mat; add_child(body_mesh)
	_add_rings(body_mesh)

func _build_rising_board(shape: CollisionShape3D) -> void:
	board_collider=shape
	# Base ground mount
	base_mount = Node3D.new(); add_child(base_mount)
	var mount_box := MeshInstance3D.new(); var mm := BoxMesh.new(); mm.size = Vector3(1.6, 0.15, 0.5); mount_box.mesh = mm
	var mount_mat := StandardMaterial3D.new(); mount_mat.albedo_color = Color("4a3828"); mount_mat.roughness = 0.95
	mount_box.material_override = mount_mat; mount_box.position.y = -0.72; base_mount.add_child(mount_box)

	# Brass hinge cylinder
	var hinge := MeshInstance3D.new(); var hm := CylinderMesh.new(); hm.top_radius = 0.05; hm.bottom_radius = 0.05; hm.height = 1.45
	hinge.mesh = hm; hinge.rotation.z = PI / 2; hinge.position = Vector3(0, -0.65, 0)
	var hinge_mat := StandardMaterial3D.new(); hinge_mat.albedo_color = Color("c49b4b"); hinge_mat.metallic = 0.7; hinge_mat.roughness = 0.35
	hinge.material_override = hinge_mat; base_mount.add_child(hinge)

	# Amber hinge glow ribbon
	hinge_glow = MeshInstance3D.new(); var gm := BoxMesh.new(); gm.size = Vector3(1.4, 0.08, 0.08); hinge_glow.mesh = gm
	hinge_glow.position = Vector3(0, -0.63, 0.04)
	var gmat := StandardMaterial3D.new(); gmat.albedo_color = Color("f5c042"); gmat.emission_enabled = true; gmat.emission = Color("f5c042"); gmat.emission_energy_multiplier = 2.0
	hinge_glow.material_override = gmat; hinge_glow.visible = false; base_mount.add_child(hinge_glow)

	# Cue indicator '!'
	cue_icon = Label3D.new(); cue_icon.text = "!"; cue_icon.font_size = 64; cue_icon.pixel_size = 0.012
	cue_icon.modulate = Color("f5c042"); cue_icon.outline_size = 10; cue_icon.outline_modulate = Color("382200")
	cue_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED; cue_icon.position = Vector3(0, 0.1, 0.1); cue_icon.visible = false
	add_child(cue_icon)

	# Board Pivot at the hinge
	board_pivot = Node3D.new(); board_pivot.position = Vector3(0, -0.65, 0); add_child(board_pivot)

	# Board mesh (stands 1.4m high, centered 0.7m above hinge)
	body_mesh = MeshInstance3D.new(); var board := BoxMesh.new(); board.size = Vector3(1.4, 1.4, .18); body_mesh.mesh = board
	body_mesh.position = Vector3(0, 0.70, 0)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("806342"); mat.roughness = .87
	body_mesh.material_override = mat; board_pivot.add_child(body_mesh)
	_add_rings(board_pivot, Vector3(0, 0.70, 0))

	var box := BoxShape3D.new(); box.size = Vector3(1.4, 1.4, .24); shape.shape = box
	shape.position = Vector3(0, 0, 0)

func _build_soft_orb(shape: CollisionShape3D) -> void:
	var sphere := SphereShape3D.new(); sphere.radius = 0.40; shape.shape = sphere
	zone_radius = 0.40
	body_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.38; sm.height = 0.76; body_mesh.mesh = sm

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.40, 0.94, 0.88, 0.78)
	mat.roughness = 0.06; mat.metallic = 0.15
	mat.emission_enabled = true; mat.emission = Color("30a89b"); mat.emission_energy_multiplier = 0.9
	body_mesh.material_override = mat; add_child(body_mesh)

	# Inner glowing core
	var inner := MeshInstance3D.new(); var im := SphereMesh.new(); im.radius = 0.16; im.height = 0.32; inner.mesh = im
	var imat := StandardMaterial3D.new(); imat.albedo_color = Color("ffe88a"); imat.emission_enabled = true
	imat.emission = Color("ffcf4d"); imat.emission_energy_multiplier = 2.5
	inner.material_override = imat; body_mesh.add_child(inner)

	# Hanging cord
	var cord := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.015; cm.bottom_radius = 0.015; cm.height = 1.8
	cord.mesh = cm; cord.position = Vector3(0, 1.25, 0)
	var cord_mat := StandardMaterial3D.new(); cord_mat.albedo_color = Color("a38b68"); cord_mat.roughness = 0.9
	cord.material_override = cord_mat; add_child(cord)

func _build_clasp(shape: CollisionShape3D) -> void:
	var box := BoxShape3D.new(); box.size = Vector3(0.5, 0.7, 0.3); shape.shape = box
	zone_radius = 0.35
	body_mesh = MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.45, 0.65, 0.25); body_mesh.mesh = bm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("c49b4b"); mat.metallic = 0.75; mat.roughness = 0.3
	body_mesh.material_override = mat; add_child(body_mesh)

	var rope := MeshInstance3D.new(); var rm := CylinderMesh.new(); rm.top_radius = 0.03; rm.bottom_radius = 0.03; rm.height = 3.0
	rope.mesh = rm; rope.position = Vector3(0, 1.8, 0)
	var rmat := StandardMaterial3D.new(); rmat.albedo_color = Color("7a5e3a"); rmat.roughness = 0.95
	rope.material_override = rmat; add_child(rope)

func _build_pendulum_suspension() -> void:
	suspension_mount = Node3D.new(); add_child(suspension_mount)
	# Suspension beam at base_position + Vector3(0, pendulum_length + 0.5, 0)
	var beam := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.8, 0.2, 0.2); beam.mesh = bm
	beam.position = Vector3(0, pendulum_length + 0.3, 0)
	var bmat := StandardMaterial3D.new(); bmat.albedo_color = Color("543d26"); bmat.roughness = 0.9
	beam.material_override = bmat; suspension_mount.add_child(beam)

	# Left and Right ropes
	for side in [-1, 1]:
		var rope := MeshInstance3D.new(); var rm := CylinderMesh.new(); rm.top_radius = 0.012; rm.bottom_radius = 0.012; rm.height = pendulum_length
		rope.mesh = rm; rope.position = Vector3(side * 0.45, (pendulum_length + 0.3) * 0.5, 0)
		var rmat := StandardMaterial3D.new(); rmat.albedo_color = Color("8f7552"); rmat.roughness = 0.9
		rope.material_override = rmat; suspension_mount.add_child(rope)

func _build_armor_petals() -> void:
	petals.clear(); petals_remaining = 3
	for i in range(3):
		var petal := MeshInstance3D.new(); var pm := BoxMesh.new(); pm.size = Vector3(0.55, 1.2, 0.12); petal.mesh = pm
		var angle := i * (TAU / 3.0) - PI / 2.0
		petal.position = Vector3(cos(angle) * 0.42, 0.2 + sin(angle) * 0.25, 0.45)
		petal.rotation.z = angle + PI / 2.0
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color("70685c"); mat.roughness = 0.9
		petal.material_override = mat; add_child(petal); petals.append(petal)

	core_mesh = MeshInstance3D.new(); var cm := SphereMesh.new(); cm.radius = 0.28; cm.height = 0.56; core_mesh.mesh = cm
	core_mesh.position = Vector3(0, 0.2, 0.35)
	var cmat := StandardMaterial3D.new(); cmat.albedo_color = Color("ffb84d"); cmat.emission_enabled = true; cmat.emission = Color("ff881a"); cmat.emission_energy_multiplier = 2.0
	core_mesh.material_override = cmat; core_mesh.visible = false; add_child(core_mesh)

func _add_rings(parent_node: Node3D = self, offset: Vector3 = Vector3.ZERO) -> void:
	for k in range(4):
		var disc := MeshInstance3D.new(); var mesh := CylinderMesh.new()
		mesh.top_radius = [.63, .46, .27, .10][k]; mesh.bottom_radius = mesh.top_radius; mesh.height = .008; disc.mesh = mesh
		disc.rotation.x = PI / 2; disc.position = offset + Vector3(0, 0, .13 + k * .009)
		var mat := StandardMaterial3D.new(); mat.albedo_color = [Color("f4efdd"), Color("9cccd6"), Color("e48275"), Color("edd26b")][k]
		disc.material_override = mat
		if material_kind in ["glass", "clay"]: disc.scale = Vector3(.48, 1, .48); disc.position = offset + Vector3(0, 0, .36 + k * .009)
		parent_node.add_child(disc); rings.append(disc)

func _physics_process(delta: float) -> void:
	if completed or not game.is_playing(): return
	elapsed += delta

	if is_pendulum:
		var angle := sin(elapsed * swing_speed + phase) * swing_amplitude
		position = base_position + Vector3(sin(angle) * pendulum_length, (1.0 - cos(angle)) * pendulum_length, 0)
		rotation.z = -angle
		if is_instance_valid(suspension_mount):
			suspension_mount.global_position = base_position

	elif is_rising:
		_process_rising_state(delta)

	elif moving:
		position = base_position + Vector3(sin(elapsed * 1.4 + phase) * 1.6, .2 * cos(elapsed + phase), 0)
		if motion_style == 1:
			active = sin(elapsed * 1.8 + phase) > -.4
			for mesh in rings: mesh.visible = active
			if body_mesh: body_mesh.visible = active

	_refresh()

func _process_rising_state(delta: float) -> void:
	if rising_single:
		var slot_time:float=rising_cue_time+rising_exposed_time+rising_retract_time
		var cycle:int=floori(elapsed/(slot_time*rising_total))
		var slot:int=posmod(rising_slot+posmod(hash(str(rising_seed)+":"+str(cycle)),rising_total),rising_total) if rising_shuffle else rising_slot
		var local_time:float=fmod(elapsed,slot_time*rising_total)-slot*slot_time
		var next_state:int=RisingState.REST
		if local_time>=0 and local_time<rising_cue_time:next_state=RisingState.CUE
		elif local_time>=rising_cue_time and local_time<rising_cue_time+rising_exposed_time:next_state=RisingState.EXPOSED
		elif local_time>=rising_cue_time+rising_exposed_time and local_time<slot_time:next_state=RisingState.RETRACT
		if next_state!=rising_state:_set_rising_state(next_state)
		if next_state==RisingState.CUE:board_pivot.rotation.x=lerpf(-PI*.48,0,clampf(local_time/rising_cue_time,0,1))
		elif next_state==RisingState.RETRACT:board_pivot.rotation.x=lerpf(0,-PI*.48,(local_time-rising_cue_time-rising_exposed_time)/rising_retract_time)
		_sync_board_collider()
		return
	rising_timer -= delta
	match rising_state:
		RisingState.REST:
			active = false
			if board_pivot: board_pivot.rotation.x = -PI * 0.48
			if hinge_glow: hinge_glow.visible = false
			if cue_icon: cue_icon.visible = false
			if rising_timer <= 0:
				_set_rising_state(RisingState.CUE)
		RisingState.CUE:
			active = false
			if hinge_glow:
				hinge_glow.visible = true
				var pulse := 1.5 + sin(elapsed * 16.0) * 0.8
				hinge_glow.material_override.set("emission_energy_multiplier", pulse)
			if cue_icon:
				cue_icon.visible = true
				cue_icon.scale = Vector3.ONE * (1.0 + sin(elapsed * 12.0) * 0.15)
			if rising_timer <= 0:
				_set_rising_state(RisingState.EXPOSED)
		RisingState.EXPOSED:
			active = true
			if hinge_glow: hinge_glow.visible = false
			if cue_icon: cue_icon.visible = false
			if board_pivot:
				board_pivot.rotation.x = lerp_angle(board_pivot.rotation.x, 0.0, delta * 12.0)
			if rising_timer <= 0:
				_set_rising_state(RisingState.RETRACT)
		RisingState.RETRACT:
			active = false
			if board_pivot:
				board_pivot.rotation.x = lerp_angle(board_pivot.rotation.x, -PI * 0.48, delta * 10.0)
			if rising_timer <= 0:
				_set_rising_state(RisingState.REST)

	_sync_board_collider()

func _sync_board_collider() -> void:
	if is_instance_valid(board_collider) and is_instance_valid(board_pivot):board_collider.transform=board_pivot.transform*Transform3D(Basis.IDENTITY,Vector3(0,.7,0))

func _set_rising_state(new_state: RisingState) -> void:
	rising_state = new_state
	match rising_state:
		RisingState.REST:
			rising_timer = rising_rest_time
			active = false
			if board_pivot: board_pivot.rotation.x = -PI * 0.48
			if hinge_glow: hinge_glow.visible = false
			if cue_icon: cue_icon.visible = false
		RisingState.CUE:
			rising_timer = rising_cue_time
			active = false
			if hinge_glow: hinge_glow.visible = true
			if cue_icon: cue_icon.visible = true
			if is_instance_valid(game) and game.has_method("play_sound"):
				game.play_sound("res://campaign/audio/cue_rise.wav")
		RisingState.EXPOSED:
			rising_timer = rising_exposed_time
			active = true
			if board_pivot: board_pivot.rotation.x = 0.0
			if hinge_glow: hinge_glow.visible = false
			if cue_icon: cue_icon.visible = false
		RisingState.RETRACT:
			rising_timer = rising_retract_time
			active = false
			if hinge_glow: hinge_glow.visible = false
			if cue_icon: cue_icon.visible = false

func set_active(value: bool) -> void:
	route_enabled=value
	active = value; _refresh()

func _refresh() -> void:
	if not marker: return
	if completed: marker.text = "CLEAR"; return
	var suffix := " · %d HP" % ceili(hp)
	if is_rising:
		var state_str := "▲ RISE" if active else ("! CUE" if rising_state == RisingState.CUE else "▽ REST")
		marker.text = ("%s %d" % [state_str, index + 1]) + suffix
		marker.modulate = Color("f5c042") if active else (Color("f59e42") if rising_state == RisingState.CUE else Color("8a9490"))
	elif is_pierceable:
		marker.text = ("◎ THREAD %d" % [index + 1]) + suffix
		marker.modulate = Color("6ee8d8")
	elif is_armor_petals:
		marker.text = ("★ CORE SEAL" if core_exposed else "◆ MONOLITH (%d/3)" % petals_remaining) + suffix
		marker.modulate = Color("ff881a") if core_exposed else Color("f6e1a2")
	else:
		marker.text = ("FINAL STONE" if final_stone else "%s %d" % ["◆" if active else "○", index + 1]) + suffix
		marker.modulate = Color("f6e1a2") if active else Color("b0bdb8")

func hit_zone(hit_pos: Vector3) -> int:
	var point := to_local(hit_pos)
	if is_armor_petals:point.y-=.2
	var radius := Vector2(point.x, point.y).length() / zone_radius
	if (material_kind == "ring" or is_rising) and radius > 1: return -1
	return 3 if radius <= .15 else (2 if radius <= .403 else (1 if radius <= .687 else 0))

func damage_multiplier(zone: int) -> float:
	if is_pierceable: return 1.0
	if material_kind in ["stone", "rune", "master"] or is_armor_petals: return [.70, .80, .90, 1.0][clampi(zone, 0, 3)]
	return [.30, .60, .80, 1.0][clampi(zone, 0, 3)]

func _combo_multiplier(zone: int) -> float:
	return 1.0 + minf(center_streak, 2) * .1 if zone == 3 and (material_kind in ["stone", "rune", "master"] or is_armor_petals) else 1.0

func can_receive_hit() -> bool:
	if completed or not game.is_playing() or not route_enabled: return false
	if get_parent() and get_parent().has_method("mechanic_allows_hit") and not get_parent().mechanic_allows_hit(self):return false
	if is_rising:
		return rising_state == RisingState.EXPOSED
	if not active: return false
	if final_stone and approach_distance > 0 and is_instance_valid(game.get("hero")):
		var archer: Node3D = game.hero
		if Vector2(archer.global_position.x - global_position.x, archer.global_position.z - global_position.z).length() > approach_distance: return false
	return true

func would_be_destroyed(hit_pos: Vector3, power: float) -> bool:
	if not can_receive_hit() or (is_armor_petals and petals_remaining>0): return false
	var zone := hit_zone(hit_pos)
	return zone >= 0 and hp <= power * damage_multiplier(zone) * (_combo_multiplier(zone))

func campaign_hit(hit_pos: Vector3, power: float, shot_context: Dictionary = {}) -> bool:
	if completed or not game.is_playing(): return false
	if is_rising and rising_state != RisingState.EXPOSED:
		game.feedback("Wait for the rise!")
		game.play_sound("res://campaign/audio/target-impact-single.wav")
		return false
	if not active or not route_enabled:
		game.feedback("Hit the highlighted target first" if motion_style == 0 else "Wait for the target to appear"); return false
	if not can_receive_hit():
		game.feedback(str(get_parent().definition.get("encounter_hint","Reach the final stone clearing") if get_parent() and "definition" in get_parent() else "Reach the final stone clearing"))
		return false
	var shot_id := int(shot_context.get("shot_id", -1))
	if shot_id >= 0 and shot_id in resolved_shots: return false

	if is_armor_petals and petals_remaining > 0:
		if shot_id >= 0: resolved_shots.append(shot_id)
		game.target_scored(3,power,true)
		var p_idx := 3 - petals_remaining
		if p_idx >= 0 and p_idx < petals.size():
			_shatter_petal(petals[p_idx])
		petals_remaining -= 1
		hp = maxf(0.01, max_hp * float(petals_remaining)/3.0) if petals_remaining>0 else max_hp
		game.play_sound("res://campaign/audio/plate_break.wav")
		if petals_remaining == 0:
			core_exposed = true
			if core_mesh: core_mesh.visible = true
			game.feedback("★ Monolith Core Exposed! Shoot the center!")
		else:
			game.feedback("Armor plate shattered! %d remaining" % petals_remaining)
		_refresh(); return true

	var zone := hit_zone(hit_pos)
	if zone < 0: center_streak = 0; game.feedback("Frame hit · aim inside the rings"); return false
	if shot_id >= 0: resolved_shots.append(shot_id)
	if not bool(shot_context.get("secondary", false)):
		if get_parent() and "targets" in get_parent():
			for other in get_parent().targets:
				if is_instance_valid(other) and other != self: other.center_streak = 0
	var damage := power * damage_multiplier(zone) * _combo_multiplier(zone)
	center_streak = center_streak + 1 if zone == 3 else 0
	hp = maxf(0, hp - damage)
	if not bool(shot_context.get("secondary", false)): game.target_scored(zone, damage, material_kind != "ring")
	var tween := create_tween(); tween.tween_property(body_mesh, "scale", Vector3.ONE * .96, .06); tween.tween_property(body_mesh, "scale", Vector3.ONE, .12)
	if hp <= 0.001:
		completed = true; collision_layer = 0
		for child in get_children():
			if child is Node3D and child != marker: child.visible = false
		if is_pierceable:
			_break_crystal_effect()
		else:
			_break_effect()
		game.target_completed(index)
	_refresh(); return true

func campaign_secondary_hit(power: float, shot_id: int) -> bool:
	if material_kind == "ring" or is_rising: return false
	return campaign_hit(global_position + Vector3(0, 0, .45), power, {"shot_id": shot_id, "secondary": true})

func _shatter_petal(petal: MeshInstance3D) -> void:
	for i in range(6):
		var piece := MeshInstance3D.new(); var cube := BoxMesh.new(); cube.size = Vector3.ONE * 0.15; piece.mesh = cube
		piece.material_override = petal.material_override; add_child(piece)
		piece.global_position = petal.global_position
		var tween := create_tween().set_parallel(true)
		tween.tween_property(piece, "position", piece.position + Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.7), randf_range(-0.5, 0.8)), 0.45)
		tween.tween_property(piece, "rotation", Vector3(randf(), randf(), randf()) * 4, 0.45)
		tween.tween_property(piece, "scale", Vector3.ZERO, 0.3).set_delay(0.45); tween.chain().tween_callback(piece.queue_free)
	petal.visible = false

func _break_crystal_effect() -> void:
	for i in range(14):
		var shard := MeshInstance3D.new(); var sm := PrismMesh.new(); sm.size = Vector3.ONE * randf_range(0.08, 0.16); shard.mesh = sm
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.45, 0.95, 0.9, 0.85); mat.emission_enabled = true
		mat.emission = Color("6ee8d8"); mat.emission_energy_multiplier = 1.8; shard.material_override = mat; add_child(shard)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(shard, "position", Vector3(randf_range(-1.2, 1.2), randf_range(-0.8, 1.0), randf_range(-1.0, 1.0)), 0.55)
		tween.tween_property(shard, "rotation", Vector3(randf(), randf(), randf()) * 6, 0.55)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.35).set_delay(0.55); tween.chain().tween_callback(shard.queue_free)

func _break_effect() -> void:
	for i in range(12 if stone_visual else 8):
		var piece := MeshInstance3D.new(); var cube := BoxMesh.new(); cube.size = Vector3.ONE * (.22 if stone_visual else .13); piece.mesh = cube
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color("506263") if stone_visual else Color("9a805c"); mat.roughness = .9; piece.material_override = mat; add_child(piece)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(piece, "position", Vector3(randf_range(-1.3, 1.3), randf_range(-.7, .8), randf_range(-.5, .7)), .55)
		tween.tween_property(piece, "rotation", Vector3(randf(), randf(), randf()) * 5, .55)
		tween.tween_property(piece, "scale", Vector3.ZERO, .4).set_delay(.55); tween.chain().tween_callback(piece.queue_free)
