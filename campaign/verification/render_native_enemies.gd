extends SceneTree
# Native Godot material review. Uses baked runtime meshes, no game or profile.
const FAMILIES=["moss_slime","briar_slime","seed_spitter","bark_stalker","mirror_wisp","root_warden"]
const OUT="/Users/sadzanrahin/Documents/Codex/2026-10-13/i-x20/outputs/combat-polish-2026-10-23/"
func _init() -> void:run.call_deferred()
func bounds(node:Node3D,transform:Transform3D=Transform3D.IDENTITY) -> AABB:
 var result:=AABB();var first:=true
 var xform:Transform3D=transform*node.transform
 if node is MeshInstance3D:
  result=xform*node.mesh.get_aabb();first=false
 for child in node.get_children():
  if child is Node3D:
   var box:AABB=bounds(child,xform)
   if box.size.length()>.0001:result=box if first else result.merge(box);first=false
 return result
func capture(family:String,angle:float=25,suffix:String="") -> void:
 var viewport:=SubViewport.new();viewport.size=Vector2i(800,800);viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var scene:=Node3D.new();viewport.add_child(scene)
 var environment:=WorldEnvironment.new();var env:=Environment.new()
 env.background_mode=Environment.BG_COLOR;env.background_color=Color("182b2e")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("c9e5df");env.ambient_light_energy=.65
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.environment=env;scene.add_child(environment)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-28,0);sun.light_energy=1.25;scene.add_child(sun)
 var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-10,145,0);fill.light_color=Color("aaa7e0");fill.light_energy=.65;scene.add_child(fill)
 var model:Node3D=load("res://campaign/combat/models/%s-v2.scn"%family).instantiate();scene.add_child(model)
 model.rotation.y=deg_to_rad(angle)
 var box:AABB=bounds(model);var center:Vector3=box.get_center()
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=maxf(box.size.y,box.size.x)*1.25;scene.add_child(camera)
 camera.position=center+Vector3(0,.22,4);camera.look_at(center);camera.current=true
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 var result:Error=viewport.get_texture().get_image().save_png(OUT+family+"-native-v3"+suffix+".png")
 assert(result==OK);print("NATIVE RENDER ",family,suffix)
 viewport.queue_free();await process_frame
func run() -> void:
 root.size=Vector2i(64,64)
 for family in FAMILIES:await capture(family)
 await capture("mirror_wisp",0,"-front")
 await capture("mirror_wisp",90,"-side")
 print("PASS native enemy review")
 quit()
