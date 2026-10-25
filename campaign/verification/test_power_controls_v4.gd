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
func restore() -> void:
 hero.cancel_draw();hero.shot_cooldown=0;hero.quick_release_left=0;hero.is_dodging=false;hero.dodge_cooldown=0
 game.power_armed=false;game.power_timers.clear();game.power_global_lock=0;game.focus_meter=100;game.arrows=30;game.ultimate_used=false
func pad(button:int,pressed:bool) -> void:
 var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=pressed;game._input(event)
func run() -> void:
 root.size=Vector2i(844,390)
 game=Scene.instantiate();game.test_mode=true;root.add_child(game);await process_frame
 game.profile.data.bow_level=100;game.profile.data.arrow_level=100;game.profile.data.character_level=100
 game.profile.data.trial_proofs={"55":true,"65":true,"75":true,"85":true,"95":true}
 game.profile.data.settings.touch_controls=true;game.profile.data.power="burst";game.profile.data.power_secondary="gale"
 game.start_stage(55,true);game.state="playing";game.set_process(false)
 game.stage.combat_manager.set_physics_process(false)
 for enemy in game.stage.combat_manager.enemies_alive:enemy.set_physics_process(false)
 hero=game.hero;hero.set_physics_process(false);await step(6)
 var touch:Control=game.touch_controller;touch._process(0)
 var geo:Dictionary=touch.geometry()
 restore()
 var before:int=game.shots
 touch.contact(11,geo.power,true)
 check(hero.drawing and game.selected_power=="burst","Touch POWER directly starts its selected draw")
 touch.contact(12,geo.draw,true);touch.contact(12,geo.draw,false,true)
 check(hero.drawing and game.power_charge_source=="touch:11" and game.shots==before,"A second SHOOT finger cannot fire or cancel the held power")
 await step(ceili(game.profile.draw_time()*60)+2)
 check(game.draw_amount>=.95 and game.shots==before and game.arrows==30 and game.focus_meter==100,"A real held charge reaches READY without spending resources")
 touch.contact(11,geo.power,false)
 check(game.shots==before+1 and game.arrows==29 and game.focus_meter==65 and not hero.drawing,"Releasing touch POWER commits exactly one Burst volley")
 touch.contact(11,geo.power,false)
 check(game.shots==before+1,"A repeated finger release cannot fire twice")
 restore();before=game.shots
 touch.contact(13,geo.secondary,true);await step(12)
 check(game.selected_power=="gale" and hero.drawing,"Secondary touch power has its own held draw")
 touch.contact(13,geo.secondary,false,true)
 check(game.shots==before and game.arrows==30 and game.focus_meter==100 and not hero.drawing and not game.power_armed and game.power_charge_source.is_empty(),"Canceled power touch spends nothing and clears ownership")
 restore()
 pad(JOY_BUTTON_X,true);await step(15);pad(JOY_BUTTON_X,false)
 check(game.shots==before+1 and game.power_charge_source.is_empty(),"Gamepad X charges and releases exactly one primary power")
 restore();before=game.shots
 pad(JOY_BUTTON_Y,true);await step(15);pad(JOY_BUTTON_Y,false)
 check(game.shots==before+1 and game.selected_power=="gale","Gamepad Y charges and releases the secondary power")
 restore();await step(3)
 pad(JOY_BUTTON_A,true)
 check(hero.jump_buffer_left>0 and not hero.drawing,"Gamepad A requests a physical jump without arming a power")
 await step(60)
 restore();before=game.shots
 check(game.begin_power_charge("burst","pause-test"),"Pause fixture starts a genuine held charge")
 await step(10);game.show_pause();game.end_power_charge("pause-test")
 check(game.shots==before and not hero.drawing and not game.power_armed and game.power_charge_source.is_empty(),"Pause cancels a held charge; late release cannot shoot")
 game.resume_game();game.state="playing"
 restore();game.begin_power_charge("burst","dodge-test");await step(10);hero.start_dodge();game.end_power_charge("dodge-test")
 check(game.shots==before and not hero.drawing and not game.power_armed and hero.is_dodging,"Dodge cancels held power without firing")
 restore();game.begin_power_charge("burst","empty-test");game.arrows=0;hero.clear_empty_aim();game.end_power_charge("empty-test")
 check(game.shots==before and not hero.drawing and not game.power_armed and game.power_charge_source.is_empty(),"Empty quiver clears a held draw and rejects stale release")
 restore();game.begin_power_charge("burst","death-test");hero.take_player_damage(1000);game.end_power_charge("death-test")
 check(game.shots==before and not hero.drawing and not game.power_armed,"Fatal damage cancels power and cannot fire on release")
 print("HELD POWER CONTROLS V4: ","PASS" if failures.is_empty() else failures)
 game.stop_audio();game.queue_free();await process_frame;await process_frame
 quit(0 if failures.is_empty() else 1)
