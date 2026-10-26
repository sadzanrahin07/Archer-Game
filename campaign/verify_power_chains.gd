extends SceneTree
class Target extends StaticBody3D:
 var completed:=false
 var hits:=0
 var total:=0.0
 func campaign_secondary_hit(amount:float,_event:int)->bool:
  hits+=1;total+=amount;return true
class Stage extends Node3D:
 var targets:Array=[]
class Profile extends RefCounted:
 var data:Dictionary={"settings":{"reduced_motion":false}}
class Game extends Node:
 var stage:Stage
 var state:="paused"
 var profile:=Profile.new()
 var hero:Node3D
 var secondary_damage:=false
 func is_combat()->bool:return false
func _initialize():run.call_deferred()
func run():
 var game:=Game.new();root.add_child(game)
 var stage:=Stage.new();game.stage=stage;game.add_child(stage)
 for i in range(4):
  var target:=Target.new();target.collision_layer=4
  var collider:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=.6;collider.shape=sphere
  target.add_child(collider);stage.add_child(target);target.position=Vector3(i*2,1,0);stage.targets.append(target)
 var arrow=load("res://campaign/projectile.gd").new();arrow.game=game;arrow.ability={"key":"super_lightning","rank":1}
 arrow.set_physics_process(false);stage.add_child(arrow);arrow.set_physics_process(false);arrow.vfx.set_process(false);arrow.vfx.set_physics_process(false)
 await physics_frame;await physics_frame
 arrow._apply_secondary(stage.targets[0],stage.targets[0].global_position)
 for i in range(1,4):assert(stage.targets[i].hits==1,"Every chain target must take exactly one hit")
 assert(stage.targets[0].hits==0,"Primary must be excluded from chained raycasts")
 var links:Array=[]
 for effect in stage.get_children():
  if effect.get_script()==load("res://campaign/vfx/elemental_burst.gd") and effect.linked:links.append(effect)
 assert(links.size()==3,"Three visible chain arcs must be created")
 game.state="playing"
 await create_timer(.8).timeout;await process_frame
 for link in links:assert(not is_instance_valid(link),"Chain arcs must expire")
 game.queue_free();await process_frame
 print("SUPER LIGHTNING CHAIN DAMAGE + ARCS + CLEANUP PASS")
 quit()
