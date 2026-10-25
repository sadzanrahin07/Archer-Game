extends RefCounted
# Original reference-led geometry. +Z is the model's face; Y is up.
static var materials:Dictionary={}
static var prototypes:Dictionary={}
static func material(key:String,hex:String,rough:float=.7,glow:float=0) -> StandardMaterial3D:
 if materials.has(key):return materials[key]
 var m:=StandardMaterial3D.new();m.resource_name=key;m.albedo_color=Color(hex);m.roughness=rough;m.vertex_color_use_as_albedo=true;m.cull_mode=BaseMaterial3D.CULL_DISABLED
 if glow>0:m.emission_enabled=true;m.emission=Color(hex);m.emission_energy_multiplier=glow
 materials[key]=m;return m
static func part(parent:Node3D,title:String,pos:Vector3=Vector3.ZERO) -> Node3D:
 var n:=Node3D.new();n.name=title;n.position=pos;n.set_meta("rig_part",true);parent.add_child(n);return n
static func mesh(parent:Node3D,title:String,geometry:Mesh,pos:Vector3,scale_value:Vector3,mat:Material) -> MeshInstance3D:
 var n:=MeshInstance3D.new();n.name=title;n.mesh=geometry;n.position=pos;n.scale=scale_value;n.material_override=mat;parent.add_child(n);return n
static func orb(parent:Node3D,title:String,pos:Vector3,size:Vector3,mat:Material,segments:int=12) -> MeshInstance3D:
 var s:=SphereMesh.new();s.radius=1;s.height=2;s.radial_segments=segments;s.rings=7
 return mesh(parent,title,s,pos,size,mat)
static func stone(parent:Node3D,title:String,pos:Vector3,size:Vector3,mat:Material) -> MeshInstance3D:
 var profile:Array[Vector2]=[Vector2(.1,-1),Vector2(.8,-.8),Vector2(1,-.25),Vector2(.84,.55),Vector2(.42,1)]
 return mesh(parent,title,lathe(profile,7,.1),pos,size,mat)
static func tube(parent:Node3D,title:String,a:Vector3,b:Vector3,r1:float,r2:float,mat:Material) -> MeshInstance3D:
 var c:=CylinderMesh.new();c.top_radius=r2;c.bottom_radius=r1;c.height=a.distance_to(b);c.radial_segments=7;c.rings=1
 var n:=mesh(parent,title,c,(a+b)*.5,Vector3.ONE,mat)
 n.quaternion=Quaternion(Vector3.UP,(b-a).normalized());return n
static func lathe(profile:Array[Vector2],segments:int=16,jitter:float=.025,smooth:bool=false) -> ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for ring in range(profile.size()-1):
  for i in range(segments):
   var v:Array[Vector3]=[]
   for pair in [[ring,i],[ring+1,i],[ring+1,i+1],[ring,i+1]]:
    var row:int=pair[0];var col:int=pair[1];var angle:float=TAU*col/segments
    var radial:float=profile[row].x*(1+jitter*sin(col*7.13+row*3.77))
    v.append(Vector3(cos(angle)*radial,profile[row].y,sin(angle)*radial))
   var tint:float=.94+.06*sin(i*4.77+ring*2.77)
   for index in [0,1,2,0,2,3]:
    if smooth:
     var pair:Array=[[ring,i],[ring+1,i],[ring+1,i+1],[ring,i+1]][index]
     var row:int=pair[0];var col:int=pair[1];var angle:float=TAU*col/segments
     var before:Vector2=profile[maxi(0,row-1)];var after:Vector2=profile[mini(profile.size()-1,row+1)]
     var slope:float=(after.x-before.x)/maxf(.001,after.y-before.y)
     st.set_normal(Vector3(cos(angle),-slope,sin(angle)).normalized())
    st.set_color(Color.WHITE if smooth else Color(tint,tint,tint));st.add_vertex(v[index])
 if not smooth:st.generate_normals()
 return st.commit()
