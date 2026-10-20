extends CharacterBody3D

var is_samurai: bool = false
var last_safe_ground_pos: Vector3 = Vector3.ZERO

const AimPitchModifierScript = preload("res://scripts/aim_pitch_modifier.gd")

# State Machine
enum State { 
	NORMAL, 
	BOW_AIM, 
	BOW_SHOOT, 
	BLOCKING,
	MELEE, 
	ROLLING, 
	JUMP_AIR, 
	LANDING,
	SWIMMING 
}

@export var character_name: String = "Archer"
@export var is_active_player: bool = true

# Locomotion Speeds
@export var walk_speed: float = 2.4
@export var jog_speed: float = 4.6
@export var sprint_speed: float = 7.4
@export var jump_velocity: float = 7.0
@export var roll_speed: float = 7.0
@export var rotation_speed: float = 14.0
@export var mouse_sensitivity: float = 0.0028

# Camera Zoom & OTS Parameters
@export var default_zoom: float = 2.8
@export var min_zoom: float = 1.6
@export var max_zoom: float = 6.0
var user_preferred_zoom: float = 2.8
@export var aim_zoom: float = 1.25
@export var default_fov: float = 70.0
@export var aim_fov: float = 48.0
var target_zoom: float = 2.8
var target_fov: float = 70.0
var normal_pivot_offset: Vector3 = Vector3(0.50, 1.42, 0.0)
var aim_pivot_offset: Vector3 = Vector3(0.46, 1.44, 0.05)
var target_pivot_offset: Vector3 = Vector3(0.50, 1.42, 0.0)

var gravity: float = 18.0
var current_state: State = State.NORMAL

# Node References
@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var char_model: Node3D = get_node_or_null("Visuals/CharacterModel")
@onready var camera_pivot: Node3D = get_node_or_null("CameraPivot")
@onready var spring_arm: SpringArm3D = get_node_or_null("CameraPivot/SpringArm3D")
@onready var camera: Camera3D = get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
@onready var col_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var hud: CanvasLayer = get_node_or_null("HUD")

# Skeleton & Animation
var skeleton: Skeleton3D = null
var anim_player: AnimationPlayer = null
var bone_spine_idx: int = -1
var bone_chest_idx: int = -1
var current_spine_pitch: float = 0.0
var rest_spine_q: Quaternion = Quaternion.IDENTITY
var rest_chest_q: Quaternion = Quaternion.IDENTITY
var bone_upper_chest_idx: int = -1
var rest_upper_chest_q: Quaternion = Quaternion.IDENTITY

# Bone Attachments & Weapon Nodes (Bow & Arrow ONLY)
var bow_hand_attach: BoneAttachment3D = null
var bow_hand_node: MeshInstance3D = null
var bow_back_attach: BoneAttachment3D = null
var bow_back_node: MeshInstance3D = null
var arrow_hand_attach: BoneAttachment3D = null
var bow_string_node: MeshInstance3D = null
var bow_arrow_node: MeshInstance3D = null
var arrow_scene_preload: PackedScene = null

# Calibrated Bow Transforms for Hand Attachment:
# 1. Idle / Catwalk Walk: Bow hangs naturally along the left thigh/hip with string placed inward towards body
var bow_transform_idle: Transform3D = Transform3D(
	Basis.from_euler(Vector3(deg_to_rad(-45.0), deg_to_rad(-130.0), deg_to_rad(-35.0))),
	Vector3(0.010, 0.055, 0.005)
)
# 2. ADS Aim / Shooting: Bow held upright and forward with belly facing target and string placed inward towards archer
var bow_transform_aim: Transform3D = Transform3D(
	Basis.from_euler(Vector3(deg_to_rad(-69.3), deg_to_rad(-50.9), deg_to_rad(-58.2))),
	Vector3(0.008, 0.055, -0.005)
)

# Dynamic Bow Parameters
var bow_shelf_offset: Vector3 = Vector3(0.025, 0.02, 0.0)
var bow_tip_top: Vector3 = Vector3(0.0, 0.85, -0.269)
var bow_tip_bot: Vector3 = Vector3(0.0, -0.83, -0.269)
var bow_string_rest: Vector3 = Vector3(0.0, 0.0, -0.269)
var bow_string_pull_current: Vector3 = Vector3(0.0, 0.0, -0.269)
var string_twang_timer: float = 0.0

var is_bow_drawn: bool = true
var is_ads_aim: bool = false
var aim_charge_time: float = 0.0
var state_timer: float = 0.0
var left_click_press_time: float = 0.0
var left_click_held: bool = false
var aim_activated_by_left_hold: bool = false
var rapid_shoot_reticle_timer: float = 0.0
var was_in_air: bool = false
var turn_180_timer: float = 0.0

# Audio Players
var snd_step: AudioStreamPlayer = null
var snd_step_pool: Array[AudioStreamPlayer] = []
var snd_step_idx: int = 0
var snd_jump: AudioStreamPlayer = null
var snd_land: AudioStreamPlayer = null
var snd_bow_draw: AudioStreamPlayer = null
var snd_arrow_swoosh: AudioStreamPlayer = null
var snd_switch: AudioStreamPlayer = null
var snd_grass_breeze: AudioStreamPlayer = null
var streams_grass_steps: Array[AudioStream] = []
var step_timer: float = 0.0

# UI References
var switch_btn: Button = null
var summon_btn: Button = null
var info_panel: PanelContainer = null
var state_label: Label = null
var aim_reticle: Control = null

func _set_head_meshes_visible(vis: bool) -> void:
	if not char_model:
		return
	for child in char_model.find_children("*", "MeshInstance3D", true, false):
		var clow = child.name.to_lower()
		if "hair" in clow or "face" in clow or "head" in clow or "cap" in clow:
			child.visible = vis

func _enter_tree() -> void:
	add_to_group("player_characters")

func _ready() -> void:
	_setup_input_actions()
	last_safe_ground_pos = global_position
	_ensure_environment_collisions()
	rotation = Vector3.ZERO
	floor_snap_length = 0.45
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(55.0)
	floor_stop_on_slope = true
	
	var def_grav = ProjectSettings.get_setting("physics/3d/default_gravity")
	if def_grav != null and float(def_grav) > 0.0:
		gravity = float(def_grav)
		
	arrow_scene_preload = load("res://scenes/arrow_projectile.tscn")
	
	if camera_pivot:
		camera_pivot.position = normal_pivot_offset
	if spring_arm:
		spring_arm.add_excluded_object(get_rid())
		spring_arm.collision_mask = 1
		spring_arm.spring_length = default_zoom
	if camera:
		camera.fov = default_fov
		camera.near = 0.05
	
	_setup_nodes()
	_setup_materials()
	_setup_weapons()
	_setup_audio()
	_setup_hud()
	
	set_active_player(is_active_player)

