extends SkeletonModifier3D
var player: CharacterBody3D
func _process_modification() -> void:
	if not is_instance_valid(player):return
	if player.character_id==2 or (player.character_id==0 and player.showcase):
		var rig:Skeleton3D=get_skeleton()
		var left:int=rig.find_bone(player.bone_names.get("leftFoot","LeftFoot"));var right:int=rig.find_bone(player.bone_names.get("rightFoot","RightFoot"));var hips:int=rig.find_bone(player.bone_names.get("hips","Hips"))
		if left>=0 and right>=0 and hips>=0:
			var foot:float=minf(rig.get_bone_global_pose(left).origin.y,rig.get_bone_global_pose(right).origin.y)
			var sole:float=minf(rig.get_bone_global_rest(left).origin.y,rig.get_bone_global_rest(right).origin.y)
			var hip:Transform3D=rig.get_bone_global_pose(hips);hip.origin.y-=clampf(foot-sole,-.25,.30);rig.set_bone_global_pose(hips,hip)
	if player.showcase or player.aim_blend<0.01:return
	var skeleton:=get_skeleton()
	var bone:=skeleton.find_bone("Chest")
	if bone<0:return
	var pose:=skeleton.get_bone_global_pose(bone)
	var axis:Vector3=skeleton.global_basis.inverse()*player.visuals.global_basis.x
	var turn:=Basis(axis.normalized(),player.pitch*player.aim_blend)
	if player.drawing or player.aim_held or player.touch_aim:
		var left:=skeleton.get_bone_global_pose(player.left_hand)
		var middle:=skeleton.find_bone("LeftMiddleProximal")
		var grip:Vector3=left.origin.lerp(skeleton.get_bone_global_pose(middle).origin,0.55) if middle>=0 else left.origin
		var right:=skeleton.get_bone_global_pose(player.right_finger if player.right_finger>=0 else player.right_hand)
		var vector:Vector3=grip-right.origin
		var from:Vector3=vector.normalized()
		var desired:Vector3=(skeleton.global_basis.inverse()*(-player.camera.global_basis.z)).normalized()
		var up:Vector3=(skeleton.global_basis.inverse()*Vector3.UP).normalized()
		var lift:float=desired.dot(up)*0.035
		var distance:float=lift+sqrt(maxf(0,vector.length_squared()-0.035*0.035+lift*lift))
		var to:Vector3=(desired*distance-up*0.035).normalized()
		var fraction:float=clampf(player.draw_elapsed/player.game.profile.draw_time(),0,1) if player.drawing else 1.0
		turn=Basis(Quaternion.IDENTITY.slerp(Quaternion(from,to),player.aim_blend*fraction))
	pose.basis=turn*pose.basis
	skeleton.set_bone_global_pose(bone,pose)
