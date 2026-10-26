extends Node3D
const Geometry = preload("res://campaign/vfx/energy_geometry.gd")
const Burst = preload("res://campaign/vfx/elemental_burst.gd")
const COLORS = {"burst":"75ed9a","gale":"5de9e2","pressure":"74caff","fire":"ff430c","lightning":"fff2bc","super_lightning":"8c38ff","ultimate":"ffdf7f"}
const WAKE_SECONDS := .26
var projectile: Node3D
var key := "normal"
var tone := Color.WHITE
var elapsed := 0.0
var history: Array[Vector3] = []
var history_age: Array[float] = []
var stream: MeshInstance3D
var core: MeshInstance3D
var tip_glow: MeshInstance3D
var particles: CPUParticles3D
var flight_light: OmniLight3D
var flow_material: ShaderMaterial
var launched := false
var finished := false
var fade := 1.0

func _ready() -> void:
 key = str(projectile.ability.get("key","normal"))
 if key == "normal": return
 tone = Color(COLORS.get(key,"75ed9a"))
 flow_material = Geometry.material()
 stream = Geometry.instance(self, flow_material)
 stream.name = "VolumetricElementTrails"
 stream.top_level = true
 core = Geometry.instance(self, flow_material)
 core.name = "EnergyArrowCore"
 # A real 3D tip stays readable when the trail is viewed along its axis.
 tip_glow=MeshInstance3D.new();tip_glow.name="ElementalArrowTip"
 var tip_mesh:=SphereMesh.new();tip_mesh.radius=.032;tip_mesh.height=.064;tip_mesh.radial_segments=12;tip_mesh.rings=6
 tip_glow.mesh=tip_mesh;tip_glow.position.z=-.035;tip_glow.scale=Vector3(.9,.9,1.35)
 tip_glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var tip_mat:=StandardMaterial3D.new();tip_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 tip_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;tip_mat.albedo_color=Color(Color.WHITE.lerp(tone,.65),.8)
 tip_mat.emission_enabled=true;tip_mat.emission=tone;tip_mat.emission_energy_multiplier=.7
 tip_glow.material_override=tip_mat;core.add_child(tip_glow)
 flight_light = OmniLight3D.new()
 flight_light.light_color = tone
 flight_light.light_energy = .65
 flight_light.omni_range = 2.2
 add_child(flight_light)
 _make_particles()

func _reduced_motion() -> bool:
 return is_instance_valid(projectile) and is_instance_valid(projectile.game) and bool(projectile.game.profile.data.settings.get("reduced_motion",false))

func _make_particles() -> void:
 particles = CPUParticles3D.new()
 particles.name = "WorldSpaceElementSparks"
 particles.amount = 40 if key in ["fire","super_lightning","ultimate"] else 24
 particles.lifetime = .38
 particles.local_coords = false
 particles.direction = Vector3.BACK
 particles.spread = 28.0
 particles.initial_velocity_min = .5
 particles.initial_velocity_max = 2.2
 particles.gravity = Vector3(0,1.1 if key=="fire" else -.25,0)
 particles.scale_amount_min = .012
 particles.scale_amount_max = .035 if key=="fire" else .022
 var gradient := Gradient.new()
 gradient.set_color(0,Color(tone,.9));gradient.set_color(1,Color(tone,0))
 particles.color_ramp = gradient
 var curve := Curve.new();curve.add_point(Vector2(0,1));curve.add_point(Vector2(1,0))
 particles.scale_amount_curve = curve
 var sphere := SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=6;sphere.rings=3
 particles.mesh = sphere
 var mat := StandardMaterial3D.new()
 mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
 mat.vertex_color_use_as_albedo = true
 mat.emission_enabled = true;mat.emission=tone;mat.emission_energy_multiplier=1.5
 particles.material_override=mat
 particles.emitting=false
 add_child(particles)

