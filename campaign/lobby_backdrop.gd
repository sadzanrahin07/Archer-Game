extends RefCounted
# Keep the familiar campsite, lake and waterfall; omit distant playable areas.
static func prepare(scene:Node3D) -> void:
	for path in ["WindriseSacredTree","ScenicCherryHilltop","ArcheryShootingRanges"]:
		var distant:=scene.get_node_or_null(path)
		if distant:scene.remove_child(distant);distant.free()
	for body in scene.find_children("*","CollisionObject3D",true,false):
		body.collision_layer=0;body.collision_mask=0
	for audio in scene.find_children("*","AudioStreamPlayer3D",true,false):
		audio.stop()
	# The lobby camera stays at the campsite. Keep only nearby foliage instances.
	for node in scene.find_children("*","MultiMeshInstance3D",true,false):
		var source:MultiMesh=node.multimesh
		if source==null or source.transform_format!=MultiMesh.TRANSFORM_3D:continue
		var keep:Array[int]=[]
		for i in range(source.instance_count):
			var world:Vector3=node.global_transform*source.get_instance_transform(i).origin
			if world.z<24 and world.z> -70 and absf(world.x)<65:
				keep.append(i)
		var cropped:=MultiMesh.new()
		cropped.transform_format=MultiMesh.TRANSFORM_3D
		cropped.use_colors=source.use_colors;cropped.use_custom_data=source.use_custom_data
		cropped.mesh=source.mesh;cropped.instance_count=keep.size()
		for i in range(keep.size()):
			cropped.set_instance_transform(i,source.get_instance_transform(keep[i]))
			if source.use_colors:cropped.set_instance_color(i,source.get_instance_color(keep[i]))
			if source.use_custom_data:cropped.set_instance_custom_data(i,source.get_instance_custom_data(keep[i]))
		node.multimesh=cropped
