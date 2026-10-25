extends SceneTree
const Visuals=preload("res://campaign/combat/enemy_visuals.gd")
const FAMILIES=["moss_slime","briar_slime","seed_spitter","bark_stalker","mirror_wisp","root_warden"]
const REVIEW="/Users/sadzanrahin/Documents/Codex/2026-10-13/i-x20/outputs/combat-polish-2026-10-23/"
func _init() -> void:run.call_deferred()
func assign_owner(node:Node,owner_node:Node) -> void:
 for c in node.get_children():c.owner=owner_node;assign_owner(c,owner_node)
func render_geometry(node:Node3D,records:Array) -> void:
 if node is MeshInstance3D and node.mesh:
  for surface in range(node.mesh.get_surface_count()):
   var mat:Material=node.material_override if node.material_override else node.mesh.surface_get_material(surface)
   var arrays:Array=node.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
   var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
   var count:int=indices.size() if not indices.is_empty() else vertices.size()
   for i in range(0,count,3):
    var points:Array=[]
    for j in range(3):
     var id:int=indices[i+j] if not indices.is_empty() else i+j
     var v:Vector3=node.global_transform*vertices[id];points.append([v.x,v.y,v.z])
    var color:Color=mat.albedo_color
    if not colors.is_empty():color*=colors[indices[i] if not indices.is_empty() else i]
    records.append([points,[color.r,color.g,color.b],float(mat.emission_energy_multiplier) if mat.emission_enabled else 0.0])
 for c in node.get_children():
  if c is Node3D:render_geometry(c,records)
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://campaign/combat/models"))
 var manifest:Array=[]
 for family in FAMILIES:
  var model:Node3D=Visuals.build(family);root.add_child(model);assign_owner(model,model)
  var packed:=PackedScene.new();var result:int=packed.pack(model)
  assert(result==OK)
  var path:String="res://campaign/combat/models/%s-v2.scn"%family
  assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
  var doc:=GLTFDocument.new();var state:=GLTFState.new()
  assert(doc.append_from_scene(model,state)==OK)
  assert(doc.write_to_filesystem(state,"res://campaign/combat/models/%s-v2.glb"%family)==OK)
  var geometry:Array=[];render_geometry(model,geometry)
  var f:=FileAccess.open(REVIEW+family+"-geometry.json",FileAccess.WRITE);f.store_string(JSON.stringify(geometry));f.close()
  manifest.append({"family":family,"scene":path,"triangles":geometry.size(),"revision":3,"art_pass":"combat_fidelity_v3","source":"res://campaign/combat/enemy_visuals.gd","reference":"res://campaign/combat/assets/enemies/%s-directions-v1.png"%family})
  print("BAKED ",family," triangles ",geometry.size())
  model.free()
 var f:=FileAccess.open("res://campaign/combat/assets/manifests/reference-models-v2.json",FileAccess.WRITE);f.store_string(JSON.stringify(manifest,"  "));f.close()
 quit()