# Called by the spawner only after world position, velocity, and orientation exist.
# Build geometry synchronously so a close hit cannot happen before the first VFX frame.
func launch() -> void:
 if key=="normal" or launched or not is_instance_valid(projectile):return
 if projectile.velocity.length_squared()<.01:return
 launched=true
 var direction:Vector3=projectile.velocity.normalized()
 var seed_length:float=.36 if _reduced_motion() else .72
 for i in range(4):
  history.append(projectile.global_position-direction*seed_length*float(i)/3)
  history_age.append(float(i)*.012)
 particles.visible=not _reduced_motion()
 particles.emitting=not _reduced_motion()
 _draw_energy()
 if not _reduced_motion() and bool(projectile.ability.get("vfx_primary",true)):
  _burst(projectile.global_position,get_parent().get_parent(),true)

func _record_head(delta:float=0.0) -> void:
 if history.is_empty() or history[0].distance_squared_to(projectile.global_position)>.000001:
  history.push_front(projectile.global_position);history_age.push_front(0.0)
 for i in range(history_age.size()):history_age[i]+=delta
 while history.size()>2 and (history_age.back()>.19 or history.size()>24):
  history.pop_back();history_age.pop_back()

func _physics_process(delta:float) -> void:
 if key=="normal" or not is_instance_valid(projectile):return
 if projectile.game.state not in ["playing","finishing"] or not projectile.flying:return
 if not launched:launch()
 _record_head(delta)

func _finish_flight() -> void:
 if finished:return
 if not launched:launch()
 _record_head()
 _draw_energy()
 finished=true;fade=1.0
 core.visible=false;particles.emitting=false;flight_light.light_energy=0

func _process(delta:float) -> void:
 if key=="normal" or not is_instance_valid(projectile):return
 if projectile.game.state=="paused":
  particles.speed_scale=0
  return
 particles.speed_scale=1
 if projectile.game.state not in ["playing","finishing"]:
  stream.visible=false;core.visible=false;particles.emitting=false;flight_light.light_energy=0
  return
 if not launched:launch()
 elapsed+=delta
 flow_material.set_shader_parameter("clock",0.0 if _reduced_motion() else elapsed)
 if not projectile.flying:
  _finish_flight()
  fade=maxf(0,fade-delta/(.12 if _reduced_motion() else WAKE_SECONDS))
  flow_material.set_shader_parameter("strength",fade)
  stream.visible=fade>0
  if fade<=0:
   stream.mesh.clear_surfaces();particles.visible=false
  return
 stream.visible=true;core.visible=true
 tip_glow.scale=Vector3(.9,.9,1.35)*(1.0 if _reduced_motion() else 1.0+.06*sin(elapsed*14))
 particles.visible=not _reduced_motion();particles.emitting=not _reduced_motion()
 _draw_energy()

func _path_length() -> float:
 var total:=0.0
 for i in range(1,history.size()):total+=history[i-1].distance_to(history[i])
 return total

func _sample_path(distance:float) -> Vector3:
 var left:=distance
 for i in range(1,history.size()):
  var segment:float=history[i-1].distance_to(history[i])
  if left<=segment and segment>.00001:return history[i-1].lerp(history[i],left/segment)
  left-=segment
 return history.back() if not history.is_empty() else projectile.global_position