static func leaf(parent:Node3D,title:String,base:Vector3,tip:Vector3,width:float,mat:Material,normal:Vector3=Vector3(0,0,1)) -> MeshInstance3D:
 var axis:Vector3=tip-base;var side:Vector3=axis.cross(normal).normalized()
 if side.length()<.01:side=Vector3.RIGHT
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var ts:Array[float]=[0,.25,.55,.8,1];var widths:Array[float]=[0,.7,1,.6,0]
 for i in range(4):
  for sign_value in [-1,1]:
   var a:Vector3=base+axis*ts[i]+normal*sin(ts[i]*PI)*width*.22
   var b:Vector3=base+axis*ts[i]+side*width*widths[i]*sign_value
   var c:Vector3=base+axis*ts[i+1]+normal*sin(ts[i+1]*PI)*width*.22
   var d:Vector3=base+axis*ts[i+1]+side*width*widths[i+1]*sign_value
   for v in [a,b,c,b,d,c]:st.set_color(Color(.91,.98,.94) if sign_value<0 else Color.WHITE);st.add_vertex(v)
 st.generate_normals();return mesh(parent,title,st.commit(),Vector3.ZERO,Vector3.ONE,mat)
static func eyes(parent:Node3D,y:float,z:float,spacing:float,size:float=1) -> void:
 var dark:=material("eyes","10242b",.2);var white:=material("eye_glint","e8fff4",.15,.18)
 for sign_value in [-1,1]:
  orb(parent,"Eye",Vector3(sign_value*spacing,y,z),Vector3(.065,.105,.028)*size,dark)
  orb(parent,"Glint",Vector3(sign_value*spacing-.016*size,y+.035*size,z+.028*size),Vector3(.019,.029,.012)*size,white,8)
static func foliage(parent:Node3D,center:Vector3,count:int,radius:float,length:float,phase:float=0) -> void:
 var greens:Array[Material]=[material("leaf_sage","66956b"),material("leaf_mint","83b785"),material("leaf_dark","315e55"),material("leaf_lime","94ad55"),material("leaf_plum","64506b")]
 for i in range(count):
  var a:float=phase+TAU*i/count;var dir:=Vector3(cos(a),0,sin(a))
  var base:Vector3=center+dir*radius*.35
  var tip:Vector3=center+dir*radius+Vector3(0,-length,0)
  leaf(parent,"Leaf",base,tip,maxf(length*.55,radius*.20),greens[i%greens.size()],(dir+Vector3.UP*.5).normalized())
static func roots(parent:Node3D,points:Array[Vector3],radius:float=.05) -> void:
 var bark:=material("root_brown","69503e");var light:=material("root_ridge","927451")
 for i in range(points.size()-1):
  tube(parent,"Root",points[i],points[i+1],radius*(1-float(i)*.15),radius*(1-float(i+1)*.15),bark)
  tube(parent,"Ridge",points[i]+Vector3(radius*.5,0,0),points[i+1]+Vector3(radius*.5,0,0),radius*.17,radius*.12,light)
