class_name ErikaArcher
extends CharacterBody3D

@export var is_active_player: bool = true

@export var inactive: LimboState
@export var active: LimboState
@export var aim: LimboState
@export var fall: LimboState
@export var limbo_state: LimboHSM

@export var camera_manager: Node3D
@export var arrow_scene: PackedScene = preload("res://scenes/arrow_projectile.tscn")

@onready var animation_tree: AnimationTree = $Animationmisc/AnimationTree

const WALK_SPEED: float = 2.6
const SPRINT_SPEED: float = 5.6
const STRAFE_SPEED: float = 2.4
const ROTATION_SPEED: float = 8.0

var last_safe_ground_pos: Vector3 = Vector3.ZERO

# Animation & Skeleton
var skeleton: Skeleton3D = null
var anim_player: AnimationPlayer = null
var shoot_anim_timer: float = 0.0

# Archery Nodes & Weapon Structure
var bow_hand_attach: BoneAttachment3D = null
var bow_hand_node: MeshInstance3D = null
var arrow_hand_attach: BoneAttachment3D = null
var bow_string_node: MeshInstance3D = null
var bow_arrow_node: MeshInstance3D = null
var hand_held_arrow: MeshInstance3D = null
var aim_reticle: Control = null

# Calibrated Local Transform for Arrow held in Right Hand (mixamorig_RightHandIndex1, scale 65):
# Natural grip: Held between fingers, shaft extending down and forward along forearm
var arrow_transform_held: Transform3D = Transform3D(
	Basis.from_euler(Vector3(deg_to_rad(10.0), deg_to_rad(0.0), deg_to_rad(5.0))).scaled(Vector3(65, 65, 65)),
	Vector3(0.005, 0.025, -0.01)
)

# Calibrated Local Transforms for Bow attached to Left Hand (mixamorig_LeftHand, scale 85):
# 1. Idle / Catwalk: Bow hangs naturally alongside left thigh/hip with string placed inward
var bow_transform_idle: Transform3D = Transform3D(
	Basis.from_euler(Vector3(deg_to_rad(-45.0), deg_to_rad(-130.0), deg_to_rad(-35.0))).scaled(Vector3(85, 85, 85)),
	Vector3(-0.005, 0.072, 0.025)
)
# 2. ADS Aim / Shooting: Bow held upright and forward, resting inside palm, belly facing target
var bow_transform_aim: Transform3D = Transform3D(
	Basis.from_euler(Vector3(deg_to_rad(-90.0), deg_to_rad(68.6), 0.0)).scaled(Vector3(85, 85, 85)),
	Vector3(-0.005, 0.072, 0.025)
)

# Dynamic Bow Parameters
var bow_shelf_offset: Vector3 = Vector3(0.02, 0.02, 0.0)
var bow_tip_top: Vector3 = Vector3(0.0, 0.85, -0.269)
var bow_tip_bot: Vector3 = Vector3(0.0, -0.83, -0.269)
var bow_string_rest: Vector3 = Vector3(0.0, 0.0, -0.269)
var bow_string_pull_current: Vector3 = Vector3(0.0, 0.0, -0.269)
var string_twang_timer: float = 0.0

var is_bow_drawn: bool = true
var is_ads_aim: bool = false

# Audio Players
var snd_bow_draw: AudioStreamPlayer = null
var snd_arrow_swoosh: AudioStreamPlayer = null

func _ready() -> void:
	floor_snap_length = 0.45
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(55.0)
	floor_stop_on_slope = true
	last_safe_ground_pos = global_position
	
	add_to_group("player")
	add_to_group("player_characters")
	
	if not inactive:
		inactive = get_node_or_null("LimboHSM/Inactive")
	if not active:
		active = get_node_or_null("LimboHSM/Active")
	if not aim:
		aim = get_node_or_null("LimboHSM/Aim")
	if not fall:
		fall = get_node_or_null("LimboHSM/Fall")
	if not limbo_state:
		limbo_state = get_node_or_null("LimboHSM")
	if not camera_manager:
		camera_manager = get_node_or_null("CameraManager")
	
	_setup_animations()
	_setup_archery_system()
	_setup_audio()
	_setup_hud()
	init_state_machine()
	setup_transitions()
	_setup_hud_switch()
	_setup_input_actions()
	set_active_player(is_active_player)

