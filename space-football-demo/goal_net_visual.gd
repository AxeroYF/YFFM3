extends Node3D
const Pitch=preload("res://pitch_geometry.gd")
var net_material:ShaderMaterial
var goal_side:=1.0

func build(side:float)->void:
 goal_side=side;position.x=Pitch.HALF_LENGTH*side;scale.x=side
 net_material=ShaderMaterial.new();net_material.shader=preload("res://shaders/goal_net.gdshader")
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var depth:=Pitch.GOAL_DEPTH;var width:=Pitch.GOAL_HALF_WIDTH
 for k in 21:
  var z:=lerpf(-width,width,k/20.0)
  strand(surface,Vector3(depth,0,z),Vector3(depth,3,z),Vector3.RIGHT)
  strand(surface,Vector3(0,3.6,z),Vector3(depth,3,z),Vector3.UP)
 for k in 7:
  var y:=k*0.5
  strand(surface,Vector3(depth,y,-width),Vector3(depth,y,width),Vector3.RIGHT)
 for k in 7:
  var x:=depth*k/6.0;var roof:=lerpf(3.6,3,x/depth)
  strand(surface,Vector3(x,roof,-width),Vector3(x,roof,width),Vector3.UP)
  for z in [-width,width]: strand(surface,Vector3(x,0,z),Vector3(x,roof,z),Vector3.BACK)
 for k in 7:
  for z in [-width,width]: strand(surface,Vector3(0,k*0.5,z),Vector3(depth,k*0.5,z),Vector3.BACK)
 var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.material_override=net_material
 mesh.extra_cull_margin=1.2;add_child(mesh)

func strand(surface:SurfaceTool,a:Vector3,b:Vector3,normal:Vector3)->void:
 var across:Vector3=normal.cross((b-a).normalized())*0.016
 var count:=maxi(1,ceili(a.distance_to(b)/0.22))
 for k in count:
  var start:=a.lerp(b,float(k)/count);var end:=a.lerp(b,float(k+1)/count)
  for point in [start-across,start+across,end+across,start-across,end+across,end-across]:
   surface.set_normal(normal);surface.add_vertex(point)

func show_state(state:Dictionary)->void:
 var point:Vector3=state.point
 var active:bool=point.x*goal_side>Pitch.HALF_LENGTH-0.1
 net_material.set_shader_parameter("impact_point",Vector3(point.x*goal_side-Pitch.HALF_LENGTH,point.y,point.z))
 net_material.set_shader_parameter("impact_normal",Vector3(state.normal.x*goal_side,state.normal.y,state.normal.z))
 net_material.set_shader_parameter("impact_strength",state.strength if active else 0.0)
 net_material.set_shader_parameter("impact_age",state.age)
