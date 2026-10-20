extends RefCounted

const KIT := "res://assests/Stylized Nature MegaKit[Standard]/glTF/"
var stage: Node3D
var rng:=RandomNumberGenerator.new()
var width:=30.0
var z_start:=24.0
var z_end:=-20.0
var ground_y:=5.68
var biome:="meadow"
var mesh_cache: Dictionary={}

func build(owner_stage: Node3D,seed_value:int,area_width:float,end_z:float,biome_name:String) -> void:
	stage=owner_stage;width=area_width;z_end=end_z;biome=biome_name;rng.seed=8123+seed_value*311
	_grass();_flowers();_trees_and_rocks()
	_end_landscape()
	_encounter_landmark(seed_value)
	if biome in ["river","coast","pressure","aurora","blossom"]:_waterfront()
	if biome in ["quarry","highland","gale","airgarden","tempest","ember","crown"]:_cliffscape()
	if biome in ["ruins","ember","storm","tempest","golden","crown"]:_ancient_gate(Vector3(0,ground_y,z_end-2))
	if biome in ["blossom","moonlit","lightning","golden","crown"]:_particles()
	if biome=="blossom":_pavilion(Vector3(-width*.3,ground_y,z_end*.35));_pavilion(Vector3(width*.3,ground_y,z_end*.65))
	if biome in ["storm","moonlit","lightning","crown"]:_magic_stones()

func _mesh(name:String) -> Mesh:
	if mesh_cache.has(name):return mesh_cache[name]
	var packed:=load(KIT+name+".gltf") as PackedScene
	if not packed:return null
	var root:=packed.instantiate()
	var meshes:=root.find_children("*","MeshInstance3D",true,false)
	var mesh:Mesh=meshes[0].mesh.duplicate() if not meshes.is_empty() else null
	root.free();mesh_cache[name]=mesh;return mesh

func _grass_material() -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=load("res://shaders/stylized_moving_grass.gdshader")
	material.set_shader_parameter("texture_albedo",load(KIT+"Grass.png"))
	# Exact map palette, texture and shader. Only dry autumn areas change the tint.
	var dry:=biome in ["ember","golden"]
	material.set_shader_parameter("top_color",Color("c9bd63") if dry else Color(.48,.84,.36,1))
	material.set_shader_parameter("bottom_color",Color("717b3d") if dry else Color(.22,.54,.22,1))
	material.set_shader_parameter("wind_speed",1.8);material.set_shader_parameter("wind_strength",.16)
	return material

func _scatter(name:String,mesh:Mesh,transforms:Array[Transform3D],material:Material) -> void:
	if not mesh or transforms.is_empty():return
	# Small spatial batches let the renderer cull grass behind the camera and along the trail.
	var chunks:Dictionary={}
	for transform in transforms:
		var key:=Vector2i(floori(transform.origin.x/16),floori(transform.origin.z/16))
		if not chunks.has(key):chunks[key]=[]
		chunks[key].append(transform)
	for key in chunks:
		var center:=Vector3(key.x*16+8,0,key.y*16+8)
		var batch:Array=chunks[key]
		var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=batch.size()
		for i in range(batch.size()):
			var local:Transform3D=batch[i];local.origin-=center;multi.set_instance_transform(i,local)
		var node:=MultiMeshInstance3D.new();node.name=name+"_"+str(key);node.position=center;node.multimesh=multi;node.material_override=material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end=45 if stage.game.has_method("touch_enabled") and stage.game.touch_enabled() else 60;node.visibility_range_end_margin=8
		stage.add_child(node)

func _grass() -> void:
	var material:=_grass_material()
	var short:Array[Transform3D]=[];var wispy:Array[Transform3D]=[];var tall:Array[Transform3D]=[]
	var factor:=.62 if OS.has_feature("android") or OS.has_feature("ios") else 1.0
	var count:=clampi(int(width*(z_start-z_end)*3.3*factor),3000,17000)
	for i in range(count):
		var x:=rng.randf_range(-width*.5,width*.5);var z:=rng.randf_range(z_end,z_start)
		var path_x:=sin(z*.058)*1.8
		var size:=rng.randf_range(.23,.50)
		if absf(x-path_x)<1.45:size*=.28
		var transform:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),Vector3(x,ground_y,z))
		if i%4==0:wispy.append(transform)
		else:short.append(transform)
	# Organic islands of waist-high grass, kept away from targets and the footpath.
	for patch in range(16+int((z_start-z_end)/12)):
		var side:=-1.0 if patch%2==0 else 1.0
		var center:=Vector2(side*rng.randf_range(5.5,width*.46),rng.randf_range(z_end+3,z_start-2))
		var radius:=rng.randf_range(1.2,2.8)
		for j in range(int(52*factor)):
			var angle:=rng.randf()*TAU;var distance:=sqrt(rng.randf())*radius
			var size:=rng.randf_range(.52,.88)*(1.0-distance/radius*.32)
			tall.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),Vector3(center.x+cos(angle)*distance,ground_y,center.y+sin(angle)*distance)))
	_scatter("MapGrassShort",_mesh("Grass_Common_Short"),short,material)
	_scatter("MapGrassWispy",_mesh("Grass_Wispy_Short"),wispy,material)
	_scatter("MapGrassDensePatches",_mesh("Grass_Common_Tall"),tall,material)

