extends Node3D

# Genshin Impact Style In-Flight & Impact Elemental VFX (No circular rings)
var projectile: Node3D
var key := "normal"
var rank := 1
var energy_core: MeshInstance3D
var trail: MeshInstance3D
var flight_light: OmniLight3D
var elapsed := 0.0
var start_height := 0.0
var tone := Color("a0ede5")
var shockwave_timer := 0.0
var shockwave_interval := 0.12
var flight_mote_count := 0
var launch_shockwave_done := false

const COLORS = {
	"burst": "a9e99a",
	"gale": "81eeff",
	"pressure": "b3f7ff",
	"fire": "ff874b",
	"lightning": "ecfff9",
	"super_lightning": "c59dff",
	"ultimate": "ffedb5"
}

func _ready() -> void:
	key = str(projectile.ability.get("key", "normal"))
	rank = int(projectile.ability.get("rank", 1))
	if key == "normal": return
	tone = Color(COLORS.get(key, "a0ede5"))

	# 1. Volumetric 3D Energy Needle Core (Pointed Arrowhead Beam)
	energy_core = MeshInstance3D.new()
	energy_core.name = "EnergyCore"
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.018
	core_mesh.bottom_radius = 0.038
	core_mesh.height = 0.55
	core_mesh.radial_segments = 12
	energy_core.mesh = core_mesh

	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	core_mat.albedo_color = Color.WHITE.lerp(tone, 0.25)
	core_mat.emission_enabled = true
	core_mat.emission = tone
	core_mat.emission_energy_multiplier = 1.6 if key in ["super_lightning", "ultimate"] else 1.2
	energy_core.material_override = core_mat
	energy_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Orient cylinder along Z (CylinderMesh is Y-up by default)
	energy_core.rotation.x = PI * 0.5
	add_child(energy_core)

	# 2. Dynamic Real-Time Flight Light
	flight_light = OmniLight3D.new()
	flight_light.name = "FlightLight"
	flight_light.light_color = tone
	flight_light.light_energy = .55
	flight_light.omni_range = 1.8
	flight_light.omni_attenuation = 1.6
	add_child(flight_light)

	# 3. Dynamic Flight Ribbon Trail
	trail = MeshInstance3D.new()
	trail.name = "Trail"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(tone.r, tone.g, tone.b, 0.85)
	mat.emission_enabled = true
	mat.emission = tone
	mat.emission_energy_multiplier = 1.1
	trail.material_override = mat
	add_child(trail)

	start_height = projectile.global_position.y
	# Launch waits for the spawner to set world position and velocity.

func _reduced_motion() -> bool:
	return is_instance_valid(projectile) and is_instance_valid(projectile.game) and bool(projectile.game.profile.data.settings.get("reduced_motion", false))

func _primary_effect() -> bool:
	return is_instance_valid(projectile) and bool(projectile.ability.get("vfx_primary", true))

func _spawn_launch_flash() -> void:
	if _reduced_motion() or not _primary_effect() or launch_shockwave_done: return
	launch_shockwave_done = true
	if not is_instance_valid(projectile): return
	var parent_stage: Node3D = _get_stage()
	if not is_instance_valid(parent_stage): return
	var pos: Vector3 = projectile.global_position
	var dir: Vector3 = projectile.velocity.normalized()
	if dir.length_squared() < 0.01:
		dir = -projectile.global_transform.basis.z

	var mult: float = _shockwave_multiplier()
	# Directional launch needle and flash sphere (NO rings)
	_create_needle_flash(parent_stage, pos, dir, 0.035 * mult, .45 * mult, tone, 0.22)
	_create_expanding_sphere(parent_stage, pos, 0.04 * mult, .18 * mult, Color.WHITE.lerp(tone, 0.3), 0.22)

func _get_stage() -> Node3D:
	if is_instance_valid(projectile) and is_instance_valid(projectile.game) and is_instance_valid(projectile.game.stage):
		return projectile.game.stage
	return get_parent() as Node3D

func _shockwave_multiplier() -> float:
	match key:
		"burst": return 0.9
		"gale": return 1.1
		"pressure": return 1.25
		"fire": return 1.20
		"lightning": return 1.35
		"super_lightning": return 1.55
		"ultimate": return 1.9
		_: return 1.0

