extends Node3D
# Arrow-local presentation only; never changes power eligibility or damage.
const COLORS={"burst":"9ceba2","gale":"81eeff","pressure":"a7edff","fire":"ff9853","lightning":"dffff3","super_lightning":"c59dff","ultimate":"ffe7ad"}
const Geometry=preload("res://campaign/vfx/energy_geometry.gd")
var charge_strands:MeshInstance3D
var flow_material:ShaderMaterial
var player:Node3D
var last_key:="normal"
var charge_time:=0.0
var release_time:=0.0
var release_duration:=.14
var released_position:=Vector3.ZERO
var released_direction:=Vector3.FORWARD
var charge_root:Node3D
var tip_core:MeshInstance3D
var flare_h:MeshInstance3D
var flare_v:MeshInstance3D
var shaft_beam:MeshInstance3D
var release_spike:MeshInstance3D
var wisps:Array[MeshInstance3D]=[]
var charge_light:OmniLight3D
var core_material:StandardMaterial3D
var energy_material:StandardMaterial3D
var bow_material:ShaderMaterial
var ready_latched:=false
var ready_pulse:=0.0
func _material(energy:float) -> StandardMaterial3D:
 var mat:=StandardMaterial3D.new()
 mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 mat.emission_enabled=true;mat.emission_energy_multiplier=energy
 return mat
