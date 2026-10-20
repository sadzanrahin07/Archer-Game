extends SkeletonModifier3D
class_name AimPitchModifier

var archer: CharacterBody3D = null

var bone_spine: int = -1
var bone_chest: int = -1
var bone_upper_chest: int = -1
var bone_l_upper_arm: int = -1
var bone_r_upper_arm: int = -1

func _ready() -> void:
	var skel = get_skeleton()
	if skel:
		bone_spine = skel.find_bone("J_Bip_C_Spine")
		bone_chest = skel.find_bone("J_Bip_C_Chest")
		bone_upper_chest = skel.find_bone("J_Bip_C_UpperChest")
		bone_l_upper_arm = skel.find_bone("J_Bip_L_UpperArm")
		bone_r_upper_arm = skel.find_bone("J_Bip_R_UpperArm")

func _process_modification() -> void:
	if not archer or not is_instance_valid(archer):
		return
	var skel = get_skeleton()
	if not skel:
		return
		
	if archer.current_state != archer.State.BOW_AIM and archer.current_state != archer.State.BOW_SHOOT:
		return
		
	var pitch: float = archer.current_spine_pitch
	if abs(pitch) < 0.0001:
		return
		
	# Upper torso pitch (negative sign tilts up when looking up in Godot VRoid coordinate space)
	var q_s = Quaternion(Vector3(-1, 0, 0), pitch * 0.30)
	var q_c = Quaternion(Vector3(-1, 0, 0), pitch * 0.35)
	var q_uc = Quaternion(Vector3(-1, 0, 0), pitch * 0.35)
	
	if bone_spine >= 0:
		var cur = skel.get_bone_pose_rotation(bone_spine)
		skel.set_bone_pose_rotation(bone_spine, cur * q_s)
	if bone_chest >= 0:
		var cur = skel.get_bone_pose_rotation(bone_chest)
		skel.set_bone_pose_rotation(bone_chest, cur * q_c)
	if bone_upper_chest >= 0:
		var cur = skel.get_bone_pose_rotation(bone_upper_chest)
		skel.set_bone_pose_rotation(bone_upper_chest, cur * q_uc)
		
	# Left arm holding bow tilts up/down in unison
	if not (archer and archer.is_samurai) and bone_l_upper_arm >= 0:
		var cur_l = skel.get_bone_pose_rotation(bone_l_upper_arm)
		var q_arm = Quaternion(Vector3(0, 0, 1), pitch * 0.40)
		skel.set_bone_pose_rotation(bone_l_upper_arm, cur_l * q_arm)
