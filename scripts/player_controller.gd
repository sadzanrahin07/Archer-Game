extends CharacterBody3D

# State Machine
enum State { 
	NORMAL, 
	CROUCHING, 
	JUMP_START, 
	JUMP_AIR, 
	LANDING, 
	ROLLING, 
	SLIDING, 
	FLIPPING, 
	ATTACKING, 
	BLOCKING, 
	CHOPPING,
	SWIMMING,
	HIT_STUN
}

enum WeaponType {
	KATANA
}

@export var character_name: String = "Samurai"
@export var is_active_player: bool = false

var current_state: State = State.NORMAL
var current_weapon: WeaponType = WeaponType.KATANA

# Movement speeds (normalized for fluid and realistic fighting)
@export var walk_speed: float = 2.4
@export var jog_speed: float = 4.6
@export var sprint_speed: float = 7.6
@export var crouch_speed: float = 2.2
@export var jump_velocity: float = 7.2
@export var roll_speed: float = 7.2
@export var dash_speed: float = 5.2 # Normalized to move 2-4 feet (~1.0 meter)
@export var rotation_speed: float = 14.0
@export var mouse_sensitivity: float = 0.0028

# Maximum step height for climbing small obstacles (1-3 inches up to ~11 inches)
const MAX_STEP_HEIGHT: float = 0.28

# Camera zoom
@export var min_zoom: float = 1.5
@export var max_zoom: float = 6.5
var target_zoom: float = 3.6

var gravity: float = 18.0

@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var char_model: Node3D = get_node_or_null("Visuals/CharacterModel")
@onready var camera_pivot: Node3D = get_node_or_null("CameraPivot")
@onready var spring_arm: SpringArm3D = get_node_or_null("CameraPivot/SpringArm3D")
@onready var camera: Camera3D = get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
@onready var ray_ledge: RayCast3D = get_node_or_null("RayCastLedge")
@onready var ray_wall: RayCast3D = get_node_or_null("RayCastWall")
@onready var col_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var hud: CanvasLayer = get_node_or_null("HUD")

# Animation & Skeleton references
var skeleton: Skeleton3D = null
var anim_player: AnimationPlayer = null

# Bone Indices
var bone_root: int = -1
var bone_hips: int = -1
var bone_spine: int = -1
var bone_chest: int = -1
var bone_head: int = -1
var bone_r_hand: int = -1
var bone_l_hand: int = -1

# Hair & Cloth physics bones
var hair_ponytail_bones: Array[int] = []
var hair_side_bones: Array[int] = []
var cloth_skirt_b_l: int = -1
var cloth_skirt_b_r: int = -1
var rest_bone_rotations: Dictionary = {}

# Katana Attachment References (Katana ONLY - No Bow or Arrow)
var katana_hand_attach: BoneAttachment3D = null
var katana_hand_blade: Node3D = null
var katana_hip_attach: BoneAttachment3D = null
var katana_hip_sheath: MeshInstance3D = null
var katana_hip_sword: Node3D = null
var katana_mesh_sheathed: Mesh = null
var katana_mesh_empty_sheath: Mesh = null
var is_katana_drawn: bool = false
var sword_stance_timer: float = 0.0

# Timers & State Variables
var state_timer: float = 0.0
var walk_cycle: float = 0.0
var air_time: float = 0.0
var landing_squish: float = 0.0

# Attack combo system
var combo_step: int = 0
var combo_reset_timer: float = 0.0
var attack_type: String = "sword" # "sword" or "punch"

# Audio system
var snd_step: AudioStreamPlayer = null
var snd_step_pool: Array[AudioStreamPlayer] = []
var snd_step_idx: int = 0
var snd_jump: AudioStreamPlayer = null
var snd_land: AudioStreamPlayer = null
var snd_roll: AudioStreamPlayer = null
var snd_action: AudioStreamPlayer = null
var snd_grass_breeze: AudioStreamPlayer = null
var streams_grass_steps: Array[AudioStream] = []
var snd_sword_draw: AudioStreamPlayer = null
var snd_sword_sheath: AudioStreamPlayer = null
var snd_sword_swings: Array[AudioStream] = []
var snd_sword_hit: AudioStreamPlayer = null
var snd_wood_chop: AudioStreamPlayer = null
var attack_has_hit: bool = false
var chop_has_hit: bool = false
var chopped_wood_count: int = 0
var screen_shake_amount: float = 0.0
var snd_swim: AudioStreamPlayer = null
var snd_splash: AudioStreamPlayer = null
var snd_switch: AudioStreamPlayer = null

# Health and Swimming
var player_health: float = 100.0
var max_player_health: float = 100.0
var swim_stroke_timer: float = 0.0
var step_timer: float = 0.0

# HUD references
var hud_label: Label = null
var switch_btn: Button = null
var summon_btn: Button = null

func _enter_tree() -> void:
	add_to_group("player_characters")
	_setup_input_actions()

func _ready() -> void:
	rotation = Vector3.ZERO
	floor_snap_length = 0.45
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(55.0)
	floor_stop_on_slope = true
	
	var def_grav = ProjectSettings.get_setting("physics/3d/default_gravity")
	if def_grav != null and float(def_grav) > 0.0:
		gravity = float(def_grav)
		
	if not char_model and visuals and visuals.get_child_count() > 0:
		char_model = visuals.get_child(0)
		
	_setup_input_actions()
	_setup_materials()
	_setup_skeleton_bones()
	_setup_animation_player()
	_setup_weapons()
	_setup_audio()
	_setup_hud()
	
	set_active_player(is_active_player)

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
	if hud:
		hud.visible = active
	if not active:
		velocity = Vector3.ZERO
		if snd_grass_breeze and snd_grass_breeze.playing: snd_grass_breeze.stop()
		if current_state != State.NORMAL:
			current_state = State.NORMAL
		var idle_name = _find_anim("Idle")
		if idle_name != "" and anim_player and anim_player.has_animation(idle_name):
			anim_player.play(idle_name)
		update_weapon_display()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if snd_grass_breeze and not snd_grass_breeze.playing: snd_grass_breeze.volume_db = -12.0; snd_grass_breeze.play()

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
		snd_switch.pitch_scale = 1.05
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

