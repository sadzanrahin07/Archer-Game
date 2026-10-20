extends SceneTree
var failures:Array[String]=[]
var game:Node
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 if not ok:failures.append(message);push_error(message)
func run():
 game=load("res://campaign/main.tscn").instantiate();game.test_mode=true;game.profile.save_path="/tmp/expansion-tests.json";root.add_child(game)
 await process_frame
 var profile=game.profile
 check(profile.data.owned_characters==[1] and profile.data.owned_costumes==[2],"Fresh save starts with Erin Base")
 profile._record(profile.skin_key()).level=11
 for level in [1,19,20,35,49,50,59,60,69,70,79,80,89,90,99,100]:
  profile.data.bow_level=level;profile.data.arrow_level=level
  for power in game.Catalog.POWERS:
   check(profile.power_is_unlocked(str(power.key))==(level>=int(power.level)),"Power threshold %s / %d"%[power.key,level])
 profile.data.bow_level=100;profile.data.arrow_level=19
 check(not profile.power_is_unlocked("burst"),"Lower of both equipped components gates power")
 profile.data.bow_level=35;profile.data.arrow_level=35
 check(profile.selected_power()=="burst","Lv35 equipment / Lv11 archer defaults to Burst")
 var kinds:Dictionary={}
 for chapter in range(20):
  var biomes:Dictionary={};var encounters:Dictionary={}
  for i in range(5):
   var d:Dictionary=game.definitions[chapter*5+i];biomes[d.biome]=true;encounters[str(d.mechanic)+str(d.biome)+str(d.layout_variant)]=true;kinds[d.mechanic]=true
   var expected:int=0
   for material in d.materials:expected+=3 if material in ["stone","rune","master"] else (4 if material=="armor_petals" else 1)
   if d.mechanic=="thread":expected=3
   check(int(d.center_hit_budget)==expected,"Authored projectile minimum %d"%int(d.id))
   check(int(d.arrows)>=expected+2,"Recovery arrows %d"%int(d.id))
  check(biomes.size()>=3 and encounters.size()==5,"Five distinct stage identities in chapter %d"%(chapter+1))
 check(kinds.size()==13,"All 12 encounter types assigned")
 # Exercise real campaign encounters, including their interaction gates.
 var fixtures:Dictionary={}
 for i in range(game.definitions.size()):
  var kind:String=game.definitions[i].mechanic
  if not fixtures.has(kind):fixtures[kind]=i
 for kind in fixtures:
  game.start_stage(fixtures[kind],true);game.state="playing";game.ready_left=0
  await physics_frame
  var course=game.stage
  check(course.encounter.kind==kind,"Runtime encounter matches configuration: "+kind)
  if kind=="rising":
   var t=course.targets[0];t._set_rising_state(t.RisingState.REST)
   check(not t.can_receive_hit(),"Resting rising board blocks hits")
   t._set_rising_state(t.RisingState.EXPOSED);check(t.can_receive_hit(),"Rising board opens")
  elif kind=="clasp":
   check(not course.mechanic_allows_hit(course.targets.back()),"Clasp protects final target")
   course.targets[0].completed=true;course.encounter._physics_process(.1)
   check(course.encounter.gate_open and course.mechanic_allows_hit(course.targets.back()),"Clasp completion opens gate")
  elif kind=="echo":
   check(not course.mechanic_allows_hit(course.targets[2]),"Second symbol pair locked")
   course.targets[0].completed=true;course.targets[1].completed=true
   check(course.mechanic_allows_hit(course.targets[2]),"Matching pair advances")
  elif kind in ["sequence","restoration"]:
   check(course.mechanic_allows_hit(course.targets[0]) and not course.mechanic_allows_hit(course.targets[1]),"Ordered rune puzzle")
  elif kind=="shutter":check(course.encounter.shutters.size()==course.targets.size(),"Physical shutter built for every target")
  elif kind=="perch":check(course.definition.roaming and course.targets.back().final_stone,"Roaming route retains endpoint seal")
  elif kind=="wind":check(course.encounter.ribbons.size()==6,"Wind has readable ribbons")
  elif kind=="thread":
   check(course.targets[2].is_pierceable and course.targets[3].position.z<course.targets[2].position.z,"Thread orbs align in depth")
  elif kind=="armor":check(course.targets.back().is_armor_petals,"Phased monolith assigned to finale")
 # Normal shot still creates only one physical arrow; Burst is three and can be used once.
 game.start_stage(25,true);game.practice=false;game.state="playing";game.ready_left=0
 profile.data.bow_level=100;profile.data.arrow_level=100
 game.selected_power="normal";game.power_armed=false;game.hero.shot_cooldown=0
 var before:int=game.shots;game.hero.instant_shoot();check(game.shots==before+1,"Normal consumes one arrow")
 game.hero.shot_cooldown=0;game.selected_power="burst";game.power_armed=true;game.focus_meter=100
 before=game.shots;game.hero.instant_shoot();check(game.shots==before+3 and game.burst_used,"Burst creates three physical arrows")
 game.power_armed=true;check(game.begin_volley().is_empty(),"Second Burst denied")
 game.selected_power="ultimate";game.power_armed=true
 check(not game.begin_volley().is_empty() and game.super_used,"Super remains available separately from Burst")
 game.power_armed=true;check(game.begin_volley().is_empty(),"Second Super denied")
 game.show_home()
 game.selected_chapter=19;game.selected_stage=99;game.show_levels()
 for i in range(6):await process_frame
 var tabs:=0
 for button in game.ui.find_children("*","Button",true,false):
  if button.text.begins_with("CHAPTER"):tabs+=1
 check(tabs==20,"All 20 chapters accessible in scroll navigation")
 # UI and save regression: no progression/ownership reset during a code update.
 profile.data.unlocked=34;profile.data.selected=34;profile.data.coins=8096
 profile.data.equipped_bow=1;profile.data.equipped_arrow=2;profile.data.owned_bows=[0,1];profile.data.owned_arrows=[0,2]
 profile.data.bow_level=35;profile.data.arrow_level=35;profile.data.bow_levels[1]=35;profile.data.arrow_levels[2]=35
 profile.save_profile()
 var restored=game.Profile.new();restored.save_path=profile.save_path;restored.load_profile()
 check(restored.data.coins==8096 and restored.data.unlocked==34 and restored.power_level()==35,"Save preserves coins, chapter and gear mastery")
 game.stop_audio();game.queue_free();await process_frame
 print("CAMPAIGN EXPANSION: ","PASS" if failures.is_empty() else failures)
 quit(0 if failures.is_empty() else 1)
