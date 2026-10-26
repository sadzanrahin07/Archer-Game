extends SceneTree
var game:Node
func _initialize():run.call_deferred()
func aim_at(p:Node3D,point:Vector3) -> void:
 for i in range(18):
  var direction:Vector3=(point-p.camera.global_position).normalized()
  p.yaw=atan2(-direction.x,-direction.z);p.pitch=asin(direction.y)
  await physics_frame
func run():
 game=load("res://campaign/main.tscn").instantiate();game.test_mode=true;game.profile.save_path="/tmp/archer_aim_alignment_qa.json"
 root.add_child(game);await process_frame
 game.profile.data.owned_characters=[0,1,2,3];game.profile.data.owned_costumes=[0,1,2,3,4,5]
 for character in range(4):
  game.profile.data.character=character;game.profile.data.costume=2;game._spawn_hero();game.start_stage(5,true)
  game.ready_left=0;game.state="playing"
  # Isolate aim calibration from the course's timed folding-target mechanics.
  for target in game.stage.targets:
   target.moving=false;target.is_rising=false;target.set_process(false);target.set_physics_process(false)
   if is_instance_valid(target.board_pivot):target.board_pivot.rotation.x=0;target._sync_board_collider()
  var p=game.hero;p.aim_held=true
  for target in game.stage.targets:
   game.arrows=20;p.shot_cooldown=0;p.drawing=true;p.draw_elapsed=game.profile.draw_time()
   var point:Vector3=target.global_position+Vector3(0,0,.2)
   await aim_at(p,point)
   assert(p.aim_target_world().distance_to(point)<.8,"Reticle must point at target")
   p._update_equipment()
   var visible_direction:Vector3=p.arrow_direction
   var origin:Vector3=p.nock_world
   var before_fov:float=p.camera.fov
   p._fire()
   assert((p.last_shot_origin-p.last_shot_direction*.72).distance_to(origin)<.04,"The flying arrow tail must preserve the drawn nock position")
   assert(p.last_shot_direction.dot(visible_direction)>.995,"Nocked arrow must agree with flight")
   for i in range(180):
    await physics_frame
    if target.completed:break
   assert(target.completed,"Real controller yaw/pitch must hit the reticle target for character "+str(character))
   assert(absf(p.camera.fov-before_fov)<3,"Release must preserve aim framing")
  print("CONTROLLER AIM + NOCK + REAL SIX-TARGET HITS PASS: ",character)
  game.start_stage(0,true);game.ready_left=0;game.state="playing"
  p=game.hero;p.aim_held=false
  var quick_target:Node3D=game.stage.targets[0]
  await aim_at(p,quick_target.global_position+Vector3(0,0,.2))
  p.instant_shoot()
  assert(p.aim_release_left==0,"Hip shots must not force a camera zoom")
  for i in range(180):
   await physics_frame
   if quick_target.completed:break
  assert(quick_target.completed,"Quick shots must fire from the release pose toward the reticle")
  print("QUICK SHOT ALIGNMENT PASS: ",character)
 var p=game.hero
 for distance in [4.0,20.0,45.0]:
  for wind in [-3.0,0.0,3.0]:
   var origin:=Vector3(1,2,0);var target:=Vector3(-2,3,-distance);var acceleration:=Vector3(wind,-9.8,0)
   var velocity:Vector3=p.solve_shot_velocity(origin,target,50,acceleration,true)
   var flight:float=(target.z-origin.z)/velocity.z
   assert((origin+velocity*flight+.5*acceleration*flight*flight).distance_to(target)<.002,"Ballistics must compensate gravity and crosswind")
 var straight:Vector3=p.solve_shot_velocity(Vector3.ZERO,Vector3(0,0,-20),50,Vector3(3,-9.8,0),false)
 assert(straight.is_equal_approx(Vector3(0,0,-50)),"Assist off must retain manual ballistics")
 # Shoulder offset follows yaw instead of staying fixed in world space.
 game.state="playing";game.arrows=10;p.aim_held=true;p.yaw=PI*.5;p.pitch=0
 for i in range(45):await physics_frame
 var local_shoulder:Vector3=p.camera_pivot.position.rotated(Vector3.UP,-p.yaw)
 assert(absf(local_shoulder.x-.68)<.02 and absf(local_shoulder.z)<.02)
 print("WIND + GRAVITY + MANUAL BALLISTICS + TURNING SHOULDER PASS")
 p._update_equipment()
 var direction:Vector3=-p.camera.global_basis.z
 var clear_origin:Vector3=p.nock_world+direction*.72
 var wall:=StaticBody3D.new();wall.collision_layer=1
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3.ONE*.18;shape.shape=box;wall.add_child(shape)
 game.stage.add_child(wall);wall.global_position=p.camera.global_position.lerp(clear_origin,.65)
 await physics_frame;await physics_frame
 var safe_origin:Vector3=p.shot_spawn(direction)
 assert(safe_origin.distance_to(clear_origin)>.05,"Nearby cover must move the spawn out of geometry")
 assert(safe_origin.distance_to(p.camera.global_position)<clear_origin.distance_to(p.camera.global_position),"Arrow must start on the camera side of nearby cover")
 wall.queue_free()
 print("NEARBY COVER SPAWN OCCLUSION PASS")
 await create_timer(1.7).timeout
 game.stop_audio();game.queue_free();await process_frame;await process_frame
 print("AIM ALIGNMENT REGRESSION PASS");quit()