func _setup_animation_player() -> void:
	if not char_model:
		return
	anim_player = char_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		char_model.add_child(anim_player)
		anim_player.root_node = anim_player.get_path_to(char_model)
		
	if not char_model.has_node("Armature"):
		var arm_dummy = Node3D.new()
		arm_dummy.name = "Armature"
		char_model.add_child(arm_dummy)
		
	if not anim_player.has_animation_library("A1") and not anim_player.has_animation_library("A2"):
		var anim_lib = load("res://animations/ual1_humanoid_library.res") as AnimationLibrary
		if anim_lib and not anim_player.has_animation_library("ual1"):
			anim_player.add_animation_library("ual1", anim_lib)

	for anim_name in anim_player.get_animation_list():
		var anim = anim_player.get_animation(anim_name)
		var t = 0
		while t < anim.get_track_count():
			var pth = str(anim.track_get_path(t))
			var t_type = anim.track_get_type(t)
			if ("Root" in pth and t_type == Animation.TYPE_POSITION_3D) or pth.begins_with("Armature") or pth == "Armature":
				anim.remove_track(t)
			else:
				t += 1
		
	var idle_name = _find_anim("Idle")
	if idle_name != "" and anim_player.has_animation(idle_name):
		anim_player.play(idle_name)

func _find_anim(keyword: String) -> String:
	if not anim_player:
		return ""
	var candidates: Array[String] = [keyword]
	if keyword == "Walking" or keyword == "Walk":
		candidates = ["Walk", "Walking", "Walk_Formal"]
	elif keyword == "Jogging" or keyword == "Jog" or keyword == "Jog_Fwd":
		candidates = ["Jog_Fwd", "Jog", "Jogging"]
	elif keyword == "Running" or keyword == "Run" or keyword == "Sprint":
		candidates = ["Sprint", "Run", "Running"]
	elif keyword == "Crouch_Walk" or keyword == "Crouch_Fwd":
		candidates = ["Crouch_Fwd", "Crouch_Walk"]
	elif keyword == "Crouch_Idle":
		candidates = ["Crouch_Idle"]
	elif keyword == "Jump_Air" or keyword == "Jump":
		candidates = ["Jump", "NinjaJump_Idle", "Jump_Air"]
	elif keyword == "Jump_Start":
		candidates = ["NinjaJump_Start", "Jump_Start"]
	elif keyword == "Jump_Land":
		candidates = ["Jump_Land", "NinjaJump_Land"]
	elif keyword == "Sword_Idle":
		candidates = ["Sword_Idle", "Idle"]

	var anim_list = anim_player.get_animation_list()
	for cand in candidates:
		for a in anim_list:
			if a.begins_with("A2/") and (a.ends_with("|" + cand) or a.ends_with("/" + cand)):
				return a
		for a in anim_list:
			if a.ends_with("|" + cand) or a.ends_with("/" + cand):
				return a
		for a in anim_list:
			if cand in a:
				return a
	return ""

func _setup_weapons() -> void:
	if not skeleton:
		return
		
	katana_mesh_sheathed = load("res://models/katana_sheathed_mesh.res")
	katana_mesh_empty_sheath = load("res://models/katana_sheath_mesh.res")
	var k_mesh = load("res://models/katana_sword_mesh.res")
	
	# KATANA (Right Hand & Left Hip ONLY)
	katana_hand_attach = skeleton.find_child("RightHandKatana", true, false) as BoneAttachment3D
	if not katana_hand_attach:
		katana_hand_attach = BoneAttachment3D.new()
		katana_hand_attach.name = "RightHandKatana"
		katana_hand_attach.bone_name = "RightHand"
		skeleton.add_child(katana_hand_attach)
		
	if not katana_hand_attach.has_node("HandBlade"):
		katana_hand_blade = MeshInstance3D.new()
		katana_hand_blade.name = "HandBlade"
		katana_hand_blade.mesh = k_mesh
		katana_hand_blade.rotation_degrees = Vector3(30.0, 180.0, -150.0)
		katana_hand_blade.position = Vector3(-0.0486, -0.123, 0.031)
		katana_hand_attach.add_child(katana_hand_blade)
	else:
		katana_hand_blade = katana_hand_attach.get_node("HandBlade")
		katana_hand_blade.mesh = k_mesh
		katana_hand_blade.rotation_degrees = Vector3(30.0, 180.0, -150.0)
		katana_hand_blade.position = Vector3(-0.0486, -0.123, 0.031)
		
	katana_hip_attach = skeleton.find_child("HipSheathAttachment", true, false) as BoneAttachment3D
	if not katana_hip_attach:
		katana_hip_attach = BoneAttachment3D.new()
		katana_hip_attach.name = "HipSheathAttachment"
		katana_hip_attach.bone_name = "Hips"
		skeleton.add_child(katana_hip_attach)
		
	if not katana_hip_attach.has_node("HipSheath"):
		katana_hip_sheath = MeshInstance3D.new()
		katana_hip_sheath.name = "HipSheath"
		katana_hip_sheath.mesh = katana_mesh_sheathed
		katana_hip_sheath.position = Vector3(-0.165, -0.03, -0.035)
		katana_hip_sheath.rotation_degrees = Vector3(12.0, -95.0, -15.0)
		katana_hip_attach.add_child(katana_hip_sheath)
	else:
		katana_hip_sheath = katana_hip_attach.get_node("HipSheath")
		katana_hip_sheath.mesh = katana_mesh_sheathed
		katana_hip_sheath.position = Vector3(-0.165, -0.03, -0.035)
		katana_hip_sheath.rotation_degrees = Vector3(12.0, -95.0, -15.0)
		
	if katana_hip_sheath.has_node("SheathedSword"):
		var old_sword = katana_hip_sheath.get_node("SheathedSword")
		old_sword.visible = false
	katana_hip_sword = null

	# Clean up any leftover bow nodes if they exist
	var old_bow = skeleton.find_child("LeftHandBow", true, false)
	if old_bow: old_bow.queue_free()
	var old_back = skeleton.find_child("BackBowAttachment", true, false)
	if old_back: old_back.queue_free()
	var old_arrow = skeleton.find_child("RightHandArrow", true, false)
	if old_arrow: old_arrow.queue_free()

	update_weapon_display()

func set_katana_drawn(drawn: bool) -> void:
	if is_katana_drawn != drawn:
		is_katana_drawn = drawn
		if is_katana_drawn:
			if snd_sword_draw and snd_sword_draw.stream:
				snd_sword_draw.pitch_scale = randf_range(0.96, 1.05)
				snd_sword_draw.play()
		else:
			if snd_sword_sheath and snd_sword_sheath.stream:
				snd_sword_sheath.pitch_scale = randf_range(0.96, 1.05)
				snd_sword_sheath.play()
	else:
		is_katana_drawn = drawn
	update_weapon_display()

