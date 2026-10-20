extends SceneTree

class CourseGame extends Node3D:
	var hero:Node3D
	var completed_indices:Array[int]=[]
	var scores:=0
	var state:="playing"
	func is_playing() -> bool:return state=="playing"
	func target_scored(_zone:int,_damage:float,_destructible:bool) -> void:scores+=1
	func target_completed(index:int) -> void:completed_indices.append(index)
	func feedback(_text:String) -> void:pass

var failures:Array[String]=[]
func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error(message)

func _initialize() -> void:run.call_deferred()
func run() -> void:
	var definitions:Array=JSON.parse_string(FileAccess.get_file_as_string("res://campaign/stages.json"))
	check(definitions.size()==100,"100 stage definitions")
	var game:=CourseGame.new();root.add_child(game)
	game.hero=Node3D.new();game.add_child(game.hero)
	var tested:=0;var stones:=0
	for d in definitions:
		var scene=load(d.scene);check(scene is PackedScene,"Stage scene missing %d"%int(d.id))
		var stage=scene.instantiate();game.add_child(stage);stage.build(game,d)
		game.hero.position=stage.spawn
		check(stage.targets.size()==d.materials.size(),"Target count %d"%int(d.id))
		check(stage.safe_bounds.has_point(Vector2(stage.spawn.x,stage.spawn.z)),"Spawn on floor %d"%int(d.id))
		var grass_count:=0;var grass_chunks:=0
		for child in stage.get_children():
			if child is MultiMeshInstance3D and str(child.name).begins_with("MapGrassShort_"):
				grass_count+=child.multimesh.instance_count;grass_chunks+=1
		check(grass_count>1000 and grass_chunks>1,"Dense spatially culled grass %d"%int(d.id))
		await physics_frame
		for target in stage.targets:
			check(target.hp==target.max_hp and target.hp>0,"Valid HP %d"%int(d.id))
			if target.material_kind in ["stone","rune","master"]:
				stones+=1
				check(target.body_mesh.name=="FacetedMonolith","Custom stone visual")
				var origin:Vector3=target.global_position+Vector3(0,0,4)
				var query:=PhysicsRayQueryParameters3D.create(origin,origin-Vector3(0,0,8),4)
				var hit:Dictionary=target.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty() and hit.collider==target,"Monolith physical collider %d"%int(d.id))
		if d.roaming:
			var final=stage.targets.back()
			check(final.final_stone and final.material_kind in ["stone","rune","master"],"Final endpoint stone %d"%int(d.id))
			final.set_active(true)
			check(not final.can_receive_hit(),"Approach required %d"%int(d.id))
			game.hero.position=stage.endpoint
			check(final.can_receive_hit(),"Approach allowed %d"%int(d.id))
			var hp:float=final.hp;var count_before:int=game.scores
			check(final.campaign_hit(final.global_position+Vector3(0,0,.45),1,{"shot_id":771}),"Primary accepted")
			var after:float=final.hp
			check(after<hp,"Damage applied")
			check(not final.campaign_hit(final.global_position,1,{"shot_id":771}),"Duplicate shot rejected")
			check(final.hp==after and game.scores==count_before+1,"Duplicate score avoided")
		if int(d.chapter_number)==1:
			check(d.seconds==10 and float(d.distance)==5*(int(d.stage_number)),"First five ranges")
		tested+=1
		game.remove_child(stage);stage.free()
		if tested%10==0:print("Verified stages ",tested)
	game.free()
	print("SCENERY VERIFICATION ","PASS" if failures.is_empty() else "FAIL"," · ",tested," stages / ",stones," physical custom stones / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
