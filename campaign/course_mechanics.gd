extends Node3D
# Authored encounters share the same projectiles, hit zones and saved stage IDs.
var course:Node3D
var kind:="normal"
var elapsed:=0.0
var shutters:Array[Node3D]=[]
var gate:Node3D
var lanterns:Array[MeshInstance3D]=[]
var glyphs:Array[Label3D]=[]
var ribbons:Array[MeshInstance3D]=[]
var gate_open:=false
var found_perch:=false
const SYMBOLS=["MOON","MOON","SUN","SUN"]
func setup(owner_course:Node3D) -> void:
 course=owner_course;kind=str(course.definition.get("mechanic","normal"))
 name="Encounter_"+kind
 for i in range(course.targets.size()):
  var target:Node3D=course.targets[i]
  if kind in ["sequence","echo","restoration"]:
   var glyph:=Label3D.new();glyph.text=SYMBOLS[i] if kind=="echo" and i<SYMBOLS.size() else str(i+1)
   glyph.position=Vector3(0,1.6,.1);glyph.font_size=48;glyph.pixel_size=.009;glyph.billboard=BaseMaterial3D.BILLBOARD_ENABLED
   glyph.modulate=Color("ffe09a");target.add_child(glyph);glyphs.append(glyph)
   var lantern:=box(target,Vector3(0,-.8,.15),Vector3(.35,.35,.35),Color("607063"),false);lanterns.append(lantern)
  if kind=="shutter":
   var root:=Node3D.new();root.position=target.position+Vector3(0,0,1.0);add_child(root);shutters.append(root)
   for side in [-1,1]:box(root,Vector3(side*.55,0,0),Vector3(.8,1.7,.12),Color("666d59"),true)
   box(root,Vector3(0,1,0),Vector3(3.7,.15,.2),Color("9a895e"),false)
  if kind=="cart":
   target.moving=true
   box(course,Vector3(target.position.x,course.spawn.y+.02,target.position.z),Vector3(4.7,.05,.12),Color("8a7964"),false)
   box(target,Vector3(0,-.9,-.1),Vector3(1.6,.15,.7),Color("72513a"),false)
 if kind=="clasp":
  var last:Node3D=course.targets.back()
  gate=Node3D.new();gate.name="CounterweightGate";gate.position=last.position+Vector3(0,0,1);add_child(gate)
  box(gate,Vector3.ZERO,Vector3(2.1,2,.2),Color("6e6150"),true)
  var clasp:Node3D=course.targets.front()
  clasp.position.y+=.5;clasp.base_position=clasp.position
  box(course,Vector3(clasp.position.x,course.spawn.y+.2,clasp.position.z-1),Vector3(1.2,.4,1.2),Color("746b57"),false)
 if kind=="perch":
  for side in [-1,1]:
   for i in range(14):
    var z:float=course.spawn.z-3-i*3
    var x:float=side*(3.5+sin(float(i)/13*PI)*2.5)
    box(course,Vector3(x,course.spawn.y+.015,z),Vector3(1.7,.035,.65),Color("c7ba81"),false)
   # A walkable ramp leads to a stable, raised aiming platform on either side.
   var ramp:=Node3D.new();ramp.position=Vector3(side*6,course.spawn.y+.5,course.spawn.z-10);ramp.rotation.x=deg_to_rad(9.5);add_child(ramp)
   box(ramp,Vector3.ZERO,Vector3(2.8,.15,6),Color("847658"),true)
   box(course,Vector3(side*6,course.spawn.y+1,course.spawn.z-14),Vector3(3.3,.2,3),Color("847658"),true)
 if kind=="wind":
  for i in range(6):
   var root:=Node3D.new();root.position=Vector3((-1 if i%2==0 else 1)*6,course.spawn.y+2.5,course.spawn.z-4-i*4);add_child(root)
   box(root,Vector3(0,-1.3,0),Vector3(.07,2.6,.07),Color("695c47"),false)
   ribbons.append(box(root,Vector3(.45,0,0),Vector3(.9,.15,.04),Color("d7b55f"),false))
func box(parent:Node3D,pos:Vector3,size:Vector3,color:Color,solid:bool) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=size;mesh.mesh=shape;mesh.position=pos
 var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.9;mesh.material_override=mat;parent.add_child(mesh)
 if solid:
  var body:=StaticBody3D.new();body.collision_layer=1;mesh.add_child(body)
  var collider:=CollisionShape3D.new();var collision:=BoxShape3D.new();collision.size=size;collider.shape=collision;body.add_child(collider)
 return mesh
func allows(target:Node3D) -> bool:
 if kind=="sequence" or kind=="restoration":
  for other in course.targets:
   if not other.completed:return target==other
 if kind=="echo":
  var first_pair_done:bool=course.targets[0].completed and course.targets[1].completed
  return target.index<2 or first_pair_done
 if kind=="clasp" and target==course.targets.back():return course.targets.front().completed
 return true
func _physics_process(delta:float) -> void:
 if not is_instance_valid(course) or not course.game.is_playing():return
 elapsed+=delta
 if kind=="perch" and not found_perch and is_instance_valid(course.game.hero):
  if absf(course.game.hero.position.x)>4 and course.game.hero.position.y>course.spawn.y+.6:
   found_perch=true;course.game.feedback("Hidden perch found - a clearer angle on the final stone")
 for i in range(shutters.size()):
  var opening:float=.18+1.15*(.5+.5*sin(elapsed*.9+i*1.2))
  var children:=shutters[i].get_children()
  children[0].position.x=-opening;children[1].position.x=opening
 if is_instance_valid(gate) and not gate_open and course.targets.front().completed:
  gate_open=true
  # Collision follows the visual down, fully revealing the final target.
  create_tween().tween_property(gate,"position:y",gate.position.y-3,1.0)
  course.game.feedback("Counterweight released - the final target is open")
 for i in range(lanterns.size()):
  if not is_instance_valid(lanterns[i]):continue
  var done:bool=course.targets[i].completed
  lanterns[i].visible=done or course.targets[i].active
  var mat:StandardMaterial3D=lanterns[i].material_override
  mat.albedo_color=Color("e8d98b") if done else Color("607063")
  mat.emission_enabled=done;mat.emission=Color("f5d36b")
  if i<glyphs.size():glyphs[i].modulate=Color("89cca8") if done else (Color("ffe09a") if allows(course.targets[i]) else Color("83938d"))
 for ribbon in ribbons:
  var wind:float=course.game.current_wind() if course.game.has_method("current_wind") else 0.0
  ribbon.position.x=signf(wind)*(.2+absf(wind)*.35)
  ribbon.scale.x=.2+absf(wind)*.7
func restore_landmark() -> void:
 for target in course.targets:
  if not is_instance_valid(target):continue
  var light:=OmniLight3D.new();light.light_color=Color("8de7bc");light.light_energy=.5;light.omni_range=4;target.add_child(light)
 var landmark:=course.get_node_or_null("RuneGate")
 if landmark:
  for mesh in landmark.find_children("*","MeshInstance3D",true,false):
   if mesh.material_override is StandardMaterial3D:
    var material:StandardMaterial3D=mesh.material_override.duplicate();material.albedo_color=material.albedo_color.lerp(Color("b4c59a"),.3);mesh.material_override=material