func _process(delta: float) -> void:
	if key == "normal" or not is_instance_valid(projectile): return
	if not is_instance_valid(projectile.game) or projectile.game.state=="paused":return
	if not projectile.flying or projectile.game.state not in ["playing","finishing"]:
		if is_instance_valid(energy_core):energy_core.visible=false
		if is_instance_valid(trail):trail.visible=false
		if is_instance_valid(flight_light):flight_light.light_energy=0
		return
	if not launch_shockwave_done and projectile.velocity.length_squared()>.01:_spawn_launch_flash()
	if elapsed == 0: start_height = projectile.global_position.y
	elapsed += delta

	# Shed trailing elemental motes along flight path (NO rings)
	if projectile.flying and not _reduced_motion() and _primary_effect() and flight_mote_count < 12:
		shockwave_timer += delta
		if shockwave_timer >= shockwave_interval:
			shockwave_timer = 0.0
			_spawn_flight_mote()

	# Align volumetric energy needle along flight velocity
	if is_instance_valid(energy_core):
		var direction: Vector3 = projectile.velocity.normalized()
		if direction.length_squared() > 0.01:
			var up_vec := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
			energy_core.global_transform = Transform3D(Basis.looking_at(direction, up_vec)*Basis(Vector3.RIGHT,-PI*.5), projectile.global_position)
		var pulse: float = 1.0 if _reduced_motion() else 1.0 + 0.10 * sin(elapsed * 22.0)
		energy_core.scale = Vector3.ONE*pulse

	# Dynamic dual-helix 3D energy trail
	if is_instance_valid(trail):
		var mesh: ImmediateMesh = trail.mesh as ImmediateMesh
		if mesh == null: mesh = ImmediateMesh.new()
		mesh.clear_surfaces()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		var spread: float = 0.045 if key in ["lightning", "super_lightning"] else 0.025
		var segments := 10
		for helix in range(2):
			var helix_phase: float = float(helix) * PI
			for i in range(segments):
				var z1: float = float(i) * 0.12
				var z2: float = float(i + 1) * 0.12
				var a1: float = (0.0 if _reduced_motion() else elapsed * 8.0) + float(i) * 0.75 + helix_phase
				var a2: float = (0.0 if _reduced_motion() else elapsed * 8.0) + float(i + 1) * 0.75 + helix_phase
				var p1 := Vector3(cos(a1) * spread, sin(a1) * spread, z1)
				var p2 := Vector3(cos(a2) * spread, sin(a2) * spread, z2)
				mesh.surface_add_vertex(p1)
				mesh.surface_add_vertex(p2)
		mesh.surface_end()
		trail.mesh = mesh

