extends Node3D
## Cosmetic only. Fixed-size GPU batches; never writes match state or ball paths.
const Conditions=preload("res://match_environment.gd")
var rain:MultiMeshInstance3D
var splashes:MultiMeshInstance3D
var wind:MultiMeshInstance3D
var meteors:Node3D
var clock_time:=0.0
var materials:Array[ShaderMaterial]=[]
var options:Dictionary=Conditions.normalize({})
var lightning:MeshInstance3D
var lightning_light:DirectionalLight3D
var lightning_material:ShaderMaterial
var lightning_age:=1.0
var lightning_wait:=4.5
var lightning_count:=0
var flash_rng:=RandomNumberGenerator.new()
var meteor_seeds:Array[Color]=[]

func build()->void:
 rain=batch("res://shaders/weather.gdshader",0,1100,Vector2(0.028,0.85))
 splashes=batch("res://shaders/weather.gdshader",1,180,Vector2(0.7,0.7))
 wind=batch("res://shaders/weather.gdshader",2,85,Vector2(0.035,2.8))
 build_meteors()
 build_lightning()
 configure({})

func build_meteors()->void:
 meteors=Node3D.new();add_child(meteors)
 var rng:=RandomNumberGenerator.new();rng.seed=823
 var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 var points:=[Vector2(-8,0),Vector2(7,0.13),Vector2(8,0),Vector2(-8,0),Vector2(8,0),Vector2(7,-0.13)]
 for point in points:
  mesh.surface_set_color(Color(0.55,0.76,1.0,0 if point.x<0 else 0.85))
  mesh.surface_add_vertex(Vector3(point.x,point.y,0))
 mesh.surface_end()
 for i in 18:
  meteor_seeds.append(Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
  var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
  mat.vertex_color_use_as_albedo=true
  var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=mat
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  node.visible=false;meteors.add_child(node)

func build_lightning()->void:
 flash_rng.seed=4521
 lightning_material=ShaderMaterial.new();lightning_material.shader=load("res://shaders/lightning.gdshader")
 var mesh:=ImmediateMesh.new()
 mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 var trunk:=[Vector2(-5,25),Vector2(1,7),Vector2(-3,-5),Vector2(7,-22),Vector2(2,-30),Vector2(12,-50),Vector2(8,-57),Vector2(18,-84)]
 var branches:=[trunk,[trunk[3],Vector2(22,-30),Vector2(19,-40),Vector2(32,-53)],[trunk[5],Vector2(-2,-58),Vector2(-9,-73)]]
 for branch_index in branches.size():
  var points:Array=branches[branch_index]
  for i in range(points.size()-1):
   var a:Vector2=points[i];var b:Vector2=points[i+1]
   var offset:Vector2=(b-a).orthogonal().normalized()*(0.30 if branch_index==0 else 0.13)
   for point in [a-offset,a+offset,b+offset,a-offset,b+offset,b-offset]:
    mesh.surface_add_vertex(Vector3(point.x,point.y,-120))
 mesh.surface_end()
 lightning=MeshInstance3D.new();lightning.mesh=mesh;lightning.material_override=lightning_material
 lightning.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(lightning)
 lightning_light=DirectionalLight3D.new();lightning_light.rotation_degrees=Vector3(-65,20,0)
 lightning_light.light_color=Color("bacdff");lightning_light.light_energy=0
 lightning_light.light_cull_mask=1;lightning_light.shadow_enabled=false
 add_child(lightning_light)

func batch(path:String,kind:int,count:int,size:Vector2)->MultiMeshInstance3D:
 var mat:=ShaderMaterial.new();mat.shader=load(path)
 if path.ends_with("weather.gdshader"): mat.set_shader_parameter("kind",kind)
 materials.append(mat)
 var mesh:=QuadMesh.new();mesh.size=size;mesh.material=mat
 var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true
 multi.mesh=mesh;multi.instance_count=count
 var rng:=RandomNumberGenerator.new();rng.seed=823+kind
 for i in count:
  multi.set_instance_transform(i,Transform3D.IDENTITY)
  multi.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
 var node:=MultiMeshInstance3D.new();node.multimesh=multi
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.custom_aabb=AABB(Vector3(-230,-180,-240),Vector3(460,350,320))
 add_child(node)
 return node

func configure(value:Dictionary)->void:
 var was_lightning:bool=Conditions.weather(options).lightning
 options=Conditions.normalize(value)
 rain.visible=Conditions.rainy(options)
 splashes.visible=rain.visible
 wind.visible=Conditions.windy(options)
 meteors.visible=Conditions.stadium(options).meteors
 if not Conditions.weather(options).lightning or not was_lightning:
  lightning_age=1.0;lightning_wait=flash_rng.randf_range(Conditions.weather(options).first_flash_delay.x,Conditions.weather(options).first_flash_delay.y)
  lightning.visible=false;lightning_light.light_energy=0
 for mat in materials:
  if mat.shader.resource_path.ends_with("weather.gdshader"):
   mat.set_shader_parameter("wind_strength",Conditions.weather(options).visual_wind)

func update(dt:float)->void:
 clock_time+=dt
 for mat in materials: mat.set_shader_parameter("clock_time",clock_time)
 if meteors.visible:
  for i in meteor_seeds.size():
   var r:Color=meteor_seeds[i]
   var phase:float=fposmod(r.b+clock_time*(0.075+r.a*0.025),1.0)
   var life:float=smoothstep(0,0.12,phase)*(1-smoothstep(0.65,0.9,phase))
   var point:=Vector3(r.r*250-150+phase*100,-35-r.g*55-phase*25,-125-r.a*35)
   var meteor:MeshInstance3D=meteors.get_child(i)
   meteor.transform=Transform3D(Basis(Vector3.FORWARD,0.49),point)
   meteor.visible=life>0.01
   meteor.material_override.albedo_color=Color(1,1,1,life)
 if not Conditions.weather(options).lightning: return
 lightning_wait-=dt
 if lightning_wait<=0:
  lightning_count+=1;lightning_age=0
  lightning_wait=flash_rng.randf_range(Conditions.weather(options).flash_interval.x,Conditions.weather(options).flash_interval.y)
  lightning.position.x=flash_rng.randf_range(-95,70)
 lightning_age+=dt
 # One brief flash with a soft fade, never rapid repeated full-screen strobing.
 var intensity:float=clampf(lightning_age/0.035,0,1)*pow(maxf(0,1-lightning_age/Conditions.weather(options).flash_duration),2)
 lightning.visible=intensity>0.005
 lightning_material.set_shader_parameter("intensity",intensity)
 lightning_light.light_energy=intensity*Conditions.weather(options).flash_energy