func update_weapon_display() -> void:
	if katana_hip_sheath:
		katana_hip_sheath.visible = true
		katana_hip_sheath.mesh = katana_mesh_empty_sheath if is_katana_drawn else katana_mesh_sheathed
	if katana_hand_blade:
		katana_hand_blade.visible = is_katana_drawn
	if katana_hip_sword:
		katana_hip_sword.visible = false

func _setup_input_actions() -> void:
	_add_action_if_missing("move_forward", [KEY_W, KEY_UP])
	_add_action_if_missing("move_backward", [KEY_S, KEY_DOWN])
	_add_action_if_missing("move_back", [KEY_S, KEY_DOWN])
	_add_action_if_missing("move_left", [KEY_A, KEY_LEFT])
	_add_action_if_missing("move_right", [KEY_D, KEY_RIGHT])
	_add_action_if_missing("jump", [KEY_SPACE])
	_add_action_if_missing("sprint", [KEY_SHIFT])
	_add_action_if_missing("jog", [KEY_ALT, KEY_Z])
	_add_action_if_missing("crouch", [KEY_X, KEY_CTRL])
	_add_action_if_missing("roll", [KEY_C])
	_add_action_if_missing("attack", [KEY_F, KEY_J])
	_add_action_if_missing("sword_dash", [KEY_E])
	_add_action_if_missing("block", [KEY_Q])
	_add_action_if_missing("punch", [KEY_V])
	_add_action_if_missing("chop", [KEY_T])
	_add_action_if_missing("toggle_weapon", [KEY_G])

func _add_action_if_missing(act_name: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(act_name):
		InputMap.add_action(act_name)
		for kc in keycodes:
			var ev = InputEventKey.new()
			ev.physical_keycode = kc
			InputMap.action_add_event(act_name, ev)

func _find_skeleton(node: Node) -> Skeleton3D:
	if not node:
		return null
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var res = _find_skeleton(c)
		if res:
			return res
	return null

func _setup_materials() -> void:
	skeleton = _find_skeleton(char_model)
	if not skeleton:
		return
		
	var toon_shader = load("res://shaders/cel_toon_character.gdshader")
	var outline_shader = load("res://shaders/inverted_hull_outline.gdshader")
	
	var mat_dict = {
		"Face": [
			{"tex": "res://assests/3675109917025159411__01.png", "scissor": true, "outline": false},
			{"tex": "res://assests/3675109917025159411__02.png", "scissor": true, "outline": false},
			{"tex": "res://assests/3675109917025159411__03.png", "scissor": true, "outline": false},
			{"tex": "res://assests/3675109917025159411__04.png", "scissor": false, "outline": true},
			{"tex": "res://assests/3675109917025159411__06.png", "scissor": true, "outline": false},
			{"tex": "res://assests/3675109917025159411__07.png", "scissor": true, "outline": false},
			{"tex": "res://assests/3675109917025159411__09.png", "scissor": true, "outline": false},
		],
		"Body": [
			{"tex": "res://assests/3675109917025159411__10.png", "scissor": false, "outline": true},
			{"tex": "res://assests/3675109917025159411__12.png", "scissor": true, "outline": true},
			{"tex": "res://assests/3675109917025159411__13.png", "scissor": false, "outline": true},
			{"tex": "res://assests/3675109917025159411__14.png", "scissor": false, "outline": true},
			{"tex": "res://assests/3675109917025159411__15.png", "scissor": false, "outline": true},
			{"tex": "res://assests/3675109917025159411__16.png", "scissor": false, "outline": true},
		],
		"Hair": [
			{"tex": "res://assests/3675109917025159411__17.png", "scissor": true, "outline": true},
			{"tex": "res://assests/3675109917025159411__19.png", "scissor": true, "outline": true},
			{"tex": "res://assests/3675109917025159411__21.png", "scissor": true, "outline": true},
			{"tex": "res://assests/3675109917025159411__23.png", "scissor": true, "outline": true},
			{"tex": "res://assests/3675109917025159411__25.png", "scissor": true, "outline": true},
			{"tex": "res://assests/3675109917025159411__31.png", "scissor": true, "outline": true},
		]
	}
	
	for m_name in mat_dict.keys():
		var mi = skeleton.find_child(m_name, true, false) as MeshInstance3D
		if mi:
			var info_list = mat_dict[m_name]
			for surf_idx in range(info_list.size()):
				var info = info_list[surf_idx]
				var smat = ShaderMaterial.new()
				smat.shader = toon_shader
				var tex: Texture2D = null
				if mi.mesh and surf_idx < mi.mesh.get_surface_count():
					var orig_mat = mi.mesh.surface_get_material(surf_idx)
					if orig_mat is StandardMaterial3D and orig_mat.albedo_texture:
						tex = orig_mat.albedo_texture
				if not tex and ResourceLoader.exists(info["tex"]):
					tex = load(info["tex"])
				smat.set_shader_parameter("albedo_texture", tex)
				smat.set_shader_parameter("shadow_color", Color(0.6, 0.6, 0.75, 1.0))
				smat.set_shader_parameter("use_alpha_scissor", info["scissor"])
				smat.set_shader_parameter("alpha_scissor_threshold", 0.5)
				
				if info["outline"]:
					var omat = ShaderMaterial.new()
					omat.shader = outline_shader
					omat.set_shader_parameter("outline_color", Color(0.12, 0.10, 0.15, 1.0))
					omat.set_shader_parameter("outline_width", 0.0038)
					omat.set_shader_parameter("use_alpha_scissor", info["scissor"])
					omat.set_shader_parameter("alpha_scissor_threshold", 0.5)
					if info["scissor"]:
						omat.set_shader_parameter("albedo_texture", tex)
					smat.next_pass = omat
				
				mi.set_surface_override_material(surf_idx, smat)

func _setup_skeleton_bones() -> void:
	skeleton = _find_skeleton(char_model)
	if not skeleton:
		return
		
	bone_root = skeleton.find_bone("Root")
	bone_hips = skeleton.find_bone("Hips")
	bone_spine = skeleton.find_bone("Spine")
	bone_chest = skeleton.find_bone("Chest")
	bone_head = skeleton.find_bone("Head")
	bone_r_hand = skeleton.find_bone("RightHand")
	bone_l_hand = skeleton.find_bone("LeftHand")
	
	hair_ponytail_bones.clear()
	for i in range(1, 6):
		var idx = skeleton.find_bone("J_Sec_Hair%d_04" % i)
		if idx != -1:
			hair_ponytail_bones.append(idx)
			
	hair_side_bones.clear()
	for sname in ["J_Sec_Hair1_01", "J_Sec_Hair2_01", "J_Sec_Hair1_02", "J_Sec_Hair2_02"]:
		var idx = skeleton.find_bone(sname)
		if idx != -1:
			hair_side_bones.append(idx)
			
	cloth_skirt_b_l = skeleton.find_bone("J_Sec_L_CoatSkirtBack_01")
	cloth_skirt_b_r = skeleton.find_bone("J_Sec_R_CoatSkirtBack_01")
	
	rest_bone_rotations.clear()
	for b_idx in range(skeleton.get_bone_count()):
		rest_bone_rotations[b_idx] = skeleton.get_bone_rest(b_idx).basis.get_rotation_quaternion()

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
	snd_action = AudioStreamPlayer.new()
	snd_action.volume_db = -2.0
	add_child(snd_action)
	add_child(snd_land)
	
	snd_roll = AudioStreamPlayer.new()
	snd_roll.volume_db = -3.0
	var r_path = "res://sounds/roll.wav"
	if not ResourceLoader.exists(r_path): r_path = "res://Sound effects/freesound_community-landing-on-grass-40650.mp3"
	snd_roll.stream = load(r_path)
	add_child(snd_roll)
	
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
				
	snd_sword_draw = AudioStreamPlayer.new()
	var draw_path = "res://sounds/sword_draw.wav"
	if not ResourceLoader.exists(draw_path): draw_path = "res://Sound effects/dragon-studio-sword-unsheathing-393851.mp3"
	snd_sword_draw.stream = load(draw_path)
	snd_sword_draw.volume_db = -2.0
	add_child(snd_sword_draw)
	
	snd_sword_sheath = AudioStreamPlayer.new()
	var sheath_path = "res://sounds/sword_sheath.wav"
	if not ResourceLoader.exists(sheath_path): sheath_path = "res://Sound effects/voicebosch-sword-sheathed-178549.mp3"
	snd_sword_sheath.stream = load(sheath_path)
	snd_sword_sheath.volume_db = -2.0
	add_child(snd_sword_sheath)
	
	snd_sword_swings.clear()
	for idx in range(1, 4):
		var p_swing = "res://sounds/sword_swing_%d.wav" % idx
		if ResourceLoader.exists(p_swing):
			snd_sword_swings.append(load(p_swing))
	if snd_sword_swings.is_empty():
		var swing_path = "res://Sound effects/oxidvideos-sword-swing-sfx-407574.mp3"
		if ResourceLoader.exists(swing_path):
			snd_sword_swings.append(load(swing_path))
			
	snd_sword_hit = AudioStreamPlayer.new()
	var hit_path = "res://sounds/sword_hit.wav"
	if not ResourceLoader.exists(hit_path): hit_path = "res://Sound effects/musicholder-sword-sound-260274.mp3"
	snd_sword_hit.stream = load(hit_path)
	snd_sword_hit.volume_db = -1.0
	add_child(snd_sword_hit)
	
	snd_wood_chop = AudioStreamPlayer.new()
	var chop_path = "res://sounds/dummy_hit.wav"
	if not ResourceLoader.exists(chop_path): chop_path = "res://sounds/target_hit.wav"
	snd_wood_chop.stream = load(chop_path)
	snd_wood_chop.volume_db = 0.0
	add_child(snd_wood_chop)
	
	snd_swim = AudioStreamPlayer.new()
	var swim_path = "res://sounds/swim_stroke.wav"
	if not ResourceLoader.exists(swim_path): swim_path = "res://Sound effects/freesound_community-waterfall-22627.mp3"
	snd_swim.stream = load(swim_path)
	snd_swim.volume_db = -6.0
	add_child(snd_swim)
	
	snd_splash = AudioStreamPlayer.new()
	var splash_path = "res://sounds/water_splash.wav"
	if not ResourceLoader.exists(splash_path): splash_path = "res://Sound effects/freesound_community-waterfall-22627.mp3"
	snd_splash.stream = load(splash_path)
	snd_splash.volume_db = -4.0
	add_child(snd_splash)
	
	snd_switch = AudioStreamPlayer.new()
	snd_switch.stream = load(draw_path)
	snd_switch.volume_db = -2.0
	add_child(snd_switch)

func _setup_hud() -> void:
	if not hud:
		return
		
	var title = hud.get_node_or_null("InfoPanel/VBox/Title")
	if title is Label:
		title.text = "⚔️ SAMURAI (Katana Master)"
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45, 1.0))
		
	var hint = hud.get_node_or_null("InfoPanel/VBox/Hint")
	if hint is Label:
		hint.text = "KATANA: [L-Click / F]: 3-Hit Combo | [Shift+L-Click / E]: Sword Dash | [R-Click / Q]: Block | [T]: Chop Tree | [G]: Sheath/Draw
