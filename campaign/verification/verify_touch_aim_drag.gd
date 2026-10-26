extends SceneTree
var game:Node
var touch:Control
var failures:Array[String]=[]
func _initialize():run.call_deferred()
func check(condition:bool,message:String) -> void:
 if not condition:failures.append(message);push_error(message)
func move_look(id:int,pos:Vector2) -> void:
 var before:=Vector2(game.hero.yaw,game.hero.pitch)
 var role:String=str(touch.roles.get(id,""))
 touch.motion(id,pos+Vector2(32,-14),Vector2(32,-14))
 var after:=Vector2(game.hero.yaw,game.hero.pitch)
 check(after.x<before.x and after.y>before.y,"Owned "+role+" drag must change horizontal and vertical aim")
 check(str(touch.roles.get(id,""))==role,"Dragging must preserve the "+role+" contact's release role")
func prepare_charge() -> void:
 game.state="playing";game.arrows=20;game.focus_meter=100;game.power_global_lock=0;game.power_timers.clear();game.power_armed=false
 game.hero.shot_cooldown=0;game.hero.drawing=false
func run():
 root.size=Vector2i(1280,720)
 game=load("res://campaign/main.tscn").instantiate();game.test_mode=true;game.profile.save_path="/tmp/archer_touch_aim_drag_qa.json"
 root.add_child(game);await process_frame
 game.profile.data.settings.touch_controls=true
 game.profile.data.purchased_powers=["gale","fire"]
 game.profile.data.power="gale";game.profile.data.power_secondary="fire"
 game.start_stage(5,true);game.ready_left=0;game.state="playing";game.arrows=20
 await process_frame;await physics_frame
 touch=game.touch_controller;touch._process(0)
 var geo:Dictionary=touch.geometry()
 var free:=Vector2(touch.size.x*.5,game.safe_margins.y+160)
 check(touch.active,"Touch controller must be active")
 # Same-finger AIM press + drag, through actual screen input coordinate conversion.
 var aim_press:=InputEventScreenTouch.new();aim_press.index=101;aim_press.position=geo.aim*game.ui_scale;aim_press.pressed=true
 touch._input(aim_press)
 check(touch.aim and game.hero.touch_aim,"AIM must synchronize to the hero immediately")
 if game.hero.has_method("is_focus_aiming"):check(game.hero.is_focus_aiming(),"Explicit touch AIM must activate focus")
 var camera_before:Vector3=-game.hero.camera.global_basis.z
 var drag:=InputEventScreenDrag.new();drag.index=101;drag.position=(geo.aim+Vector2(32,-14))*game.ui_scale;drag.relative=Vector2(32,-14)*game.ui_scale
 var yaw_before:float=game.hero.yaw
 touch._input(drag)
 check(game.hero.yaw<yaw_before,"Same-finger AIM ScreenDrag must rotate aim")
 check(touch.roles.get(101)=="aim","AIM drag must retain AIM release ownership")
 await physics_frame;await physics_frame
 check((-game.hero.camera.global_basis.z).distance_to(camera_before)>.005,"Dragging AIM must move the actual camera aiming ray")
 aim_press.pressed=false;touch._input(aim_press)
 check(touch.aim and game.hero.touch_aim,"Releasing AIM contact must preserve its toggled aiming state")
 # Free-area look still works while AIM remains toggled on.
 touch.contact(102,free,true);check(touch.roles.get(102)=="look","Free-area contact must own look")
 move_look(102,free);touch.contact(102,free,false)
 check(touch.aim,"Free-area look release must preserve AIM toggle")
 # Toggling AIM off is immediate; dragging its inactive button must not look.
 touch.contact(103,geo.aim,true)
 check(not touch.aim and not game.hero.touch_aim,"AIM off must synchronize immediately")
 var inactive_yaw:float=game.hero.yaw
 touch.motion(103,geo.aim+Vector2(30,0),Vector2(30,0))
 check(game.hero.yaw==inactive_yaw,"Inactive AIM contact must not rotate the camera")
 touch.contact(103,geo.aim,false)
 touch.contact(104,geo.aim,true);touch.contact(104,geo.aim,false)
 # SHOOT can adjust the held draw and still fires exactly once on its release.
 prepare_charge();var shots:int=game.shots
 touch.contact(105,geo.draw,true)
 check(game.hero.drawing and game.shots==shots,"Aimed SHOOT must start drawing without firing")
 move_look(105,geo.draw)
 check(game.shots==shots,"Dragging SHOOT must not fire prematurely")
 game.hero.draw_elapsed=.25;touch.contact(105,geo.draw,false)
 check(game.shots==shots+1 and not game.hero.drawing,"SHOOT release must still fire once")
 # Primary power drag keeps the charge's owner, even when another power contact appears.
 prepare_charge();shots=game.shots
 touch.contact(106,geo.power,true)
 check(game.power_charge_source=="touch:106" and game.hero.drawing,"POWER contact must own its held charge")
 move_look(106,geo.power)
 touch.contact(107,geo.secondary,true)
 var owner_yaw:float=game.hero.yaw
 touch.motion(107,geo.secondary+Vector2(32,-14),Vector2(32,-14))
 check(game.hero.yaw==owner_yaw,"A power contact that did not obtain the charge must not steer another owner's draw")
 touch.contact(107,geo.secondary,false)
 check(game.power_charge_source=="touch:106" and game.hero.drawing and game.shots==shots,"Secondary release must not steal or release the primary charge")
 game.hero.draw_elapsed=.25;touch.contact(106,geo.power,false)
 check(game.power_charge_source.is_empty() and game.shots==shots+1,"POWER release must still fire its owned charge once")
 # Secondary can steer and release its own charge independently.
 prepare_charge();shots=game.shots
 touch.contact(108,geo.secondary,true)
 check(game.power_charge_source=="touch:108" and game.selected_power=="fire","SECONDARY must own the secondary charge")
 move_look(108,geo.secondary)
 game.hero.draw_elapsed=.25;touch.contact(108,geo.secondary,false)
 check(game.power_charge_source.is_empty() and game.shots==shots+1,"SECONDARY release must still fire exactly once")
 # Movement drags stay movement drags and cannot rotate aim.
 game.hero.stationary=false
 var move_yaw:float=game.hero.yaw
 touch.contact(109,geo.stick,true);touch.motion(109,geo.stick+Vector2(30,-20),Vector2(30,-20))
 check(touch.roles.get(109)=="move" and touch.move_vector.length()>.1,"Movement stick must preserve movement ownership")
 check(game.hero.yaw==move_yaw,"Movement stick drag must not rotate aim")
 touch.contact(109,geo.stick,false);check(touch.move_vector==Vector2.ZERO,"Movement must stop on stick release")
 # Desktop preview follows the same held AIM drag path.
 touch.reset();prepare_charge();touch._process(0)
 var mouse:=InputEventMouseButton.new();mouse.device=0;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.position=geo.aim*game.ui_scale
 touch._input(mouse)
 check(game.hero.touch_aim and touch.roles.get(-100)=="aim","Mouse AIM preview must toggle immediately")
 var mouse_before:float=game.hero.yaw
 var mouse_motion:=InputEventMouseMotion.new();mouse_motion.device=0;mouse_motion.position=(geo.aim+Vector2(24,-8))*game.ui_scale;mouse_motion.relative=Vector2(24,-8)*game.ui_scale
 touch._input(mouse_motion)
 check(game.hero.yaw<mouse_before and touch.roles.get(-100)=="aim","Mouse preview must support same-contact AIM dragging")
 mouse.pressed=false;touch._input(mouse)
 check(touch.aim and not touch.roles.has(-100),"Mouse release must preserve toggled aim and clear contact ownership")
 touch.reset();game.stop_audio();game.queue_free();await process_frame;await process_frame
 if failures.is_empty():print("TOUCH AIM + FREE LOOK + SHOOT/POWER/SECONDARY DRAG + OWNER RELEASE + MOVE ISOLATION + MOUSE PREVIEW PASS")
 else:print("TOUCH AIM DRAG FAILURES: ",failures)
 quit(0 if failures.is_empty() else 1)