static func slime(family:String) -> Node3D:
 var root:=Node3D.new();root.name="ReferenceModel"
 var briar:bool=family=="briar_slime"
 var jelly:=material("briar_jelly" if briar else "mint_jelly","a35487" if briar else "8ed4b9",.18)
 # An opaque clearcoat keeps the reference's jelly sheen without alpha-sorting artifacts.
 jelly.clearcoat_enabled=true;jelly.clearcoat=.65;jelly.clearcoat_roughness=.12
 jelly.rim_enabled=true;jelly.rim=.40;jelly.rim_tint=.35
 var body_profile:Array[Vector2]=[Vector2(.02,.055),Vector2(.31,.075),Vector2(.43,.12),Vector2(.485,.21),Vector2(.48,.31),Vector2(.435,.44),Vector2(.365,.59),Vector2(.285,.72),Vector2(.19,.82),Vector2(.09,.885),Vector2(.005,.91)]
 mesh(root,"Jelly",lathe(body_profile,40,0,true),Vector3.ZERO,Vector3.ONE,jelly)
 for i in range(6):
  var a:float=TAU*i/6
  orb(root,"JellyLobe",Vector3(cos(a)*.34,.075,sin(a)*.30),Vector3(.13,.075,.14),jelly)
 eyes(root,.43,.415,.17,1.08)
 if not briar:
  var cheek:=material("cheeks","8ce5c8",.3)
  for sign_value in [-1,1]:orb(root,"Cheek",Vector3(sign_value*.27,.31,.385),Vector3(.057,.024,.013),cheek,10)
  var fern:=part(root,"Fern",Vector3(0,.84,0))
  roots(fern,[Vector3.ZERO,Vector3(0,.16,0),Vector3(.055,.36,0)],.018)
  for i in range(5):
   for sign_value in [-1,1]:
    leaf(fern,"FernLeaf",Vector3(0,.055+i*.052,0),Vector3(sign_value*(.11-i*.012),.10+i*.052,.016),.045,material("fern_green","396b56") if sign_value<0 else material("fern_plum","6c527a"))
  # The leaf-shaped inclusions are surface inlays, avoiding transparent sorting artifacts.
  for i in range(13):
   var a:float=TAU*i/13;var h:float=.2+float(i%3)*.15;var r:float=.49 if h<.4 else .43
   var pos:=Vector3(cos(a)*r,h,sin(a)*r)
   if pos.z>.25 and absf(pos.x)>.08 and absf(pos.x)<.32 and h<.58:continue
   leaf(root,"LeafInlay",pos-Vector3(0,.065,0),pos+Vector3(.015,.11,0),.06,material("inlay_plum","87728d",.3) if i%4==0 else material("inlay_forest","5b9c86",.3),Vector3(cos(a),0,sin(a)))
 else:
  var rose:=material("rose_patch","d57a9e",.45)
  orb(root,"RoseBelly",Vector3(0,.255,.49),Vector3(.21,.17,.012),rose)
  for i in range(5):
   var a:float=TAU*i/5;leaf(root,"RosePetal",Vector3(0,.255,.51),Vector3(cos(a)*.12,.255+sin(a)*.12,.515),.04,material("rose_inner","a4507c"))
  foliage(root,Vector3(0,.73,0),11,.47,.20,.15)
  for i in range(3):
   var bud:=part(root,"ThornBud",Vector3((i-1)*.31,.67+(.14 if i==1 else 0),-.03))
   mesh(bud,"WoodBud",lathe([Vector2(.04,0),Vector2(.14,.10),Vector2(.13,.23),Vector2(.02,.38)],9,.09),Vector3.ZERO,Vector3.ONE,material("bud_wood","76583d"))
   mesh(bud,"RoseCrystal",lathe([Vector2(.01,.13),Vector2(.075,.24),Vector2(.0,.40)],7),Vector3(0,0,.055),Vector3.ONE,material("rose_crystal","bc548b",.25))
   for j in range(5):
    var a:float=TAU*j/5;tube(bud,"Thorn",Vector3(cos(a)*.1,.12,sin(a)*.1),Vector3(cos(a)*.21,.21,sin(a)*.21),.04,0,material("bud_wood","76583d"))
  for i in range(9):
   var a:float=TAU*i/9;stone(root,"RoseShard",Vector3(cos(a)*.43,.26+float(i%2)*.15,sin(a)*.43),Vector3(.035,.055,.035),material("rose_crystal","bc548b",.25))
 for p in [Vector3(-.21,.61,.30),Vector3(.26,.59,.28)]:leaf(root,"JellyGlint",p,p+Vector3(.06,.09,.012),.026,material("jelly_glint","dbf4d4",.25))
 return root