func _mesh(mesh:Mesh,material:Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 charge_root.add_child(node);return node
func _ready() -> void:
 name="BowPowerCharge";top_level=true;visible=false
 charge_root=Node3D.new();add_child(charge_root)
 core_material=_material(1.3);energy_material=_material(.8)
 flow_material=Geometry.material();charge_strands=Geometry.instance(charge_root,flow_material)
 var tip:=PrismMesh.new();tip.size=Vector3(.035,.09,.035)
 tip_core=_mesh(tip,core_material);tip_core.rotation.x=-PI*.5
 var horizontal:=BoxMesh.new();horizontal.size=Vector3(.14,.008,.004)
 flare_h=_mesh(horizontal,core_material)
 var vertical:=BoxMesh.new();vertical.size=Vector3(.008,.14,.004)
 flare_v=_mesh(vertical,core_material)
 var shaft:=CylinderMesh.new();shaft.top_radius=.009;shaft.bottom_radius=.012;shaft.height=.58;shaft.radial_segments=8
 shaft_beam=_mesh(shaft,energy_material);shaft_beam.rotation.x=PI*.5;shaft_beam.position.z=.29
 for i in range(24):
  var particle:=BoxMesh.new();particle.size=Vector3(.007,.007,.014)
  wisps.append(_mesh(particle,energy_material))
 var spike:=PrismMesh.new();spike.size=Vector3(.045,.28,.045)
 release_spike=_mesh(spike,core_material);release_spike.rotation.x=-PI*.5;release_spike.visible=false
 charge_light=OmniLight3D.new();charge_light.omni_range=1.3;charge_light.light_energy=0;charge_light.shadow_enabled=false;add_child(charge_light)
 bow_material=ShaderMaterial.new();bow_material.shader=load("res://campaign/bow_charge.gdshader")
 if is_instance_valid(player):player.attack_release.connect(_on_attack_release)
func _audio() -> Node:
 return player.game._power_audio()
func _set_key(key:String,_kind:String) -> void:
 last_key=key
 var tone:=Color(COLORS.get(key,"a7edff"))
 energy_material.albedo_color=Color(tone,.55);energy_material.emission=tone
 core_material.albedo_color=Color(Color.WHITE.lerp(tone,.45),.75);core_material.emission=tone
 charge_light.light_color=tone;bow_material.set_shader_parameter("tone",tone)
func _align(direction:Vector3,point:Vector3) -> void:
 var heading:=direction.normalized() if direction.length_squared()>.001 else Vector3.FORWARD
 var up:=Vector3.RIGHT if absf(heading.dot(Vector3.UP))>.98 else Vector3.UP
 global_position=point;charge_root.global_transform=Transform3D(Basis.looking_at(heading,up),point)
 charge_light.global_position=point
func _on_attack_release(key:String,_quick:bool) -> void:
 if key=="normal" or not is_instance_valid(player) or player.showcase or not player.game.is_playing():return
 _set_key(key,"release")
 release_duration=.08 if bool(player.game.profile.data.settings.get("reduced_motion",false)) else .20
 release_time=release_duration;charge_time=0;ready_latched=false;ready_pulse=0
 released_position=player.last_shot_origin;released_direction=player.last_shot_direction
 _align(released_direction,released_position);visible=true;_clear_bow()
func _clear_bow() -> void:
 if is_instance_valid(player) and is_instance_valid(player.bow_hand_node) and player.bow_hand_node.material_overlay==bow_material:player.bow_hand_node.material_overlay=null
func _reset_effect() -> void:
 visible=false;charge_time=0;release_time=0;ready_latched=false;ready_pulse=0
 charge_light.light_energy=0;_clear_bow()
 if is_instance_valid(player) and is_instance_valid(player.game):
  var audio:Node=player.game.get_node_or_null("PowerAudio")
  if audio:audio.stop_charge()
func _process(delta:float) -> void:
 if not is_instance_valid(player) or not is_instance_valid(player.game):return
 var game:Node=player.game
 if player.showcase or game.state not in ["playing","paused"]:_reset_effect();return
 if game.state=="paused":return
 var key:String=game.selected_power
 var charging:bool=player.drawing and game.power_armed and key!="normal" and game.profile.power_is_unlocked(key)
 var reduced:bool=bool(game.profile.data.settings.get("reduced_motion",false))
 if charging:
  if key!=last_key or release_time>0 or charge_time==0:
   _set_key(key,"charge");ready_latched=false;ready_pulse=0;_audio().begin_charge(key)
  charge_time+=delta;release_time=0
  var ratio:float=clampf(player.draw_elapsed/game.profile.draw_time(),0,1)
  if ratio>=.95 and not ready_latched:
   ready_latched=true;ready_pulse=.16;_audio().charge_ready(key)
  ready_pulse=maxf(0,ready_pulse-delta)
  _align(player.arrow_direction,player.arrow_tip_world);visible=true
  _draw_charge(ratio,reduced)
  tip_core.visible=true;release_spike.visible=false;shaft_beam.visible=true
  tip_core.scale=Vector3.ONE*lerpf(.55,1.15,ratio)
  shaft_beam.scale=Vector3(lerpf(.5,1,ratio),1,lerpf(.5,1,ratio))
  var flare:float=clampf((ratio-.7)/.25,0,1)
  flare_h.visible=flare>.05;flare_v.visible=flare>.05
  var pulse:float=1 if reduced else 1+sin(PI*ready_pulse/.16)*.22
  flare_h.scale=Vector3.ONE*flare*pulse;flare_v.scale=Vector3.ONE*flare*pulse
  for i in range(wisps.size()):
   wisps[i].visible=not reduced
   var progress:float=fposmod(float(i)/wisps.size()+charge_time*1.8,1)
   var angle:float=TAU*float(i)/wisps.size()+charge_time*.6
   var radius:float=lerpf(.48,.015,progress)
   wisps[i].position=Vector3(cos(angle)*radius,sin(angle)*radius,lerpf(.18,0,progress))
   wisps[i].scale=Vector3.ONE*lerpf(1,.3,progress)
  charge_light.light_energy=.12 if reduced else lerpf(.1,.65,ratio)
  player.bow_hand_node.material_overlay=bow_material;bow_material.set_shader_parameter("strength",lerpf(.03,.14,ratio))
 elif release_time>0:
  release_time=maxf(0,release_time-delta)
  var phase:float=1-release_time/release_duration
  _align(released_direction,released_position)
  tip_core.visible=false;flare_h.visible=false;flare_v.visible=false;shaft_beam.visible=false
  for mote in wisps:mote.visible=false
  charge_strands.visible=false
  release_spike.visible=true;release_spike.position.z=-phase*(.08 if reduced else .3)
  release_spike.scale=Vector3(1-phase,lerpf(1,1.5,phase),1-phase)
  core_material.albedo_color.a=(1-phase)*.65
  charge_light.light_energy=0 if reduced else (1-phase)*.8
  if release_time<=0:_reset_effect()
 else:_reset_effect()
func _exit_tree() -> void:
 _clear_bow()
 if is_instance_valid(player) and is_instance_valid(player.game):
  var audio:Node=player.game.get_node_or_null("PowerAudio")
  if audio:audio.stop_charge()

func _draw_charge(ratio:float,reduced:bool) -> void:
 charge_strands.visible=true
 var tone:=Color(COLORS.get(last_key,"a7edff"))
 var clock:float=0 if reduced else charge_time
 flow_material.set_shader_parameter("clock",clock)
 var mesh:ImmediateMesh=charge_strands.mesh
 mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 # Broken arcs gather into the arrow tip, like the reference charged bow.
 for strand in range(1 if reduced else 4):
  var points:=PackedVector3Array()
  for i in range(25):
   var t:float=float(i)/24
   var angle:float=t*PI*1.3-clock*1.8+strand*TAU/4
   var radius:float=lerpf(.48,.28,ratio)*(1-t*.72)
   points.append(Vector3(cos(angle)*radius,sin(angle)*radius,lerpf(.18,0,t)))
  var color:Color=Color("ad7fff") if last_key=="ultimate" and strand==1 else tone
  Geometry.tube(mesh,points,lerpf(.002,.005,ratio),Color(color,(.20+ratio*.35) if not reduced else .2))
 mesh.surface_end()
