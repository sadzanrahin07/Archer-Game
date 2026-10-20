extends SceneTree
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 if not ok:failures.append(message);push_error(message)
func run():
 var game=load("res://campaign/main.tscn").instantiate();game.test_mode=true;game.profile.save_path="/tmp/upgrade-flow-isolated.json";root.add_child(game);await process_frame
 var p=game.profile
 p.data.coins=10000;p.data.owned_bows=[0,1];p.data.owned_arrows=[0,2];p.data.owned_characters=[1,0]
 p.data.bow_levels=[20,39,1,1];p.data.bow_level=20;p.data.arrow_levels=[20,1,40,1];p.data.arrow_level=40;p.data.equipped_arrow=2
 var before:int=p.data.coins
 check(p.upgrade_item("bow",1),"Owned unequipped bow upgrades without XP")
 check(p.data.equipped_bow==0 and p.data.bow_level==20 and p.data.bow_levels[1]==40,"Upgrading preview preserves active weapon")
 check(p.data.coins<before,"Upgrade deducts coins")
 check(not p.upgrade_item("bow",1),"Tier cap enforced")
 check(p.upgrade_item("character",0),"Owned preview character upgrades")
 check(p.data.character==1 and p.level_for(0)==2,"Preview character upgrade preserves active character")
 p.data.owned_costumes=[2,1]
 check(p.upgrade_item("character",1,1),"Owned Erin skin upgrades independently")
 check(p.skin_level(1)==2 and p.skin_level(2)==1,"Skin progress stays independent")
 var normal:Dictionary=p.upgrade_info("character",1,2)
 p._record(p.skin_key()).xp=1000
 var trained:Dictionary=p.upgrade_info("character",1,2)
 check(trained.cost<normal.cost,"Training XP discounts upgrades")
 p.data.coins=0;var snapshot:Dictionary=p.data.duplicate(true)
 check(not p.upgrade_item("character",1,2) and p.data==snapshot,"Unaffordable upgrade has no side effects")
 p.data.coins=10000;p.equip_bow(1)
 check(game.shot_budget(game.definitions[33])<=9,"Chapter 7 Stage 4 clearable with max Premium gear / Lv1 Erin")
 print("STAGE 7.4: ",game.preparation_hint(game.definitions[33]))
 # Every authored chapter is clearable on normal center hits at the intended loadout.
 for d in game.definitions:
  var tier:int=d.required_tier;p.data.equipped_bow=tier;p.data.equipped_arrow=[0,2,1,3][tier]
  p.data.bow_level=d.required_gear_level;p.data.arrow_level=d.required_gear_level;p._record(p.skin_key()).level=d.required_character_level
  check(game.shot_budget(d)<=int(d.arrows),"Normal shot budget stage %d"%d.id)
 game.stop_audio();game.queue_free();await process_frame
 print("UPGRADE FLOW: ","PASS" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)