static func spitter() -> Node3D:
 var root:=Node3D.new();root.name="ReferenceModel"
 for i in range(4):
  var a:float=TAU*i/4
  roots(root,[Vector3(cos(a)*.12,.32,sin(a)*.12),Vector3(cos(a)*.28,.10,sin(a)*.28),Vector3(cos(a)*.45,.025,sin(a)*.4)],.10)
 stone(root,"Stem",Vector3(0,.48,0),Vector3(.27,.38,.25),material("plant_base","526d35"))
 for j in range(3):foliage(root,Vector3(0,.40+j*.15,0),7,.32-j*.015,.19,.4*j)
 for sign_value in [-1,1]:
  var ear:=part(root,"LeafLeft" if sign_value<0 else "LeafRight",Vector3(sign_value*.14,.78,0))
  leaf(ear,"BroadLeaf",Vector3.ZERO,Vector3(sign_value*.45,.53,-.05),.23,material("broad_leaf","799b59"))
  leaf(ear,"Vein",Vector3.ZERO,Vector3(sign_value*.44,.52,-.035),.025,material("leaf_vein","b3c783"))
 var pod:=part(root,"PodMuzzle",Vector3(0,.82,.28))
 orb(pod,"DarkMouth",Vector3(0,0,.09),Vector3(.22,.23,.07),material("mouth_cavity","442c24"))
 for i in range(8):
  var a:float=TAU*i/8
  var position:=Vector3(cos(a)*.24,sin(a)*.24,.10)
  stone(pod,"CreamPetal",position,Vector3(.10,.13,.12),material("pod_cream","ebd8a0"))
  leaf(pod,"BriarSepal",position-Vector3(0,0,.11),Vector3(cos(a)*.35,sin(a)*.35,-.03),.065,material("sepal_plum","825365"))
 for p in [Vector3(-.06,.08,.17),Vector3(.065,.025,.17),Vector3(0,-.09,.17)]:stone(pod,"Seed",p,Vector3(.052,.062,.045),material("seed_gold","c8a66a"))
 return root
static func stalker() -> Node3D:
 var root:=Node3D.new();root.name="ReferenceModel"
 var bark:=material("fox_bark","614736");var cream:=material("fox_cream","e0ddad");var moss:=material("fox_sage","789569")
 stone(root,"Torso",Vector3(0,.49,-.1),Vector3(.24,.27,.47),bark)
 for i in range(4):
  var sign_value:int=-1 if i%2==0 else 1
  var leg:=part(root,"Leg%d"%i,Vector3(sign_value*.19,.44,.21 if i<2 else -.38))
  roots(leg,[Vector3.ZERO,Vector3(sign_value*.015,-.21,-.04),Vector3(0,-.37,.02)],.065)
  for j in range(3):orb(leg,"Toe",Vector3((j-1)*.038,-.39,.065),Vector3(.033,.045,.065),moss,8)
  leaf(leg,"ShinLeaf",Vector3(0,-.1,.065),Vector3(0,-.31,.07),.07,moss)
 var head:=part(root,"Head",Vector3(0,.78,.29))
 stone(head,"Skull",Vector3.ZERO,Vector3(.27,.25,.25),moss)
 stone(head,"Muzzle",Vector3(0,-.075,.22),Vector3(.14,.10,.19),cream)
 orb(head,"Nose",Vector3(0,-.04,.385),Vector3(.04,.028,.022),material("fox_nose","302530"),8)
 leaf(head,"FaceMark",Vector3(0,.24,.20),Vector3(0,-.13,.29),.19,cream)
 for sign_value in [-1,1]:
  leaf(head,"Ear",Vector3(sign_value*.15,.10,0),Vector3(sign_value*.25,.67,-.02),.15,material("ear_plum","655066"))
  leaf(head,"InnerEar",Vector3(sign_value*.15,.12,.025),Vector3(sign_value*.24,.61,.015),.10,moss)
  orb(head,"AmberEye",Vector3(sign_value*.14,.012,.239),Vector3(.07,.045,.025),material("amber_eye","ffc15a",.25,.5),10)
  orb(head,"Pupil",Vector3(sign_value*.14,.012,.261),Vector3(.016,.035,.01),material("eyes","10242b",.2),8)
  leaf(head,"CheekRuff",Vector3(sign_value*.12,-.05,.13),Vector3(sign_value*.34,-.19,.08),.12,cream)
 for j in range(3):foliage(root,Vector3(0,.54,-.28+j*.20),7,.29,.19,j*.7)
 for i in range(5):leaf(root,"ChestLeaf",Vector3((i-2)*.055,.70,.33),Vector3((i-2)*.04,.32-abs(i-2)*.02,.37),.075,cream)
 var tail:=part(root,"Tail",Vector3(0,.49,-.49))
 roots(tail,[Vector3.ZERO,Vector3(0,.12,-.28),Vector3(0,.06,-.65)],.10)
 for i in range(7):
  var a:float=TAU*i/7
  leaf(tail,"TailLeaf",Vector3(cos(a)*.06,.04+sin(a)*.06,-.1),Vector3(cos(a)*.15,-.08+sin(a)*.15,-.85),.18,moss if i%3 else material("ear_plum","655066"),Vector3(cos(a),sin(a),.2).normalized())
 return root
