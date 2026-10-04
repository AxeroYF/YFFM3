extends RefCounted
## Fitted CC0 hair and authored facial-hair masks, all attached to the same rig.
const Morph=preload("res://player_morph.gd")
const HAIR:={"short":"short03","crop":"short04","quiff":"short04","swept":"short01","long":"bob02","waves":"bob01","curly":"afro01","curls_long":"bob01","afro":"afro01","tied":"ponytail01","locks":"afro01","mascot":"short04"}
const LABELS:={"short":"短发","crop":"短碎发","quiff":"短发上梳","swept":"侧梳发","long":"中长发","waves":"蓬松中长发","curly":"卷发","curls_long":"长卷发","afro":"蓬松卷发","tied":"束发","locks":"长束卷发","bald":"光头","shaved":"剃短发","buzz":"寸头","receding":"后退发际线","mascot":"趣味外观"}
static var assets:Dictionary={}
static var cache:Dictionary={}

static func skin_material(body:Dictionary)->ShaderMaterial:
 var m:=ShaderMaterial.new()
 m.shader=preload("res://assets/humanoid/skin_tint.gdshader")
 m.set_shader_parameter("skin_texture",preload("res://assets/humanoid/skin.png"))
 m.set_shader_parameter("skin_tint",Color(body.skin))
 m.set_shader_parameter("hair_tint",Color(body.hair))
 m.set_shader_parameter("beard_style",["none","stubble","full","goatee","moustache"].find(body.beard_style))
 return m

static func beard_mask(v:Array)->Color:
 # Store coverage on the unposed mesh, so headers/dives/turns cannot slide the
 # beard around the face. Vertex colours travel with the skinned surface.
 var x:=absf(float(v[0]));var y:float=v[1];var z:float=v[2]
 var edge:=lerpf(0.902,0.914,smoothstep(0.016,0.032,x))
 var beard:=smoothstep(0.868,0.883,y)*(1.0-smoothstep(edge-0.003,edge+0.003,y))*smoothstep(0.038,0.060,z)
 var lips:=exp(-pow(x/0.020,4.0)-pow((y-0.895)/0.0032,2.0))
 beard*=1.0-lips
 var moustache:float=(1.0-smoothstep(0.017,0.026,x))*smoothstep(0.898,0.901,y)*(1.0-smoothstep(0.905,0.908,y))*smoothstep(0.073,0.083,z)
 return Color(beard,moustache,beard*(1.0-smoothstep(0.013,0.025,x)),1)

static func build(actor,skin:Skin)->void:
 var body:Dictionary=actor.body
 var style:String=body.hair_style
 if style=="bald": return
 var key:=Morph.signature(body)+"/"+style+"/"+str(body.hair_volume)+"/"+str(body.hair_length)
 if not cache.has(key):
  if cache.size()>=32: cache.erase(cache.keys()[0])
  cache[key]=scalp_geometry(actor,style) if style in ["buzz","shaved","receding"] else hair_geometry(actor,style)
 var hair:=MeshInstance3D.new()
 hair.name="PersonalHair"
 hair.mesh=cache[key]
 hair.skin=skin
 hair.skeleton=NodePath("../Skeleton3D")
 hair.extra_cull_margin=body.height
 actor.add_child(hair)
 if style in ["buzz","shaved","receding"]:
  var m:=StandardMaterial3D.new()
  m.albedo_color=Color(body.hair).lerp(Color(body.skin),0.52 if style=="shaved" else 0.10)
  m.roughness=0.96
  hair.material_override=m
 else:
  var m:=ShaderMaterial.new()
  m.shader=preload("res://assets/humanoid/hair_tint.gdshader")
  m.set_shader_parameter("hair_texture",load("res://assets/humanoid/hair/%s.png" % HAIR[style]))
  m.set_shader_parameter("hair_tint",Color(body.hair))
  hair.material_override=m
 if style=="locks": add_locks(actor)
 if style=="mascot": add_mascot_details(actor)

static func write_vertex(st:SurfaceTool,data:Dictionary,index:int,point:Vector3,normal:Vector3,uv:Vector2)->void:
 var binds:=PackedInt32Array([0,0,0,0])
 var weights:=PackedFloat32Array([0,0,0,0])
 for w in data.weights[index].size():
  binds[w]=int(data.weights[index][w][0]);weights[w]=float(data.weights[index][w][1])
 st.set_bones(binds);st.set_weights(weights)
 st.set_normal(normal);st.set_uv(uv);st.add_vertex(point)