func _setup_animations() -> void:
	anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_tree:
		animation_tree.active = false
		
	if not anim_player:
		return
		
	# 1. Looping for locomotion, idle, and aim overdraw
	for a_name in anim_player.get_animation_list():
		var anim = anim_player.get_animation(a_name)
		var a_low = a_name.to_lower()
		if "walk" in a_low or "run" in a_low or "idle" in a_low or "overdraw" in a_low:
			anim.loop_mode = Animation.LOOP_LINEAR
			
		# Zero root motion translation keys to prevent drifting
		for t in range(anim.get_track_count()):
			var pth = str(anim.track_get_path(t))
			if "mixamorig_Root" in pth and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				for k in range(anim.track_get_key_count(t)):
					anim.track_set_key_value(t, k, Vector3.ZERO)
					
	# 2. Build upright shooting & upright aim animations (matching Archer character)
	_create_upright_animation("standing aim recoil", "standing_aim_recoil_upright", 0)
	_create_upright_animation("standing aim overdraw", "standing_aim_overdraw_upright", 1)
	
	if anim_player.has_animation("standing idle 01"):
		anim_player.play("standing idle 01")

func _create_upright_animation(source_name: String, new_name: String, loop_mode: int) -> void:
	if not anim_player or not anim_player.has_animation(source_name):
		return
	var orig_anim = anim_player.get_animation(source_name)
	var idle_anim: Animation = null
	if anim_player.has_animation("standing idle 01"):
		idle_anim = anim_player.get_animation("standing idle 01")
	var new_anim = orig_anim.duplicate()
	for t in range(new_anim.get_track_count()):
		var p = str(new_anim.track_get_path(t))
		if "Hips" in p or "Leg" in p or "Foot" in p or "Toe" in p or "Root" in p:
			if idle_anim:
				var idle_t = idle_anim.find_track(new_anim.track_get_path(t), new_anim.track_get_type(t))
				if idle_t >= 0 and idle_anim.track_get_key_count(idle_t) > 0:
					while new_anim.track_get_key_count(t) > 0:
						new_anim.track_remove_key(t, 0)
					var val = idle_anim.track_get_key_value(idle_t, 0)
					new_anim.track_insert_key(t, 0.0, val)
					new_anim.track_insert_key(t, new_anim.length, val)
	new_anim.loop_mode = loop_mode
	var lib = anim_player.get_animation_library("")
	if lib:
		if lib.has_animation(new_name):
			lib.remove_animation(new_name)
		lib.add_animation(new_name, new_anim)

func update_locomotion_animation(input_dir: Vector2, is_sprint: bool, delta: float) -> void:
	if not anim_player:
		return
		
	# While shoot recoil animation is actively playing, don't override it
	if shoot_anim_timer > 0.0:
		return
		
	if is_ads_aim:
		if input_dir.length() > 0.1:
			anim_player.speed_scale = 1.0
			if input_dir.y < -0.3:
				if anim_player.current_animation != "standing aim walk forward":
					anim_player.play("standing aim walk forward", 0.15)
			elif input_dir.y > 0.3:
				if anim_player.current_animation != "standing aim walk back":
					anim_player.play("standing aim walk back", 0.15)
			elif input_dir.x < -0.3:
				if anim_player.current_animation != "standing aim walk left":
					anim_player.play("standing aim walk left", 0.15)
			elif input_dir.x > 0.3:
				if anim_player.current_animation != "standing aim walk right":
					anim_player.play("standing aim walk right", 0.15)
			else:
				if anim_player.current_animation != "standing aim walk forward":
					anim_player.play("standing aim walk forward", 0.15)
		else:
			anim_player.speed_scale = 1.0
			if anim_player.current_animation != "standing_aim_overdraw_upright":
				anim_player.play("standing_aim_overdraw_upright", 0.15)
	else:
		if input_dir.length() > 0.1:
			if is_sprint:
				var run_anim = "Slow Run" if anim_player.has_animation("Slow Run") else "standing run forward"
				if anim_player.current_animation != run_anim:
					anim_player.play(run_anim, 0.15)
				anim_player.speed_scale = 1.25
			else:
				anim_player.speed_scale = 1.05
				# Directional 4-way normal walking holding the arrow:
				# forward, back, left, right
				if abs(input_dir.y) >= abs(input_dir.x):
					if input_dir.y < -0.2:
						if anim_player.current_animation != "standing walk forward":
							anim_player.play("standing walk forward", 0.15)
					else:
						if anim_player.current_animation != "standing walk back":
							anim_player.play("standing walk back", 0.15)
				else:
					if input_dir.x < -0.2:
						if anim_player.current_animation != "standing walk left":
							anim_player.play("standing walk left", 0.15)
					else:
						if anim_player.current_animation != "standing walk right":
							anim_player.play("standing walk right", 0.15)
		else:
			anim_player.speed_scale = 1.0
			if anim_player.current_animation != "standing idle 01":
				anim_player.play("standing idle 01", 0.2)

