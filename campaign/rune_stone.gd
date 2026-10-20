extends Node3D

var body: MeshInstance3D
var facets: Array[Vector3] = []
var accent := Color("66e9ec")
var shards: Array[Node3D] = []
var shard_bases: Array[Vector3] = []
var elapsed := 0.0
var variant := 0

func build(kind: String, seed_value: int = 0) -> MeshInstance3D:
	variant = posmod(seed_value,3)
	accent = Color("a3efd0") if kind=="stone" else (Color("8fe5ff") if kind=="rune" else Color("ab9bff"))
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value+733
	var levels:Array[float]=[-1.45,-0.95,0.5,1.25,1.75]
	var widths:Array[float]=[0.69,0.99,0.91,0.55,0.04]
	var rings:Array[Array]=[]
	for y in range(levels.size()):
		var ring:Array[Vector3]=[]
		for j in range(8):
			var angle:=j*TAU/8.0
			var p:=Vector3(cos(angle)*widths[y]*(1+rng.randf_range(-.11,.11)),levels[y]+rng.randf_range(-.07,.07),sin(angle)*(.38 if y>0 else .32))
			ring.append(p);facets.append(p)
		rings.append(ring)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_color:=Color("68746b") if kind=="stone" else (Color("455c67") if kind=="rune" else Color("343f53"))
	for y in range(rings.size()-1):
		for j in range(8):
			var next:=posmod(j+1,8)
			var shade:=rng.randf_range(.77,1.16)
			for p in [rings[y][j],rings[y+1][j],rings[y+1][next],rings[y][j],rings[y+1][next],rings[y][next]]:
				surface.set_color(base_color*shade);surface.add_vertex(p)
	surface.generate_normals()
	body=MeshInstance3D.new();body.mesh=surface.commit();body.name="FacetedMonolith"
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.96
	body.material_override=mat;add_child(body)
	var rune:=Node3D.new();rune.name="EngravedTarget";rune.position.z=.445;add_child(rune)
	var rune_mat:=StandardMaterial3D.new();rune_mat.albedo_color=accent; rune_mat.emission_enabled=true;rune_mat.emission=accent;rune_mat.emission_energy_multiplier=1.7
	# Geometric engraved marks leave a clearly readable central precision point.
	_polyline(rune,[Vector3(0,.62,0),Vector3(-.38,0,0),Vector3(0,-.62,0),Vector3(.38,0,0),Vector3(0,.62,0)],.018,rune_mat)
	_polyline(rune,[Vector3(0,.32,.008),Vector3(-.19,0,.008),Vector3(0,-.32,.008),Vector3(.19,0,.008),Vector3(0,.32,.008)],.024,rune_mat)
	_polyline(rune,[Vector3(0,.85,0),Vector3(0,1.12,0),Vector3(.12,1.27,0)],.016,rune_mat)
	_polyline(rune,[Vector3(0,-.85,0),Vector3(0,-1.16,0),Vector3(-.13,-1.27,0)],.016,rune_mat)
	var core:=MeshInstance3D.new();var ball:=SphereMesh.new();ball.radius=.085;ball.height=.17
	core.mesh=ball;core.material_override=rune_mat;rune.add_child(core)
	if kind=="master" or variant==2:
		for i in range(6):
			var shard:=MeshInstance3D.new();var chunk:=PrismMesh.new();chunk.size=Vector3(.23,.46,.22);shard.mesh=chunk
			var dark:=StandardMaterial3D.new();dark.albedo_color=base_color;dark.roughness=.78;dark.emission_enabled=true;dark.emission=accent;dark.emission_energy_multiplier=.16
			shard.material_override=dark
			var origin:=Vector3(cos(i*TAU/6)*1.19,sin(i*TAU/6)*1.31,.02)
			shard.position=origin;shard.rotation=Vector3(rng.randf(),rng.randf(),rng.randf());add_child(shard)
			shards.append(shard);shard_bases.append(origin)
	for i in range(5):
		var moss:=MeshInstance3D.new();var patch:=SphereMesh.new();patch.radius=.19;patch.height=.12;moss.mesh=patch
		var green:=StandardMaterial3D.new();green.albedo_color=Color("79a950");green.roughness=1
		moss.material_override=green;moss.position=Vector3(rng.randf_range(-.55,.55),-1.35,.36);add_child(moss)
	return body

func _process(delta: float) -> void:
	elapsed+=delta
	for i in range(shards.size()):
		shards[i].position=shard_bases[i]+Vector3(0,sin(elapsed*1.5+i)*.075,0)
		shards[i].rotation.y+=delta*.12

func _polyline(parent: Node3D,points:Array,width:float,mat:Material) -> void:
	for i in range(points.size()-1):
		var a:Vector3=points[i];var b:Vector3=points[i+1]
		var line:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=width;cylinder.bottom_radius=width;cylinder.height=a.distance_to(b);cylinder.radial_segments=6
		line.mesh=cylinder;line.material_override=mat;line.position=(a+b)*.5;line.quaternion=Quaternion(Vector3.UP,(b-a).normalized());parent.add_child(line)
