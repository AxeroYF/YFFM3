extends RefCounted
## Authority keeps the scored ball moving inside a soft, three-sided goal net.
const Pitch=preload("res://pitch_geometry.gd")
const Physics=preload("res://ball_physics.gd")
static func empty()->Dictionary:
 return {"point":Vector3.ZERO,"normal":Vector3.ZERO,"strength":0.0,"age":10.0,"serial":0}

static func advance(pos:Vector2,velocity:Vector2,height:float,vertical:float,spin:float,team:int,dt:float)->Dictionary:
 var side:=1.0 if team==0 else -1.0
 var result:=Physics.advance(pos,velocity,height,vertical,spin,true,dt)
 var point:=Vector3(result.pos.x,result.height,result.pos.y)
 var speed:=Vector3(result.velocity.x,result.vertical,result.velocity.y)
 var contact:=Vector3.ZERO;var normal:=Vector3.ZERO;var force:=0.0
 var depth:float=point.x*side-Pitch.HALF_LENGTH
 if depth>Pitch.GOAL_DEPTH-Physics.RADIUS:
  point.x=(Pitch.HALF_LENGTH+Pitch.GOAL_DEPTH-Physics.RADIUS)*side
  if speed.x*side>0:
   force=absf(speed.x);normal=Vector3(side,0,0);contact=point+normal*Physics.RADIUS
   speed.x*=-0.16;speed.y*=0.65;speed.z*=0.65
 if depth>0:
  if absf(point.z)>Pitch.GOAL_HALF_WIDTH-Physics.RADIUS:
   var direction:=signf(point.z);point.z=direction*(Pitch.GOAL_HALF_WIDTH-Physics.RADIUS)
   if speed.z*direction>0:
    if absf(speed.z)>force: force=absf(speed.z);normal=Vector3(0,0,direction);contact=point+normal*Physics.RADIUS
    speed.z*=-0.18;speed.x*=0.70;speed.y*=0.70
  var roof:float=lerpf(Pitch.GOAL_HEIGHT,Pitch.GOAL_BACK_HEIGHT,clampf(depth/Pitch.GOAL_DEPTH,0,1))
  if point.y>roof-Physics.RADIUS:
   point.y=roof-Physics.RADIUS
   if speed.y>0:
    if speed.y>force: force=speed.y;normal=Vector3.UP;contact=point+normal*Physics.RADIUS
    speed.y*=-0.15;speed.x*=0.75;speed.z*=0.75
 result.pos=Vector2(point.x,point.z);result.height=maxf(Physics.FLOOR,point.y)
 result.velocity=Vector2(speed.x,speed.z);result.vertical=speed.y
 result.contact=contact;result.normal=normal;result.force=force
 return result

static func tick(s,dt:float)->void:
 # Substeps also make headless large-dt goal/replay tests follow the same trajectory.
 var left:=minf(dt,6.0)
 while left>0.00001:
  var step:=minf(left,1.0/120);left-=step;s.goal_net.age+=step
  var f:=advance(s.ball,s.velocity,s.ball_height,s.vertical_speed,s.ball_spin,s.goal_team,step)
  s.ball=f.pos;s.velocity=f.velocity;s.ball_height=f.height;s.vertical_speed=f.vertical;s.ball_spin=f.spin
  if f.force>1.0:
   s.goal_net={"point":f.contact,"normal":f.normal,"strength":clampf(f.force/32.0,0.06,1.0),"age":0.0,"serial":int(s.goal_net.serial)+1}

static func pack(net:Dictionary)->PackedFloat32Array:
 return PackedFloat32Array([net.point.x,net.point.y,net.point.z,net.normal.x,net.normal.y,net.normal.z,net.strength,net.age,net.serial])

static func unpack(data:PackedFloat32Array)->Dictionary:
 if data.size()<9: return empty()
 return {"point":Vector3(data[0],data[1],data[2]),"normal":Vector3(data[3],data[4],data[5]),"strength":data[6],"age":data[7],"serial":int(data[8])}