WASD: Move | Shift: Sprint | Alt: Jog | Space: Ninja Jump | C: Roll/Slide | X: Crouch
TAB / Button: Switch to Archer | Z: Summon Companion"
		
	var hud_node = hud.get_node_or_null("InfoPanel/VBox/StateLabel")
	if hud_node is Label:
		hud_label = hud_node

	# On-Screen Character Switch Button
	switch_btn = Button.new()
	switch_btn.name = "SwitchCharacterBtn"
	switch_btn.text = "🏹 Switch to Archer (Tab / C)"
	switch_btn.anchors_preset = Control.PRESET_TOP_RIGHT
	switch_btn.anchor_left = 0.72
	switch_btn.anchor_top = 0.025
	switch_btn.anchor_right = 0.98
	switch_btn.anchor_bottom = 0.085
	switch_btn.focus_mode = Control.FOCUS_NONE
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.14, 0.10, 0.92)
	btn_style.border_color = Color(1.0, 0.8, 0.35, 0.95)
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
	btn_hover.bg_color = Color(0.28, 0.22, 0.14, 0.98)
	btn_hover.border_color = Color(1.0, 0.9, 0.5, 1.0)
	switch_btn.add_theme_stylebox_override("hover", btn_hover)
	
	switch_btn.pressed.connect(_on_switch_pressed)
	hud.add_child(switch_btn)
	
	# Companion Summon Button
	summon_btn = Button.new()
	summon_btn.name = "SummonBtn"
	summon_btn.text = "📍 Call Archer to Here (Z)"
	summon_btn.anchors_preset = Control.PRESET_TOP_RIGHT
	summon_btn.anchor_left = 0.72
	summon_btn.anchor_top = 0.095
	summon_btn.anchor_right = 0.98
	summon_btn.anchor_bottom = 0.145
	summon_btn.focus_mode = Control.FOCUS_NONE
	
	var sum_style = StyleBoxFlat.new()
	sum_style.bg_color = Color(0.14, 0.12, 0.10, 0.85)
	sum_style.border_color = Color(0.8, 0.65, 0.3, 0.7)
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

