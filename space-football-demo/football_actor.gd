extends Node3D
## A reusable articulated prototype rig, driven by authoritative action states.
var hips:Node3D
var chest:Node3D
var legs:Array[Node3D]=[]
var shins:Array[Node3D]=[]
var arms:Array[Node3D]=[]
var phase:=0.0
var gait:=0.0
var last_pos:=Vector3.ZERO
var tint:=Color("6af4dc")

func mat(color:Color,metal:float=0.0)->StandardMaterial3D:
 var m:=StandardMaterial3D.new()
 m.albedo_color=color
 m.roughness=0.66
 m.metallic=metal
 return m

func part(parent:Node3D,point:Vector3,size:Vector3,material:Material,round_shape:bool=false)->MeshInstance3D:
 var n:=MeshInstance3D.new()
 if round_shape:
  var mesh:=SphereMesh.new()
  mesh.radius=0.5
  mesh.height=1
  mesh.radial_segments=16
  mesh.rings=8
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

func build(color:Color,number:String,keeper:bool=false)->void:
 tint=color
 var jersey:=mat(color,0.12)
 var shorts:=mat(Color("172638"))
 var skin:=mat(Color("ce997a"))
 var socks:=mat(color.darkened(0.18))
 hips=Node3D.new()
 hips.position.y=1.12
 add_child(hips)
 part(hips,Vector3(0,0.03,0),Vector3(0.66,0.35,0.38),shorts,true)
 chest=Node3D.new()
 chest.position.y=0.29
 hips.add_child(chest)
 part(chest,Vector3(0,0.34,0),Vector3(0.82,0.85,0.43),jersey,true)
 part(chest,Vector3(0,0.84,0),Vector3(0.22,0.24,0.23),skin,true)
 part(chest,Vector3(0,1.11,0),Vector3(0.45,0.54,0.46),skin,true)
 part(chest,Vector3(0,1.31,-0.03),Vector3(0.46,0.18,0.44),mat(Color("1d1b22")),true)
 var label:=Label3D.new()
 label.text=number
 label.font_size=80
 label.pixel_size=0.004
 label.position=Vector3(0,0.38,-0.225)
 label.rotation.y=PI
 label.modulate=Color.WHITE
 label.outline_size=4
 chest.add_child(label)
 for side in [-1,1]:
  var leg:=Node3D.new()
  leg.position=Vector3(side*0.22,-0.07,0)
  hips.add_child(leg)
  legs.append(leg)
  part(leg,Vector3(0,-0.25,0),Vector3(0.27,0.53,0.27),shorts,true)
  var shin:=Node3D.new()
  shin.position.y=-0.5
  leg.add_child(shin)
  shins.append(shin)
  part(shin,Vector3(0,-0.21,0),Vector3(0.21,0.49,0.22),socks,true)
  part(shin,Vector3(0,-0.45,0.09),Vector3(0.25,0.16,0.47),mat(Color("eff1e8")),true)
  var arm:=Node3D.new()
  arm.position=Vector3(side*0.45,0.65,0)
  chest.add_child(arm)
  arms.append(arm)
  part(arm,Vector3(side*0.04,-0.16,0),Vector3(0.25,0.40,0.27),jersey,true)
  part(arm,Vector3(side*0.06,-0.47,0.10),Vector3(0.19,0.38,0.20),skin,true)
  part(arm,Vector3(side*0.06,-0.67,0.15),Vector3(0.22,0.22,0.25),mat(Color("dcebf5")) if keeper else skin,true)

func animate_player(p:Dictionary,dt:float,holding:bool)->void:
 var speed:float=p.vel.length()
 gait=lerpf(gait,minf(1,speed/6),minf(1,dt*12))
 phase+=dt*speed*1.5
 hips.position.y=1.12+absf(sin(phase))*0.055*gait
 chest.rotation.x=lerpf(chest.rotation.x,0.10*gait,minf(1,dt*10))
 chest.rotation.z=sin(phase)*0.035*gait
 for i in 2:
  var wave:=sin(phase+PI*i)
  legs[i].rotation.x=wave*0.62*gait
  shins[i].rotation.x=maxf(0,-wave)*0.85*gait
  arms[i].rotation.x=-wave*0.48*gait
  arms[i].rotation.z=(-0.12 if i==0 else 0.12)
 hips.rotation.z=0
 if p.action_time>0:
  var progress:=1.0-clampf(float(p.action_time)/0.4,0,1)
  if p.action in ["shoot","pass"]:
   legs[1].rotation.x=-sin(progress*PI)*1.3
   shins[1].rotation.x=0.22
   arms[0].rotation.z=-0.65
  elif p.action=="tackle":
   legs[1].rotation.x=-0.95
   hips.position.y=0.93
   chest.rotation.x=0.25
  elif p.action=="save":
   hips.rotation.z=sin(progress*PI)*0.75
   arms[0].rotation.z=-1.2
   arms[1].rotation.z=1.2
  elif p.action=="receive": legs[0].rotation.x=-0.3
 if holding and speed<0.3: legs[1].rotation.x=-0.08