func _setup_nodes() -> void:
	if not char_model and visuals and visuals.get_child_count() > 0:
		char_model = visuals.get_child(0)
		
	if char_model:
		skeleton = char_model.find_child("Skeleton3D", true, false) as Skeleton3D
		anim_player = char_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		
	if skeleton:
		bone_spine_idx = skeleton.find_bone("J_Bip_C_Spine")
		bone_chest_idx = skeleton.find_bone("J_Bip_C_Chest")
		bone_upper_chest_idx = skeleton.find_bone("J_Bip_C_UpperChest")
		if bone_spine_idx >= 0:
			rest_spine_q = skeleton.get_bone_rest(bone_spine_idx).basis.get_rotation_quaternion()
		if bone_chest_idx >= 0:
			rest_chest_q = skeleton.get_bone_rest(bone_chest_idx).basis.get_rotation_quaternion()
		if bone_upper_chest_idx >= 0:
			rest_upper_chest_q = skeleton.get_bone_rest(bone_upper_chest_idx).basis.get_rotation_quaternion()
			
		var existing_mod = skeleton.find_child("AimPitchModifier", true, false)
		if not existing_mod:
			var pitch_mod = AimPitchModifierScript.new()
			pitch_mod.name = "AimPitchModifier"
			pitch_mod.archer = self
			skeleton.add_child(pitch_mod)
		
	if anim_player:
		# 1. Seamless looping for locomotion and idle
		for anim_name in anim_player.get_animation_list():
			var anim = anim_player.get_animation(anim_name)
			var a_low = anim_name.to_lower()
			if "walk" in a_low or "run" in a_low or "idle" in a_low or "overdraw" in a_low:
				anim.loop_mode = Animation.LOOP_LINEAR
			elif is_samurai:
				if anim_name == "X bow/Armature|mixamo_com_007":
					anim.loop_mode = Animation.LOOP_LINEAR
				elif anim_name == "X bow/Armature|mixamo_com_002":
					anim.loop_mode = Animation.LOOP_LINEAR
				elif anim_name in ["X bow/Armature|mixamo_com_003", "X bow/Armature|mixamo_com_004", "X bow/Armature|mixamo_com_005", "X bow/Armature|mixamo_com_006"]:
					anim.loop_mode = Animation.LOOP_LINEAR
				
			# Zero Root translation keys to prevent model drifting while preserving Hips standing height
			for t in range(anim.get_track_count()):
				var pth = str(anim.track_get_path(t))
				var t_type = anim.track_get_type(t)
				if ("Skeleton3D:Root" in pth or pth.ends_with("/Root")) and t_type == Animation.TYPE_POSITION_3D:
					for k in range(anim.track_get_key_count(t)):
						anim.track_set_key_value(t, k, Vector3.ZERO)
		
		# 2. Build Upright Shooting & Upright Aim Animations
		# Upper body aims/shoots while legs stay in natural upright standing pose!
		_create_upright_animation("Armature_048|VRoid_standing_aim_recoil", "standing_aim_recoil_upright")
		_create_upright_animation("Armature_048|VRoid_standing_aim_overdraw", "standing_aim_overdraw_upright")
					
		if is_samurai:
			if anim_player.has_animation("X bow/Armature|mixamo_com_007"):
				anim_player.play("X bow/Armature|mixamo_com_007")
		else:
			if anim_player.has_animation("Armature_048|VRoid_standing_idle_01"):
				anim_player.play("Armature_048|VRoid_standing_idle_01")

func _create_upright_animation(source_name: String, new_name: String) -> void:
	if not anim_player or not anim_player.has_animation(source_name):
		return
	var orig_anim = anim_player.get_animation(source_name)
	var idle_anim: Animation = null
	if anim_player.has_animation("Armature_048|VRoid_standing_idle_01"):
		idle_anim = anim_player.get_animation("Armature_048|VRoid_standing_idle_01")
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
	var lib = anim_player.get_animation_library("")
	if lib:
		if lib.has_animation(new_name):
			lib.remove_animation(new_name)
		lib.add_animation(new_name, new_anim)

func _setup_materials() -> void:
	if not skeleton:
		return
	var toon_shader = load("res://shaders/cel_toon_character.gdshader")
	for c in skeleton.get_children():
		if c is MeshInstance3D and c.mesh:
			for s in range(c.mesh.get_surface_count()):
				var mat = c.mesh.surface_get_material(s)
				if mat is StandardMaterial3D and mat.albedo_texture:
					var smat = ShaderMaterial.new()
					smat.shader = toon_shader
					smat.set_shader_parameter("albedo_texture", mat.albedo_texture)
					smat.set_shader_parameter("shadow_color", Color(0.55, 0.52, 0.65, 1.0))
					smat.set_shader_parameter("brightness_multiplier", 0.70)
					var is_alpha = (c.name == "Hair" or c.name == "Face" or s in [0, 1, 2, 5, 6, 7, 8])
					smat.set_shader_parameter("use_alpha_scissor", is_alpha)
					smat.set_shader_parameter("alpha_scissor_threshold", 0.35)
					c.set_surface_override_material(s, smat)