func _setup_archery_system() -> void:
	skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		return
		
	# 1. Left Hand Bow Attachment (mixamorig_LeftHand, bone idx 18)
	bow_hand_attach = skeleton.find_child("LeftHandBow", true, false) as BoneAttachment3D
	if not bow_hand_attach:
		var old_attach = skeleton.find_child("BoneAttachment3D", true, false) as BoneAttachment3D
		if old_attach:
			bow_hand_attach = old_attach
			bow_hand_attach.name = "LeftHandBow"
		else:
			bow_hand_attach = BoneAttachment3D.new()
			bow_hand_attach.name = "LeftHandBow"
			skeleton.add_child(bow_hand_attach)
	bow_hand_attach.bone_name = "mixamorig_LeftHand"
	
	for c in bow_hand_attach.get_children():
		if c.name == "bow" or c.name == "Bow":
			c.queue_free()
			
	# Dynamic Wooden Bow Mesh
	var b_frame_mesh = load("res://models/bow_frame_mesh.res")
	bow_hand_node = bow_hand_attach.find_child("HandBow", true, false) as MeshInstance3D
	if not bow_hand_node:
		bow_hand_node = MeshInstance3D.new()
		bow_hand_node.name = "HandBow"
		bow_hand_node.mesh = b_frame_mesh
		bow_hand_node.transform = bow_transform_idle
		bow_hand_attach.add_child(bow_hand_node)
	else:
		bow_hand_node.mesh = b_frame_mesh
		bow_hand_node.transform = bow_transform_idle
		
	# Procedural Dynamic Bowstring
	bow_string_node = bow_hand_node.find_child("DynamicBowString", true, false) as MeshInstance3D
	if not bow_string_node:
		bow_string_node = MeshInstance3D.new()
		bow_string_node.name = "DynamicBowString"
		var s_mat = StandardMaterial3D.new()
		s_mat.albedo_color = Color(0.95, 0.93, 0.88, 1.0)
		s_mat.roughness = 0.35
		bow_string_node.material_override = s_mat
		bow_hand_node.add_child(bow_string_node)
		
	# Procedural Dynamic Nocked Arrow
	var a_mesh = load("res://models/arrow_mesh.res")
	bow_arrow_node = bow_hand_node.find_child("DynamicNockedArrow", true, false) as MeshInstance3D
	if not bow_arrow_node:
		bow_arrow_node = MeshInstance3D.new()
		bow_arrow_node.name = "DynamicNockedArrow"
		bow_arrow_node.mesh = a_mesh
		bow_arrow_node.visible = false
		bow_hand_node.add_child(bow_arrow_node)
	else:
		bow_arrow_node.mesh = a_mesh
		bow_arrow_node.visible = false
		
	# 2. Right Hand Finger Tracking (mixamorig_RightHandIndex1, bone idx 48)
	arrow_hand_attach = skeleton.find_child("RightHandArrow", true, false) as BoneAttachment3D
	if not arrow_hand_attach:
		arrow_hand_attach = BoneAttachment3D.new()
		arrow_hand_attach.name = "RightHandArrow"
		arrow_hand_attach.bone_name = "mixamorig_RightHandIndex1"
		skeleton.add_child(arrow_hand_attach)
	else:
		arrow_hand_attach.bone_name = "mixamorig_RightHandIndex1"

	# Hand Held Arrow mesh when walking / idling
	hand_held_arrow = arrow_hand_attach.find_child("HandHeldArrow", true, false) as MeshInstance3D
	if not hand_held_arrow:
		hand_held_arrow = MeshInstance3D.new()
		hand_held_arrow.name = "HandHeldArrow"
		hand_held_arrow.mesh = a_mesh
		hand_held_arrow.transform = arrow_transform_held
		hand_held_arrow.visible = is_bow_drawn and not is_ads_aim
		arrow_hand_attach.add_child(hand_held_arrow)
	else:
		hand_held_arrow.mesh = a_mesh
		hand_held_arrow.transform = arrow_transform_held
		hand_held_arrow.visible = is_bow_drawn and not is_ads_aim