static func wisp() -> Node3D:
 var root:=Node3D.new();root.name="ReferenceModel"
 var teal:=material("prism_teal","50bfc4",.23);var violet:=material("prism_lilac","a48cda",.26)
 var housing:=material("prism_housing","ffffff",.24)
 housing.metallic=.12;housing.rim_enabled=true;housing.rim=.38;housing.rim_tint=.3
 var shell:=part(root,"Shell",Vector3(0,1.0,0))
 # Two solid, eight-sided jewel ribbons surround the pearl. Their thickness remains
 # visible from the side; separate top and bottom crystals preserve the reference's
 # pointed silhouette without turning its open center into a solid cone.
 for sign_value in [-1,1]:
  var path:Array[Vector3]=[Vector3(sign_value*.04,-.54,-.025),Vector3(sign_value*.26,-.33,0),Vector3(sign_value*.315,-.08,.025),Vector3(sign_value*.10,.16,.045),Vector3(-sign_value*.18,.37,.025),Vector3(0,.62,-.025)]
  var widths:Array[float]=[.025,.14,.155,.155,.14,.025]
  var depths:Array[float]=[.055,.17,.19,.18,.16,.055]
  var section:Array[Vector2]=[Vector2(-1,0),Vector2(-.65,.75),Vector2(0,1),Vector2(.65,.75),Vector2(1,0),Vector2(.65,-.75),Vector2(0,-1),Vector2(-.65,-.75)]
  var loops:Array=[]
  for row in range(path.size()):
   var tangent:Vector3=path[min(row+1,path.size()-1)]-path[max(0,row-1)]
   var across:=Vector3(tangent.y,-tangent.x,0).normalized()
   var loop:Array[Vector3]=[]
   for corner in section:loop.append(path[row]+across*corner.x*widths[row]+Vector3(0,0,corner.y*depths[row]))
   loops.append(loop)
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var face_colors:Array=[Color("ad9bdf"),Color("c0b3eb"),Color("9e8bd4"),Color("8c79c5"),Color("42638e"),Color("41647f"),Color("487d94"),Color("6b78a6")] if sign_value<0 else [Color("69c6be"),Color("a1e2cd"),Color("7dd8c8"),Color("48aea9"),Color("368799"),Color("3c5b8c"),Color("427696"),Color("6bafb7")]
  for row in range(loops.size()-1):
   for face in range(8):
    var next:int=(face+1)%8
    var points:Array[Vector3]=[loops[row][face],loops[row+1][face],loops[row+1][next],loops[row][next]]
    for index in [0,1,2,0,2,3]:
     st.set_color(face_colors[(face+row%2)%face_colors.size()]);st.add_vertex(points[index])
  for row in [0,loops.size()-1]:
   for face in range(8):
    for point in [path[row],loops[row][face],loops[row][(face+1)%8]]:st.set_color(face_colors[face]);st.add_vertex(point)
  st.generate_normals();mesh(shell,"JewelRibbon",st.commit(),Vector3.ZERO,Vector3.ONE,housing)
 var crown:=mesh(shell,"CrownCrystal",lathe([Vector2(.005,.36),Vector2(.20,.57),Vector2(.005,.96)],7),Vector3(0,0,-.055),Vector3.ONE,teal);crown.rotation.y=.18
 var pendant:=mesh(shell,"LowerCrystal",lathe([Vector2(.005,-.91),Vector2(.15,-.65),Vector2(.01,-.47)],7),Vector3(0,0,-.03),Vector3.ONE,violet)
 pendant.rotation.y=.2
 for sign_value in [-1,1]:
  var splinter:=mesh(shell,"LowerSplinter",lathe([Vector2(.005,-.14),Vector2(.065,0),Vector2(.005,.14)],5),Vector3(sign_value*.22,-.58,-.015),Vector3.ONE,teal if sign_value<0 else violet);splinter.rotation.z=-sign_value*.45
 # Keep a rig pivot: static mesh batching used to remove the CentralPearl node.
 var pearl:=part(root,"CentralPearl",Vector3(0,1,.22))
 var pearl_mat:=material("pearl","c9e3df",.12,.12)
 pearl_mat.clearcoat_enabled=true;pearl_mat.clearcoat=.6;pearl_mat.clearcoat_roughness=.08
 orb(pearl,"PearlSurface",Vector3.ZERO,Vector3(.185,.185,.145),pearl_mat,20)
 orb(pearl,"PearlGlint",Vector3(-.055,.065,.132),Vector3(.035,.04,.018),material("pearl_glint","f2fff5",.15,.08),10)
 for sign_value in [-1,1]:
  var facet:=part(root,"FacetLeft" if sign_value<0 else "FacetRight",Vector3(sign_value*.60,1,0))
  mesh(facet,"Satellite",lathe([Vector2(0,-.18),Vector2(.12,0),Vector2(0,.24)],7),Vector3.ZERO,Vector3.ONE,teal if sign_value<0 else violet)
 var torus:=TorusMesh.new();torus.inner_radius=.60;torus.outer_radius=.615;torus.rings=32;torus.ring_segments=6
 var ring:=mesh(root,"OrbitRing",torus,Vector3(0,1,0),Vector3.ONE,material("orbit_glow","70d9cf",.4,.15));ring.rotation.x=.12
 return root
