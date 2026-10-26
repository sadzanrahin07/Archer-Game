extends SceneTree
var game:Node
var hero:Node3D
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
 if not ok:failures.append(message);push_error(message)
func _initialize():run.call_deferred()
func step(frames:int)->void:
 for i in range(frames):
  await physics_frame
  hero._physics_process(1.0/60)
  game._physics_process(1.0/60)
func mouse(button:int,pressed:bool)->void:
 var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed
 hero._unhandled_input(event)
func run():
 root.size=Vector2i(1280,720)
 game=load("res://campaign/main.tscn").instantiate();game.test_mode=true;game.profile.save_path="/tmp/archer_focus_scope_qa.json"
 root.add_child(game);await process_frame
 game.profile.data.settings.touch_controls=false
 game.profile.data.purchased_powers=["pressure"]
 game.start_stage(5,true);game.ready_left=0;game.state="playing"
 game.set_physics_process(false);hero=game.hero;hero.set_physics_process(false)
 await step(3)
 check(hero.focus_blend==0,"Idle has no focus lens")
 hero.instant_shoot();await step(3)
 check(hero.quick_release_left>0 and hero.aim_blend>0,"Quick shot exercises the aiming body pose")
 check(hero.focus_blend==0 and float(game.focus_material.get_shader_parameter("strength"))==0,"Instant shooting never activates the lens")
 mouse(MOUSE_BUTTON_RIGHT,true);await step(12)
 check(hero.is_focus_aiming() and hero.focus_blend>.99,"Holding desktop AIM activates the focus ring")
 check(float(game.focus_material.get_shader_parameter("strength"))>.99,"HUD receives explicit focus strength")
 var before:Vector2=Vector2(hero.yaw,hero.pitch)
 var motion:=InputEventMouseMotion.new();motion.relative=Vector2(52,-24)
 hero._unhandled_input(motion);await step(2)
 check(hero.yaw<before.x and hero.pitch>before.y,"Dragging mouse while aiming changes both camera axes")
 mouse(MOUSE_BUTTON_RIGHT,false)
 hero.shot_cooldown=0;hero.instant_shoot()
 check(hero.focus_blend==0 and float(game.focus_material.get_shader_parameter("strength"))==0,"Instant shoot after releasing AIM clears a fading lens immediately")
 await step(36)
 game.profile.data.settings.touch_controls=true
 var touch:Control=game.touch_controller;touch._process(0)
 var geo:Dictionary=touch.geometry()
 touch.contact(101,geo.aim,true);touch._process(0);await step(12)
 check(touch.aim and hero.touch_aim and hero.focus_blend>.99,"Touch AIM toggles a persistent focus lens")
 before=Vector2(hero.yaw,hero.pitch)
 touch.motion(101,geo.aim+Vector2(40,-20),Vector2(40,-20));await step(2)
 check(hero.yaw<before.x and hero.pitch>before.y,"The AIM button finger can drag the focused aim point")
 touch.contact(101,geo.aim,false)
 check(touch.aim and hero.touch_aim,"Lifting AIM finger preserves toggle")
 touch.contact(102,geo.aim,true);touch.contact(102,geo.aim,false);touch._process(0);await step(12)
 check(not touch.aim and hero.focus_blend==0,"Toggling AIM off removes the ring")
 hero.shot_cooldown=0
 touch.contact(103,geo.draw,true);touch.contact(103,geo.draw,false);await step(2)
 check(hero.focus_blend==0,"Touch instant SHOOT has no focus ring")
 touch.reset();game.profile.data.settings.touch_controls=false;touch._process(0)
 mouse(MOUSE_BUTTON_RIGHT,true);await step(12)
 check(hero.focus_blend>.99,"Pause fixture begins with a visible focus ring")
 game.show_pause();game.resume_game();game.state="playing"
 check(hero.focus_blend==0,"Pause and resume cannot restore a cleared AIM ring")
 game.profile.data.settings.touch_controls=true;touch._process(0)
 geo=touch.geometry();touch.contact(104,geo.aim,true);touch.contact(104,geo.aim,false);await step(12)
 check(touch.aim and hero.focus_blend>.99,"Stage-reset fixture begins with AIM toggled on")
 game.start_stage(5,true)
 check(not touch.aim and touch.roles.is_empty() and not hero.touch_aim and hero.focus_blend==0,"A new stage clears stale aim toggles and drag ownership")
 game.stop_audio();game.queue_free();await process_frame;await process_frame
 print("FOCUS SCOPE AND INSTANT-SHOT ISOLATION: ","PASS" if failures.is_empty() else failures)
 quit(0 if failures.is_empty() else 1)