func _setup_audio() -> void:
	snd_bow_draw = AudioStreamPlayer.new()
	snd_bow_draw.name = "SndBowDraw"
	snd_bow_draw.volume_db = -1.5
	var bd_path = "res://sounds/bow_draw.wav"
	if ResourceLoader.exists(bd_path):
		snd_bow_draw.stream = load(bd_path)
	add_child(snd_bow_draw)
	
	snd_arrow_swoosh = AudioStreamPlayer.new()
	snd_arrow_swoosh.name = "SndArrowSwoosh"
	snd_arrow_swoosh.volume_db = 0.5
	var sw_path = "res://sounds/arrow_swoosh.wav"
	if not ResourceLoader.exists(sw_path):
		sw_path = "res://Sound effects/freesoundeffects-wind-swoosh-short-289744.mp3"
	if ResourceLoader.exists(sw_path):
		snd_arrow_swoosh.stream = load(sw_path)
	add_child(snd_arrow_swoosh)

func _setup_hud() -> void:
	var hud_node = get_node_or_null("HUD") as CanvasLayer
	if not hud_node:
		return
		
	var old_ch = hud_node.get_node_or_null("Crosshair")
	if old_ch:
		old_ch.queue_free()
		
	var reticle_script = load("res://scripts/aim_reticle.gd")
	if reticle_script:
		aim_reticle = reticle_script.new()
		aim_reticle.name = "CustomAimReticle"
		hud_node.add_child(aim_reticle)
		aim_reticle.set_mode(aim_reticle.ReticleMode.HIP_FIRE if is_bow_drawn else aim_reticle.ReticleMode.HIDDEN)

func init_state_machine() -> void:
	if not limbo_state:
		limbo_state = get_node_or_null("LimboHSM")
	if limbo_state:
		limbo_state.initialize(self)
		limbo_state.set_active(true)
		if active:
			limbo_state.change_active_state(active)
		elif inactive:
			limbo_state.change_active_state(inactive)

func setup_transitions() -> void:
	if not limbo_state:
		return
	limbo_state.add_transition(inactive, active, "to_active")
	limbo_state.add_transition(active, inactive, "to_inactive")
	limbo_state.add_transition(active, aim, "to_aim")
	limbo_state.add_transition(aim, active, "to_active")
	limbo_state.add_transition(inactive, fall, "to_fall")
	limbo_state.add_transition(active, fall, "to_fall")
	limbo_state.add_transition(aim, fall, "to_fall")
	limbo_state.add_transition(fall, inactive, "to_inactive")
	limbo_state.add_transition(fall, active, "to_active")

func change_state(from_state: LimboState, event: String) -> void:
	if limbo_state:
		limbo_state.dispatch(event)

func get_previous_state() -> String:
	if limbo_state and limbo_state.get_previous_active_state():
		return limbo_state.get_previous_active_state().name
	return "Inactive"

func rotation_based_on_camera(input_dir: Vector2, delta: float) -> void:
	var cam = get_active_camera()
	if not cam or not get_viewport():
		return
	var cam_fwd = -cam.global_transform.basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()
	var cam_right = cam.global_transform.basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	
	var move_dir = (cam_right * input_dir.x + cam_fwd * -input_dir.y).normalized()
	if move_dir.length() > 0.001:
		var target_rot = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, ROTATION_SPEED * delta)