func _setup_weapons() -> void:
	if not skeleton:
		return
		
	var b_frame_mesh = load("res://models/bow_frame_mesh.res")
	var a_mesh = load("res://models/arrow_mesh.res")
	
	# 1. Left Hand Bow Attachment (VRoid bone: J_Bip_L_Hand)
	bow_hand_attach = skeleton.find_child("LeftHandBow", true, false) as BoneAttachment3D
	if not bow_hand_attach:
		bow_hand_attach = BoneAttachment3D.new()
		bow_hand_attach.name = "LeftHandBow"
		bow_hand_attach.bone_name = "J_Bip_L_Hand"
		skeleton.add_child(bow_hand_attach)
		
	bow_hand_node = MeshInstance3D.new()
	bow_hand_node.name = "HandBow"
	bow_hand_node.mesh = b_frame_mesh
	bow_hand_node.scale = Vector3(0.85, 0.85, 0.85)
	# Default to idle vertical hold at left side
	bow_hand_node.transform = bow_transform_idle
	bow_hand_attach.add_child(bow_hand_node)
	
	# Dynamic Bowstring
	bow_string_node = MeshInstance3D.new()
	bow_string_node.name = "DynamicBowString"
	var s_mat = StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.95, 0.93, 0.88, 1.0)
	s_mat.roughness = 0.35
	bow_string_node.material_override = s_mat
	bow_hand_node.add_child(bow_string_node)
	
	# Dynamic Nocked Arrow
	bow_arrow_node = MeshInstance3D.new()
	bow_arrow_node.name = "DynamicNockedArrow"
	bow_arrow_node.mesh = a_mesh
	bow_arrow_node.visible = false
	bow_hand_node.add_child(bow_arrow_node)
	
	# 2. Right Hand String/Nock Tracking (VRoid bone: J_Bip_R_Hand)
	arrow_hand_attach = skeleton.find_child("RightHandArrow", true, false) as BoneAttachment3D
	var target_bone_name = "J_Bip_R_Index2" if skeleton.find_bone("J_Bip_R_Index2") >= 0 else "J_Bip_R_Hand"
	if not arrow_hand_attach:
		arrow_hand_attach = BoneAttachment3D.new()
		arrow_hand_attach.name = "RightHandArrow"
		arrow_hand_attach.bone_name = target_bone_name
		skeleton.add_child(arrow_hand_attach)
	else:
		arrow_hand_attach.bone_name = target_bone_name
		
	# 3. Slung Bow on Chest/Back (VRoid bone: J_Bip_C_Chest)
	bow_back_attach = skeleton.find_child("BackBowAttachment", true, false) as BoneAttachment3D
	if not bow_back_attach:
		bow_back_attach = BoneAttachment3D.new()
		bow_back_attach.name = "BackBowAttachment"
		bow_back_attach.bone_name = "J_Bip_C_Chest"
		skeleton.add_child(bow_back_attach)
		
	bow_back_node = MeshInstance3D.new()
	bow_back_node.name = "BackBow"
	bow_back_node.mesh = b_frame_mesh
	bow_back_node.scale = Vector3(0.85, 0.85, 0.85)
	bow_back_node.position = Vector3(0.06, 0.05, -0.04)
	bow_back_node.rotation_degrees = Vector3(32.0, -21.0, -37.5)
	bow_back_attach.add_child(bow_back_node)
	
	update_weapon_display()

func update_weapon_display() -> void:
	if is_bow_drawn:
		if bow_hand_node: bow_hand_node.visible = true
		if bow_back_node: bow_back_node.visible = false
		if bow_string_node: bow_string_node.visible = true
		if bow_arrow_node: bow_arrow_node.visible = (current_state == State.BOW_AIM)
	else:
		if bow_hand_node: bow_hand_node.visible = false
		if bow_back_node: bow_back_node.visible = true
		if bow_string_node: bow_string_node.visible = false
		if bow_arrow_node: bow_arrow_node.visible = false

func _setup_audio() -> void:
	snd_step_pool.clear()
	for i in range(3):
		var sp = AudioStreamPlayer.new()
		sp.name = "SndStep_%d" % i
		sp.volume_db = -8.0
		add_child(sp)
		snd_step_pool.append(sp)
	snd_step = snd_step_pool[0]
	
	snd_jump = AudioStreamPlayer.new()
	snd_jump.volume_db = -4.0
	var j_path = "res://sounds/jump.wav"
	if not ResourceLoader.exists(j_path): j_path = "res://Sound effects/freesound_community-jump-landing-30946.mp3"
	snd_jump.stream = load(j_path)
	add_child(snd_jump)
	
	snd_land = AudioStreamPlayer.new()
	snd_land.volume_db = -3.0
	var l_path = "res://sounds/land.wav"
	if not ResourceLoader.exists(l_path): l_path = "res://Sound effects/freesound_community-landing-on-grass-40650.mp3"
	snd_land.stream = load(l_path)
	add_child(snd_land)
	
	# Bow Draw Sound (Played strictly when initiating ADS aim)
	snd_bow_draw = AudioStreamPlayer.new()
	snd_bow_draw.volume_db = -1.5
	var bd_path = "res://sounds/bow_draw.wav"
	if not ResourceLoader.exists(bd_path): bd_path = "res://sounds/bow_draw.wav"
	snd_bow_draw.stream = load(bd_path)
	add_child(snd_bow_draw)
	
	# Arrow Swoosh Sound (Wind swoosh short - used for all arrow releases and rapid continuous shots)
	snd_arrow_swoosh = AudioStreamPlayer.new()
	snd_arrow_swoosh.volume_db = 0.5
	var sw_path = "res://sounds/arrow_swoosh.wav"
	if not ResourceLoader.exists(sw_path): sw_path = "res://Sound effects/freesoundeffects-wind-swoosh-short-289744.mp3"
	snd_arrow_swoosh.stream = load(sw_path)
	add_child(snd_arrow_swoosh)
	
	snd_switch = AudioStreamPlayer.new()
	snd_switch.volume_db = -2.0
	var sw_step = "res://sounds/step_grass_1.wav"
	if ResourceLoader.exists(sw_step): snd_switch.stream = load(sw_step)
	add_child(snd_switch)
	
	# Atmospheric Field Grass Breeze (Loops continuously; swells whenever standing on grass)
	snd_grass_breeze = AudioStreamPlayer.new()
	snd_grass_breeze.name = "GrassBreezePlayer"
	snd_grass_breeze.volume_db = -12.0
	var gb_path = "res://Sound effects/soul_serenity_sounds-field_softgrassandgentlebreeze-337196.mp3"
	if not ResourceLoader.exists(gb_path): gb_path = "res://sounds/ambient_breeze.wav"
	var gb_stream = load(gb_path)
	if gb_stream is AudioStreamMP3:
		(gb_stream as AudioStreamMP3).loop = true
	snd_grass_breeze.stream = gb_stream
	add_child(snd_grass_breeze)
	if is_active_player:
		snd_grass_breeze.play()
	
	streams_grass_steps.clear()
	var step_files = [
		"res://sounds/step_grass_1.wav",
		"res://sounds/step_grass_2.wav",
		"res://sounds/step_grass_3.wav",
		"res://sounds/step_stone_1.wav",
		"res://sounds/step_stone_2.wav"
	]
	for sf in step_files:
		if ResourceLoader.exists(sf):
			var res = load(sf)
			if res: streams_grass_steps.append(res)

func _setup_hud() -> void:
	if not hud:
		return
		
	# 1. Info Panel
	info_panel = PanelContainer.new()
	info_panel.name = "InfoPanel"
	info_panel.anchors_preset = Control.PRESET_TOP_LEFT
	info_panel.anchor_left = 0.02
	info_panel.anchor_top = 0.02
	info_panel.anchor_right = 0.58
	info_panel.anchor_bottom = 0.26
	hud.add_child(info_panel)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	info_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "🏹 ARCHER (Bow Specialist)"
	title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.65, 1.0))
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	state_label = Label.new()
	state_label.text = "State: NORMAL | Speed: 0.0 m/s | Weapon: LONGBOW [READY]"
	vbox.add_child(state_label)
	
	var hint = Label.new()
	hint.text = "BOW CONTROLS:
• Left-Click Tap: Instant Shoot (Arrow Swoosh)
• Left-Click Hold: Focus ADS Aim (Circle Sight Ring) -> Release to Shoot
• Right-Click: Toggle Focus ADS Aim -> Left-Click Shoots
• Mouse Wheel: Smooth Zoom In / Zoom Out
• G: Stow/Draw Bow | Q: Block | F: Instant Shoot | WASD: Catwalk Locomotion
• TAB / Button: Switch to Samurai | Z: Summon Companion"
	vbox.add_child(hint)
	
	# 2. On-Screen Character Switch Button
	switch_btn = Button.new()
	switch_btn.name = "SwitchCharacterBtn"
	switch_btn.text = "⚔️ Switch Character (Tab)"
	switch_btn.anchors_preset = Control.PRESET_TOP_RIGHT
	switch_btn.anchor_left = 0.72
	switch_btn.anchor_top = 0.025
	switch_btn.anchor_right = 0.98
	switch_btn.anchor_bottom = 0.085
	switch_btn.focus_mode = Control.FOCUS_NONE
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.16, 0.24, 0.92)
	btn_style.border_color = Color(0.35, 0.75, 1.0, 0.95)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	switch_btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.18, 0.26, 0.40, 0.98)
	btn_hover.border_color = Color(0.5, 0.9, 1.0, 1.0)
	switch_btn.add_theme_stylebox_override("hover", btn_hover)
	
	switch_btn.pressed.connect(_on_switch_pressed)
	hud.add_child(switch_btn)
	
	# 3. Companion Summon Button
	summon_btn = Button.new()
	summon_btn.name = "SummonBtn"
	summon_btn.text = "📍 Call Samurai to Here (Z)"
	summon_btn.anchors_preset = Control.PRESET_TOP_RIGHT
	summon_btn.anchor_left = 0.72
	summon_btn.anchor_top = 0.095
	summon_btn.anchor_right = 0.98
	summon_btn.anchor_bottom = 0.145
	summon_btn.focus_mode = Control.FOCUS_NONE
	
	var sum_style = StyleBoxFlat.new()
	sum_style.bg_color = Color(0.10, 0.14, 0.18, 0.85)
	sum_style.border_color = Color(0.3, 0.6, 0.8, 0.7)
	sum_style.border_width_left = 1
	sum_style.border_width_top = 1
	sum_style.border_width_right = 1
	sum_style.border_width_bottom = 1
	sum_style.corner_radius_top_left = 6
	sum_style.corner_radius_top_right = 6
	sum_style.corner_radius_bottom_left = 6
	sum_style.corner_radius_bottom_right = 6
	summon_btn.add_theme_stylebox_override("normal", sum_style)
	
	summon_btn.pressed.connect(_on_summon_pressed)
	hud.add_child(summon_btn)
	
	# 4. Circular Focus Ring Reticle (aim_reticle.gd - matching Image 5)
	var reticle_script = load("res://scripts/aim_reticle.gd")
	if reticle_script:
		aim_reticle = reticle_script.new()
		aim_reticle.name = "CustomAimReticle"
		hud.add_child(aim_reticle)
		aim_reticle.set_mode(aim_reticle.ReticleMode.HIP_FIRE if is_bow_drawn else aim_reticle.ReticleMode.HIDDEN)

func set_active_player(active: bool) -> void:
	is_active_player = active
	if not camera:
		camera = find_child("Camera3D", true, false) as Camera3D
	if camera:
		if active:
			camera.make_current()
		else:
			camera.current = false
	if not hud:
		hud = find_child("HUD", true, false) as CanvasLayer
		if not hud:
			hud = find_child("*HUD*", true, false) as CanvasLayer
	if hud:
		hud.visible = active
	if not active:
		velocity = Vector3.ZERO
		is_ads_aim = false
		if current_state != State.NORMAL:
			current_state = State.NORMAL
		if anim_player and anim_player.has_animation("Armature_048|VRoid_standing_idle_01"):
			anim_player.play("Armature_048|VRoid_standing_idle_01")
		if aim_reticle:
			aim_reticle.set_mode(aim_reticle.ReticleMode.HIDDEN)
		if snd_grass_breeze and snd_grass_breeze.playing:
			snd_grass_breeze.stop()
		update_weapon_display()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if snd_grass_breeze and not snd_grass_breeze.playing:
			snd_grass_breeze.volume_db = -12.0
			snd_grass_breeze.play()

func _on_switch_pressed() -> void:
	switch_to_partner()

func _on_summon_pressed() -> void:
	summon_companion()

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
	if snd_switch and snd_switch.stream:
		snd_switch.pitch_scale = 1.1
		snd_switch.play()

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
		
	# Toggle mouse mode with ESC
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
		
	# Switch character shortcut (TAB or C when not rolling)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			switch_to_partner()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_Z:
			summon_companion()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_G:
			is_bow_drawn = not is_bow_drawn
			update_weapon_display()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_Q:
			# Standing block / defensive stance
			if current_state == State.NORMAL:
				current_state = State.BLOCKING
				state_timer = 0.55
				if anim_player and anim_player.has_animation("Armature_048|VRoid_standing_block"):
					anim_player.play("Armature_048|VRoid_standing_block", 0.12)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_C and current_state == State.NORMAL and velocity.length_squared() < 0.2:
			switch_to_partner()
			get_viewport().set_input_as_handled()
			return
			
	# Camera rotation with mouse
	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or current_state == State.BOW_AIM or current_state == State.BOW_SHOOT):
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clampf(spring_arm.rotation.x, deg_to_rad(-65.0), deg_to_rad(65.0))
		if current_state == State.BOW_AIM or current_state == State.BOW_SHOOT:
			visuals.rotation.y = camera_pivot.global_rotation.y
			visuals.rotation.x = 0.0
		get_viewport().set_input_as_handled()
		return
		
	# Archery & Camera Zoom Input handling
	if event is InputEventMouseButton:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
		# Mouse Wheel: Smooth Zoom In / Out
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			user_preferred_zoom = clampf(user_preferred_zoom - 0.35, min_zoom, max_zoom)
			if current_state != State.BOW_AIM:
				target_zoom = user_preferred_zoom
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			user_preferred_zoom = clampf(user_preferred_zoom + 0.35, min_zoom, max_zoom)
			if current_state != State.BOW_AIM:
				target_zoom = user_preferred_zoom
			get_viewport().set_input_as_handled()
			return
			
		# Right Click: Toggle / Activate Focus ADS Aim
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if current_state == State.BOW_AIM:
					stop_bow_aim()
				else:
					start_bow_aim()
			get_viewport().set_input_as_handled()
			return
			
		# Left Click: Tap for Instant Shoot, Hold for Focus Aim (Release shoots), Click during ADS shoots
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if current_state == State.BOW_AIM:
					shoot_arrow()
					if aim_activated_by_left_hold:
						stop_bow_aim()
						aim_activated_by_left_hold = false
				else:
					left_click_held = true
					left_click_press_time = Time.get_ticks_msec() / 1000.0
					aim_activated_by_left_hold = false
			else:
				if left_click_held:
					left_click_held = false
					if aim_activated_by_left_hold:
						shoot_arrow()
						stop_bow_aim()
						aim_activated_by_left_hold = false
					else:
						shoot_arrow_instant()
			get_viewport().set_input_as_handled()
			return
	
	# Keyboard attack shortcuts
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			# Instant continuous rapid shot
			shoot_arrow_instant()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_LEFT:
			# Left key: click/tap fires instant shot, hold > 2.0s triggers focus aim
			if event.pressed and not event.echo:
				left_click_held = true
				left_click_press_time = Time.get_ticks_msec() / 1000.0
				aim_activated_by_left_hold = false
			elif not event.pressed:
				if left_click_held:
					left_click_held = false
					if aim_activated_by_left_hold:
						shoot_arrow()
						stop_bow_aim()
						aim_activated_by_left_hold = false
					else:
						shoot_arrow_instant()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_V or event.keycode == KEY_E:
			melee_kick()
			get_viewport().set_input_as_handled()
			return

