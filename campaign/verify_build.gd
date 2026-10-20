extends SceneTree
var g:Node
func _initialize():run.call_deferred()
func run():
 g=load("res://campaign/main.tscn").instantiate();g.test_mode=true;g.profile.save_path="/tmp/archer_build_qa.json";root.add_child(g)
 g.profile.data.owned_characters=[0,1,2,3];g.profile.data.owned_costumes=[0,1,2,3,4,5]
 for character in range(4):
  g.profile.data.character=character;g.profile.data.costume=2;g._spawn_hero();g.start_stage(5,true);g.state="playing"
  g.hero.aim_held=true
  for frame in range(30):await physics_frame
  var original:Vector3=g.hero.global_position;g.hero.touch_move=Vector2(0,-1)
  g.hero.drawing=true;g.hero.draw_elapsed=g.profile.draw_time()
  for frame in range(8):await physics_frame
  assert(g.hero.global_position.distance_to(original)<.02,"Aiming must plant feet")
  g.hero.touch_move=Vector2.ZERO
  for target in g.stage.targets:
   g.hero.camera.look_at(target.global_position+Vector3(0,0,.2));g.hero.draw_elapsed=g.profile.draw_time();g.hero._fire()
   for frame in range(180):
    await physics_frame
    if target.completed:break
   assert(target.completed,"Every character must hit real course targets")
  assert(g.completed==6 and g.shots==6 and g.hits==6)
  assert(g.state=="finishing","Final impact must not show instant results")
  await create_timer(1.4).timeout;assert(g.state=="results")
  print("REAL ARROWS AND POSE PASS ",character)
 g.profile.data.character=1;g.profile.data.costume=2
 g.profile.data.skin_progress[g.profile.skin_key()]={"level":100,"xp":0,"total_xp":90000}
 for key in ["burst","gale","pressure","fire","lightning","super_lightning","ultimate"]:
  g._spawn_hero();g.start_stage(0,true);g.state="playing";g.focus_meter=100;g.arrows=10;g.selected_power=key
  g.hero.aim_held=true;g.hero.drawing=true;g.hero.draw_elapsed=g.profile.draw_time()
  for frame in range(30):await physics_frame
  g.hero.camera.look_at(g.stage.targets[0].global_position+Vector3(0,0,.2));g.trigger_power();assert(g.power_armed)
  var before:int=g.impact_sound_count;g.hero._fire();assert(g.shots==(3 if key=="burst" else 1))
  for frame in range(100):
   await physics_frame
   if g.completed==1:break
  assert(g.completed==1 and g.impact_sound_count==before+1,"One impact sound for one accepted final contact")
  assert(g.state=="finishing" and g.page=="hud")
  await create_timer(.4).timeout;assert(g.state=="finishing")
  await create_timer(1).timeout;assert(g.state=="results")
  print("POWER, AMMO, IMPACT AND DELAY PASS ",key)
 g.stop_audio();await create_timer(.25).timeout;g.queue_free();await process_frame
 print("INTEGRATED BUILD VERIFICATION PASS");quit()