func _on_switch_pressed() -> void:
	switch_to_partner()

func _on_summon_pressed() -> void:
	summon_companion()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active_player:
		return
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-70.0), deg_to_rad(35.0))
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom - 0.35, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom + 0.35, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				else:
					if Input.is_action_pressed("sprint"):
						trigger_sword_dash()
					else:
						trigger_attack("sword")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				trigger_block(true)
			else:
				trigger_block(false)
		get_viewport().set_input_as_handled()
		return
			
	if event is InputEventKey and event.is_echo():
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_TAB:
			switch_to_partner()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_Z:
			summon_companion()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_C and current_state == State.NORMAL and velocity.length_squared() < 0.2:
			switch_to_partner()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_1:
			set_katana_drawn(true)
			sword_stance_timer = 5.0
		elif event.keycode == KEY_F or event.keycode == KEY_J:
			trigger_attack("sword")
		elif event.keycode == KEY_E:
			trigger_sword_dash()
		elif event.keycode == KEY_Q:
			trigger_block(true)
		elif event.keycode == KEY_V:
			trigger_attack("punch")
		elif event.keycode == KEY_T:
			trigger_tree_chopping()
		elif event.keycode == KEY_G:
			set_katana_drawn(not is_katana_drawn)
			sword_stance_timer = 5.0 if is_katana_drawn else 0.0

func _physics_process(delta: float) -> void:
	if sword_stance_timer > 0.0:
		sword_stance_timer -= delta
		if sword_stance_timer <= 0.0 and current_state != State.ATTACKING and current_state != State.BLOCKING:
			set_katana_drawn(false)
			
	if not is_active_player:
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 12.0 * delta)
		move_and_slide()
		_animate_body(delta)
		return
		
	_check_water_level()
	
	if current_state == State.SWIMMING:
		_process_swimming(delta)
		move_and_slide()
		_animate_body(delta)
		_update_camera_rig(delta)
		_update_hud(delta)
		return
		
	match current_state:
		State.NORMAL:
			_process_normal(delta)
		State.CROUCHING:
			_process_crouching(delta)
		State.JUMP_START:
			_process_jump_start(delta)
		State.JUMP_AIR:
			_process_jump_air(delta)
		State.LANDING:
			_process_landing(delta)
		State.ROLLING:
			_process_rolling(delta)
		State.SLIDING:
			_process_sliding(delta)
		State.FLIPPING:
			_process_flipping(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.BLOCKING:
			_process_blocking(delta)
		State.CHOPPING:
			_process_chopping(delta)
		State.HIT_STUN:
			_process_hit_stun(delta)
			
	_apply_step_climb(delta)
	move_and_slide()
	_animate_body(delta)
	_update_camera_rig(delta)
	if snd_grass_breeze and is_active_player:
		var horiz_spd := Vector2(velocity.x, velocity.z).length()
		var target_vol: float = -20.0
		if is_on_floor():
			if horiz_spd < 0.4:
				target_vol = -7.0
			else:
				target_vol = -16.0
		else:
			target_vol = -24.0
		snd_grass_breeze.volume_db = lerpf(snd_grass_breeze.volume_db, target_vol, 2.5 * delta)

	_update_footsteps(delta)
	_update_hud(delta)

func _process_normal(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		current_state = State.JUMP_AIR
		air_time = 0.0
		return
		
	if Input.is_action_just_pressed("jump"):
		current_state = State.JUMP_START
		state_timer = 0.08
		return
		
	if Input.is_action_just_pressed("crouch"):
		current_state = State.CROUCHING
		return
		
	if Input.is_action_just_pressed("roll"):
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if input_dir != Vector2.ZERO:
			current_state = State.ROLLING
			state_timer = 0.55
			var cam_yaw: float = camera_pivot.rotation.y
			var roll_dir := Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, cam_yaw).normalized()
			velocity.x = roll_dir.x * roll_speed
			velocity.z = roll_dir.z * roll_speed
			if snd_roll and snd_roll.stream: snd_roll.play()
			return
			
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_yaw: float = camera_pivot.rotation.y
	
	if input_dir != Vector2.ZERO:
		var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, cam_yaw).normalized()
		var target_spd: float = walk_speed
		
		if Input.is_action_pressed("sprint"):
			target_spd = sprint_speed
		elif Input.is_action_pressed("jog"):
			target_spd = jog_speed
			
		velocity.x = move_dir.x * target_spd
		velocity.z = move_dir.z * target_spd
		
		var target_rot_y := atan2(-move_dir.x, -move_dir.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rot_y, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, 16.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 16.0 * delta)

func _process_crouching(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		current_state = State.JUMP_AIR
		return
	if not Input.is_action_pressed("crouch"):
		current_state = State.NORMAL
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_yaw: float = camera_pivot.rotation.y
	if input_dir != Vector2.ZERO:
		var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, cam_yaw).normalized()
		velocity.x = move_dir.x * crouch_speed
		velocity.z = move_dir.z * crouch_speed
		var target_rot_y := atan2(-move_dir.x, -move_dir.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rot_y, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, 16.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 16.0 * delta)

func _process_jump_start(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		velocity.y = jump_velocity
		current_state = State.JUMP_AIR
		air_time = 0.0
		if snd_jump and snd_jump.stream: snd_jump.play()

func _process_jump_air(delta: float) -> void:
	air_time += delta
	velocity.y -= gravity * delta
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_yaw: float = camera_pivot.rotation.y
	if input_dir != Vector2.ZERO:
		var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, cam_yaw).normalized()
		velocity.x = move_toward(velocity.x, move_dir.x * jog_speed, 10.0 * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * jog_speed, 10.0 * delta)
		var target_rot_y := atan2(-move_dir.x, -move_dir.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rot_y, rotation_speed * delta)
	if is_on_floor() and velocity.y <= 0.0:
		current_state = State.LANDING
		state_timer = 0.12
		landing_squish = 0.2
		if air_time > 0.18 and snd_land and snd_land.stream:
			snd_land.pitch_scale = randf_range(0.95, 1.05)
			snd_land.play()

func _process_landing(delta: float) -> void:
	state_timer -= delta
	velocity.x = move_toward(velocity.x, 0, 16.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 16.0 * delta)
	if state_timer <= 0.0:
		current_state = State.NORMAL

