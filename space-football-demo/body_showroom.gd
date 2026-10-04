extends Node3D
const Model=preload("res://skinned_player.gd")
const Body=preload("res://player_body.gd")
const Library=preload("res://player_library.gd")
const Appearance=preload("res://player_appearance.gd")
var models:Array[Node3D]=[]
var records:Array=[]
var page:=0
var page_records:Array=[]
var display_root:Node3D
var focus_index:=-1
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
 var featured:=["legend-messi","legend-haaland","legend-maradona","s4-dlc-20260731-031"]
 for id in featured: records.append(Library.find(id))
 for record in Library.all():
  if Appearance.is_legend(record) and record.id not in featured: records.append(record)
 set_page(0)
 var key:=OmniLight3D.new()
 key.position=Vector3(-4,6,7)
 key.light_color=Color("ffebd2")
 key.light_energy=0.5
 key.light_cull_mask=2
 key.omni_range=20
 add_child(key)
 var fill:=OmniLight3D.new()
 fill.position=Vector3(5,4,3)
 fill.light_color=Color("bcdcff")
 fill.light_energy=0.25
 fill.light_cull_mask=2
 fill.omni_range=16
 add_child(fill)
 var studio_key:=DirectionalLight3D.new()
 studio_key.rotation_degrees=Vector3(-35,-25,0)
 studio_key.light_energy=0.85
 studio_key.light_color=Color("fff0e2")
 studio_key.light_cull_mask=2
 studio_key.shadow_enabled=true
 add_child(studio_key)
 var studio_fill:=DirectionalLight3D.new()
 studio_fill.rotation_degrees=Vector3(-20,145,0)
 studio_fill.light_energy=0.2
 studio_fill.light_color=Color("bcd5f5")
 studio_fill.light_cull_mask=2
 add_child(studio_fill)
 set_studio_layer(self)

func page_count()->int:
 return ceili(records.size()/4.0)

func set_page(value:int)->void:
 page=posmod(value,page_count())
 focus_index=-1
 if is_instance_valid(display_root): display_root.free()
 display_root=Node3D.new();add_child(display_root)
 models.clear()
 page_records=records.slice(page*4,mini(records.size(),page*4+4))
 for i in page_records.size():
  var record:Dictionary=page_records[i]
  var body:=Body.from_record(record,0 if record.role=="GK" else 1)
  var model:=Model.new()
  display_root.add_child(model)
  model.position.x=-4.5+i*3
  model.build(Color("46bca9"),"%02d" % (i+1),record.role=="GK",body)
  model.animate_player({"vel":Vector2.ZERO,"action":"idle","action_time":0},0,false)
  set_studio_layer(model)
  models.append(model)

func focus(index:int)->void:
 focus_index=index
 for i in models.size():
  models[i].visible=index<0 or index==i
  models[i].position.x=-4.5+i*3 if index<0 else 0

func set_studio_layer(node:Node)->void:
 if node is VisualInstance3D: node.layers=2
 for child in node.get_children(): set_studio_layer(child)

func update(dt:float)->void:
 preview_time+=dt
 if turning: angle+=dt*0.45
 for model in models:
  model.rotation.y=angle
  model.animate_player({"vel":Vector2(6,0) if running else Vector2.ZERO,"action":"idle","action_time":0},dt,false)
