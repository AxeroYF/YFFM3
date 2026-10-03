extends RefCounted
const Pitch=preload("res://pitch_geometry.gd")
## Deterministic gameplay physics in pitch units, shared by authority and prediction.
const RADIUS:=0.30
const FLOOR:=RADIUS+0.01
const GRAVITY:=14.0

static func rebound(pos:Vector2,velocity:Vector2,height:float)->Dictionary:
 if absf(pos.x)>Pitch.HALF_LENGTH and (absf(pos.y)>=Pitch.GOAL_HALF_WIDTH or height>=Pitch.GOAL_HEIGHT):
  var side:=signf(pos.x);pos.x=side*(Pitch.HALF_LENGTH-0.02)
  if velocity.x*side>0: velocity.x*=-0.78
 if absf(pos.y)>Pitch.HALF_WIDTH:
  var side:=signf(pos.y);pos.y=side*(Pitch.HALF_WIDTH-0.02)
  if velocity.y*side>0: velocity.y*=-0.82
 return {"pos":pos,"velocity":velocity}

static func player_contact(start:Vector2,finish:Vector2,center:Vector2,radius:float)->Dictionary:
 # Resolve the first surface crossed, rather than the far side of an overlap.
 var offset:=start-center
 var travel:=finish-start
 var time:=0.0
 if offset.length_squared()>radius*radius:
  var a:=travel.length_squared()
  if a<0.000001: return {}
  var b:=offset.dot(travel)
  var discriminant:=b*b-a*(offset.length_squared()-radius*radius)
  if discriminant<0: return {}
  time=(-b-sqrt(discriminant))/a
  if time<0 or time>1: return {}
 var normal:Vector2=(start+travel*time-center).normalized()
 if normal.length_squared()<0.5:
  normal=-travel.normalized() if travel.length_squared()>0.000001 else Vector2.RIGHT
 return {"time":time,"normal":normal,"position":center+normal*(radius+0.015)}

static func deflect(velocity:Vector2,normal:Vector2,restitution:float)->Vector2:
 # Passive contact can redirect/dissipate existing speed, never add a kick.
 var approach:=velocity.dot(normal)
 if approach>=0: return velocity
 var tangent:=velocity-normal*approach
 return tangent*0.82-normal*approach*clampf(restitution,0,1)

static func advance(pos:Vector2,velocity:Vector2,height:float,vertical:float,spin:float,shot:bool,dt:float,wind:float=0.0)->Dictionary:
 var airborne:bool=height>FLOOR+0.025 or vertical>0.2
 # Spin rotates velocity without adding energy. Air drag and turf friction dissipate it.
 if airborne:
  velocity=velocity.rotated(spin*0.12*dt)
  velocity*=exp(-0.10*dt)
  spin*=exp(-0.65*dt)
 else:
  velocity=velocity.move_toward(Vector2.ZERO,(4.0 if shot else 8.0)*dt)
  spin*=exp(-4.0*dt)
 velocity.y+=wind*dt
 pos+=velocity*dt
 if airborne or vertical!=0.0:
  height+=vertical*dt-0.5*GRAVITY*dt*dt
  vertical-=GRAVITY*dt
 if height<=FLOOR:
  height=FLOOR
  vertical=-vertical*0.32 if vertical < -1.2 else 0.0
  if airborne:
   velocity*=0.90
   spin*=0.65
 return {"pos":pos,"velocity":velocity,"height":height,"vertical":vertical,"spin":spin}
