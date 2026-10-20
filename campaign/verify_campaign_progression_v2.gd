extends SceneTree
const Profile=preload("res://campaign/profile.gd")
const Catalog=preload("res://campaign/catalog.gd")
var failures:Array=[]
func _initialize():run.call_deferred()
func check(value:bool,message:String):
 if not value:failures.append(message);push_error(message)
func run():
 var game=load("res://campaign/main.tscn").instantiate();game.test_mode=true;game.profile.save_path="/tmp/progression2-ui.json";root.add_child(game);await process_frame
 for kind in ["bow","arrow","character"]:
  for tier in range(4):
   var previous:int=0
   for level in range(1,100):
    var cost:int=Catalog.upgrade_price(kind,level,tier)
    check(cost>previous,"Strictly increasing %s tier %d / %d"%[kind,tier,level]);previous=cost
 for rating in [1,2]:
  var p=Profile.new();p.save_path="/tmp/progression2-economy-%d.json"%rating
  game.profile=p
  var minimum:int=int(p.data.coins);var spent:int=0
  for d in game.definitions:
   var id:int=d.id;var tier:int=d.required_tier;var goal:int=d.required_gear_level
   check(goal==Catalog.stage_gear_goal(id),"Roadmap matches authored stage %d"%id)
   p.data.unlocked=id
   for kind in ["bow","arrow"]:
    var item:int=tier if kind=="bow" else [0,2,1,3][tier]
    if not p.is_owned(kind,item):
     var before:int=p.data.coins
     check(p.buy_equipment(kind,item),"%d-star purchase %s stage %d"%[rating,kind,id]);spent+=before-int(p.data.coins)
     check(int(p.data[kind+"_levels"][item])==Catalog.tier_start(tier),"Promotion starts at prior mastery cap")
    if kind=="bow":p.equip_bow(item)
    else:p.equip_arrow(item)
    while int(p.data[kind+"_level"])<goal:
     p.data[kind+"_xp"][item]=0
     var before:int=p.data.coins
     if not p.upgrade(kind):check(false,"%d-star funded %s upgrade before stage %d"%[rating,kind,id]);break
     spent+=before-int(p.data.coins)
   while p.level()<goal:
    p._record(p.skin_key()).xp=0
    var before:int=p.data.coins
    if not p.upgrade_character():check(false,"%d-star funded character upgrade before stage %d"%[rating,id]);break
    spent+=before-int(p.data.coins)
   minimum=mini(minimum,int(p.data.coins))
   check(p.power_level()>=int(d.minimum_power_level),"Power available in chapter %d"%d.chapter_number)
   check(game.shot_budget(d)<=int(d.arrows),"Normal-shot budget stage %d"%id)
   var reward:Dictionary=p.reward(id,rating,1,20,"economy-v2:%d"%id)
   check(int(reward.coins)>0,"Stage pays coins")
  check(p.power_level()==100 and p.level()==100,"Final chapter reaches full mastery")
  print("ECONOMY V2 ",rating," star: zero replays, minimum coins ",minimum,", spent ",spent,", final coins ",p.data.coins)
 # Existing saves gain only the difference in already-earned first-clear rewards, once.
 var legacy=Profile.new();legacy.save_path="/tmp/progression2-migration.json";legacy.data.coins=97;legacy.data.stars={"0":3,"70":1};legacy.data.owned_bows=[0,1,2];legacy.data.bow_levels=[20,40,60,1];legacy.data.equipped_bow=2;legacy.data.bow_level=60
 var old:Dictionary=legacy.data.duplicate(true);old.erase("economy_revision")
 legacy._apply_campaign_economy(old);var coins:int=legacy.data.coins
 check(coins>97 and legacy.data.bow_levels==[20,40,60,1],"Migration preserves levels and reprices earned rewards")
 legacy._apply_campaign_economy(legacy.data.duplicate(true));check(int(legacy.data.coins)==coins,"Migration cannot pay twice")
 game.profile=legacy;legacy.data.unlocked=99;game.selected_chapter=14;game.selected_stage=70
 for resolution in [Vector2i(640,360),Vector2i(844,390),Vector2i(1280,720)]:
  root.size=resolution;game._refresh_layout();game.show_levels()
  for i in range(8):await process_frame
  var scroller:ScrollContainer=game.ui.find_child("ChapterScroll",true,false)
  check(scroller!=null and scroller.get_h_scroll_bar().max_value>scroller.get_h_scroll_bar().page,"Chapter strip overflows and scrolls at %s"%resolution)
  scroller.scroll_horizontal=0
  game.ui.find_child("NextChapters",true,false).pressed.emit()
  check(scroller.scroll_horizontal>0,"Next-page chapter button moves viewport")
  var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
  var before:int=scroller.scroll_horizontal
  game.menu_builder._chapter_scroll_input(wheel,scroller,{"moved":false})
  check(scroller.scroll_horizontal>before,"Mouse wheel moves chapter strip")
  var finger:=InputEventScreenDrag.new();finger.relative=Vector2(-100,0);before=scroller.scroll_horizontal
  game.menu_builder._chapter_scroll_input(finger,scroller,{"moved":false})
  check(scroller.scroll_horizontal>before,"Touch dragging moves chapter strip")
 # Exercise real entry gating and chapter power selection using isolated saves.
 legacy.save_path="/tmp/progression2-entry.json";legacy.data.unlocked=99
 game.test_mode=false;legacy.data.bow_level=99;legacy.data.arrow_level=99
 game.show_home();game.start_stage(95,false)
 check(game.page=="levels","Final chapter blocks entry before both weapons reach 100")
 legacy.data.bow_level=100;legacy.data.arrow_level=100
 legacy.data.equipped_bow=3;legacy.data.equipped_arrow=3
 legacy.data.owned_bows=[0,1,2,3];legacy.data.owned_arrows=[0,1,2,3]
 legacy.data.bow_levels[3]=100;legacy.data.arrow_levels[3]=100
 legacy.data.chapter_run={};legacy.data.stars={}
 for id in range(95):legacy.data.stars[str(id)]=1
 game.start_stage(95,false)
 check(game.selected_stage==95 and game.selected_power=="ultimate","Final chapter equips Aurora at full mastery")
 game.test_mode=true
 game.stop_audio();game.queue_free();await process_frame
 print("CAMPAIGN PROGRESSION V2: ","PASS" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)