func face_camera_direction(delta: float) -> void:
	var cam = get_active_camera()
	if not cam:
		return
	var cam_fwd = -cam.global_transform.basis.z
	cam_fwd.y = 0.0
	if cam_fwd.length() > 0.001:
		cam_fwd = cam_fwd.normalized()
		var target_rot = atan2(-cam_fwd.x, -cam_fwd.z)
		rotation.y = lerp_angle(rotation.y, target_rot, ROTATION_SPEED * 1.5 * delta)

func set_walk_velocity(input_dir: Vector2, is_sprint: bool, delta: float) -> void:
	var cam = get_active_camera()
	if not cam:
		return
	var cam_fwd = -cam.global_transform.basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()
	var cam_right = cam.global_transform.basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	
	var move_dir = (cam_right * input_dir.x + cam_fwd * -input_dir.y).normalized()
	var spd = SPRINT_SPEED if is_sprint else WALK_SPEED
	velocity.x = move_dir.x * spd
	velocity.z = move_dir.z * spd
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = -0.5
	apply_floor_snap()
	move_and_slide()

func set_strafe_velocity(input_dir: Vector2, delta: float) -> void:
	var cam = get_active_camera()
	if not cam:
		return
	var cam_fwd = -cam.global_transform.basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()
	var cam_right = cam.global_transform.basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	
	var move_dir = (cam_right * input_dir.x + cam_fwd * -input_dir.y).normalized()
	velocity.x = move_dir.x * STRAFE_SPEED
	velocity.z = move_dir.z * STRAFE_SPEED
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = -0.5
	apply_floor_snap()
	move_and_slide()

func set_velocity_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = -0.5
	apply_floor_snap()
	move_and_slide()

func set_bow_visible(p_visible: bool) -> void:
	is_bow_drawn = p_visible
	if bow_hand_node:
		bow_hand_node.visible = p_visible
	if bow_string_node:
		bow_string_node.visible = p_visible
	if hand_held_arrow:
		hand_held_arrow.visible = p_visible and not is_ads_aim
	if not p_visible and bow_arrow_node:
		bow_arrow_node.visible = false
	if aim_reticle and is_active_player:
		if is_ads_aim:
			aim_reticle.set_mode(aim_reticle.ReticleMode.ADS_AIM)
		elif is_bow_drawn:
			aim_reticle.set_mode(aim_reticle.ReticleMode.HIP_FIRE)
		else:
			aim_reticle.set_mode(aim_reticle.ReticleMode.HIDDEN)

