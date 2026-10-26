extends SceneTree
const POWERS=["burst","gale","pressure","fire","lightning","super_lightning","ultimate"]
# Verify the real project flight effect, including hits before any render callback.
var VFX=load("res://campaign/power_vfx.gd")
class Profile extends RefCounted:
 var data:Dictionary={"settings":{"reduced_motion":false}}
class Game extends Node:
 var state:="playing"
 var profile:=Profile.new()
 var stage:Node3D
 var hero:Node3D
class Projectile extends Node3D:
 var game:Game
 var ability:Dictionary={}
 var velocity:=Vector3(0,0,-70)
 var flying:=true
func _initialize():run.call_deferred()
func fixture(key:String)->Dictionary:
 var game:=Game.new();root.add_child(game)
 var stage:=Node3D.new();game.stage=stage;game.add_child(stage)
 var p:=Projectile.new();p.game=game;p.ability={"key":key,"vfx_primary":true};stage.add_child(p)
 p.position=Vector3(1,2,3)
 var vfx=VFX.new();vfx.projectile=p;p.add_child(vfx);vfx.set_process(false);vfx.set_physics_process(false)
 return {"game":game,"p":p,"vfx":vfx}
func run():
 var normal:=fixture("normal");normal.vfx.launch();assert(normal.vfx.stream==null and normal.vfx.core==null);normal.game.queue_free()
 var signatures:Dictionary={}
 for key in POWERS:
  var f:=fixture(key);var game=f.game;var p=f.p;var v=f.vfx
  v.launch()
  assert(v.launched and v.stream.mesh.get_surface_count()==1 and v.core.mesh.get_surface_count()==1,"Power must have geometry before its first render: "+key)
  assert(v.history.size()>=4 and v.particles.emitting)
  var initial=v.stream.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  signatures[key]=hash(initial)
  v._process(.08)
  assert(initial!=v.stream.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"Elemental geometry must animate: "+key)
  var elapsed:float=v.elapsed;game.state="paused";v._process(.3)
  assert(v.elapsed==elapsed and v.particles.speed_scale==0,"Pause freezes particles and geometry")
  game.state="playing";game.profile.data.settings.reduced_motion=true;v._process(.02)
  assert(not v.particles.emitting and not v.particles.visible and v.flow_material.get_shader_parameter("clock")==0.0)
  game.profile.data.settings.reduced_motion=false;v._process(.02)
  assert(v.particles.emitting and v.particles.speed_scale==1)
  game.queue_free()
  # A fresh projectile hits in one physics step, before any _process callback.
  f=fixture(key);game=f.game;p=f.p;v=f.vfx;v.launch()
  p.global_position+=p.velocity*.018;p.flying=false
  v.impact(p.global_position,game.stage)
  assert(v.finished and v.stream.visible and not v.core.visible and v.stream.mesh.get_surface_count()==1,"Close hit must retain a visible wake: "+key)
  var contact_vertices=v.stream.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  var max_distance:=0.0
  for vertex in contact_vertices:max_distance=maxf(max_distance,vertex.distance_to(p.global_position))
  assert(max_distance>.6,"Wake must have world-space extent after contact")
  for i in range(5):v._process(.08)
  assert(not v.stream.visible and v.stream.mesh.get_surface_count()==0 and not v.particles.emitting and v.flight_light.light_energy==0,"Flight effects must clean up after bounded fade")
  game.queue_free();await process_frame
  print("POWER VISIBLE AT LAUNCH + MOTION + PAUSE + REDUCED + CLOSE HIT WAKE + CLEANUP PASS: ",key)
 var unique:Array=[]
 for signature in signatures.values():
  if not unique.has(signature):unique.append(signature)
 assert(unique.size()==POWERS.size(),"Each power needs a distinct 3D flight signature")
 await process_frame;await process_frame
 print("ALL SIX ELEMENTAL POWERS + BURST VISIBILITY PASS")
 quit()