func start_bow_aim() -> void:
	if current_state == State.ROLLING or current_state == State.SWIMMING:
		return
	is_bow_drawn = true
	current_state = State.BOW_AIM
	is_ads_aim = true
	aim_charge_time = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# View angle: Smooth Over-The-Right-Shoulder Aim View matching reference video
	target_zoom = aim_zoom
	target_fov = aim_fov
	target_pivot_offset = aim_pivot_offset
	if camera:
		camera.near = 0.05
	if visuals and camera_pivot:
		visuals.rotation.y = camera_pivot.global_rotation.y
		visuals.rotation.x = 0.0
	if bow_hand_node:
		bow_hand_node.transform = bow_transform_aim
	
	if info_panel: info_panel.visible = false
	if switch_btn: switch_btn.visible = false
	if summon_btn: summon_btn.visible = false
	
	update_weapon_display()
	
	if aim_reticle:
		aim_reticle.set_mode(aim_reticle.ReticleMode.ADS_AIM)
		
	# Play bow draw sound strictly while focusing
	if snd_bow_draw and snd_bow_draw.stream:
		snd_bow_draw.pitch_scale = randf_range(0.98, 1.02)
		snd_bow_draw.play()

func stop_bow_aim() -> void:
	if snd_bow_draw and snd_bow_draw.playing:
		snd_bow_draw.stop()
		
	if current_state == State.BOW_AIM or is_ads_aim:
		is_ads_aim = false
		if current_state == State.BOW_AIM:
			current_state = State.NORMAL
			
		target_zoom = user_preferred_zoom
		target_fov = default_fov
		target_pivot_offset = normal_pivot_offset
		if camera:
			camera.near = 0.05
			
		_set_head_meshes_visible(true)
		
		if info_panel and is_active_player: info_panel.visible = true
		if switch_btn and is_active_player: switch_btn.visible = true
		if summon_btn and is_active_player: summon_btn.visible = true
		
		update_weapon_display()
		if aim_reticle:
			aim_reticle.set_mode(aim_reticle.ReticleMode.HIP_FIRE if is_bow_drawn else aim_reticle.ReticleMode.HIDDEN)

func shoot_arrow_instant() -> void:
	if current_state == State.ROLLING or current_state == State.SWIMMING:
		return
	# Instant shoot: Ensure no bow draw sound plays
	if snd_bow_draw and snd_bow_draw.playing:
		snd_bow_draw.stop()
		
	is_bow_drawn = true
	_spawn_and_fire_projectile()
	
	current_state = State.BOW_SHOOT
	state_timer = 0.32
	string_twang_timer = 0.18
	rapid_shoot_reticle_timer = 0.35
	target_pivot_offset = normal_pivot_offset
	
	if aim_reticle:
		aim_reticle.set_mode(aim_reticle.ReticleMode.HIP_FIRE)
		
	# Instant shoot sound: Wind swoosh sound ONLY
	if snd_arrow_swoosh and snd_arrow_swoosh.stream:
		snd_arrow_swoosh.pitch_scale = randf_range(0.97, 1.05)
		snd_arrow_swoosh.play()
		
	# Posture selection:
	# If shooting at the ground (steep downward aim): archer braced combat posture
	# Otherwise: shoots while standing upright!
	var is_shooting_at_ground = (spring_arm.rotation.x < -0.22)
	if anim_player:
		if is_shooting_at_ground:
			if anim_player.has_animation("Armature_048|VRoid_standing_aim_recoil"):
				anim_player.play("Armature_048|VRoid_standing_aim_recoil", 0.08)
		else:
			if anim_player.has_animation("standing_aim_recoil_upright"):
				anim_player.play("standing_aim_recoil_upright", 0.08)
			elif anim_player.has_animation("Armature_048|VRoid_standing_aim_recoil"):
				anim_player.play("Armature_048|VRoid_standing_aim_recoil", 0.08)
		
	var cam_yaw: float = camera_pivot.global_rotation.y if camera_pivot else (visuals.global_rotation.y if visuals else 0.0)
	visuals.rotation.y = cam_yaw
	visuals.rotation.x = 0.0

func shoot_arrow() -> void:
	if current_state == State.ROLLING or current_state == State.SWIMMING:
		return
	# Stop bow focus sound and play wind swoosh on release
	if snd_bow_draw and snd_bow_draw.playing:
		snd_bow_draw.stop()
		
	is_bow_drawn = true
	_spawn_and_fire_projectile()
	
	current_state = State.BOW_SHOOT
	state_timer = 0.35
	string_twang_timer = 0.22
	
	if bow_arrow_node:
		bow_arrow_node.visible = false
	update_weapon_display()
	
	# Focus aim release sound: Wind swoosh sound ONLY
	if snd_arrow_swoosh and snd_arrow_swoosh.stream:
		snd_arrow_swoosh.pitch_scale = randf_range(0.97, 1.04)
		snd_arrow_swoosh.play()
		
	# Posture selection:
	var is_shooting_at_ground = (spring_arm.rotation.x < -0.22)
	if anim_player:
		if is_shooting_at_ground:
			if anim_player.has_animation("Armature_048|VRoid_standing_aim_recoil"):
				anim_player.play("Armature_048|VRoid_standing_aim_recoil", 0.08)
		else:
			if anim_player.has_animation("standing_aim_recoil_upright"):
				anim_player.play("standing_aim_recoil_upright", 0.08)
			elif anim_player.has_animation("Armature_048|VRoid_standing_aim_recoil"):
				anim_player.play("Armature_048|VRoid_standing_aim_recoil", 0.08)
		
	var cam_yaw: float = camera_pivot.global_rotation.y if camera_pivot else (visuals.global_rotation.y if visuals else 0.0)
	visuals.rotation.y = cam_yaw
	visuals.rotation.x = 0.0

