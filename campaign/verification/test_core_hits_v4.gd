extends SceneTree
const Scene=preload("res://campaign/main.tscn")
const Projectile=preload("res://campaign/projectile.gd")
var game:Node3D
var boss:CharacterBody3D
var hero:CharacterBody3D
var failures:Array[String]=[]
func check(ok:bool,message:String) -> void:
 if not ok:failures.append(message);push_error(message)
func _init() -> void:run.call_deferred()
func aim_at_core() -> void:
 boss._sync_core_collision()
 var point:Vector3=boss.core_mesh.global_position
 hero.camera.global_position=hero.global_position+Vector3(.47,1.55,3.5)
 hero.camera.look_at(point)
 var direction:Vector3=-hero.camera.global_basis.z
 hero.yaw=atan2(-direction.x,-direction.z)
 hero.pitch=atan2(direction.y,Vector2(direction.x,direction.z).length())
func resolve_player_arrow() -> void:
 var arrow:Node3D
 for child in game.stage.get_children():
  if child.get_script()==Projectile and child.shot_id==game.shot_serial*10:arrow=child
 check(is_instance_valid(arrow),"Player input creates a real arrow from the equipped bow")
 if not is_instance_valid(arrow):return
 arrow.set_physics_process(false)
 for frame in range(100):
  if not arrow.flying:break
  arrow._physics_process(1.0/60)
 check(not arrow.flying,"Bow projectile physically reaches a collision")
func normal_shot() -> void:
 hero.shot_cooldown=0;game.power_armed=false;game.power_charge_source=""
 aim_at_core();hero.instant_shoot();resolve_player_arrow()
func charge_power(duration:float) -> void:
 hero.shot_cooldown=0;game.power_timers.clear();game.power_global_lock=0;game.ultimate_used=false;game.focus_meter=100
 var press:=InputEventKey.new();press.keycode=KEY_F;press.pressed=true
 game._input(press)
 check(hero.drawing and game.power_charge_source=="key:"+str(KEY_F),"Holding F starts the selected power's real bow draw")
 var before:int=game.shots
 hero.instant_shoot();check(game.shots==before,"A normal trigger cannot steal a held power draw")
 for frame in range(ceili(duration*60)):
  await physics_frame
  hero._physics_process(1.0/60)
 check(game.shots==before,"Holding power charges without firing or spending an arrow")
 aim_at_core()
 var release:=InputEventKey.new();release.keycode=KEY_F;release.pressed=false;game._input(release)
 resolve_player_arrow()
func run() -> void:
 root.size=Vector2i(1280,720)
 game=Scene.instantiate();game.test_mode=true;root.add_child(game);await process_frame
 game.profile.data.bow_level=100;game.profile.data.arrow_level=100;game.profile.data.character_level=100
 game.profile.data.trial_proofs={"55":true,"65":true,"75":true,"85":true,"95":true};game.profile.equip_power("ultimate")
 game.start_stage(99,true);await process_frame;game.state="playing";game.set_process(false)
 hero=game.hero;hero.set_physics_process(false)
 boss=game.stage.combat_manager.boss;boss.set_physics_process(false);game.stage.combat_manager.set_physics_process(false)
 for lean in [Vector3(.12,0,.10),Vector3(-.10,0,-.08)]:
  for side in [-3.0,0.0,3.0]:
   boss.hp=1476;boss._enter_state(boss.State.P1_OPEN);boss.body_root.rotation=lean;boss._sync_core_collision()
   hero.global_position=game.stage.spawn+Vector3(side,0,0)
   await physics_frame
   check(boss.core_mesh.global_position.distance_to(boss.core_col.global_position)<.001,"Visible leaning core and collider coincide")
   var before:float=boss.hp
   normal_shot()
   check(boss.last_hit_result.core_hit and is_equal_approx(before-boss.hp,game.profile.power()),"Real bow shot damages the visible core at lean %s, side %.1f"%[lean,side])
 boss.hp=1476;boss.body_root.rotation=Vector3.ZERO;boss._enter_state(boss.State.P1_CLOSED);hero.global_position=game.stage.spawn
 await physics_frame
 normal_shot()
 check(not boss.last_hit_result.core_hit and is_equal_approx(1476-boss.hp,game.profile.power()*.25),"Closed-core contact deals and reports actual armored damage")
 var hp_after:float=boss.hp;var receipt:int=int(boss.last_hit_result.shot_id)
 boss.campaign_hit(boss.core_col.global_position,1000,{"shot_id":receipt,"power_key":"normal","direct":true})
 check(boss.hp==hp_after and boss.last_hit_result.reason=="duplicate","Repeated arrow receipt cannot damage or score twice")
 game.arrows=12;game.focus_meter=100;game.ultimate_used=false;boss.hp=boss.GATE_10;boss._enter_state(boss.State.FINAL_REARM)
 boss._physics_process(.8)
 check(boss.attack_phase=="telegraph" or boss.attack_phase=="wait","A ready final player can continue the fight without a compulsory well visit")
 check(not boss.combat_status().rearm_required,"Ready resources show a core-opening objective rather than a false refill requirement")
 boss._clear_danger();boss._enter_state(boss.State.FINAL_OPEN);await physics_frame
 normal_shot()
 check(boss.hp==boss.GATE_10 and not boss.last_hit_result.accepted and boss.last_hit_result.reason=="aurora_required","Normal final-core hit gives an explicit seal explanation")
 await charge_power(game.profile.draw_time()*.4)
 check(boss.hp==boss.GATE_10 and boss.last_hit_result.reason=="full_draw_required","An undercharged real Aurora cannot finish and explains the charge requirement")
 boss._enter_state(boss.State.FINAL_REARM);game.power_timers.ultimate=10;game.power_global_lock=2
 check(boss.combat_status().rearm_required,"Spent Aurora shows the refill requirement")
 boss.collect_rearm_well(hero)
 check(game.power_global_lock==0 and not game.power_timers.has("ultimate") and game.focus_meter==100 and not game.ultimate_used,"Rearm restores actual cast eligibility, including old cooldowns")
 boss._enter_state(boss.State.FINAL_OPEN);await physics_frame
 await charge_power(game.profile.draw_time())
 check(boss.completed and boss.hp==0 and boss.last_hit_result.finisher,"Fully charged player-held Aurora strikes the visible core and defeats the boss")
 print("CORE HIT AND POWER INPUT V4: ","PASS" if failures.is_empty() else failures)
 game.stop_audio();game.queue_free();await process_frame;await process_frame
 quit(0 if failures.is_empty() else 1)
