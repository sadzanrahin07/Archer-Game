extends SceneTree
const Scene=preload("res://campaign/main.tscn")
var game:Node3D
var hero:CharacterBody3D
var failures:Array[String]=[]
func check(ok:bool,message:String) -> void:
 if not ok:failures.append(message);push_error(message)
func _init() -> void:run.call_deferred()
func step(frames:int) -> void:
 for frame in range(frames):
  await physics_frame
  hero._physics_process(1.0/60)
func run() -> void:
 root.size=Vector2i(1280,720)
 game=Scene.instantiate();game.test_mode=true;root.add_child(game);await process_frame
 game.profile.data.bow_level=100;game.profile.data.arrow_level=100;game.profile.data.character_level=100
 game.start_stage(55,true);game.state="playing";game.set_process(false);game.stage.combat_manager.set_physics_process(false)
 for enemy in game.stage.combat_manager.enemies_alive:enemy.set_physics_process(false)
 hero=game.hero;hero.set_physics_process(false)
 await step(8)
 check(hero.is_on_floor(),"Real course floor grounds the player")
 game.arrows=0;hero.touch_move=Vector2(0,-1)
 var origin:Vector3=hero.global_position
 await step(20)
 check(hero.global_position.distance_to(origin)>.8,"Empty-quiver movement traverses the real course")
 check(hero.last_pose=="walk" and hero.anim_player.current_animation_position>.12,"Empty quiver lets the walking clip advance instead of restarting idle")
 var clip:float=hero.anim_player.current_animation_position;hero.clear_empty_aim()
 check(hero.last_pose=="walk" and is_equal_approx(hero.anim_player.current_animation_position,clip),"Repeated empty checks preserve the active gait")
 game.arrows=12;hero.shot_cooldown=0;hero._start_draw()
 await step(8)
 check(hero.last_pose=="draw_walk","Combat power drawing keeps an authored moving gait")
 await step(60)
 check(hero.last_pose=="aim_walk" and hero.anim_player.current_animation_position>.05,"Fully drawn combat strafe keeps the legs animated")
 hero.cancel_draw();game.arrows=0
 hero.touch_move=Vector2.ZERO;await step(2)
 var floor_y:float=hero.global_position.y
 Input.action_press("jump")
 var apex:float=floor_y;var airborne:=false;var saw_start:=false;var saw_fall:=false;var saw_land:=false;var launches:=0;var was_rising:=false
 for frame in range(95):
  await step(1)
  apex=maxf(apex,hero.global_position.y)
  airborne=airborne or not hero.is_on_floor()
  saw_start=saw_start or hero.last_pose=="jump_start"
  saw_fall=saw_fall or hero.last_pose=="fall"
  saw_land=saw_land or hero.last_pose=="land"
  if hero.velocity.y>1 and not was_rising:launches+=1
  was_rising=hero.velocity.y>1
 Input.action_release("jump")
 check(airborne and apex>floor_y+.75 and apex<floor_y+1.3,"Space creates a bounded physical jump and apex")
 check(hero.is_on_floor() and absf(hero.global_position.y-floor_y)<.06,"Jump returns to the actual ground")
 check(saw_start and saw_fall and saw_land,"Authored takeoff, fall and landing states play")
 check(launches==1,"Holding jump cannot auto-bounce or create infinite air jumps")
 await step(2);hero.request_jump();await step(5)
 var first_peak:float=hero.global_position.y
 hero.request_jump();await step(5)
 check(hero.velocity.y<hero.JUMP_SPEED and hero.global_position.y>first_peak,"An airborne jump press cannot add a second upward impulse")
 await step(60)
 game.profile.data.settings.touch_controls=true;game.touch_controller._process(0)
 var geo:Dictionary=game.touch_controller.geometry();game.touch_controller.contact(99,geo.jump,true);game.touch_controller.contact(99,geo.jump,false)
 check(hero.jump_buffer_left>0,"Touch JUMP submits a one-shot jump request")
 await step(3);check(hero.global_position.y>floor_y+.15,"Touch JUMP lifts the real player body")
 game.show_pause();var paused_y:float=hero.global_position.y;var paused_v:float=hero.velocity.y
 hero.request_jump();hero._physics_process(.5)
 check(hero.jump_buffer_left==0 and hero.global_position.y==paused_y and hero.velocity.y==paused_v,"Pause rejects queued jump and freezes an active jump")
 game.resume_game();game.state="playing";await step(60)
 # Low expanding attacks use a vertical hit band, so a properly timed jump has a purpose.
 var ring=load("res://campaign/combat/boss_hazard.gd").new();ring.game=game;ring.kind="ring";ring.warning=0;ring.damage=20
 game.stage.add_child(ring);ring.set_physics_process(false);ring.global_position=hero.global_position+Vector3(0,0,-2.5)
 hero.current_hp=160;hero.is_invulnerable=false;hero.global_position.y=floor_y+.8
 ring._physics_process(.5)
 check(hero.current_hp==160,"Jumping clear of a low root wave avoids its damage")
 ring.queue_free();hero.global_position.y=floor_y
 for character_id in range(4):
  game.profile.data.character=character_id;game._spawn_hero();await process_frame
  hero=game.hero;hero.set_showcase(false);hero.set_physics_process(false)
  check(hero.anim_player.has_animation("shared/jump_start") and hero.anim_player.has_animation("shared/land"),"Character %d has retargeted jump and landing clips"%character_id)
  check(hero.anim_player.has_animation("shared/draw_walk") and hero.anim_player.has_animation("shared/aim_walk"),"Character %d has bow-and-leg animation layering"%character_id)
  for pose in ["draw_walk","aim_walk"]:
   var animation:Animation=hero.anim_player.get_animation("shared/"+pose)
   var leg:int=hero.skeleton.find_bone("LeftUpperLeg")
   hero.anim_player.play("shared/"+pose,0);hero.anim_player.seek(animation.length*.15,true)
   var early:Quaternion=hero.skeleton.get_bone_pose_rotation(leg)
   hero.anim_player.seek(animation.length*.55,true)
   var late:Quaternion=hero.skeleton.get_bone_pose_rotation(leg)
   check(early.angle_to(late)>.1,"Character %d moving %s actually articulates a leg through the bow action"%[character_id,pose])
 print("LOCOMOTION AND JUMP V4: ","PASS" if failures.is_empty() else failures)
 game.stop_audio();game.queue_free();await process_frame;await process_frame
 quit(0 if failures.is_empty() else 1)
