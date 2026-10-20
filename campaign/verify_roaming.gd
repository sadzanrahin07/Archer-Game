extends SceneTree
class CourseGame extends Node3D:
	var hero:CharacterBody3D
	var playing:=false
	func is_playing() -> bool:return playing
	func target_scored(_zone:int,_damage:float,_destructible:bool) -> void:pass
	func target_completed(_index:int) -> void:pass
	func feedback(_text:String) -> void:pass
class Walker extends CharacterBody3D:
	var destination:=Vector3.ZERO
	var walking:=false
	var distance_walked:=0.0
	func _ready() -> void:
		collision_layer=2;collision_mask=1;floor_snap_length=.4;floor_max_angle=deg_to_rad(55)
		var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.28;capsule.height=1.55
		shape.shape=capsule;shape.position.y=.775;add_child(shape)
	func _physics_process(delta:float) -> void:
		var from:=position
		var offset:=destination-position;offset.y=0
		var step:=offset.normalized()*minf(6.8,offset.length()/delta) if walking and offset.length()>.03 else Vector3.ZERO
		velocity.x=step.x;velocity.z=step.z;velocity.y=-.2 if is_on_floor() else velocity.y-9.8*delta
		move_and_slide();distance_walked+=Vector2(position.x-from.x,position.z-from.z).length()
var errors:Array[String]=[]
func check(value:bool,message:String) -> void:
	if not value:errors.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	Engine.time_scale=12
	var definitions:Array=JSON.parse_string(FileAccess.get_file_as_string('res://campaign/stages.json'))
	var game:=CourseGame.new();root.add_child(game)
	var body:=Walker.new();game.add_child(body);game.hero=body
	var total_distance:=0.0;var built:=0;var probed:=0
	for index in range(30,100,5):
		var d:Dictionary=definitions[index+4]
		var stage=load(d.scene).instantiate();game.add_child(stage);stage.build(game,d)
		body.position=stage.spawn;body.velocity=Vector3.ZERO;body.distance_walked=0;body.walking=false
		for frame in range(4):await physics_frame
		for x in [-stage.safe_bounds.size.x*.4,0,stage.safe_bounds.size.x*.4]:
			for z in [stage.spawn.z,(stage.spawn.z+stage.endpoint.z)*.5,stage.endpoint.z]:
				var query:=PhysicsRayQueryParameters3D.create(Vector3(x,12,z),Vector3(x,3,z),1)
				var hit:Dictionary=stage.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty() and absf(hit.position.y-5.68)<.01,'Ground exists across roaming field %d'%int(d.id));probed+=1
		body.walking=true
		for target in stage.targets:
			var waypoint:Vector3=target.global_position;waypoint.y=stage.spawn.y
			body.destination=waypoint
			var frames:=0
			while Vector2(body.position.x-waypoint.x,body.position.z-waypoint.z).length()>.12 and frames<180:
				await physics_frame;frames+=1
				check(body.position.y>5.60 and body.position.y<5.80,'Walking stays on course floor %d'%int(d.id))
			check(frames<180,'Walking reaches target clearing %d'%int(d.id))
		body.walking=false;game.playing=true
		var final=stage.targets.back();final.set_active(true)
		check(final.can_receive_hit(),'Walked route reaches final stone seal %d'%int(d.id));game.playing=false
		check(body.distance_walked>=float(d.route_length)*.95,'Full route traversed %d'%int(d.id))
		total_distance+=body.distance_walked;built+=1
		print('Walked chapter ',d.chapter_number,' ',snappedf(body.distance_walked,.1),'m; final HP ',final.max_hp,'; advised power ',d.recommended_power)
		game.remove_child(stage);stage.free()
	game.free();print('ROAMING WALK VERIFICATION ', 'PASS' if errors.is_empty() else 'FAIL',' · ',built,' chapters / ',probed,' floor probes / ',snappedf(total_distance,.1),'m / ',errors.size(),' failures');quit(0 if errors.is_empty() else 1)