func _process_rolling(delta: float) -> void:
	state_timer -= delta
	if not is_on_floor():
		velocity.y -= gravity * delta
	if state_timer <= 0.0:
		current_state = State.NORMAL

func _process_sliding(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.NORMAL

func _process_flipping(delta: float) -> void:
	state_timer -= delta
	velocity.y -= gravity * delta
	if is_on_floor() and velocity.y <= 0.0:
		current_state = State.LANDING
		state_timer = 0.10

func _process_attacking(delta: float) -> void:
	state_timer -= delta
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	
	# Sword swing hit collision against trees and solid matter
	if attack_type == "sword" and not attack_has_hit and state_timer < 0.48 and state_timer > 0.08:
		var hit = _perform_melee_hit_check(false)
		if not hit.is_empty():
			attack_has_hit = true
			_handle_melee_hit(hit, false)
			
	if state_timer <= 0.0:
		current_state = State.NORMAL
		combo_reset_timer = 1.2

func _process_blocking(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = move_toward(velocity.x, 0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 14.0 * delta)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_action_pressed("block"):
		current_state = State.NORMAL

func _process_chopping(delta: float) -> void:
	state_timer -= delta
	velocity.x = move_toward(velocity.x, 0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 14.0 * delta)
	
	# Tree chopping downswing hit connection (strikes on the heavy downward sweep)
	if not chop_has_hit and state_timer < 0.95 and state_timer > 0.10:
		var hit = _perform_melee_hit_check(true)
		if not hit.is_empty():
			chop_has_hit = true
			_handle_melee_hit(hit, true)
			
	if state_timer <= 0.0:
		current_state = State.NORMAL

func _process_hit_stun(delta: float) -> void:
	state_timer -= delta
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	if state_timer <= 0.0:
		current_state = State.NORMAL

func _process_swimming(delta: float) -> void:
	velocity.y = move_toward(velocity.y, 0, 8.0 * delta)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_yaw: float = camera_pivot.rotation.y
	if input_dir != Vector2.ZERO:
		var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, cam_yaw).normalized()
		velocity.x = move_dir.x * 2.0
		velocity.z = move_dir.z * 2.0
		var target_rot_y := atan2(-move_dir.x, -move_dir.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rot_y, rotation_speed * delta)
		swim_stroke_timer += delta
		if swim_stroke_timer >= 1.2:
			swim_stroke_timer = 0.0
			if snd_swim and snd_swim.stream: snd_swim.play()
	else:
		velocity.x = move_toward(velocity.x, 0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 8.0 * delta)

func _check_water_level() -> void:
	if global_position.y < -0.2:
		if current_state != State.SWIMMING:
			current_state = State.SWIMMING
			if snd_splash and snd_splash.stream: snd_splash.play()
	else:
		if current_state == State.SWIMMING and is_on_floor():
			current_state = State.NORMAL

func trigger_attack(type: String = "sword") -> void:
	if current_state == State.ROLLING or current_state == State.SLIDING or current_state == State.FLIPPING or current_state == State.SWIMMING:
		return
		
	attack_has_hit = false
	attack_type = type
	if type == "sword":
		set_katana_drawn(true)
		sword_stance_timer = 5.0
		if combo_reset_timer <= 0.0 or combo_step >= 3:
			combo_step = 1
		else:
			combo_step += 1
		state_timer = 0.55
		current_state = State.ATTACKING
		
		# Play sword swing sound
		if not snd_sword_swings.is_empty():
			var swing_snd = snd_sword_swings[(combo_step - 1) % snd_sword_swings.size()]
			if snd_action:
				snd_action.stream = swing_snd
				snd_action.pitch_scale = randf_range(0.95, 1.05)
				snd_action.play()
				
		# Forward momentum on sword strikes
		var fwd = -visuals.global_transform.basis.z
		velocity.x = fwd.x * (1.8 if combo_step < 3 else 3.2)
		velocity.z = fwd.z * (1.8 if combo_step < 3 else 3.2)
	else:
		combo_step = 1
		state_timer = 0.45
		current_state = State.ATTACKING

func trigger_sword_dash() -> void:
	if current_state == State.ROLLING or current_state == State.SWIMMING:
		return
	set_katana_drawn(true)
	sword_stance_timer = 5.0
	current_state = State.ATTACKING
	attack_type = "sword"
	attack_has_hit = false
	combo_step = 2
	state_timer = 0.40
	var fwd = -visuals.global_transform.basis.z
	velocity.x = fwd.x * (dash_speed * 1.5)
	velocity.z = fwd.z * (dash_speed * 1.5)
	if not snd_sword_swings.is_empty() and snd_action:
		snd_action.stream = snd_sword_swings[1 % snd_sword_swings.size()]
		snd_action.pitch_scale = 1.15
		snd_action.play()

func trigger_block(start: bool) -> void:
	if start:
		set_katana_drawn(true)
		sword_stance_timer = 5.0
		current_state = State.BLOCKING
	else:
		if current_state == State.BLOCKING:
			current_state = State.NORMAL

func trigger_tree_chopping() -> void:
	set_katana_drawn(true)
	sword_stance_timer = 5.0
	current_state = State.CHOPPING
	state_timer = 1.15
	chop_has_hit = false
	
	var fwd = -visuals.global_transform.basis.z
	velocity.x = fwd.x * 1.5
	velocity.z = fwd.z * 1.5
	if not snd_sword_swings.is_empty() and snd_action:
		snd_action.stream = snd_sword_swings[2 % snd_sword_swings.size()]
		snd_action.pitch_scale = 0.90
		snd_action.play()

func _apply_step_climb(delta: float) -> void:
	if not is_on_floor() or velocity.length_squared() < 0.1:
		return
	if ray_wall and ray_wall.is_colliding() and ray_ledge and not ray_ledge.is_colliding():
		global_position.y += MAX_STEP_HEIGHT * 6.0 * delta

func _animate_body(delta: float) -> void:
	if not anim_player:
		return
		
	var target_anim = ""
	var blend_time = 0.15
	var speed_scale = 1.0
	
	match current_state:
		State.NORMAL:
			var horiz_speed = Vector2(velocity.x, velocity.z).length()
			if horiz_speed > 5.5:
				target_anim = _find_anim("Sprint")
				speed_scale = horiz_speed / 7.0
			elif horiz_speed > 3.0:
				target_anim = _find_anim("Jog_Fwd")
				speed_scale = horiz_speed / 4.5
			elif horiz_speed > 0.3:
				target_anim = _find_anim("Walk")
				speed_scale = horiz_speed / 2.3
			else:
				if is_katana_drawn:
					target_anim = _find_anim("Sword_Idle")
					if target_anim == "": target_anim = _find_anim("Idle")
				else:
					target_anim = _find_anim("Idle")
					
		State.CROUCHING:
			var horiz_speed = Vector2(velocity.x, velocity.z).length()
			target_anim = _find_anim("Crouch_Fwd") if horiz_speed > 0.3 else _find_anim("Crouch_Idle")
			
		State.JUMP_START:
			target_anim = _find_anim("Jump_Start")
			blend_time = 0.05
			
		State.JUMP_AIR:
			target_anim = _find_anim("Jump")
			if target_anim == "": target_anim = _find_anim("NinjaJump_Idle")
			blend_time = 0.10
			
		State.LANDING:
			target_anim = _find_anim("Jump_Land")
			blend_time = 0.05
			
		State.ROLLING:
			target_anim = _find_anim("Roll")
			blend_time = 0.05
			speed_scale = 1.2
			
		State.ATTACKING:
			if attack_type == "sword":
				if combo_step == 1:
					target_anim = "A2/Armature|Armature|Sword_Regular_A"
					speed_scale = 1.45
				elif combo_step == 2:
					target_anim = "A2/Armature|Armature|Sword_Regular_B"
					speed_scale = 1.45
				else:
					target_anim = "A2/Armature|Armature|Sword_Regular_C"
					speed_scale = 1.6
			else:
				target_anim = _find_anim("Punch")
			blend_time = 0.05
			
		State.BLOCKING:
			target_anim = _find_anim("Sword_Block")
			blend_time = 0.10
			
		State.CHOPPING:
			target_anim = _find_anim("TreeChopping")
			blend_time = 0.15
			speed_scale = 1.15

	if target_anim != "" and anim_player.has_animation(target_anim):
		if anim_player.current_animation != target_anim:
			anim_player.play(target_anim, blend_time)
		anim_player.speed_scale = speed_scale

	# Secondary procedural physics: ponytail and coat skirt reactive flutter
	var is_moving = Vector2(velocity.x, velocity.z).length() > 0.2
	var is_sprinting = Input.is_action_pressed("sprint") and is_moving
	walk_cycle += delta * (11.0 if is_sprinting else (7.0 if is_moving else 2.0))
	
	var hair_pitch = deg_to_rad(-24.0 if is_sprinting else (-10.0 if is_moving else 0.0)) + sin(walk_cycle * 2.0) * deg_to_rad(6.5 if is_moving else 2.5)
	for h in hair_ponytail_bones:
		_set_bone_delta(h, Quaternion(Vector3(1, 0, 0), hair_pitch) * Quaternion(Vector3(0, 0, 1), sin(walk_cycle) * deg_to_rad(3.0)))
	for b in hair_side_bones:
		_set_bone_delta(b, Quaternion(Vector3(1, 0, 0), deg_to_rad(-6.0) if is_moving else 0.0))
		
	var skirt_back = deg_to_rad(-16.0 if is_sprinting else (-6.0 if is_moving else 0.0)) + sin(walk_cycle * 2.0) * deg_to_rad(5.0 if is_moving else 1.5)
	_set_bone_delta(cloth_skirt_b_l, Quaternion(Vector3(1, 0, 0), skirt_back))
	_set_bone_delta(cloth_skirt_b_r, Quaternion(Vector3(1, 0, 0), skirt_back))
	
	if bone_root != -1:
		skeleton.set_bone_pose_position(bone_root, Vector3.ZERO)
		
	skeleton.force_update_all_bone_transforms()

func _set_bone_delta(bone_idx: int, rot_delta: Quaternion) -> void:
	if bone_idx != -1 and skeleton:
		var rest_q = rest_bone_rotations.get(bone_idx, Quaternion.IDENTITY)
		skeleton.set_bone_pose_rotation(bone_idx, rest_q * rot_delta)

func _update_camera_rig(delta: float) -> void:
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var speed_ratio := clampf(horiz_speed / sprint_speed, 0.0, 1.2)
	
	var target_len := target_zoom + speed_ratio * 0.85
	var target_pivot_y := 1.45
	var target_pivot_x := 0.0
	var target_pivot_z := 0.0
	var target_fov := 72.0
	
	if current_state == State.CROUCHING:
		target_pivot_y = 1.0
	elif current_state == State.ROLLING or current_state == State.SLIDING:
		target_len *= 0.85
		target_pivot_y = 1.15
	elif current_state == State.FLIPPING:
		target_pivot_y = 1.65
	elif current_state == State.ATTACKING or current_state == State.BLOCKING:
		target_len *= 0.95
			
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_len, 14.0 * delta)
	camera.fov = lerp(camera.fov, target_fov, 12.0 * delta)
	camera_pivot.position.y = lerp(camera_pivot.position.y, target_pivot_y, 14.0 * delta)
	camera_pivot.position.x = lerp(camera_pivot.position.x, target_pivot_x, 14.0 * delta)
	camera_pivot.position.z = lerp(camera_pivot.position.z, target_pivot_z, 14.0 * delta)
	
	if screen_shake_amount > 0.0:
		camera.h_offset = randf_range(-screen_shake_amount, screen_shake_amount)
		camera.v_offset = randf_range(-screen_shake_amount, screen_shake_amount)
		screen_shake_amount = move_toward(screen_shake_amount, 0.0, 0.35 * delta)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func _update_footsteps(delta: float) -> void:
	if not is_on_floor() or current_state == State.ROLLING or current_state == State.SLIDING or current_state == State.FLIPPING or current_state == State.CROUCHING:
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