func _spawn_and_fire_projectile() -> void:
	if not arrow_scene_preload:
		arrow_scene_preload = load("res://scenes/arrow_projectile.tscn")
	if not arrow_scene_preload:
		return
		
	var arrow = arrow_scene_preload.instantiate()
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
	var ray_start: Vector3 = camera.project_ray_origin(center)
	var ray_dir: Vector3 = camera.project_ray_normal(center)
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
	var drop_comp: float = clampf(0.5 * arrow.gravity_strength * (flight_time * flight_time), 0.0, 1.4)
	var compensated_target: Vector3 = target_point + Vector3(0.0, drop_comp, 0.0)
	var shoot_dir: Vector3 = (compensated_target - spawn_pos).normalized()
	
	arrow.launch(shoot_dir, arrow_spd)

func melee_kick() -> void:
	if current_state != State.NORMAL:
		return
	current_state = State.MELEE
	state_timer = 0.65
	if anim_player and anim_player.has_animation("Armature_048|VRoid_standing_melee_kick"):
		anim_player.play("Armature_048|VRoid_standing_melee_kick", 0.1)

func _physics_process(delta: float) -> void:
	_update_bow_visuals(delta)
	
	# Head Mesh Visibility:
	# Keep head visible in normal & OTS aim; auto-hide only if camera gets too close (< 0.70m)
	if spring_arm and spring_arm.spring_length < 0.70:
		_set_head_meshes_visible(false)
		if camera: camera.near = 0.02
	else:
		_set_head_meshes_visible(true)
		if camera: camera.near = 0.05
	
	# Smooth Camera zoom, FOV, and OTS pivot interpolation (Dynamic zoom in/out effect)
	var zoom_lerp_speed: float = 14.0
	if spring_arm:
		spring_arm.spring_length = lerpf(spring_arm.spring_length, target_zoom, zoom_lerp_speed * delta)
	if camera:
		camera.fov = lerpf(camera.fov, target_fov, zoom_lerp_speed * delta)
	if camera_pivot:
		camera_pivot.position = camera_pivot.position.lerp(target_pivot_offset, zoom_lerp_speed * delta)
		
	# Upper-Body Aim Pitch:
	# Both during State.BOW_AIM and State.BOW_SHOOT, current_spine_pitch follows camera pitch.
	# AimPitchModifier (SkeletonModifier3D) processes this post-animation so hand, bow, and arrow stay perfectly aligned.
	visuals.rotation.x = 0.0
	if current_state == State.BOW_AIM or current_state == State.BOW_SHOOT:
		var target_pitch: float = clampf(spring_arm.rotation.x, deg_to_rad(-55.0), deg_to_rad(55.0))
		current_spine_pitch = lerpf(current_spine_pitch, target_pitch, 20.0 * delta)
	else:
		if abs(current_spine_pitch) > 0.001:
			current_spine_pitch = move_toward(current_spine_pitch, 0.0, 15.0 * delta)
				
	# Left click hold-to-aim threshold detection
	if left_click_held and not aim_activated_by_left_hold and current_state != State.BOW_AIM and current_state != State.ROLLING:
		var hold_dur := (Time.get_ticks_msec() / 1000.0) - left_click_press_time
		if hold_dur >= 2.0:
			aim_activated_by_left_hold = true
			start_bow_aim()

	# Reticle Mode Management (Hip-Fire pointer is always visible when bow is drawn; ADS Circle when aiming)
	if is_active_player and aim_reticle:
		if current_state == State.BOW_AIM:
			if aim_reticle.current_mode != aim_reticle.ReticleMode.ADS_AIM:
				aim_reticle.set_mode(aim_reticle.ReticleMode.ADS_AIM)
		elif is_bow_drawn:
			if aim_reticle.current_mode != aim_reticle.ReticleMode.HIP_FIRE:
				aim_reticle.set_mode(aim_reticle.ReticleMode.HIP_FIRE)
		else:
			if aim_reticle.current_mode != aim_reticle.ReticleMode.HIDDEN:
				aim_reticle.set_mode(aim_reticle.ReticleMode.HIDDEN)
			
	# Ambient Grass Breezing Sound
	# When standing still on the grass, volume swells gently; when moving, it stays subtly ambient
	if snd_grass_breeze and is_active_player:
		var horiz_spd := Vector2(velocity.x, velocity.z).length()
		var target_vol: float = -20.0
		if is_on_floor():
			if horiz_spd < 0.4:
				# Standing on the grass!
				target_vol = -7.0
			else:
				target_vol = -16.0
		else:
			target_vol = -24.0
		snd_grass_breeze.volume_db = lerpf(snd_grass_breeze.volume_db, target_vol, 2.5 * delta)
		
	if not is_active_player:
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 12.0 * delta)
		move_and_slide()
		if anim_player and not anim_player.is_playing():
			anim_player.play("Armature_048|VRoid_standing_idle_01")
		return
		
	match current_state:
		State.NORMAL:
			_handle_normal(delta)
		State.BOW_AIM:
			_handle_bow_aim(delta)
		State.BOW_SHOOT:
			_handle_bow_shoot(delta)
		State.BLOCKING:
			_handle_blocking(delta)
		State.MELEE:
			_handle_melee(delta)
		State.ROLLING:
			_handle_rolling(delta)
		State.JUMP_AIR:
			_handle_jump_air(delta)
		State.LANDING:
			_handle_landing(delta)
			
	move_and_slide()

	# Void Fallback Safety:
	if is_on_floor():
		last_safe_ground_pos = global_position
	elif global_position.y < -15.0:
		velocity = Vector3.ZERO
		global_position = last_safe_ground_pos + Vector3.UP * 0.3
		current_state = State.NORMAL
		was_in_air = false

	_update_footsteps(delta)
	_update_hud()


func _setup_input_actions() -> void:
	_add_action_key_if_missing("move_forward", KEY_W)
	_add_action_key_if_missing("move_backward", KEY_S)
	_add_action_key_if_missing("move_left", KEY_A)
	_add_action_key_if_missing("move_right", KEY_D)
	_add_action_key_if_missing("jump", KEY_SPACE)
	_add_action_key_if_missing("sprint", KEY_SHIFT)