func _flowers() -> void:
	for color_index in range(3):
		var material:=ShaderMaterial.new();material.shader=load("res://shaders/stylized_moving_flower.gdshader")
		material.set_shader_parameter("texture_albedo",load(KIT+"Flowers.png"));material.set_shader_parameter("use_custom_color",true)
		material.set_shader_parameter("color_tint",[Color("8dcdf4"),Color("eca0c7"),Color("fff2cc")][color_index])
		var list:Array[Transform3D]=[]
		for i in range(110+int((z_start-z_end)*1.5)):
			var x:=rng.randf_range(-width*.47,width*.47);var z:=rng.randf_range(z_end+2,z_start-2)
			if absf(x-sin(z*.058)*1.8)<1.7:continue
			var size:=rng.randf_range(.18,.32)
			list.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),Vector3(x,ground_y,z)))
		_scatter("SmallFieldFlowers%d"%color_index,_mesh("Flower_%d_Single"%(3+color_index%2)),list,material)

func _asset(name:String,pos:Vector3,size:float,rotate_y:float=0) -> Node3D:
	var path:=name if name.begins_with("res://") else KIT+name+".gltf"
	if not ResourceLoader.exists(path):return null
	var packed:=load(path) as PackedScene
	if not packed:return null
	var node:=packed.instantiate() as Node3D
	if not node:return null
	node.position=pos;node.scale*=size;node.rotation.y=rotate_y;stage.add_child(node)
	for mesh in node.find_children("*","GeometryInstance3D",true,false):
		mesh.visibility_range_end=75.0;mesh.visibility_range_end_margin=10.0
		mesh.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for child in node.find_children("*","CollisionObject3D",true,false):child.collision_layer=0
	if node is CollisionObject3D:node.collision_layer=0
	return node

func _trees_and_rocks() -> void:
	var count:=22+int((z_start-z_end)/3.7)
	for i in range(count):
		var side:=-1.0 if i%2==0 else 1.0
		var z:=lerpf(z_start,z_end,float(i)/count)+rng.randf_range(-2,2)
		var x:=side*rng.randf_range(width*.40,width*.58)
		var tree_name:="CommonTree_%d"%(1+i%5)
		if biome in ["birch","river","coast","aurora"]:tree_name="res://scenes/props/birch_tree_green.tscn"
		if biome in ["highland","gale","airgarden"]:tree_name="Pine_%d"%(1+i%5)
		var tree:=_asset(tree_name,Vector3(x,ground_y,z),rng.randf_range(.85,1.5),rng.randf()*TAU)
		if tree and biome in ["blossom","ember","golden"]:_tint_leaves(tree)
		if i%2==0:_asset("Rock_Medium_%d"%(1+i%3),Vector3(x*.89,ground_y,z+1.7),rng.randf_range(.72,1.5))
		if i%3==0:_asset("Bush_Common_Flowers",Vector3(x*.75,ground_y,z-1.1),rng.randf_range(.55,.85))
	for i in range(16):
		_asset("res://scenes/props/rock_path_round_small_1.tscn",Vector3(sin((z_start-i*(z_start-z_end)/16)*.058)*1.8,ground_y,z_start-i*(z_start-z_end)/16),.53,rng.randf()*TAU)
	_asset("res://scenes/props/tent.tscn",Vector3(-7,ground_y,18.5),.7)
	_asset("res://scenes/props/signpost.tscn",Vector3(6,ground_y,18),.8)

func _tint_leaves(tree:Node3D) -> void:
	for mesh in tree.find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_surface_count()):
			var mat=mesh.get_active_material(i)
			if mat is StandardMaterial3D and mat.albedo_texture and "Leaves" in mat.albedo_texture.resource_path:
				if biome=="blossom":
					var pink:=ShaderMaterial.new();pink.shader=load("res://campaign/cherry.gdshader");pink.set_shader_parameter("leaves_texture",mat.albedo_texture);mesh.set_surface_override_material(i,pink)
				else:
					var warm:=ShaderMaterial.new();warm.shader=load("res://campaign/course_leaves.gdshader");warm.set_shader_parameter("leaves_texture",mat.albedo_texture);warm.set_shader_parameter("foliage_color",Color("ec9e54") if biome=="ember" else Color("dccc68"));mesh.set_surface_override_material(i,warm)