func _spawn_flight_mote() -> void:
	if _reduced_motion() or not _primary_effect(): return
	flight_mote_count += 1
	var stage: Node3D = _get_stage()
	if not is_instance_valid(stage): return
	var pos: Vector3 = projectile.global_position
	var dir: Vector3 = projectile.velocity.normalized()
	if dir.length_squared() < 0.01: return
	# Create small glowing spark mote trailing behind
	var spark := MeshInstance3D.new()
	spark.process_mode=Node.PROCESS_MODE_PAUSABLE
	var sm := BoxMesh.new()
	sm.size = Vector3(0.025, 0.025, 0.08)
	spark.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(tone.r, tone.g, tone.b, 0.8)
	mat.emission_enabled = true
	mat.emission = tone
	mat.emission_energy_multiplier = 1.0
	spark.material_override = mat
	stage.add_child(spark)
	spark.global_position = pos
	var tw := spark.create_tween().set_parallel(true)
	tw.tween_property(spark, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(spark.queue_free)

func impact(position_world: Vector3, parent: Node3D) -> void:
	if key == "normal": return
	var target_parent: Node3D = parent if is_instance_valid(parent) else _get_stage()
	if not is_instance_valid(target_parent): return

	if _reduced_motion():
		_create_expanding_sphere(target_parent,position_world,.08,.08,tone,.12)
		return
	var mult: float = _shockwave_multiplier()

	# 1. 3D Volumetric Energy Burst Flash Sphere (NO concentric rings)
	_create_expanding_sphere(target_parent, position_world, 0.07 * mult, .60 * mult, Color.WHITE.lerp(tone, 0.35), 0.32)

	# 2. Genshin Radiating Impact Sparks (12 directional shard sparks flying outward)
	_spawn_impact_sparks(target_parent, position_world, 8, mult)

	# 3. Dynamic Impact Flash Light
	var impact_light := OmniLight3D.new()
	impact_light.process_mode=Node.PROCESS_MODE_PAUSABLE
	impact_light.light_color = tone
	impact_light.light_energy = .7 * mult
	impact_light.omni_range = 1.7 * mult
	impact_light.omni_attenuation = 1.4
	target_parent.add_child(impact_light)
	impact_light.global_position = position_world + Vector3.UP * 0.4
	var light_tw := impact_light.create_tween()
	light_tw.tween_property(impact_light, "light_energy", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	light_tw.chain().tween_callback(impact_light.queue_free)

	# 4. Screen Trauma / Camera Punch
	if is_instance_valid(projectile) and is_instance_valid(projectile.game) and is_instance_valid(projectile.game.hero):
		var hero = projectile.game.hero
		if hero.has_method("apply_shockwave_shake"):
			hero.apply_shockwave_shake(0.09 if key in ["super_lightning", "ultimate"] else 0.04)

func _spawn_impact_sparks(parent: Node3D, pos: Vector3, count: int, mult: float) -> void:
	for i in range(count):
		var spark := MeshInstance3D.new()
		spark.process_mode=Node.PROCESS_MODE_PAUSABLE
		var bm := BoxMesh.new()
		bm.size = Vector3(0.02, 0.02, 0.08)
		spark.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(tone.r, tone.g, tone.b, 0.9)
		mat.emission_enabled = true
		mat.emission = tone
		mat.emission_energy_multiplier = 1.4
		spark.material_override = mat
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(spark)
		spark.global_position = pos

		var rnd_dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.1, 1.0), randf_range(-1.0, 1.0)).normalized()
		var speed: float = randf_range(3.5, 7.5) * mult
		var duration: float = randf_range(0.20, 0.38)
		var dest: Vector3 = pos + rnd_dir * (speed * duration)

		var up_v := Vector3.UP if absf(rnd_dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		spark.look_at(pos + rnd_dir, up_v)

		var tw := spark.create_tween().set_parallel(true)
		tw.tween_property(spark, "global_position", dest, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "scale", Vector3(0.2, 0.2, 1.5), duration)
		tw.tween_property(mat, "albedo_color:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(spark.queue_free)

func _create_needle_flash(parent: Node3D, pos: Vector3, dir: Vector3, start_w: float, length: float, color: Color, duration: float) -> MeshInstance3D:
	if not is_instance_valid(parent): return null
	var needle := MeshInstance3D.new()
	needle.process_mode=Node.PROCESS_MODE_PAUSABLE
	var pm := PrismMesh.new()
	pm.size = Vector3(start_w, length, start_w)
	needle.mesh = pm

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	needle.material_override = mat
	needle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(needle)

	var y_up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	needle.global_transform = Transform3D(Basis.looking_at(dir, y_up), pos + dir * (length * 0.5))
	needle.transform.basis=needle.transform.basis*Basis(Vector3.RIGHT,-PI*.5)

	var tw := needle.create_tween().set_parallel(true)
	tw.tween_property(needle, "scale", Vector3(0.1, 2.0, 0.1), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(needle.queue_free)
	return needle

func _create_expanding_sphere(parent: Node3D, pos: Vector3, start_r: float, end_r: float, color: Color, duration: float) -> MeshInstance3D:
	if not is_instance_valid(parent): return null
	var sphere := MeshInstance3D.new()
	sphere.process_mode=Node.PROCESS_MODE_PAUSABLE
	var smesh := SphereMesh.new()
	smesh.radius = start_r
	smesh.height = start_r * 2.0
	smesh.radial_segments = 24
	smesh.rings = 12
	sphere.mesh = smesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.30)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.0
	sphere.material_override = mat
	sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sphere)
	sphere.global_position = pos

	var scale_factor: float = end_r / maxf(0.01, start_r)
	var tw := sphere.create_tween().set_parallel(true)
	tw.tween_property(sphere, "scale", Vector3.ONE * scale_factor, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(sphere.queue_free)
	return sphere