func _add_action_key_if_missing(act_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(act_name):
		InputMap.add_action(act_name)
		var ev = InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(act_name, ev)

func _get_movement_input() -> Vector2:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir == Vector2.ZERO:
		var l := 1.0 if (Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)) else 0.0
		var r := 1.0 if (Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) else 0.0
		var f := 1.0 if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0
		var b := 1.0 if (Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0
		input_dir = Vector2(r - l, b - f)
		if input_dir.length_squared() > 1.0:
			input_dir = input_dir.normalized()
	return input_dir

func _handle_normal(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		current_state = State.JUMP_AIR
		was_in_air = true
		if anim_player and anim_player.has_animation("Armature_048|VRoid_fall_a"):
			anim_player.play("Armature_048|VRoid_fall_a", 0.15)
		return
	else:
		if was_in_air:
			was_in_air = false
			current_state = State.LANDING
			state_timer = 0.28
			if snd_land and snd_land.stream: snd_land.play()
			var horiz_m := Vector2(velocity.x, velocity.z).length()
			if anim_player:
				if horiz_m > 1.5 and anim_player.has_animation("Armature_048|VRoid_fall_a_land_to_run_forward"):
					anim_player.play("Armature_048|VRoid_fall_a_land_to_run_forward", 0.08)
				elif anim_player.has_animation("Armature_048|VRoid_fall_a_land_to_standing_idle_01"):
					anim_player.play("Armature_048|VRoid_fall_a_land_to_standing_idle_01", 0.08)
			return
			
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
			was_in_air = true
			current_state = State.JUMP_AIR
			if snd_jump and snd_jump.stream: snd_jump.play()
			if anim_player and anim_player.has_animation("Armature_048|VRoid_fall_a"):
				anim_player.play("Armature_048|VRoid_fall_a", 0.1)
			return
				
	var cam_yaw: float = camera_pivot.global_rotation.y if camera_pivot else (visuals.global_rotation.y if visuals else 0.0)
	var input_dir := _get_movement_input()
	
	if input_dir != Vector2.ZERO:
		var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, cam_yaw).normalized()
		var is_sprint := Input.is_action_pressed("sprint")
		var is_jog := Input.is_action_pressed("jog")
		
		var target_spd: float = walk_speed
		if is_sprint:
			target_spd = sprint_speed
		elif is_jog:
			target_spd = jog_speed
			
		velocity.x = move_dir.x * target_spd
		velocity.z = move_dir.z * target_spd
		
		var target_rot_y := atan2(-move_dir.x, -move_dir.z)
		
		# Detect sharp 180° turn
		var angle_diff := absf(wrapf(target_rot_y - visuals.rotation.y, -PI, PI))
		if angle_diff > deg_to_rad(140.0) and turn_180_timer <= 0.0 and velocity.length_squared() > 1.0:
			turn_180_timer = 0.35
			if anim_player and anim_player.has_animation("Armature_048|VRoid_catwalk_walk_turn_180_tight"):
				anim_player.play("Armature_048|VRoid_catwalk_walk_turn_180_tight", 0.1)
				
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rot_y, rotation_speed * delta)
		visuals.rotation.x = 0.0
		
		if turn_180_timer > 0.0:
			turn_180_timer -= delta
			return
			
		var horiz_spd := Vector2(velocity.x, velocity.z).length()
		if anim_player:
			if is_sprint:
				if anim_player.current_animation != "Armature_048|VRoid_running":
					anim_player.play("Armature_048|VRoid_running", 0.15)
				anim_player.speed_scale = clampf(horiz_spd / 6.5, 0.8, 1.4)
			elif is_jog:
				if anim_player.current_animation != "Armature_048|VRoid_medium_run":
					anim_player.play("Armature_048|VRoid_medium_run", 0.15)
				anim_player.speed_scale = clampf(horiz_spd / 4.2, 0.8, 1.3)
			else:
				if input_dir.x > 0.35 and input_dir.y < -0.2 and anim_player.has_animation("Armature_048|VRoid_catwalk_walk_forward_arc_90r"):
					if anim_player.current_animation != "Armature_048|VRoid_catwalk_walk_forward_arc_90r":
						anim_player.play("Armature_048|VRoid_catwalk_walk_forward_arc_90r", 0.15)
					anim_player.speed_scale = clampf(horiz_spd / 2.3, 0.8, 1.3)
				elif input_dir.y > 0.5 and anim_player.has_animation("Armature_048|VRoid_female_walk"):
					if anim_player.current_animation != "Armature_048|VRoid_female_walk":
						anim_player.play("Armature_048|VRoid_female_walk", 0.15)
					anim_player.speed_scale = clampf(horiz_spd / 2.3, 0.8, 1.3)
				else:
					# Catwalk walk forward crossed (main walking style)
					if anim_player.current_animation != "Armature_048|VRoid_catwalk_walk_forward_crossed":
						anim_player.play("Armature_048|VRoid_catwalk_walk_forward_crossed", 0.15)
					anim_player.speed_scale = clampf(horiz_spd / 2.3, 0.8, 1.3)
	else:
		turn_180_timer = 0.0
		velocity.x = move_toward(velocity.x, 0, 16.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 16.0 * delta)
		if anim_player and anim_player.current_animation != "Armature_048|VRoid_standing_idle_01":
			anim_player.play("Armature_048|VRoid_standing_idle_01", 0.2)
			anim_player.speed_scale = 1.0

func _handle_jump_air(delta: float) -> void:
	velocity.y -= gravity * delta
	if is_on_floor():
		current_state = State.LANDING
		state_timer = 0.25
		was_in_air = false
		if snd_land and snd_land.stream: snd_land.play()
		var horiz_m := Vector2(velocity.x, velocity.z).length()
		if anim_player:
			if horiz_m > 1.5 and anim_player.has_animation("Armature_048|VRoid_fall_a_land_to_run_forward"):
				anim_player.play("Armature_048|VRoid_fall_a_land_to_run_forward", 0.08)
			elif anim_player.has_animation("Armature_048|VRoid_fall_a_land_to_standing_idle_01"):
				anim_player.play("Armature_048|VRoid_fall_a_land_to_standing_idle_01", 0.08)
		return
		
	var cam_yaw: float = camera_pivot.global_rotation.y if camera_pivot else (visuals.global_rotation.y if visuals else 0.0)
	var input_dir := _get_movement_input()
	if input_dir != Vector2.ZERO:
		var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, cam_yaw).normalized()
		velocity.x = move_dir.x * walk_speed
		velocity.z = move_dir.z * walk_speed
		visuals.rotation.y = lerp_angle(visuals.rotation.y, atan2(-move_dir.x, -move_dir.z), rotation_speed * delta)

