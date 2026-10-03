extends Node3D
const Model=preload("res://skinned_player.gd")
const Body=preload("res://player_body.gd")
var models:Array[Node3D]=[]
var running:=false
var turning:=false
var angle:=0.0
var preview_time:=0.0

func block(point:Vector3,size_value:Vector3,color:Color)->void:
 var node:=MeshInstance3D.new()
 var mesh:=BoxMesh.new()
 mesh.size=size_value
 node.mesh=mesh
 node.position=point
 var material:=StandardMaterial3D.new()
 material.albedo_color=color
 material.roughness=0.72
 node.material_override=material
 node.layers=2
 add_child(node)

func build()->void:
 position.y=75
 block(Vector3(0,-0.09,0),Vector3(12,0.18,3.5),Color("102236"))
 var slots:=[2,1,3,4]
 for i in 4:
  var x:float=-4.5+i*3
  var body:=Body.profile(slots[i])
  var model:=Model.new()
  add_child(model)
  model.position.x=x
  model.build(Color("46bca9"),["10","09","05","04"][i],false,body)
  model.animate_player({"vel":Vector2.ZERO,"action":"idle","action_time":0},0,false)
  set_studio_layer(model)
  models.append(model)
  block(Vector3(x,0.015,0),Vector3(1.55,0.03,1.4),Color("1e3b4e"))
  for cm in range(0,211,10):
   var y:=cm*0.01*Body.WORLD_UNITS_PER_METRE
   block(Vector3(x+0.94,y,-0.5),Vector3(0.22 if cm%50==0 else 0.12,0.009,0.012),Color("4b6576"))
  block(Vector3(x+0.98,1.52,-0.5),Vector3(0.012,3.04,0.012),Color("4b6576"))
  block(Vector3(x+0.58,body.height,-0.5),Vector3(0.82,0.014,0.025),Color("62edda"))
 var key:=OmniLight3D.new()
 key.position=Vector3(-4,6,7)
 key.light_color=Color("ffebd2")
 key.light_energy=0.85
 key.light_cull_mask=2
 key.omni_range=20
 add_child(key)
 var fill:=OmniLight3D.new()
 fill.position=Vector3(5,4,3)
 fill.light_color=Color("bcdcff")
 fill.light_energy=0.6
 fill.light_cull_mask=2
 fill.omni_range=16
 add_child(fill)
 var studio_key:=DirectionalLight3D.new()
 studio_key.rotation_degrees=Vector3(-35,-25,0)
 studio_key.light_energy=1.15
 studio_key.light_color=Color("fff0e2")
 studio_key.light_cull_mask=2
 studio_key.shadow_enabled=true
 add_child(studio_key)
 var studio_fill:=DirectionalLight3D.new()
 studio_fill.rotation_degrees=Vector3(-20,145,0)
 studio_fill.light_energy=0.4
 studio_fill.light_color=Color("bcd5f5")
 studio_fill.light_cull_mask=2
 add_child(studio_fill)

func set_studio_layer(node:Node)->void:
 if node is VisualInstance3D: node.layers=2
 for child in node.get_children(): set_studio_layer(child)

func update(dt:float)->void:
 preview_time+=dt
 if turning: angle+=dt*0.45
 for model in models:
  model.rotation.y=angle
  model.animate_player({"vel":Vector2(6,0) if running else Vector2.ZERO,"action":"idle","action_time":0},dt,false)