func _update_bow_visuals(delta: float) -> void:
	# Hand-held arrow visibility:
	# Visible during idle, walk, run when bow is drawn
	# Hidden during ADS aiming (when nocked on bow) and during instant shoot release
	if hand_held_arrow and is_instance_valid(hand_held_arrow):
		hand_held_arrow.visible = is_bow_drawn and not is_ads_aim and (shoot_anim_timer <= 0.0)

	if not bow_hand_node or not bow_hand_node.visible:
		if bow_string_node: bow_string_node.visible = false
		if bow_arrow_node: bow_arrow_node.visible = false
		return
		
	var is_shooting = (shoot_anim_timer > 0.0)
	var in_aim_pose = is_ads_aim or is_shooting
	var target_bow_tx = bow_transform_aim if in_aim_pose else bow_transform_idle
	if in_aim_pose:
		bow_hand_node.transform = bow_transform_aim
	else:
		bow_hand_node.transform = bow_hand_node.transform.interpolate_with(target_bow_tx, clampf(16.0 * delta, 0.0, 1.0))
		
	if bow_string_node: bow_string_node.visible = true
	var target_pull: Vector3 = bow_string_rest
	
	if is_ads_aim and not is_shooting:
		var shelf_world = bow_hand_node.global_transform * bow_shelf_offset
		var cam = get_active_camera()
		var cam_fwd: Vector3
		var aim_target: Vector3
		if cam:
			cam_fwd = -cam.global_transform.basis.z
			aim_target = cam.global_position + cam_fwd * 60.0
		else:
			aim_target = shelf_world + Vector3.FORWARD * 60.0
			
		var r_hand_pos: Vector3
		if arrow_hand_attach and is_instance_valid(arrow_hand_attach):
			r_hand_pos = arrow_hand_attach.global_position
		else:
			r_hand_pos = shelf_world - (aim_target - shelf_world).normalized() * 0.48
			
		var arrow_dir = (aim_target - shelf_world).normalized()
		var pull_local = bow_hand_node.global_transform.affine_inverse() * r_hand_pos
		bow_string_pull_current = pull_local
		
		if bow_arrow_node:
			bow_arrow_node.visible = true
			var arrow_scale = 0.75
			var arrow_center = shelf_world + arrow_dir * 0.20
			var arrow_center_local = bow_hand_node.global_transform.affine_inverse() * arrow_center
			var arrow_dir_local = bow_hand_node.global_transform.basis.inverse() * arrow_dir
			
			var up_hint = Vector3.UP if abs(arrow_dir_local.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
			var y_col = arrow_dir_local.normalized()
			var x_col = y_col.cross(up_hint).normalized()
			var z_col = x_col.cross(y_col).normalized()
			
			var arrow_basis = Basis()
			arrow_basis.x = x_col * arrow_scale
			arrow_basis.y = y_col * arrow_scale
			arrow_basis.z = z_col * arrow_scale
			
			bow_arrow_node.transform = Transform3D(arrow_basis, arrow_center_local)
	else:
		if bow_arrow_node: bow_arrow_node.visible = false
		if string_twang_timer > 0.0:
			string_twang_timer -= delta
			var twang = sin(string_twang_timer * 65.0) * (string_twang_timer * 0.04)
			target_pull = bow_string_rest + Vector3(0, 0, twang)
			bow_string_pull_current = target_pull
		else:
			bow_string_pull_current = bow_string_rest
			
	if bow_string_node:
		bow_string_node.mesh = _build_bowstring_mesh(bow_tip_top, bow_string_pull_current, bow_tip_bot, 0.003)

func _build_bowstring_mesh(p0: Vector3, p1: Vector3, p2: Vector3, radius: float = 0.003) -> ArrayMesh:
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	_add_tube_segment(verts, normals, uvs, indices, p0, p1, radius)
	_add_tube_segment(verts, normals, uvs, indices, p1, p2, radius)
	
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = indices
	
	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return arr_mesh

func _add_tube_segment(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, start_pt: Vector3, end_pt: Vector3, radius: float) -> void:
	var dir = (end_pt - start_pt).normalized()
	if dir.length_squared() < 0.0001:
		return
	var up_hint = Vector3.UP if abs(dir.y) < 0.9 else Vector3.RIGHT
	var radial_x = dir.cross(up_hint).normalized()
	var radial_y = radial_x.cross(dir).normalized()
	
	var base_idx = verts.size()
	var sides = 4
	for i in range(sides):
		var angle = (float(i) / float(sides)) * TAU
		var offset = (radial_x * cos(angle) + radial_y * sin(angle)) * radius
		var n = offset.normalized()
		verts.append(start_pt + offset)
		normals.append(n)
		uvs.append(Vector2(float(i) / float(sides), 0.0))
		verts.append(end_pt + offset)
		normals.append(n)
		uvs.append(Vector2(float(i) / float(sides), 1.0))
		
	for i in range(sides):
		var v0 = base_idx + i * 2
		var v1 = base_idx + i * 2 + 1
		var next_i = (i + 1) % sides
		var v2 = base_idx + next_i * 2
		var v3 = base_idx + next_i * 2 + 1
		indices.append(v0)
		indices.append(v1)
		indices.append(v2)
		indices.append(v2)
		indices.append(v1)
		indices.append(v3)

func shoot_arrow_instant() -> void:
	if not is_bow_drawn:
		set_bow_visible(true)
	if snd_bow_draw and snd_bow_draw.playing:
		snd_bow_draw.stop()
		
	face_camera_direction(1.0)
	shoot_anim_timer = 0.35
	string_twang_timer = 0.18
	
	# Play upright shooting recoil animation (matching Archer character)
	if anim_player:
		if anim_player.has_animation("standing_aim_recoil_upright"):
			anim_player.play("standing_aim_recoil_upright", 0.08)
		elif anim_player.has_animation("standing aim recoil"):
			anim_player.play("standing aim recoil", 0.08)
			
	_spawn_and_fire_projectile()
	
	if snd_arrow_swoosh and snd_arrow_swoosh.stream:
		snd_arrow_swoosh.pitch_scale = randf_range(0.97, 1.05)
		snd_arrow_swoosh.play()
		
	if aim_reticle:
		aim_reticle.set_mode(aim_reticle.ReticleMode.HIP_FIRE)

func shoot_arrow() -> void:
	if snd_bow_draw and snd_bow_draw.playing:
		snd_bow_draw.stop()
		
	shoot_anim_timer = 0.35
	string_twang_timer = 0.22
	
	if bow_arrow_node:
		bow_arrow_node.visible = false
		
	# Play upright shooting recoil animation
	if anim_player:
		if anim_player.has_animation("standing_aim_recoil_upright"):
			anim_player.play("standing_aim_recoil_upright", 0.08)
		elif anim_player.has_animation("standing aim recoil"):
			anim_player.play("standing aim recoil", 0.08)
			
	_spawn_and_fire_projectile()
	
	if snd_arrow_swoosh and snd_arrow_swoosh.stream:
		snd_arrow_swoosh.pitch_scale = randf_range(0.97, 1.04)
		snd_arrow_swoosh.play()

func _spawn_and_fire_projectile() -> void:
	if not arrow_scene:
		arrow_scene = load("res://scenes/arrow_projectile.tscn")
	if not arrow_scene:
		return
		
	var cam = get_active_camera()
	if not cam:
		return
		
	var arrow = arrow_scene.instantiate()
	arrow.shooter = self
	get_parent().add_child(arrow)
	
	var spawn_pos: Vector3
	if bow_hand_node:
		spawn_pos = bow_hand_node.global_transform * bow_shelf_offset
	elif bow_hand_attach:
		spawn_pos = bow_hand_attach.global_position + Vector3(0, 0.08, 0)
	else:
		spawn_pos = global_position + Vector3(0, 1.35, 0)
		
	arrow.global_position = spawn_pos
	
	var vp_rect := get_viewport().get_visible_rect()
	var center := vp_rect.size * 0.5
	var ray_start: Vector3 = cam.project_ray_origin(center)
	var ray_dir: Vector3 = cam.project_ray_normal(center)
	var ray_end: Vector3 = ray_start + ray_dir * 180.0
	
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	var excludes: Array[RID] = [get_rid(), arrow.get_rid()]
	for p in get_tree().get_nodes_in_group("player_characters"):
		if p is CollisionObject3D:
			excludes.append(p.get_rid())
	query.exclude = excludes
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	
	var target_point: Vector3
	var aim_dist: float
	if hit:
		target_point = hit.position
		aim_dist = clampf(spawn_pos.distance_to(target_point), 2.0, 80.0)
	else:
		target_point = ray_start + ray_dir * 50.0
		aim_dist = 50.0
		
	var arrow_spd: float = 55.0
	var flight_time: float = aim_dist / arrow_spd
	var drop_comp: float = clampf(0.5 * 2.4 * (flight_time * flight_time), 0.0, 1.4)
	var compensated_target: Vector3 = target_point + Vector3(0.0, drop_comp, 0.0)
	var shoot_dir: Vector3 = (compensated_target - spawn_pos).normalized()
	
	arrow.launch(shoot_dir, arrow_spd)

func get_active_camera() -> Camera3D:
	if camera_manager:
		var cam = camera_manager.get_node_or_null("SpringArm3D/Camera3D") as Camera3D
		if cam:
			return cam
	return null

func _physics_process(delta: float) -> void:
	if shoot_anim_timer > 0.0:
		shoot_anim_timer -= delta
	_update_bow_visuals(delta)
	
	if is_on_floor():
		last_safe_ground_pos = global_position
	elif global_position.y < -15.0:
		velocity = Vector3.ZERO
		global_position = last_safe_ground_pos + Vector3.UP * 0.5
		if limbo_state and inactive:
			limbo_state.change_active_state(inactive)
	if is_active_player:
		RenderingServer.global_shader_parameter_set("player_pos", global_position)

func _setup_input_actions() -> void:
	_add_action_key_if_missing("move_forward", KEY_W)
	_add_action_key_if_missing("move_backward", KEY_S)
	_add_action_key_if_missing("move_left", KEY_A)
	_add_action_key_if_missing("move_right", KEY_D)
	_add_action_key_if_missing("sprint", KEY_SHIFT)
	_add_action_key_if_missing("equip", KEY_E)
	_add_action_mouse_if_missing("aim", MOUSE_BUTTON_RIGHT)
	_add_action_mouse_if_missing("shoot", MOUSE_BUTTON_LEFT)

func _add_action_key_if_missing(act_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(act_name):
		InputMap.add_action(act_name)
		var ev = InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(act_name, ev)

func _add_action_mouse_if_missing(act_name: StringName, btn_idx: MouseButton) -> void:
	if not InputMap.has_action(act_name):
		InputMap.add_action(act_name)
		var ev = InputEventMouseButton.new()
		ev.button_index = btn_idx
		InputMap.action_add_event(act_name, ev)

func set_active_player(active_flag: bool) -> void:
	is_active_player = active_flag
	if camera_manager:
		var cam = camera_manager.get_node_or_null("SpringArm3D/Camera3D") as Camera3D
		if cam:
			if active_flag:
				cam.make_current()
			else:
				cam.current = false
	var hud_node = get_node_or_null("HUD") as CanvasLayer
	if hud_node:
		hud_node.visible = active_flag
	if not active_flag:
		velocity = Vector3.ZERO
		is_ads_aim = false
		if limbo_state and inactive:
			limbo_state.change_active_state(inactive)
		if aim_reticle:
			aim_reticle.set_mode(aim_reticle.ReticleMode.HIDDEN)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if limbo_state and active:
			limbo_state.change_active_state(active)
		if aim_reticle:
			aim_reticle.set_mode(aim_reticle.ReticleMode.HIP_FIRE if is_bow_drawn else aim_reticle.ReticleMode.HIDDEN)

func switch_to_partner() -> void:
	var chars = get_tree().get_nodes_in_group("player_characters")
	if chars.size() <= 1:
		return
	var my_idx = chars.find(self)
	var next_idx = (my_idx + 1) % chars.size() if my_idx != -1 else 0
	var next_char = chars[next_idx]
	set_active_player(false)
	if next_char.has_method("set_active_player"):
		next_char.set_active_player(true)

func summon_companion() -> void:
	var chars = get_tree().get_nodes_in_group("player_characters")
	var idx = 1
	for c in chars:
		if c != self and is_instance_valid(c):
			var spawn_offset = global_transform.basis.x * (1.8 * idx)
			c.global_position = global_position + spawn_offset
			if "velocity" in c:
				c.velocity = Vector3.ZERO
			print("[PARTY] Summoned partner ", c.name, " to ", c.global_position)
			idx += 1

func _unhandled_input(event: InputEvent) -> void:
	if not is_active_player:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			switch_to_partner()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z:
			summon_companion()
			get_viewport().set_input_as_handled()

func _setup_hud_switch() -> void:
	var hud_node = get_node_or_null("HUD") as CanvasLayer
	if not hud_node:
		return
	var btn = Button.new()
	btn.name = "SwitchCharacterBtn"
	btn.text = "⚔️ Switch Character (Tab)"
	btn.anchors_preset = Control.PRESET_TOP_RIGHT
	btn.anchor_left = 0.72
	btn.anchor_top = 0.025
	btn.anchor_right = 0.98
	btn.anchor_bottom = 0.085
	btn.focus_mode = Control.FOCUS_NONE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.24, 0.92)
	style.border_color = Color(0.35, 0.75, 1.0, 0.95)
	style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8; style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	btn.pressed.connect(switch_to_partner)
	hud_node.add_child(btn)
