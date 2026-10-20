extends Node3D
var projectile:Node3D
var key:="normal"
var rank:=1
var sprite:Sprite3D
var hoops:Array[Node3D]=[]
var trail:MeshInstance3D
var elapsed:=0.0
var start_height:=0.0
var tone:=Color("a0ede5")
const COLORS={"burst":"a9e99a","gale":"81eeff","pressure":"b3f7ff","fire":"ff874b","lightning":"ecfff9","super_lightning":"c59dff","ultimate":"ffedb5"}
func _ready() -> void:
 key=str(projectile.ability.get("key","normal"));rank=int(projectile.ability.get("rank",1))
 if key=="normal":return
 tone=Color(COLORS.get(key,"a0ede5"))
 sprite=Sprite3D.new();sprite.texture=load("res://campaign/vfx/"+key+"-flight.png");sprite.pixel_size=.0035
 if key=="burst":
  # The source board depicts three arrows; each physics projectile gets ONE region.
  sprite.region_enabled=true;sprite.region_rect=Rect2(0,24,1024,102)
 sprite.offset.x=-float(sprite.texture.get_width())*.48
 sprite.no_depth_test=false;sprite.shaded=false;sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;sprite.top_level=true;add_child(sprite)
 trail=MeshInstance3D.new();trail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=tone;mat.emission_enabled=true;mat.emission=tone;mat.emission_energy_multiplier=1.1 if key!="super_lightning" else 1.7;trail.material_override=mat;add_child(trail)
 for i in range(3 if key in ["gale","pressure","ultimate"] else 0):
  var hoop:=MeshInstance3D.new();var mesh:=TorusMesh.new();mesh.inner_radius=.21+i*.12;mesh.outer_radius=.225+i*.12;mesh.rings=16;mesh.ring_segments=8
  hoop.mesh=mesh;hoop.rotation.x=PI/2;hoop.position.z=.4+i*.6;hoop.material_override=mat;add_child(hoop);hoops.append(hoop)
 start_height=projectile.global_position.y
func _process(delta:float) -> void:
 if key=="normal" or not is_instance_valid(projectile):return
 if elapsed==0:start_height=projectile.global_position.y
 elapsed+=delta
 if is_instance_valid(sprite):
  var direction:Vector3=projectile.velocity.normalized()
  var camera:Camera3D=get_viewport().get_camera_3d()
  var viewing:Vector3=camera.global_position-projectile.global_position if camera else Vector3.UP
  var normal:Vector3=(viewing-direction*viewing.dot(direction)).normalized()
  if normal.length()<.1:normal=Vector3.UP.cross(direction).normalized()
  var up:Vector3=normal.cross(direction).normalized()
  sprite.global_transform=Transform3D(Basis(direction,up,normal),projectile.global_position)
  sprite.modulate.a=.9 if projectile.flying else maxf(0,.5-(elapsed-float(projectile.age))*.6)
  var pulse:float=1.0 if bool(projectile.game.profile.data.settings.get("reduced_motion",false)) else 1.0+.035*sin(elapsed*10)
  sprite.scale=Vector3.ONE*pulse
 if is_instance_valid(trail):
  var mesh:ImmediateMesh=trail.mesh as ImmediateMesh
  if mesh==null:mesh=ImmediateMesh.new()
  mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
  var spread:float=.12 if key in ["lightning","super_lightning"] else .045
  for ribbon in range(3):
   for i in range(8):
    var z:float=float(i)*.28
    mesh.surface_add_vertex(Vector3(sin(elapsed*7+i+ribbon)*spread,.025*cos(i+ribbon),z))
    mesh.surface_add_vertex(Vector3(sin(elapsed*7+i+1+ribbon)*spread,.025*cos(i+1+ribbon),z+.28))
  mesh.surface_end();trail.mesh=mesh
 for i in range(hoops.size()):
  hoops[i].scale=Vector3.ONE*(1+.06*sin(elapsed*8+i))
  if key=="pressure":
   hoops[i].top_level=true
   var xz:Vector3=Vector3(projectile.velocity.x,0,projectile.velocity.z)
   if xz.length_squared() > 0.001:
    var flat:Vector3=xz.normalized()
    var origin:Vector3=Vector3(projectile.global_position.x,start_height,projectile.global_position.z)-flat*(.4+i*.6)
    hoops[i].global_transform=Transform3D(Basis.looking_at(flat,Vector3.UP)*Basis(Vector3.RIGHT,PI/2),origin)
func impact(position_world:Vector3,parent:Node3D) -> void:
 if key=="normal":return
 var effect:=Sprite3D.new();effect.texture=load("res://campaign/vfx/"+key+"-impact.png");effect.pixel_size=.007
 effect.billboard=BaseMaterial3D.BILLBOARD_ENABLED;effect.shaded=false;effect.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(effect);effect.global_position=position_world;effect.scale=Vector3.ONE*.55
 var tw=effect.create_tween().set_parallel(true);tw.tween_property(effect,"scale",Vector3.ONE*1.3,.3);tw.tween_property(effect,"modulate:a",0.0,.4);tw.chain().tween_callback(effect.queue_free)
