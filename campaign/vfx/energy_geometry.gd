extends RefCounted
# Tubes have real volume and depth from every viewing angle. No billboard textures.
static func material() -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = preload("res://campaign/vfx/energy_flow.gdshader")
 return result

static func instance(parent: Node3D, mat: Material) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.mesh = ImmediateMesh.new()
 node.material_override = mat
 node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(node)
 return node

static func tube(mesh: ImmediateMesh, points: PackedVector3Array, radius: float, color: Color, taper: bool = true, sides: int = 5) -> void:
 if points.size() < 2: return
 for i in range(points.size()-1):
  var tangent: Vector3 = (points[i+1]-points[i]).normalized()
  if tangent.length_squared() < .01: continue
  var axis: Vector3 = tangent.cross(Vector3.UP if absf(tangent.y)<.95 else Vector3.RIGHT).normalized()
  var other: Vector3 = tangent.cross(axis).normalized()
  var u0: float = float(i)/(points.size()-1)
  var u1: float = float(i+1)/(points.size()-1)
  var r0: float = radius * (pow(1.0-u0,.7) if taper else 1.0)
  var r1: float = radius * (pow(1.0-u1,.7) if taper else 1.0)
  for j in range(sides):
   var a: float = TAU*float(j)/sides
   var b: float = TAU*float(j+1)/sides
   var va: Vector3 = axis*cos(a)+other*sin(a)
   var vb: Vector3 = axis*cos(b)+other*sin(b)
   var vertices: Array[Vector3] = [points[i]+va*r0,points[i+1]+va*r1,points[i]+vb*r0,points[i]+vb*r0,points[i+1]+va*r1,points[i+1]+vb*r1]
   for k in range(6):
    var u: float = u1 if k in [1,4,5] else u0
    mesh.surface_set_color(Color(color, color.a * (1.0-u*.8 if taper else 1.0)))
    mesh.surface_set_uv(Vector2(u,float(j)/sides))
    mesh.surface_set_normal(va if k in [0,1,4] else vb)
    mesh.surface_add_vertex(vertices[k])
