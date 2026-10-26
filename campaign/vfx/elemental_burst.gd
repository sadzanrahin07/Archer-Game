extends Node3D
const Geometry=preload("res://campaign/vfx/energy_geometry.gd")
var game:Node
var key:="fire"
var tone:=Color.WHITE
var direction:=Vector3.FORWARD
var launch:=false
var reduced:=false
var linked:=false
var link:=Vector3.ZERO
var elapsed:=0.0
var duration:=.62
var geometry:MeshInstance3D
var material:ShaderMaterial
var rays:Array[Vector3]=[]
var light:OmniLight3D
func _ready() -> void:
 name="ElementalLaunch" if launch else "ElementalImpact"
 process_mode=Node.PROCESS_MODE_PAUSABLE
 duration=.24 if linked else (.18 if launch else (.16 if reduced else .62))
 material=Geometry.material();geometry=Geometry.instance(self,material)
 var rng:=RandomNumberGenerator.new();rng.seed=get_instance_id()
 var count:int=5 if launch else (4 if reduced else 12)
 for i in range(count):
  var ray:=Vector3(rng.randf_range(-1,1),rng.randf_range(-.6,1),rng.randf_range(-1,1)).normalized()
  rays.append(ray)
 light=OmniLight3D.new();light.light_color=tone;light.omni_range=2.7
 light.light_energy=.35 if launch else 1.1
 add_child(light)
func _process(delta:float) -> void:
 if is_instance_valid(game) and game.state=="paused":return
 elapsed+=delta
 if elapsed>=duration:queue_free();return
 var phase:float=elapsed/duration
 var fade:float=pow(1-phase,1.7)
 material.set_shader_parameter("clock",elapsed)
 light.light_energy=fade*(.3 if launch else .95)
 var mesh:ImmediateMesh=geometry.mesh
 mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 if linked:
  var path:=PackedVector3Array()
  var axis:Vector3=link.normalized().cross(Vector3.UP).normalized()
  for i in range(17):
   var t:float=float(i)/16
   path.append(link*t+axis*sin(i*7.13+floor(elapsed*30)*3)*sin(t*PI)*.18)
  Geometry.tube(mesh,path,.018,Color(tone,fade),false)
  mesh.surface_end()
  return
 for i in range(rays.size()):
  var ray:Vector3=rays[i]
  var size:float=.23 if launch else (.15 if reduced else .85)
  var front:Vector3=ray*size*(1-pow(1-phase,2))
  if key=="fire":front.y+=phase*phase*.32
  var points:=PackedVector3Array()
  for j in range(6):
   var t:float=float(j)/5
   var pos:Vector3=front-ray*t*size*.25*(1-phase)
   if key in ["lightning","super_lightning","ultimate"]:
    var axis:Vector3=ray.cross(Vector3.UP).normalized()
    pos+=axis*sin(j*2.4+i+floor(elapsed*20))*sin(t*PI)*.10*(1-phase)
   points.append(pos)
  var color:Color=tone
  if key=="ultimate" and i%2==0:color=Color("ad7fff")
  Geometry.tube(mesh,points,.025*(1-phase),Color(color,fade))
 # Rippling shock front intersects the scene in 3D rather than covering it with a sprite.
 if not reduced:
  var axis:Vector3=direction.cross(Vector3.UP if absf(direction.y)<.9 else Vector3.RIGHT).normalized()
  var other:Vector3=direction.cross(axis).normalized()
  var wave:=PackedVector3Array()
  var radius:float=.06+phase*(.55 if launch else (.65 if key in ["burst","gale"] else .85))
  for i in range(41):
   var angle:float=TAU*float(i)/40
   var ripple:float=1+sin(angle*7+elapsed*12)*.025
   wave.append((axis*cos(angle)+other*sin(angle))*radius*ripple)
  Geometry.tube(mesh,wave,.014*(1-phase),Color(tone,fade*(.22 if launch else .45)),false)
 mesh.surface_end()