func _update_hud(delta: float) -> void:
	if not hud_label:
		return
		
	var state_names = [
		"NORMAL", "CROUCHING", "JUMP_START", "JUMP_AIR", "LANDING", 
		"ROLLING", "SLIDING", "FLIPPING", "ATTACKING", "BLOCKING", "CHOPPING",
		"SWIMMING", "HIT_STUN"
	]
	var st = state_names[current_state] if current_state < state_names.size() else "UNKNOWN"
	var horiz_spd = Vector2(velocity.x, velocity.z).length()
	var weapon_str = "KATANA [DRAWN]" if is_katana_drawn else "KATANA [SHEATHED]"
			
	var wood_str = " | 🪵 Wood: %d" % chopped_wood_count if chopped_wood_count > 0 else ""
	hud_label.text = "State: [%s] | Speed: %.1f m/s | HP: %d/100 | Weapon: %s%s | Camera: %.1fm" % [
		st, horiz_spd, int(player_health), weapon_str, wood_str, spring_arm.spring_length
	]

# ---------------------------------------------------------
# SWORD COLLISION & TREE CHOPPING COMBAT SYSTEM
# ---------------------------------------------------------

func _is_tree_collider(col: Node) -> bool:
	if not col:
		return false
	var n_name = col.name.to_lower()
	if "tree" in n_name or "birch" in n_name:
		return true
	var p = col.get_parent()
	while p and p != get_tree().root:
		var p_name = p.name.to_lower()
		if "tree" in p_name or "birch" in p_name or "foliage" in p_name or "woodrise" in p_name:
			return true
		p = p.get_parent()
	return false