func _draw_energy() -> void:
 var direction:Vector3=projectile.velocity.normalized()
 if direction.length_squared()<.01:return
 var side:Vector3=direction.cross(Vector3.UP if absf(direction.y)<.95 else Vector3.RIGHT).normalized()
 var up:Vector3=side.cross(direction).normalized()
 var reduced:bool=_reduced_motion()
 var clock:float=0.0 if reduced else elapsed
 var mesh:ImmediateMesh=stream.mesh
 mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 # Follow recorded world positions and retain a short wake after contact.
 var length:float=minf(clampf(projectile.velocity.length()*.085,.72,2.5),maxf(.01,_path_length()))
 var strands:int=4 if key in ["fire","super_lightning","ultimate"] else (3 if key=="lightning" else 2)
 if reduced:strands=1;length=minf(length,.65)
 for strand in range(strands):
  var points:=PackedVector3Array()
  for i in range(23):
   var t:float=float(i)/22
   var center:Vector3=_sample_path(t*length)
   var phase:float=t*10-clock*9+strand*TAU/strands
   var spread:float=sin(t*PI)*(.055 if key=="burst" else .13)
   var offset:Vector3=(side*cos(phase)+up*sin(phase))*spread
   if key=="gale":offset=(side*cos(phase)+up*sin(phase))*spread
   elif key=="pressure":offset=(side*cos(phase)+up*sin(phase))*spread*.45
   elif key in ["lightning","super_lightning"]:
    var tick:float=floor(clock*24)
    var amplitude:float=1.35 if key=="super_lightning" else 1.0
    offset=(side*(_noise(i*12.9+tick*7.3+strand*21)-.5)+up*(_noise(i*27.1-tick*9.2+strand*8)-.5))*spread*amplitude*2
   elif key=="fire":
    offset=side*sin(t*13-clock*11+strand*2)*spread*.8+up*(sin(t*19-clock*19+strand)*spread*.7+t*.15)
   elif key=="ultimate":offset=(side*cos(phase)+up*sin(phase))*spread*.9
   if strand==0:offset=Vector3.ZERO
   points.append(center+offset)
  var color:Color=tone.lerp(Color.WHITE,.2) if strand==0 else tone
  if key=="fire":color=Color("ffbd3d") if strand==0 else Color("ff430c")
  if key=="ultimate" and strand%2==1:color=Color("ae86ff")
  var radius:float=.013 if key in ["lightning","super_lightning"] else .017
  if key=="fire":radius=.027 if strand>0 else .017
  if reduced:radius=.012
  Geometry.tube(mesh,points,radius,Color(color,.85))
  if strand==0:Geometry.tube(mesh,points,radius*2.4,Color(tone,.10))
  if key in ["lightning","super_lightning"] and strand>0 and not reduced:
   var fork:=PackedVector3Array()
   for j in range(8):
    var t:float=float(j)/7
    fork.append(points[5+j]+(side*cos(strand*2.1)+up*sin(strand*2.1))*sin(t*PI)*(.20 if key=="super_lightning" else .12))
   Geometry.tube(mesh,fork,.007,Color(color,.65))
 if key=="pressure" and not reduced:
  for ring in range(3):
   var travel:float=fposmod(clock*3+float(ring)/3,1)
   var wave:=PackedVector3Array()
   for j in range(25):
    var angle:float=TAU*float(j)/24
    wave.append(_sample_path(length*travel)+(side*cos(angle)+up*sin(angle))*(.11+travel*.19))
   Geometry.tube(mesh,wave,.013,Color(tone,(1-travel)*.65),false)
 mesh.surface_end();stream.global_transform=Transform3D.IDENTITY
 # Keep the actual equipped ArrowModel readable, with a small bright leading point.
 var cm:ImmediateMesh=core.mesh
 cm.clear_surfaces();cm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 var centerline:=PackedVector3Array([Vector3(0,0,-.08),Vector3.ZERO,Vector3(0,0,.12),Vector3(0,0,.50)])
 Geometry.tube(cm,centerline,.018,Color(Color.WHITE.lerp(tone,.30),.75))
 cm.surface_end()

func _burst(point:Vector3,parent:Node3D,launch_effect:bool=false) -> void:
 if not is_instance_valid(parent):return
 var effect:=Burst.new()
 effect.key=key;effect.tone=tone;effect.launch=launch_effect;effect.reduced=_reduced_motion()
 effect.direction=projectile.velocity.normalized();effect.game=projectile.game
 parent.add_child(effect);effect.global_position=point

func impact(position_world:Vector3,parent:Node3D) -> void:
 if key=="normal":return
 if not projectile.flying:_finish_flight()
 _burst(position_world,parent)
 if not _reduced_motion() and is_instance_valid(projectile.game.hero):
  projectile.game.hero.apply_shockwave_shake(.07 if key in ["super_lightning","ultimate"] else .035)

func _noise(seed_value:float) -> float:
 return fposmod(sin(seed_value)*43758.5453,1.0)

func chain(from:Vector3,to:Vector3,parent:Node3D) -> void:
 if key not in ["lightning","super_lightning","ultimate"] or _reduced_motion():return
 var effect:=Burst.new()
 effect.key=key;effect.tone=tone;effect.game=projectile.game
 effect.link=to-from;effect.linked=true
 parent.add_child(effect);effect.global_position=from
