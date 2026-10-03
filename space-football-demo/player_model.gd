extends Node3D
## Dimensioned procedural game-art rig, not a scanned player likeness.
const Body=preload("res://player_body.gd")
var hips:Node3D
var chest:Node3D
var head:Node3D
var legs:Array[Node3D]=[]
var shins:Array[Node3D]=[]
var arms:Array[Node3D]=[]
var elbows:Array[Node3D]=[]
var phase:=0.0
var gait:=0.0
var body:Dictionary
var hip_height:=0.0

func mat(color:Color,metal:float=0.0)->StandardMaterial3D:
 var m:=StandardMaterial3D.new()
 m.albedo_color=color
 m.roughness=0.78
 m.metallic=metal
 return m

func part(parent:Node3D,point:Vector3,size:Vector3,material:Material,round_shape:bool=true)->MeshInstance3D:
 var n:=MeshInstance3D.new()
 if round_shape:
  var mesh:=SphereMesh.new()
  mesh.radius=0.5
  mesh.height=1
  mesh.radial_segments=24
  mesh.rings=12
  n.mesh=mesh
 else:
  var mesh:=BoxMesh.new()
  mesh.size=Vector3.ONE
  n.mesh=mesh
 n.scale=size
 n.position=point
 n.material_override=material
 parent.add_child(n)
 return n

func contour(parent:Node3D,point:Vector3,rings:Array,material:Material)->MeshInstance3D:
 # Cross sections define waist, rib cage, shoulders, and tapered muscle groups.
 var surface:=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var segments:=24
 for r in rings.size():
  var ring:Vector3=rings[r]
  for j in segments+1:
   var a:=TAU*j/segments
   surface.set_uv(Vector2(float(j)/segments,float(r)/maxi(1,rings.size()-1)))
   surface.add_vertex(Vector3(cos(a)*ring.y,ring.x,sin(a)*ring.z))
 for r in rings.size()-1:
  for j in segments:
   var a:=r*(segments+1)+j
   var b:=a+segments+1
   for index in [a,a+1,b,b,a+1,b+1]: surface.add_index(index)
 surface.generate_normals()
 var mesh:=MeshInstance3D.new()
 mesh.mesh=surface.commit()
 mesh.position=point
 mesh.material_override=material
 parent.add_child(mesh)
 return mesh

func joint(parent:Node3D,point:Vector3)->Node3D:
 var node:=Node3D.new()
 node.position=point
 parent.add_child(node)
 return node