func _perform_melee_hit_check(is_chopping: bool = false) -> Dictionary:
	var space = get_world_3d().direct_space_state
	if not space:
		return {}
		
	var from = global_position + Vector3(0, 1.05, 0)
	var fwd = -visuals.global_transform.basis.z.normalized()
	var right = visuals.global_transform.basis.x.normalized()
	
	var reach = 2.2 if is_chopping else 2.0
	var check_rays: Array[Vector3] = [
		fwd * reach,
		(fwd + right * 0.45).normalized() * (reach * 0.95),
		(fwd - right * 0.45).normalized() * (reach * 0.95),
		(fwd + Vector3(0, -0.35, 0)).normalized() * (reach * 0.9),
		(fwd + Vector3(0, 0.25, 0)).normalized() * (reach * 0.9)
	]
	
	var exclude_rids = [get_rid()]
	if is_inside_tree():
		for c in get_tree().get_nodes_in_group("player_characters"):
			if c is CollisionObject3D:
				exclude_rids.append(c.get_rid())
		
	# 1. Cast rays across the swing arc
	for ray_dir in check_rays:
		var q = PhysicsRayQueryParameters3D.create(from, from + ray_dir)
		q.exclude = exclude_rids
		var res = space.intersect_ray(q)
		if not res.is_empty() and res.collider:
			return res
			
	# 2. Sphere sweep check in front of character (covers wide obstacles)
	var shape_q = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.55
	shape_q.shape = sphere
	shape_q.transform = Transform3D(Basis(), from + fwd * 1.15)
	shape_q.exclude = exclude_rids
	var shape_results = space.intersect_shape(shape_q, 4)
	for s_res in shape_results:
		if s_res.collider:
			return {
				"collider": s_res.collider,
				"position": from + fwd * 1.15,
				"normal": -fwd
			}
			
	return {}

func _handle_melee_hit(hit: Dictionary, is_chopping: bool) -> void:
	var col = hit.get("collider", null)
	var hit_pos: Vector3 = hit.get("position", global_position + -visuals.global_transform.basis.z * 1.2 + Vector3(0, 1.0, 0))
	var is_tree = _is_tree_collider(col)
	
	if is_tree:
		chopped_wood_count += 1
		# Layered wood chop impact + steel blade bite sound
		if snd_wood_chop:
			snd_wood_chop.pitch_scale = randf_range(0.92, 1.08)
			snd_wood_chop.play()
		if snd_sword_hit:
			snd_sword_hit.pitch_scale = randf_range(1.10, 1.25)
			snd_sword_hit.play()
			
		_spawn_impact_particles(hit_pos, true)
		_shake_tree(col)
		screen_shake_amount = 0.06 if is_chopping else 0.04
		
		var msg = "🪵 +1 Wood Chopped!" if is_chopping else "🪵 Tree Struck!"
		_spawn_hit_billboard(hit_pos, msg, Color(0.96, 0.82, 0.45))
	else:
		# Solid matter impact (rocks, stone, terrain, structures)
		if snd_sword_hit:
			snd_sword_hit.pitch_scale = randf_range(0.95, 1.12)
			snd_sword_hit.play()
			
		_spawn_impact_particles(hit_pos, false)
		screen_shake_amount = 0.04
		_spawn_hit_billboard(hit_pos, "⚔️ Clang!", Color(1.0, 0.88, 0.35))

func _shake_tree(col: Node) -> void:
	var target_node = col
	if col.get_parent() and col.get_parent() is Node3D and col.get_parent() != get_tree().root:
		target_node = col.get_parent()
	if not (target_node is Node3D):
		return
		
	var orig_rot = target_node.rotation
	var tween = create_tween()
	var shake_axis = Vector3(randf_range(-0.035, 0.035), 0.0, randf_range(-0.035, 0.035))
	tween.tween_property(target_node, "rotation", orig_rot + shake_axis, 0.06).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target_node, "rotation", orig_rot - shake_axis * 0.5, 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target_node, "rotation", orig_rot, 0.10).set_trans(Tween.TRANS_SINE)

func _spawn_impact_particles(pos: Vector3, is_wood: bool) -> void:
	var parts = CPUParticles3D.new()
	parts.top_level = true
	var parent_node = get_parent() if get_parent() else self
	parent_node.add_child(parts)
	parts.global_position = pos
	parts.emitting = true
	parts.one_shot = true
	parts.explosiveness = 0.95
	parts.lifetime = 0.45
	parts.amount = 16 if is_wood else 12
	parts.direction = Vector3.UP + Vector3(randf_range(-0.5, 0.5), randf_range(0.3, 0.9), randf_range(-0.5, 0.5)).normalized()
	parts.spread = 45.0
	parts.initial_velocity_min = 2.0
	parts.initial_velocity_max = 4.2
	parts.gravity = Vector3(0, -9.8, 0)
	
	var p_mesh = BoxMesh.new()
	var mat = StandardMaterial3D.new()
	if is_wood:
		p_mesh.size = Vector3(0.04, 0.08, 0.03) # Wood splinter
		mat.albedo_color = Color(0.55, 0.38, 0.22)
	else:
		p_mesh.size = Vector3(0.025, 0.025, 0.06) # Spark
		mat.albedo_color = Color(1.0, 0.85, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mesh.material = mat
	parts.mesh = p_mesh
	
	var timer = get_tree().create_timer(0.65)
	timer.timeout.connect(parts.queue_free)

func _spawn_hit_billboard(pos: Vector3, txt: String, col: Color) -> void:
	var lbl = Label3D.new()
	lbl.text = txt
	lbl.modulate = col
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	lbl.outline_render_priority = 1
	lbl.font_size = 38
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	var parent_node = get_parent() if get_parent() else self
	parent_node.add_child(lbl)
	lbl.global_position = pos + Vector3(0, 0.45, 0)
	
	var tw = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 0.85, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)