static func warden() -> Node3D:
 var root:=Node3D.new();root.name="ReferenceModel"
 var rock:=material("warden_stone","89917b");var darkrock:=material("warden_shadow","58695b");var gold:=material("warden_gold","efd389",.35,.35)
 stone(root,"Torso",Vector3(0,1.15,0),Vector3(.54,.55,.32),rock)
 for sign_value in [-1,1]:
  var leg:=part(root,"Leg%d"%(0 if sign_value<0 else 1),Vector3(sign_value*.28,.65,0))
  stone(leg,"Thigh",Vector3(0,-.15,0),Vector3(.24,.29,.23),darkrock)
  stone(leg,"Foot",Vector3(0,-.50,.12),Vector3(.27,.14,.32),rock)
  roots(leg,[Vector3(sign_value*.1,.1,.17),Vector3(-sign_value*.07,-.17,.24),Vector3(sign_value*.1,-.45,.30)],.08)
  var arm:=part(root,"ArmLeft" if sign_value<0 else "ArmRight",Vector3(sign_value*.56,1.5,0))
  stone(arm,"UpperArm",Vector3(sign_value*.09,-.23,0),Vector3(.21,.29,.22),darkrock)
  stone(arm,"Fist",Vector3(sign_value*.18,-.68,.08),Vector3(.25,.27,.25),rock)
  for j in range(3):roots(arm,[Vector3((j-1)*.12,0,.12),Vector3((1-j)*.08,-.32,.21),Vector3((j-1)*.1,-.69,.23)],.065)
  foliage(arm,Vector3(sign_value*.03,-.10,0),9,.29,.19)
  foliage(root,Vector3(sign_value*.45,1.64,0),13,.49,.21,.4)
  roots(root,[Vector3(sign_value*.28,1.15,.25),Vector3(sign_value*.39,1.5,.23),Vector3(sign_value*.23,1.84,.17),Vector3(sign_value*.35,2.10,.09)],.07)
  roots(root,[Vector3(sign_value*.33,1.85,.11),Vector3(sign_value*.54,1.98,.09)],.04)
 var head:=part(root,"Head",Vector3(0,1.70,.13))
 stone(head,"Face",Vector3.ZERO,Vector3(.22,.27,.17),rock)
 for sign_value in [-1,1]:orb(head,"Eye",Vector3(sign_value*.09,.01,.16),Vector3(.045,.025,.02),material("amber_eye","ffc15a",.25,.5),8)
 for i in range(3):stone(root,"BellyPlate",Vector3(0,.65+i*.21,.30),Vector3(.27-i*.025,.11,.09),rock if i%2 else darkrock)
 var knot:=part(root,"ChestKnot",Vector3(0,1.23,.35))
 for i in range(3):
  var s:float=.23-i*.065
  var diamond:=BoxMesh.new();diamond.size=Vector3(s,s,.035)
  var n:=mesh(knot,"Diamond",diamond,Vector3(0,0,.04*i),Vector3.ONE,gold if i%2==0 else material("knot_dark","9c7137"));n.rotation.z=PI*.25
 for row in range(3):foliage(root,Vector3(0,1.68-row*.12,-.12-row*.025),12,.56-row*.02,.23,row*.25)
 for i in range(5):
  var pos:=Vector3((i-2)*.2,1.69,-.08+float(i%2)*.17)
  tube(root,"MushroomStem",pos,pos+Vector3(0,.09,0),.025,.025,material("mushroom_stem","bfa477"))
  var cap:=mesh(root,"MushroomCap",lathe([Vector2(.1,0),Vector2(.08,.05),Vector2(.01,.11)],8),pos+Vector3(0,.09,0),Vector3.ONE,material("mushroom_plum","8a5f91"))
 return root