func build(color:Color,number:String,is_keeper:bool=false,profile:Dictionary={})->void:
 body=Body.profile(0 if is_keeper else 1) if profile.is_empty() else profile.duplicate(true)
 var h:float=body.height
 var shoulder:float=body.shoulder
 var hip_width:float=body.hip_width
 var leg_length:float=body.leg_length
 var head_size:float=body.head_size
 var jersey:=mat(color)
 var trim:=mat(color.lightened(0.4))
 var shorts:=mat(Color("102132"))
 var skin:=mat(Color(body.skin))
 var hair:=mat(Color(body.hair))
 var socks:=mat(color.darkened(0.26))
 var boots:=mat(Color("e1efdf"),0.10)
 hip_height=leg_length
 hips=joint(self,Vector3(0,hip_height,0))
 contour(hips,Vector3.ZERO,[Vector3(-h*0.075,hip_width*0.47,h*0.065),Vector3(0,hip_width*0.55,h*0.085),Vector3(h*0.075,hip_width*0.47,h*0.071)],shorts)
 chest=joint(hips,Vector3(0,h*0.065,0))
 var torso_top:=h*0.79-hip_height-h*0.065
 contour(chest,Vector3.ZERO,[Vector3(0,hip_width*0.48,h*0.073),Vector3(torso_top*0.24,hip_width*0.49,h*0.08),Vector3(torso_top*0.70,shoulder*0.43,h*0.105),Vector3(torso_top*0.90,shoulder*0.48,h*0.088),Vector3(torso_top,shoulder*0.34,h*0.065)],jersey)
 part(chest,Vector3(0,torso_top,0),Vector3(h*0.12,h*0.024,h*0.13),shorts)
 part(chest,Vector3(0,torso_top+h*0.025,0),Vector3(h*0.079,h*0.075,h*0.075),skin)
 for side in [-1,1]:
  part(chest,Vector3(side*shoulder*0.36,torso_top*0.93,h*0.032),Vector3(h*0.072,h*0.025,h*0.12),trim)
 part(chest,Vector3(-shoulder*0.23,torso_top*0.68,h*0.102),Vector3(h*0.04,h*0.05,h*0.008),trim,false)
 for front in [false,true]:
  var label:=Label3D.new()
  label.text=number
  label.font_size=96
  label.pixel_size=h*(0.0010 if front else 0.0016)
  label.position=Vector3(0,torso_top*0.46,h*(0.109 if front else -0.109))
  if not front: label.rotation.y=PI
  label.modulate=Color("f3f7f5")
  label.outline_size=2
  chest.add_child(label)
 head=joint(chest,Vector3(0,h*0.931-hip_height-h*0.065,0))
 part(head,Vector3.ZERO,Vector3(head_size*0.72,head_size,head_size*0.83),skin)
 part(head,Vector3(0,-head_size*0.26,head_size*0.13),Vector3(head_size*0.58,head_size*0.36,head_size*0.55),skin)
 part(head,Vector3(0,-head_size*0.015,head_size*0.43),Vector3(head_size*0.14,head_size*0.27,head_size*0.22),skin)
 for side in [-1,1]:
  part(head,Vector3(side*head_size*0.37,0,0),Vector3(head_size*0.13,head_size*0.26,head_size*0.18),skin)
  part(head,Vector3(side*head_size*0.16,head_size*0.07,head_size*0.369),Vector3(head_size*0.16,head_size*0.066,head_size*0.043),mat(Color("eee6d7")))
  part(head,Vector3(side*head_size*0.16,head_size*0.07,head_size*0.394),Vector3(head_size*0.058,head_size*0.058,head_size*0.014),hair)
  part(head,Vector3(side*head_size*0.16,head_size*0.15,head_size*0.35),Vector3(head_size*0.18,head_size*0.043,head_size*0.037),hair)
 part(head,Vector3(0,-head_size*0.22,head_size*0.405),Vector3(head_size*0.22,head_size*0.026,head_size*0.024),mat(Color(body.skin).darkened(0.38)))
 part(head,Vector3(0,head_size*0.35,-head_size*0.025),Vector3(head_size*0.75,head_size*0.31,head_size*0.79),hair)
 if body.hair_style=="tied":
  part(head,Vector3(0,head_size*0.20,-head_size*0.43),Vector3(head_size*0.32,head_size*0.30,head_size*0.32),hair)
 elif body.hair_style=="curly":
  for i in 15:
   var a:=TAU*i/15
   part(head,Vector3(cos(a)*head_size*0.26,head_size*(0.35+0.04*sin(i*4)),sin(a)*head_size*0.26),Vector3.ONE*head_size*0.22,hair)
 if body.beard:
  part(head,Vector3(0,-head_size*0.32,head_size*0.15),Vector3(head_size*0.62,head_size*0.26,head_size*0.58),hair)
 var thigh:=leg_length*0.48
 var shin_length:=leg_length-thigh-h*0.055
 for side in [-1,1]:
  var leg:=joint(hips,Vector3(side*hip_width*0.29,0,0))
  legs.append(leg)
  contour(leg,Vector3.ZERO,[Vector3(-thigh,h*0.044,h*0.048),Vector3(-thigh*0.40,h*0.063,h*0.067),Vector3(0,h*0.073,h*0.078)],skin)
  contour(leg,Vector3.ZERO,[Vector3(-thigh*0.56,h*0.068,h*0.073),Vector3(0,h*0.077,h*0.083)],shorts)
  var shin:=joint(leg,Vector3(0,-thigh,0))
  shins.append(shin)
  part(shin,Vector3.ZERO,Vector3(h*0.09,h*0.085,h*0.094),skin)
  contour(shin,Vector3.ZERO,[Vector3(-shin_length,h*0.032,h*0.037),Vector3(-shin_length*0.4,h*0.051,h*0.055),Vector3(-shin_length*0.05,h*0.044,h*0.047)],socks)
  part(shin,Vector3(0,-shin_length*0.14,0),Vector3(h*0.10,h*0.025,h*0.105),trim)
  var ankle_y:=-shin_length
  part(shin,Vector3(0,ankle_y-h*0.02,h*0.028),Vector3(h*0.092,h*0.066,h*0.173),boots)
  part(shin,Vector3(0,ankle_y-h*0.042,h*0.028),Vector3(h*0.095,h*0.018,h*0.175),shorts)
  for lace in 3:
   part(shin,Vector3(0,ankle_y+h*0.011,h*(0.025+lace*0.017)),Vector3(h*0.052,h*0.006,h*0.005),shorts,false)
  var arm:=joint(chest,Vector3(side*shoulder*0.48,torso_top*0.82,0))
  arms.append(arm)
  var upper:=h*0.16
  var forearm:=h*0.145
  contour(arm,Vector3.ZERO,[Vector3(-upper,h*0.032,h*0.035),Vector3(-upper*0.35,h*0.047,h*0.05),Vector3(0,h*0.05,h*0.051)],skin)
  contour(arm,Vector3.ZERO,[Vector3(-upper*0.51,h*0.05,h*0.053),Vector3(0,h*0.056,h*0.057)],jersey)
  var elbow:=joint(arm,Vector3(0,-upper,0))
  elbows.append(elbow)
  part(elbow,Vector3.ZERO,Vector3.ONE*h*0.067,skin)
  contour(elbow,Vector3.ZERO,[Vector3(-forearm,h*0.023,h*0.026),Vector3(-forearm*0.28,h*0.035,h*0.038),Vector3(0,h*0.032,h*0.035)],skin)
  var hand_mat:=boots if is_keeper else skin
  part(elbow,Vector3(0,-forearm-h*0.035,h*0.006),Vector3(h*0.062,h*0.077,h*0.034),hand_mat)
  for finger in 4:
   part(elbow,Vector3((finger-1.5)*h*0.013,-forearm-h*0.079,h*0.008),Vector3(h*0.012,h*0.038,h*0.022),hand_mat)
  part(elbow,Vector3(-side*h*0.034,-forearm-h*0.034,h*0.018),Vector3(h*0.024,h*0.047,h*0.027),hand_mat)