func _waterfront() -> void:
	var center:=(z_start+z_end)*.5
	var river:=MeshInstance3D.new();river.name="TurquoiseWaterfront"
	var mesh:=PlaneMesh.new();mesh.size=Vector2(11,z_start-z_end+18);river.mesh=mesh;river.position=Vector3(width*.5+4.8,ground_y-.48,center)
	var material:=ShaderMaterial.new();material.shader=load("res://campaign/course_water.gdshader")
	if biome=="aurora":material.set_shader_parameter("water_color",Color("7b9ac9"))
	river.material_override=material;stage.add_child(river)
	for i in range(12):
		var z:=lerpf(z_start,z_end,float(i)/12)
		_asset("Rock_Medium_%d"%(1+i%3),Vector3(width*.5-1.3,ground_y-.25,z),rng.randf_range(.6,1.4))
		_asset("res://scenes/props/pampas_grass.tscn",Vector3(width*.5-2.0,ground_y,z+2),.7)
	if biome in ["river","coast","aurora"]:_asset("res://scenes/props/dock.tscn",Vector3(width*.5,ground_y-.05,7),.72,PI/2)

func _cliffscape() -> void:
	for i in range(14):
		var side:=-1.0 if i%2==0 else 1.0
		var z:=lerpf(z_start,z_end,float(i)/14)
		var node:=_asset("Rock_Medium_%d"%(1+i%3),Vector3(side*(width*.58+3),ground_y-1.4,z),rng.randf_range(2.5,4.0))
		if node:node.scale.y*=rng.randf_range(1.4,2.5)
	if biome in ["airgarden","crown"]:
		for i in range(7):
			var island:=_asset("Rock_Medium_%d"%(1+i%3),Vector3((-1 if i%2==0 else 1)*(width*.7+6),12+rng.randf()*6,z_end*.2-i*9),rng.randf_range(1.4,2.2))
			if island:island.rotation.z=rng.randf_range(-.25,.25)

func _box(parent:Node3D,pos:Vector3,size:Vector3,color:Color) -> MeshInstance3D:
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=pos
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.94;node.material_override=mat;parent.add_child(node);return node

func _ancient_gate(origin:Vector3) -> void:
	var gate:=Node3D.new();gate.name="RuneGate";gate.position=origin;stage.add_child(gate)
	var color:=Color("697c70")
	if biome=="ember":color=Color("a46e45")
	if biome in ["golden","crown"]:color=Color("b1ab86")
	for side in [-1,1]:
		for block in range(6):
			var node:=_box(gate,Vector3(side*4.5,block*1.5+.75,0),Vector3(1.8,1.4,1.7),color*(.9+block*.025))
			node.rotation.y=side*.02*block
			if block%2==0:_asset("Bush_Common",origin+Vector3(side*4.6,block*1.5+1.4,0),.48)
	# Segmented stone crown with a large open shooting sightline.
	for block in range(11):
		var angle:=PI*float(block)/10.0
		var crown:=_box(gate,Vector3(cos(angle)*4.5,9+sin(angle)*4.5,0),Vector3(1.7,1.45,1.8),color)
		crown.rotation.z=angle-PI/2
	var rune_color:=Color("76dfdc") if biome!="ember" else Color("ffbe71")
	for side in [-1,1]:
		for i in range(4):
			var glyph:=_box(gate,Vector3(side*4.5,3+i*1.45,.90),Vector3(.08,.74,.03),rune_color)
			var mat:=glyph.material_override as StandardMaterial3D;mat.emission_enabled=true;mat.emission=rune_color;mat.emission_energy_multiplier=1.2
	for i in range(6):_asset("res://scenes/props/stone_lantern.tscn",origin+Vector3((-1 if i%2==0 else 1)*6,0,7+i*1.8),.8)

func _pavilion(origin:Vector3) -> void:
	var building:=Node3D.new();building.name="BlossomPavilion";building.position=origin;stage.add_child(building)
	for x in [-1,1]:
		for z in [-1,1]:_box(building,Vector3(x*1.7,1.5,z*1.5),Vector3(.19,3,.19),Color("54483f"))
		var roof:=_box(building,Vector3(x*.95,3.05,0),Vector3(2.8,.18,4.3),Color("586a71"));roof.rotation.z=x*-.34
	_box(building,Vector3(0,.12,0),Vector3(4,.24,3.8),Color("a6967c"))

