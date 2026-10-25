extends SceneTree
const Scene=preload("res://campaign/main.tscn")
const Projectile=preload("res://campaign/projectile.gd")
var failures:Array[String]=[]
func check(ok:bool,message:String) -> void:
 if not ok:failures.append(message);push_error(message)
func _init() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,720)
 var game=Scene.instantiate();game.test_mode=true;root.add_child(game);await process_frame
 game.profile.data.bow_level=100;game.profile.data.arrow_level=100;game.profile.data.character_level=100
 game.profile.data.trial_proofs={"55":true,"65":true,"75":true,"85":true,"95":true}
 game.start_stage(55,true);game.state="playing";game.set_process(false)
 game.stage.combat_manager.set_physics_process(false)
 for enemy in game.stage.combat_manager.enemies_alive:enemy.set_physics_process(false)
 var hero=game.hero;hero.set_physics_process(false)
 var fx=hero.get_node("BowPowerCharge");fx.set_process(false)
 var audio=game._power_audio();audio.set_process(false)
 for key in ["burst","gale","pressure","fire","lightning","super_lightning","ultimate"]:
  game.selected_power=key;game.power_armed=true;game.arrows=40;game.focus_meter=100;game.ultimate_used=false;game.power_timers.clear();game.power_global_lock=0
  hero.shot_cooldown=0;hero.drawing=true;hero.draw_elapsed=game.profile.draw_time()*.4;hero._update_equipment()
  fx._process(.05)
  check(fx.visible and fx.charge_time>0 and audio.charge_voice.playing,"Charge VFX and sound begin together: "+key)
  hero.draw_elapsed=game.profile.draw_time();fx._process(.05)
  check(fx.ready_latched and audio.ready_latched,"READY chime is latched once per draw: "+key)
  check(fx.charge_light.light_energy<=.7 and fx.tip_core.mesh.size.y*fx.tip_core.scale.y<.15,"Charge remains compact and lighting stays bounded: "+key)
  var origin:Vector3=hero.arrow_tip_world
  check(fx.global_position.distance_to(origin)<.001,"Charge follows the physical arrow tip: "+key)
  var time:float=fx.charge_time;game.state="paused";fx._process(1);audio._process(1)
  check(fx.charge_time==time and audio.charge_voice.stream_paused,"Pause freezes charge motion and sound: "+key)
  game.state="playing";audio._process(0)
  hero.instant_shoot()
  check(fx.release_time>0 and audio.release_voice.playing and not audio.charge_voice.playing,"Actual volley releases one synchronized power cue: "+key)
  var bolt:Node3D
  for child in game.stage.get_children():
   if child.get_script()==Projectile:
    child.set_physics_process(false);child.vfx.set_process(false)
    if child.shot_id==game.shot_serial*10:bolt=child
  check(is_instance_valid(bolt),"Actual power volley exists: "+key)
  check(not bolt.vfx.launch_shockwave_done,"Launch does not flash at an uninitialized world origin: "+key)
  bolt.vfx._process(.01)
  check(bolt.vfx.launch_shockwave_done,"Leading bolt emits its launch after placement: "+key)
  check(bolt.vfx.energy_core.global_basis.y.normalized().dot(bolt.velocity.normalized())>.99,"Energy needle points along the flight direction: "+key)
  var elapsed:float=bolt.vfx.elapsed;game.state="paused";bolt.vfx._process(1)
  check(bolt.vfx.elapsed==elapsed,"Pause freezes flight animation: "+key);game.state="playing"
  bolt.flying=false;bolt.vfx._process(.01)
  check(not bolt.vfx.energy_core.visible and not bolt.vfx.trail.visible and bolt.vfx.flight_light.light_energy==0,"Impact removes the lingering flight effect: "+key)
  fx._process(.03);fx._process(.3)
  game.power_armed=true;hero.drawing=true;hero.draw_elapsed=game.profile.draw_time();fx._process(.01)
  var all_visible:=true
  for wisp in fx.wisps:all_visible=all_visible and wisp.visible
  check(all_visible and fx.core_material.albedo_color.a>.5,"Second charge restores particles and alpha after release: "+key)
  hero.cancel_draw();fx._process(.01)
  check(not fx.visible and not audio.charge_voice.playing and hero.bow_hand_node.material_overlay==null,"Canceled charge clears glow and hum: "+key)
  audio.impact_gate=0;audio.play_impact(key)
  check(audio.impact_voice.playing and audio.impact_voice.stream.get_length()<=.31,"Impact uses a short dedicated cue: "+key)
  audio._process(.01);audio.play_impact(key)
  check(audio.impact_gate<.065,"Simultaneous Burst contacts do not retrigger impact sound: "+key)
 game.profile.data.settings.reduced_motion=true;game.selected_power="ultimate";game.power_armed=true;hero.drawing=true;hero.draw_elapsed=game.profile.draw_time()
 fx._process(.02)
 var hidden:=true
 for wisp in fx.wisps:hidden=hidden and not wisp.visible
 check(hidden and fx.charge_light.light_energy<=.12,"Reduced Motion removes orbiting charge particles and bright light")
 var last_bolt:Node3D
 for child in game.stage.get_children():
  if child.get_script()==Projectile:last_bolt=child
 var before:int=game.stage.get_child_count();last_bolt.vfx.impact(last_bolt.global_position,game.stage)
 check(game.stage.get_child_count()==before+1,"Reduced-motion impact adds only one small fade, without sparks, shake or light")
 var pulse:MeshInstance3D=last_bolt.vfx._create_expanding_sphere(game.stage,last_bolt.global_position,.08,.3,Color.WHITE,.25)
 await process_frame
 var frozen_scale:Vector3=pulse.scale
 game.state="paused";paused=true
 await create_timer(.08,true).timeout
 check(pulse.scale.is_equal_approx(frozen_scale),"Transient impact animation pauses with the game")
 paused=false;game.state="playing"
 await create_timer(.3,true).timeout
 check(not is_instance_valid(pulse),"Transient impact cleans up after resuming")
 check(audio.get_child_count()==3 and audio.release_voice.bus=="SFX" and audio.impact_voice.bus=="SFX" and audio.charge_voice.bus=="SFX","Power audio has three bounded voices and respects the SFX bus")
 hero.cancel_draw();fx._process(.01);game.show_home()
 check(game.profile.data.bow_level==100 and game.profile.data.arrow_level==100,"Presentation leaves weapon mastery unchanged")
 print("POWER PRESENTATION AND SOUND: ","PASS" if failures.is_empty() else failures)
 game.stop_audio();game.queue_free();await process_frame;await process_frame
 quit(0 if failures.is_empty() else 1)