static func hair_geometry(actor,style:String)->ArrayMesh:
 var name:String=HAIR[style]
 if not assets.has(name): assets[name]=JSON.parse_string(FileAccess.get_file_as_string("res://assets/humanoid/hair/%s.json" % name))
 var data:Dictionary=assets[name]
 var positions:=PackedVector3Array()
 for v in data.vertices:
  var p:Array=v.duplicate()
  var upper:=smoothstep(0.942,0.996,float(p[1]))
  var volume:float=lerpf(1.0,float(actor.body.hair_volume),upper)
  p[0]*=volume
  p[2]=0.025+(float(p[2])-0.025)*volume
  p[1]=float(p[1])+maxf(0,float(p[1])-0.96)*(volume-1.0)
  if style=="quiff": p[1]+=smoothstep(0.982,1.0,float(p[1]))*0.0025
  if style in ["long","waves","curls_long"]:
   # These source bobs were made for casual clothing. Sweep the fringe off the
   # central face for football while preserving the longer sides and back.
   var fringe:float=(1.0-smoothstep(0.022,0.041,absf(float(p[0]))))*smoothstep(0.042,0.070,float(p[2]))
   p[1]=lerpf(float(p[1]),maxf(float(p[1]),0.963),fringe)
  if style=="tied" and float(p[1])<0.91 and float(p[2])<-0.02:
   p[1]=0.91-(0.91-float(p[1]))*float(actor.body.hair_length)
  if style in ["curls_long","waves"]:
   var wave:float=sin(float(p[1])*360.0+float(p[0])*240.0)*0.0025
   p[0]+=signf(float(p[0]))*wave
   p[2]+=wave
   if style=="curls_long" and float(p[1])<0.925: p[1]=0.925-(0.925-float(p[1]))*1.6
  positions.append(actor.dimensions(p))
 var mesh:=ArrayMesh.new()
 for surface in data.surfaces:
  var normals:=PackedVector3Array();normals.resize(positions.size())
  for i in range(0,surface.indices.size(),3):
   var a:int=surface.indices[i];var b:int=surface.indices[i+1];var c:int=surface.indices[i+2]
   var n:Vector3=(positions[b]-positions[a]).cross(positions[c]-positions[a])
   normals[a]+=n;normals[b]+=n;normals[c]+=n
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for t in range(0,surface.indices.size(),3):
   for k in [0,2,1]:
    var at:int=t+k;var index:int=surface.indices[at]
    write_vertex(st,data,index,positions[index],normals[index].normalized(),Vector2(surface.uv[at][0],1.0-surface.uv[at][1]))
  st.index();st.commit(mesh)
 return mesh

static func scalp_mask(v:Array,style:String)->bool:
 var y:float=v[1];var x:=absf(float(v[0]));var z:float=v[2]
 var front:=smoothstep(0.008,0.073,z)
 var line:=lerpf(0.908,0.965,front)
 if style=="receding":
  if y>0.973 or (x<0.034 and z>0.006): return false
 return y>line

static func scalp_geometry(actor,style:String)->ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var data:Dictionary=actor.asset
 var skin:Dictionary=data.surfaces.filter(func(s):return s.material=="skin")[0]
 for t in range(0,skin.indices.size(),3):
  var ids:Array=[skin.indices[t],skin.indices[t+1],skin.indices[t+2]]
  if not ids.all(func(id):return scalp_mask(data.vertices[id],style)): continue
  for k in [0,2,1]:
   var id:int=ids[k];var v:Array=data.vertices[id]
   var outward:=Vector3(v[0],float(v[1])-0.938,float(v[2])-0.025).normalized()
   var point:Vector3=actor.dimensions(v)+outward*actor.body.height*0.00065
   write_vertex(st,data,id,point,outward,Vector2.ZERO)
 st.index()
 return st.commit()

static func head_attachment(actor)->BoneAttachment3D:
 var at:=BoneAttachment3D.new();at.bone_name="head"
 actor.skeleton.add_child(at)
 return at

static func add_locks(actor)->void:
 var at:=head_attachment(actor)
 var origin:Vector3=actor.dimensions(actor.asset.bones[actor.bone_ids.head].head)
 var material:=StandardMaterial3D.new();material.albedo_color=Color(actor.body.hair);material.roughness=0.95
 # Authored curved locks surround the back and sides; no floating primitive joints.
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for strand in 18:
  var angle:float=0.66+strand/17.0*(TAU-1.32)
  var rings:Array=[]
  for row in 7:
   var f:float=row/6.0
   var center:=Vector3(sin(angle)*(0.042+sin(f*PI)*0.012),0.972-f*(0.092+0.012*sin(strand*2.3)),0.026+cos(angle)*0.052-f*0.009)
   center.x+=sin(f*5.0+strand)*0.004
   var ring:Array=[]
   for side in 8:
    var theta:float=side/8.0*TAU
    var p:=center+Vector3(cos(theta),0,sin(theta))*(0.004*(1.0-f*0.5))
    ring.append(actor.dimensions([p.x,p.y,p.z])-origin)
   rings.append(ring)
  for row in 6:
   for side in 8:
    var next:=(side+1)%8
    for p in [rings[row][side],rings[row+1][side],rings[row][next],rings[row][next],rings[row+1][side],rings[row+1][next]]: st.add_vertex(p)
 st.generate_normals();st.index()
 var mesh:=MeshInstance3D.new();mesh.name="CurvedLocks";mesh.mesh=st.commit();mesh.material_override=material;at.add_child(mesh)

static func add_mascot_details(actor)->void:
 var at:=head_attachment(actor)
 var origin:Vector3=actor.dimensions(actor.asset.bones[actor.bone_ids.head].head)
 for item in [[Vector3(-0.052,0.975,0.024),Vector3(0.053,0.063,0.020),Color(actor.body.skin)],[Vector3(0.052,0.975,0.024),Vector3(0.053,0.063,0.020),Color(actor.body.skin)],[Vector3(-0.052,0.975,0.034),Vector3(0.036,0.046,0.009),Color("c7a4a0")],[Vector3(0.052,0.975,0.034),Vector3(0.036,0.046,0.009),Color("c7a4a0")],[Vector3(0,0.918,0.103),Vector3(0.026,0.019,0.024),Color("b99792")]]:
  var node:=MeshInstance3D.new();var shape:=SphereMesh.new();shape.height=1;shape.radius=0.5;shape.radial_segments=24;shape.rings=12
  node.mesh=shape;node.scale=item[1]*actor.body.height
  node.position=actor.dimensions([item[0].x,item[0].y,item[0].z])-origin
  var mat:=StandardMaterial3D.new();mat.albedo_color=item[2];mat.roughness=0.85;node.material_override=mat
  at.add_child(node)
