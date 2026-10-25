extends SceneTree
const GameScene=preload("res://campaign/main.tscn")
var failures:Array[String]=[]
func check(value:bool,message:String) -> void:
 if not value:failures.append(message);push_error(message)
func _init() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,720)
 var game=GameScene.instantiate();game.test_mode=true;root.add_child(game)
 await process_frame
 game.profile.data.bow_level=100;game.profile.data.arrow_level=100;game.profile.data.character_level=100
 game.profile.data.trial_proofs={"55":true,"65":true,"75":true,"85":true,"95":true}
 game.start_stage(55,true);await process_frame;game.state="playing";game.set_process(false)
 game.stage.process_mode=Node.PROCESS_MODE_DISABLED
 var hero=game.hero;hero.set_physics_process(false)
 var fx=hero.get_node("BowPowerCharge");fx.set_process(false)
 var hud:Control
 for node in game.ui.get_children():
  if node.get_script()==load("res://campaign/combat_hud.gd"):hud=node
 check(is_instance_valid(hud) and hud.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Combat HUD exists without consuming look or shoot input")
 check(not game.hud_ammo.is_visible_in_tree() and not game.hud_draw.visible,"Combat uses compact gauges instead of legacy giant ammo card and duplicate charge bar")
 game.selected_power="gale";game.power_armed=true
 hero.drawing=true;hero.draw_elapsed=game.profile.draw_time()*.7
 fx._process(.1)
 check(fx.visible and fx.charge_time>0 and fx.release_time==0,"Armed draw shows the local charge")
 check(hero.bow_hand_node.material_overlay!=null and fx.tip_core.mesh.size.y*fx.tip_core.scale.y<.15,"Charge illuminates actual bow at readable scale")
 var old_time:float=fx.charge_time;game.state="paused";fx._process(1)
 check(fx.charge_time==old_time,"Pause freezes charge animation")
 game.state="playing";hero.cancel_draw();fx._process(.01)
 check(not fx.visible and fx.release_time==0 and hero.bow_hand_node.material_overlay==null,"Canceled draw clears glow without a false release")
 game.power_armed=true;game.arrows=20;game.focus_meter=100;hero.shot_cooldown=0
 hero.instant_shoot()
 check(fx.release_time>0 and fx.last_key=="gale","A successful instant power release emits its own flash event")
 var release_time:float=fx.release_time;game.state="paused";fx._process(1)
 check(is_equal_approx(fx.release_time,release_time),"Pause freezes release effect")
 game.state="playing";fx._process(.5)
 check(fx.release_time==0 and not fx.visible,"Release effect expires")
 hero.showcase=true;fx._process(.1)
 check(not fx.visible and hero.bow_hand_node.material_overlay==null,"Lobby always shows equipped physical bow and arrow")
 game.profile.data.settings.reduced_motion=true;hero.showcase=false
 fx._on_attack_release("ultimate",false);fx._process(.01)
 check(fx.charge_light.light_energy==0 and fx.release_duration<.10,"Reduced motion suppresses release light and shortens the directional flash")
 game.profile.data.settings.reduced_motion=false
 game.selected_power="burst";game.power_armed=true;game.power_timers.clear();game.power_global_lock=0;game.focus_meter=100;hero.shot_cooldown=0
 hero.instant_shoot()
 var bolt_count:=0;var full_launches:=0
 for bolt in game.stage.get_children():
  if bolt.get_script()==load("res://campaign/projectile.gd") and bolt.ability.key=="burst":
   bolt_count+=1
   bolt.vfx._process(.01)
   if bolt.vfx.launch_shockwave_done:full_launches+=1
 check(bolt_count==3 and full_launches==1,"One Burst release produces three bolts and only one full launch effect")
 game.profile.data.settings.reduced_motion=true
 game.selected_power="gale";game.power_armed=true;game.power_timers.clear();game.power_global_lock=0;game.focus_meter=100;hero.shot_cooldown=0
 hero.instant_shoot()
 for bolt in game.stage.get_children():
  if bolt.get_script()==load("res://campaign/projectile.gd") and bolt.shot_id==game.shot_serial*10:
   bolt.vfx._process(.2)
   check(not bolt.vfx.launch_shockwave_done and bolt.vfx.flight_mote_count==0,"Reduced motion suppresses real projectile launch and repeated flight shocks")
   var before_effects:int=game.stage.get_child_count()
   bolt.vfx.impact(bolt.global_position,game.stage)
   check(game.stage.get_child_count()==before_effects+1,"Reduced-motion impact leaves one small fade without expanding blast geometry")
 for character_id in range(4):
  game.profile.data.character=character_id;game._spawn_hero();await process_frame
  var actor=game.hero
  check(actor.anim_player.has_animation("shared/dodge"),"Authored dodge is available on character %d"%character_id)
  actor.anim_player.play("shared/dodge",0);actor.anim_player.seek(.25,true)
  var skeleton:Skeleton3D=actor.skeleton
  check(skeleton.get_bone_count()>20 and actor.anim_player.get_animation("shared/dodge").get_track_count()>20,"Roll preserves rig tracks for character %d"%character_id)
  actor.set_showcase(false);actor.is_dodging=false;actor.dodge_cooldown=0;game.state="playing";actor.start_dodge()
  check(actor.last_pose=="dodge","Character %d enters actual roll pose"%character_id)
 game.start_stage(99,true);await process_frame;game.state="playing"
 check(is_instance_valid(game.stage.combat_manager.boss),"Boss and compact HUD coexist")
 print("COMBAT PRESENTATION: ","PASS" if failures.is_empty() else failures)
 game.stop_audio();game.queue_free();await process_frame;await process_frame
 quit(0 if failures.is_empty() else 1)
