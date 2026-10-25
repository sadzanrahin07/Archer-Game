extends SceneTree
const Projectile=preload("res://campaign/projectile.gd")
const GameScene=preload("res://campaign/main.tscn")
var failures:Array[String]=[]
func check(value:bool,message:String) -> void:
 if not value:failures.append(message);push_error(message)
func _init() -> void:run.call_deferred()
func run() -> void:
 var game=GameScene.instantiate();game.test_mode=true;root.add_child(game);await process_frame
 game.profile.data.bow_level=100;game.profile.data.arrow_level=100;game.profile.data.character_level=100
 var manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://campaign/combat/assets/manifests/reference-models-v2.json"))
 for record in manifest:
  var family:String=record.family
  check(record.triangles<6000,"Mobile geometry budget "+family)
  var model:Node3D=load(record.scene).instantiate()
  check(model.get_meta("art_revision")==int(record.revision),"Baked reference revision "+family)
  check(not model.find_children("*","MeshInstance3D",true,false).is_empty(),"Real mesh geometry "+family)
  var materials_ok:=true
  for part in model.find_children("*","MeshInstance3D",true,false):
   for surface in range(part.mesh.get_surface_count()):
    var arrays:Array=part.mesh.surface_get_arrays(surface)
    var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
    for color in colors:
     if color.r+color.g+color.b<.01:materials_ok=false;break
  check(materials_ok,"Merged geometry retains nonblack vertex colors "+family)
  model.free()
 for chapter_index in range(6):
  var family:String=manifest[chapter_index].family
  for local in range(5):
   var id:int=55+chapter_index*5+local;game.start_stage(id,true);await process_frame
   var manager=game.stage.combat_manager
   check(manager.total_enemies_expected==local+1,"Family count grows one through five ID%d"%id)
   check(game.stage.targets.is_empty(),"No puzzle targets in combat ID%d"%id)
   for enemy in manager.enemies_alive:
    check(enemy.family==family and enemy.combat_visuals_mode=="reference_3d_v2","Correct reference rig ID%d"%id)
    check(enemy.body_mesh.get_meta("family")==family,"Unique model identity ID%d"%id)
    check(not enemy.direction_sprite.visible,"No flat billboard substitutes ID%d"%id)
    check(enemy.recovery_time>=1.35,"Readable charged counter window ID%d"%id)
 # Actual swept projectile must recognize the visual weak-point collider boundary.
 for id in [55,80]:
  game.start_stage(id,true);await process_frame;game.state="playing"
  var enemy=game.stage.combat_manager.enemies_alive[0];enemy.set_physics_process(false)
  var initial:float=enemy.hp;var forward:Vector3=-enemy.global_basis.z
  var arrow=Projectile.new();arrow.game=game;arrow.owner_body=game.hero;arrow.power=10;arrow.shot_id=700+id;arrow.score_id="qa-reference-"+str(id)
  game.airborne=1;game.stage.add_child(arrow);arrow.global_position=enemy.vital_shape.global_position+forward*2;arrow.velocity=-forward*80
  for frame in range(5):await physics_frame
  check(is_equal_approx(enemy.hp,initial-12.5),"Physical weak point applies 1.25 damage ID%d"%id)
 print("REFERENCE MODEL / CURRICULUM CHECKS: ","PASS" if failures.is_empty() else failures)
 game.stop_audio();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