func _handle_landing(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.NORMAL

func _handle_blocking(delta: float) -> void:
	state_timer -= delta
	velocity.x = move_toward(velocity.x, 0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 12.0 * delta)
	if state_timer <= 0.0 or not Input.is_key_pressed(KEY_Q):
		current_state = State.NORMAL

func _handle_bow_aim(delta: float) -> void:
	aim_charge_time += delta
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	var cam_yaw: float = camera_pivot.global_rotation.y if camera_pivot else (visuals.global_rotation.y if visuals else 0.0)
	visuals.rotation.y = cam_yaw
	visuals.rotation.x = 0.0
	
	var is_shooting_at_ground = (spring_arm.rotation.x < -0.22)
	var input_dir := _get_movement_input()
	
	if input_dir != Vector2.ZERO:
		var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, cam_yaw).normalized()
		velocity.x = move_dir.x * 2.2
		velocity.z = move_dir.z * 2.2
		
		if anim_player:
			if input_dir.y < -0.3:
				if anim_player.current_animation != "Armature_048|VRoid_standing_aim_walk_forward":
					anim_player.play("Armature_048|VRoid_standing_aim_walk_forward", 0.15)
			elif input_dir.y > 0.3:
				if anim_player.current_animation != "Armature_048|VRoid_standing_aim_walk_back":
					anim_player.play("Armature_048|VRoid_standing_aim_walk_back", 0.15)
			elif input_dir.x < -0.3:
				if anim_player.current_animation != "Armature_048|VRoid_standing_aim_walk_left":
					anim_player.play("Armature_048|VRoid_standing_aim_walk_left", 0.15)
			elif input_dir.x > 0.3:
				if anim_player.current_animation != "Armature_048|VRoid_standing_aim_walk_right":
					anim_player.play("Armature_048|VRoid_standing_aim_walk_right", 0.15)
	else:
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
		if anim_player:
			if is_shooting_at_ground:
				# Posture of archer aiming down at the ground
				if anim_player.current_animation != "Armature_048|VRoid_standing_aim_overdraw":
					anim_player.play("Armature_048|VRoid_standing_aim_overdraw", 0.15)
			else:
				# Shoot while standing upright!
				if anim_player.current_animation != "standing_aim_overdraw_upright":
					anim_player.play("standing_aim_overdraw_upright", 0.15)

func _handle_bow_shoot(delta: float) -> void:
	state_timer -= delta
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	
	var cam_yaw: float = camera_pivot.global_rotation.y if camera_pivot else (visuals.global_rotation.y if visuals else 0.0)
	visuals.rotation.y = cam_yaw
	visuals.rotation.x = 0.0
	
	if state_timer <= 0.0:
		if is_ads_aim and (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			current_state = State.BOW_AIM
			aim_charge_time = 0.0
			if aim_reticle: aim_reticle.set_mode(aim_reticle.ReticleMode.ADS_AIM)
		else:
			stop_bow_aim()

func _handle_melee(delta: float) -> void:
	state_timer -= delta
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	if state_timer <= 0.0:
		current_state = State.NORMAL

func _handle_rolling(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.NORMAL

func _update_bow_visuals(delta: float) -> void:
	if not bow_hand_node or not bow_hand_node.visible:
		if bow_string_node: bow_string_node.visible = false
		if bow_arrow_node: bow_arrow_node.visible = false
		return
		
	var target_bow_tx = bow_transform_aim if (current_state == State.BOW_AIM or current_state == State.BOW_SHOOT) else bow_transform_idle
	if current_state == State.BOW_AIM or current_state == State.BOW_SHOOT:
		bow_hand_node.transform = bow_transform_aim
	else:
		bow_hand_node.transform = bow_hand_node.transform.interpolate_with(target_bow_tx, clampf(16.0 * delta, 0.0, 1.0))
	
	if bow_string_node: bow_string_node.visible = true
	var target_pull: Vector3 = bow_string_rest
	
	if current_state == State.BOW_AIM:
		var shelf_world = bow_hand_node.global_transform * bow_shelf_offset
		var cam_fwd: Vector3
		var aim_target: Vector3
		if camera:
			cam_fwd = -camera.global_transform.basis.z
			aim_target = camera.global_position + cam_fwd * 60.0
		else:
			aim_target = shelf_world + Vector3.FORWARD * 60.0
			
		# Physical finger grip: String apex p1 & arrow nock anchored directly to right index finger
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
			var arrow_scale = 0.72
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

func _update_hud() -> void:
	if not state_label:
		return
	var spd = Vector2(velocity.x, velocity.z).length()
	var st_name = "NORMAL"
	match current_state:
		State.BOW_AIM: st_name = "AIMING [PRECISION ADS]"
		State.BOW_SHOOT: st_name = "SHOOTING"
		State.BLOCKING: st_name = "BLOCKING"
		State.MELEE: st_name = "MELEE KICK"
		State.ROLLING: st_name = "ROLLING"
		State.JUMP_AIR: st_name = "JUMP AIR"
		State.LANDING: st_name = "LANDING"
	state_label.text = "State: %s | Speed: %.1f m/s | Weapon: LONGBOW [%s]" % [
		st_name, spd, ("DRAWN" if is_bow_drawn else "STOWED")
	]

func _update_footsteps(delta: float) -> void:
	if not is_on_floor() or current_state == State.ROLLING:
		return
	var horiz_speed = Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.4:
		var step_cadence = clampf(horiz_speed * 0.55, 1.4, 3.4)
		step_timer += delta * step_cadence
		if step_timer >= 1.0:
			step_timer = 0.0
			if not snd_step_pool.is_empty() and not streams_grass_steps.is_empty():
				var sp = snd_step_pool[snd_step_idx]
				snd_step_idx = (snd_step_idx + 1) % snd_step_pool.size()
				sp.stream = streams_grass_steps[randi() % streams_grass_steps.size()]
				sp.pitch_scale = randf_range(0.96, 1.04)
				sp.play()


func _ensure_environment_collisions() -> void:
	var parent_node = get_parent()
	if not parent_node: return
	var nature = parent_node.find_child("Nature", true, false)
	if not nature: return
	for c in nature.get_children():
		var sb = c.find_child("TreeStaticBody", true, false)
		if sb:
			var has_canopy = false
			for ch in sb.get_children():
				if ch.name == "CanopyCol":
					has_canopy = true
					break
			if not has_canopy:
				var cs = CollisionShape3D.new()
				cs.name = "CanopyCol"
				var sph = SphereShape3D.new()
				sph.radius = 2.4
				cs.shape = sph
				cs.position = Vector3(0.0, 5.5, 0.0)
				sb.add_child(cs)
