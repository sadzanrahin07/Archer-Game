extends SceneTree
func _initialize(): run.call_deferred()
func run():
 var game=load("res://campaign/main.tscn").instantiate()
 game.test_mode=true
 game.profile.save_path="/tmp/archer_vfx_qa.json"
 root.add_child(game)
 await process_frame
 game.profile.data.purchased_powers=["burst","gale","pressure","fire","lightning","super_lightning","ultimate"]
 for key in ["burst","gale","pressure","fire","lightning","super_lightning","ultimate"]:
  game.start_stage(0,true)
  await process_frame
  game.ready_left=0;game.state="playing";game.focus_meter=100;game.arrows=10
  game.selected_power=key;game.power_armed=true
  game.hero.aim_held=true
  game.hero.drawing=true;game.hero.draw_elapsed=game.profile.draw_time();game.hero.shot_cooldown=0
  game.hero.camera.look_at(game.stage.targets[0].global_position+Vector3(0,0,.2))
  game.hero._fire()
  var found=false
  for child in game.stage.get_children():
   if child.get_script()==load("res://campaign/projectile.gd"):
    found=true
    assert(child.vfx.stream!=null and child.vfx.core!=null and child.vfx.particles!=null)
    child.vfx._process(.08)
    assert(child.vfx.stream.mesh.get_surface_count()==1)
    assert(child.vfx.find_children("*","Sprite3D",true,false).is_empty())
    assert(child.vfx.stream.top_level and not child.vfx.particles.local_coords)
    var original_geometry=child.vfx.stream.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    child.vfx._process(.08)
    assert(original_geometry!=child.vfx.stream.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "Geometry must change continuously")
    var clock=child.vfx.elapsed
    game.state="paused";child.vfx._process(.2)
    assert(child.vfx.elapsed==clock)
    game.state="playing"
    game.profile.data.settings.reduced_motion=true;child.vfx._process(.1)
    assert(child.vfx.flow_material.get_shader_parameter("clock")==0.0)
    assert(not child.vfx.particles.emitting)
    game.profile.data.settings.reduced_motion=false
  assert(found,"Power must spawn a real projectile")
  for i in range(180):
   await physics_frame
   if game.completed>0:break
  assert(game.completed>0,"Power must hit and destroy the course target: "+key)
  var impacts=game.stage.find_children("ElementalImpact*","Node3D",true,false)
  await create_timer(.85).timeout
  await process_frame
  for effect in impacts:
   if is_instance_valid(effect):
    print("PENDING EFFECT ",effect.elapsed," / ",effect.duration)
    assert(false,"Impact VFX must clean up")
  print("VOLUMETRIC VFX + GEOMETRY MOTION + PAUSE + REDUCED MOTION + REAL HIT + CLEANUP PASS: ",key)
 await create_timer(1.7).timeout
 game.stop_audio();game.queue_free();await process_frame
 await process_frame
 print("POWER REGRESSION PASS")
 quit()