func _magic_stones() -> void:
	var script:=load("res://campaign/rune_stone.gd")
	for i in range(5):
		var stone:=script.new() as Node3D;stone.name="ScenicRuneMonolith";stone.position=Vector3((-1 if i%2==0 else 1)*(width*.36),ground_y+1.0,z_start-5-i*(z_start-z_end)/5)
		stone.scale=Vector3.ONE*.75;stage.add_child(stone);stone.build("rune",i+9)

func _particles() -> void:
	var particles:=CPUParticles3D.new();particles.name="PetalsAndFireflies";particles.amount=90;particles.lifetime=8
	particles.position=Vector3(0,ground_y+3,(z_start+z_end)*.5);particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents=Vector3(width*.47,2,(z_start-z_end)*.48);particles.gravity=Vector3(.025,-.05,0);particles.initial_velocity_min=.04;particles.initial_velocity_max=.14
	var mesh:=QuadMesh.new();mesh.size=Vector2(.07,.04);var mat:=StandardMaterial3D.new();mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.albedo_color=Color("f6b5cc") if biome=="blossom" else Color("bfeee8");mat.emission_enabled=true;mat.emission=mat.albedo_color;mat.emission_energy_multiplier=.55;mesh.material=mat;particles.mesh=mesh;stage.add_child(particles)


func _end_landscape() -> void:
	# Close the extended trail with the original kit, rather than an empty horizon.
	for band in range(3):
		for i in range(11):
			var x:float=(float(i)-5)*7.0+rng.randf_range(-1.5,1.5)
			var z:float=z_end-11-band*7+rng.randf_range(-2,2)
			var tree:=_asset("CommonTree_%d"%(1+(i+band)%5),Vector3(x,ground_y,z),rng.randf_range(1.6,2.7),rng.randf()*TAU)
			if tree and biome in ["blossom","ember","golden","crown"]:_tint_leaves(tree)
	for side in [-1,1]:
		for i in range(5):
			var rock:=_asset("Rock_Medium_%d"%(1+i%3),Vector3(side*(width*.58+6+i*3),ground_y-2,z_end+12-i*9),rng.randf_range(4.0,7.0))
			if rock:rock.scale.y*=1.5
	for i in range(4):
		_asset("Bush_Common_Flowers",Vector3((-1 if i%2==0 else 1)*(4+i*.4),ground_y,z_end+8+i*3),.9)

func _encounter_landmark(seed_value:int) -> void:
	var variant:int=seed_value%5
	var focal_z:float=stage.spawn.z-float(stage.definition.get("distance",15))-8
	if biome in ["ruins","birch","meadow","blossom"]:
		# Broken crescent ruin from the original scene references, framed beside the shot.
		var root:=Node3D.new();root.name="CrescentRuin";root.position=Vector3(-7 if variant%2==0 else 7,ground_y+2.5,focal_z);stage.add_child(root)
		for i in range(13):
			var angle:float=.15*PI+float(i)*1.7*PI/12
			var block:=_box(root,Vector3(cos(angle)*2.5,sin(angle)*2.5,0),Vector3(.85,.9,.9),Color("86977e"))
			block.rotation.z=angle
		_asset("Bush_Common_Flowers",root.position+Vector3(0,-2.4,.5),1.4)
	if biome in ["river","coast","aurora","pressure"]:
		var water:=MeshInstance3D.new();water.name="ScenicLake";var plane:=PlaneMesh.new();plane.size=Vector2(width*2,22);water.mesh=plane
		water.position=Vector3(0,ground_y-.3,z_end-10)
		var material:=ShaderMaterial.new();material.shader=load("res://campaign/course_water.gdshader");water.material_override=material;stage.add_child(water)
		if biome in ["river","pressure"]:
			var fall:=MeshInstance3D.new();fall.name="Waterfall";var cascade:=PlaneMesh.new();cascade.size=Vector2(2.5,7);fall.mesh=cascade;fall.rotation.x=PI/2
			fall.position=Vector3(-8,ground_y+3.3,focal_z-2);fall.material_override=material;stage.add_child(fall)
			for side in [-1,1]:
				var cliff:=_asset("Rock_Medium_1",fall.position+Vector3(side*2,-3,0),3)
				if cliff:cliff.scale.y*=2
	if biome in ["airgarden","golden","crown"]:
		var tower:=Node3D.new();tower.name="SkySanctuary";tower.position=Vector3(6,ground_y,focal_z-5);stage.add_child(tower)
		for side in [-1,1]:_box(tower,Vector3(side*1.8,5,0),Vector3(1.1,10,1.5),Color("c3b98c"))
		_box(tower,Vector3(0,10.5,0),Vector3(6,1,3),Color("cdbb7b"))
		for i in range(4):_box(tower,Vector3(0,2+i*1.8,.8),Vector3(.12,1,.04),Color("f4d473"))
	if biome in ["ember","storm","lightning","tempest","moonlit"]:
		_magic_stones()