func animate_player(p:Dictionary,dt:float,holding:bool)->void:
 var speed:float=p.vel.length()
 var h:float=body.height
 gait=lerpf(gait,minf(1,speed/6),minf(1,dt*12))
 phase+=dt*speed*1.5*(2.7/h)
 hips.position.y=hip_height+absf(sin(phase))*h*0.019*gait
 chest.rotation.x=lerpf(chest.rotation.x,0.10*gait,minf(1,dt*10))
 chest.rotation.z=sin(phase)*0.035*gait
 head.rotation.y=sin(phase*0.5)*0.04*gait
 for i in 2:
  var wave:=sin(phase+PI*i)
  legs[i].rotation.x=wave*0.62*gait
  shins[i].rotation.x=maxf(0,-wave)*0.85*gait
  arms[i].rotation.x=-wave*0.48*gait
  arms[i].rotation.z=(-0.11 if i==0 else 0.11)
  elbows[i].rotation.x=-0.25-0.65*gait
 hips.rotation.z=0
 if p.action_time>0:
  var progress:=1.0-clampf(float(p.action_time)/0.4,0,1)
  if p.action in ["shoot","pass"]:
   legs[1].rotation.x=-sin(progress*PI)*1.3
   shins[1].rotation.x=0.22
   arms[0].rotation.z=-0.65
  elif p.action=="tackle":
   legs[1].rotation.x=-0.95
   hips.position.y=hip_height-h*0.065
   chest.rotation.x=0.25
  elif p.action=="save":
   hips.rotation.z=sin(progress*PI)*0.75
   arms[0].rotation.z=-2.3
   arms[1].rotation.z=2.3
   elbows[0].rotation.x=-0.15
   elbows[1].rotation.x=-0.15
  elif p.action=="block": chest.rotation.x=-0.18
  elif p.action=="receive": legs[0].rotation.x=-0.3
 if holding and speed<0.3: legs[1].rotation.x=-0.08