static func build(family:String,merge:bool=true) -> Node3D:
 var root:Node3D
 match family:
  "moss_slime","briar_slime":root=slime(family)
  "seed_spitter":root=spitter()
  "bark_stalker":root=stalker()
  "mirror_wisp":root=wisp()
  _:root=warden()
 root.set_meta("art_revision",3);root.set_meta("art_pass","combat_fidelity_v3");root.set_meta("family",family)
 if merge:batch(root)
 return root
static func batch(root:Node3D) -> void:
 # Merge static detail by material inside each animated part; retain the rig pivots.
 var groups:Dictionary={}
 collect(root,root,Transform3D.IDENTITY,groups)
 var combined:=ArrayMesh.new()
 for key in groups:
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for record in groups[key]:
   var arrays:Array=record.mesh.surface_get_arrays(0)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
   var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
   var count:int=indices.size() if not indices.is_empty() else vertices.size()
   var transform:Transform3D=record.transform
   var normal_basis:Basis=transform.basis.inverse().transposed()
   for i in range(count):
    var id:int=indices[i] if not indices.is_empty() else i
    st.set_color(colors[id] if not colors.is_empty() else Color.WHITE)
    st.set_normal((normal_basis*normals[id]).normalized())
    st.add_vertex(transform*vertices[id])
  st.set_material(groups[key][0].material);st.commit(combined)
 if combined.get_surface_count()>0:mesh(root,"BatchedDetail",combined,Vector3.ZERO,Vector3.ONE,null)
 for child in root.get_children():
  if child is Node3D and child.has_meta("rig_part"):batch(child)
static func collect(root:Node3D,node:Node3D,transform:Transform3D,groups:Dictionary) -> void:
 for child in node.get_children():
  if not child is Node3D:continue
  if child.has_meta("rig_part"):continue
  var t:Transform3D=transform*child.transform
  if child is MeshInstance3D and child.mesh:
   var mat:Material=child.material_override
   if mat==null:continue
   var key:String=str(mat.get_instance_id())
   if not groups.has(key):groups[key]=[]
   groups[key].append({"mesh":child.mesh,"transform":t,"material":mat})
   node.remove_child(child);child.free()
  else:collect(root,child,t,groups)
