extends SceneTree
var failures:Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
 if not ok:failures.append(message);push_error(message)
func run() -> void:
 var game=load("res://campaign/game.gd").new();game.test_mode=true
 root.size=Vector2i(1280,720)
 root.add_child(game)
 await process_frame
 game.profile.save_path="/tmp/archer-rebalance-test.json"
 var defs:Array=game.definitions
 for d in defs:
  var tier:int=d.required_tier;var gear:int=d.required_gear_level;var charlevel:int=d.required_character_level
  game.profile.data.equipped_bow=tier;game.profile.data.equipped_arrow=[0,2,1,3][tier]
  game.profile.data.bow_level=gear;game.profile.data.arrow_level=gear
  game.profile._record(game.profile.skin_key()).level=charlevel
  check(game.loadout_requirement(d).is_empty(),"Reference gate %d"%d.id)
  var attack:float=game.profile.power()
  var arrows_needed:int=0
  for i in range(d.materials.size()):
   var hp:float=d.target_hp[i];var stone:bool=d.materials[i] in ["stone","rune","master"]
   var count:int=0
   while hp>.001 and count<100:
    hp-=attack*(1+mini(count,2)*.1 if stone else 1);count+=1
   arrows_needed+=count
   check(count==(3 if stone else 1),"Reference target shots %d:%d = %d"%[d.id,i,count])
  check(arrows_needed+2==int(d.arrows),"Ammo budget %d"%d.id)
 game.profile._record(game.profile.skin_key()).level=1
 game.profile.data.equipped_bow=0;game.profile.data.equipped_arrow=0;game.profile.data.bow_level=1;game.profile.data.arrow_level=1
 check(not game.loadout_requirement(defs[9]).is_empty(),"Untrained starter cannot pass chapter 2 finale")
 game.profile.data.unlocked=99
 for tab in ["bow","arrow","costumes","character"]:
  game.inventory_tab=tab;game.preview_item=-1;game.show_store();await process_frame
  game.show_collection();await process_frame
 game.show_characters();await process_frame
 game.show_home();game.start_stage(10);game.state="playing"
 await physics_frame
 for child in game.backdrop.get_children():
  if child is Node3D and not child is Light3D:check(not child.visible,"Backdrop hidden "+child.name)
 var target=game.stage.targets[0]
 check(target.damage_multiplier(3)==1.0 and target.damage_multiplier(2)==.8 and target.damage_multiplier(1)==.6 and target.damage_multiplier(0)==.3,"Four damage zones")
 game.profile.data.settings.touch_controls=true;game.touch_controller._process(0)
 game._refresh_layout()
 for frame in range(6):await process_frame
 game.state="playing";game.touch_controller._process(0)
 var touch=game.touch_controller;var geo:Dictionary=touch.geometry()
 print("TOUCH GEOMETRY ",geo," size ",touch.size," shots ",game.shots," cooldown ",game.hero.shot_cooldown)
 var before:int=game.shots
 touch.contact(81,geo.draw,true);check(game.shots==before+1,"Shoot fires immediately")
 touch.contact(81,geo.draw,false);check(game.shots==before+1,"Release does not fire twice")
 var left:=Vector2(geo.stick.x+150,game.ui.size.y*.45)
 touch.contact(82,left,true);check(touch.roles.get(82)=="look","Left screen look");touch.contact(82,left,false)
 var stone=game.stage.targets[game.stage.targets.size()-1]
 check(stone.material_kind in ["stone","rune","master"],"Test fixture has rock")
 var reference:float=game.current_definition.recommended_power
 var center:Vector3=stone.global_position+Vector3(0,0,.1)
 for i in range(2):
  stone.campaign_hit(center,reference,{"shot_id":800+i})
  check(not stone.completed,"Rock survives first two centers")
 stone.campaign_hit(center,reference,{"shot_id":802})
 check(stone.completed,"Rock breaks on third consecutive center")
 game.profile._record(game.profile.skin_key()).level=100
 game.focus_meter=100;game.power_cooldown=0;game.selected_power="burst";game.power_armed=true
 check(not game.begin_volley().is_empty(),"First burst allowed")
 game.focus_meter=100;game.power_cooldown=0;game.power_armed=true
 check(game.begin_volley().is_empty(),"Second burst denied")
 game.selected_power="gale";game.power_armed=true
 check(not game.begin_volley().is_empty(),"First super allowed separately from burst")
 game.focus_meter=100;game.power_cooldown=0;game.selected_power="fire";game.power_armed=true
 check(game.begin_volley().is_empty(),"Second super denied across ability changes")
 game.profile.data.selected=12;game.profile.data.chapter_run={"active":true,"chapter":2,"stage":2,"transaction":"test","stage_stars":[2,2,0,0,0]}
 check(game.profile.fail_run()==12,"Failure retains stage checkpoint")
 game.stop_audio();game.queue_free();await process_frame
 print("REBALANCE: 100 loadout gates, 100 shot budgets, store/collection categories, map hiding, damage zones, instant shooting, left look and retry: ","PASS" if failures.is_empty() else failures)
 quit(0 if failures.is_empty() else 1)
