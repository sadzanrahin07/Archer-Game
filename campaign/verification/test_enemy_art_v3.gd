extends SceneTree
# Geometry regression checks; these do not read a player profile or launch gameplay.
const FAMILIES=["moss_slime","briar_slime","seed_spitter","bark_stalker","mirror_wisp","root_warden"]
const Wisp=preload("res://campaign/combat/mirror_wisp.gd")
class PausedReview:
 extends Node
 func is_playing() -> bool:return false
var checks:int=0
func _init() -> void:run.call_deferred()
func require(condition:bool,message:String) -> void:
 checks+=1
 if not condition:
  push_error(message)
  quit(1)
  assert(false,message)
func meshes(node:Node) -> Array[MeshInstance3D]:
 var result:Array[MeshInstance3D]=[]
 if node is MeshInstance3D:result.append(node)
 for child in node.get_children():result.append_array(meshes(child))
 return result
func model_bounds(node:Node) -> AABB:
 var bounds:=AABB();var first:bool=true
 for instance in meshes(node):
  var box:AABB=instance.global_transform*instance.mesh.get_aabb()
  bounds=box if first else bounds.merge(box);first=false
 return bounds
func run() -> void:
 for family in FAMILIES:
  var model:Node3D=load("res://campaign/combat/models/%s-v2.scn"%family).instantiate();root.add_child(model)
  require(model.get_meta("art_pass","")=="combat_fidelity_v3",family+" stale art pass")
  require(model.get_meta("art_revision",0)==3,family+" stale geometry revision")
  require(model.get_meta("family","")==family,family+" wrong family")
  var triangles:int=0;var jelly_found:bool=false
  for instance in meshes(model):
   for surface in range(instance.mesh.get_surface_count()):
    var arrays:Array=instance.mesh.surface_get_arrays(surface)
    triangles+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()/3
    var mat:StandardMaterial3D=instance.mesh.surface_get_material(surface)
    require(mat!=null,family+" missing material")
    if mat.resource_name in ["mint_jelly","briar_jelly"]:
     jelly_found=true
     require(mat.clearcoat_enabled and mat.clearcoat>=.6,family+" loses jelly clearcoat")
     require(mat.roughness<=.3,family+" becomes chalky")
  require(triangles>500 and triangles<6000,family+" triangle budget invalid")
  if family in ["moss_slime","briar_slime"]:require(jelly_found,family+" no jelly material")
  if family=="mirror_wisp":
   var shell:Node3D=model.find_child("Shell",true,false)
   require(shell!=null,"Wisp shell pivot missing")
   var size:Vector3=model_bounds(shell).size
   require(size.x>.75 and size.z>.35 and size.y>1.8,"Wisp housing is flat or too small")
   var pearl:Node3D=model.find_child("CentralPearl",true,false)
   require(pearl!=null and pearl.get_meta("rig_part",false),"Wisp pearl was removed by batching")
   require(model.find_child("FacetLeft",true,false)!=null and model.find_child("FacetRight",true,false)!=null,"Wisp orbit pivots missing")
   var pearl_mat:StandardMaterial3D=meshes(pearl)[0].mesh.surface_get_material(0)
   require(pearl_mat.resource_name=="pearl" and pearl_mat.emission_energy_multiplier<=.5,"Wisp pearl is overexposed")
  print("ART PASS ",family," triangles ",triangles)
  model.free()
 var paused:=PausedReview.new()
 var first:=Wisp.new();var second:=Wisp.new()
 first._build_visuals();second._build_visuals()
 require(first.pearl_material!=null and second.pearl_material!=null,"Wisp pearl material unavailable to charge cue")
 require(first.pearl_material!=second.pearl_material,"Wisp actors share mutable charge material")
 first.pearl_material.emission_energy_multiplier=.4
 require(second.pearl_material.emission_energy_multiplier<.2,"Wisp charging changes another actor")
 first.game=paused;first.visual_clock=3.2
 var clock_before:float=first.visual_clock;var facet_before:Vector3=first.facet_left.position
 first._physics_process(.5)
 require(first.visual_clock==clock_before and first.facet_left.position==facet_before,"Wisp orbit advances while paused")
 first.free();second.free();paused.free()
 print("PASS enemy art v3: ",checks," geometry/material/pivot checks")
 quit(0)
