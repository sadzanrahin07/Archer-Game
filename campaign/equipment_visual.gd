extends RefCounted
const Catalog=preload("res://campaign/catalog.gd")

static func build(kind:String,id:int) -> Node3D:
	var root:=Node3D.new()
	var mesh:=MeshInstance3D.new()
	mesh.name="EquipmentMesh"
	mesh.mesh=load((Catalog.BOWS if kind=="bow" else Catalog.ARROWS)[id].mesh)
	root.add_child(mesh)
	if kind=="arrow":
		Catalog.apply_arrow_finish(mesh,id)
		var bounds:=mesh.mesh.get_aabb()
		var width_scale:=minf(.8,.085/maxf(bounds.size.x,bounds.size.z))
		mesh.scale=Vector3(width_scale,1.0/bounds.size.y,width_scale)
		mesh.position.y=-bounds.get_center().y*mesh.scale.y
	else:
		mesh.rotation.y=PI/2
		var top:=Vector3(0,.85,-.269);var bottom:=Vector3(0,-.83,-.269)
		var geometry:String=Catalog.BOWS[id].geometry
		if geometry!="standard":
			var points:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://campaign/equipment/geometry.json"))[geometry]
			top=Vector3(points.top[0],points.top[1],points.top[2]);bottom=Vector3(points.bottom[0],points.bottom[1],points.bottom[2])
		var string_mesh:=ImmediateMesh.new();string_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		string_mesh.surface_add_vertex(top);string_mesh.surface_add_vertex(bottom);string_mesh.surface_end()
		var bowstring:=MeshInstance3D.new();bowstring.name="Bowstring";bowstring.mesh=string_mesh
		var material:=StandardMaterial3D.new();material.albedo_color=Color("ebe8d6");bowstring.material_override=material
		mesh.add_child(bowstring)
	return root

static func thumbnail(parent:Node,kind:String,id:int) -> SubViewport:
	var viewport:=SubViewport.new();viewport.name="EquipmentCard_"+kind+str(id)
	viewport.size=Vector2i(256,256);viewport.transparent_bg=true;viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	parent.add_child(viewport)
	var model:=build(kind,id);model.rotation.z=-.38;viewport.add_child(model)
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color(0,0,0,0)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.8
	environment.environment=env;viewport.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-25,-30,0);light.light_energy=1.6;viewport.add_child(light)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.0 if kind=="bow" else 1.25
	camera.position=Vector3(0,0,3);viewport.add_child(camera);camera.look_at(Vector3.ZERO);camera.current=true
	return viewport
