extends RefCounted
const Pitch=preload("res://pitch_geometry.gd")
## Swept sphere versus six goal-frame capsules prevents fast shots tunnelling.
const BALL_RADIUS:=0.30
const FRAME_RADIUS:=0.12

static func roots(a:float,b:float,c:float)->Array:
 if a<0.000001: return []
 var discriminant:=b*b-4*a*c
 if discriminant<0: return []
 var root:=sqrt(discriminant)
 return [(-b-root)/(2*a),(-b+root)/(2*a)]

static func capsule_time(start:Vector3,travel:Vector3,a:Vector3,b:Vector3,radius:float)->float:
 var axis:Vector3=(b-a).normalized()
 var length:=a.distance_to(b)
 var offset:=start-a
 var radial:=offset-axis*offset.dot(axis)
 var perpendicular:=travel-axis*travel.dot(axis)
 var earliest:=INF
 for t in roots(perpendicular.length_squared(),2*radial.dot(perpendicular),radial.length_squared()-radius*radius):
  if t<0 or t>1: continue
  var along:float=(offset+travel*t).dot(axis)
  if along>=0 and along<=length: earliest=minf(earliest,t)
 for endpoint in [a,b]:
  var delta:Vector3=start-endpoint
  for t in roots(travel.length_squared(),2*delta.dot(travel),delta.length_squared()-radius*radius):
   if t>=0 and t<=1: earliest=minf(earliest,t)
 return earliest

static func collide(previous:Vector3,current:Vector3,velocity:Vector3)->Dictionary:
 if maxf(absf(previous.x),absf(current.x))<Pitch.HALF_LENGTH-0.6: return {}
 var travel:=current-previous
 if travel.length_squared()<0.000001: return {}
 var best:=INF
 var hit_a:=Vector3.ZERO;var hit_b:=Vector3.ZERO
 var kind:=""
 for side in [-1.0,1.0]:
  for segment in [[Vector3(Pitch.HALF_LENGTH*side,0,-5),Vector3(Pitch.HALF_LENGTH*side,3.6,-5),"post"],[Vector3(Pitch.HALF_LENGTH*side,0,5),Vector3(Pitch.HALF_LENGTH*side,3.6,5),"post"],[Vector3(Pitch.HALF_LENGTH*side,3.6,-5),Vector3(Pitch.HALF_LENGTH*side,3.6,5),"bar"]]:
   var t:=capsule_time(previous,travel,segment[0],segment[1],BALL_RADIUS+FRAME_RADIUS)
   if t<best: best=t;hit_a=segment[0];hit_b=segment[1];kind=segment[2]
 if best==INF: return {}
 var point:=previous+travel*best
 var axis:Vector3=hit_b-hit_a
 var nearest:=hit_a+axis*clampf((point-hit_a).dot(axis)/axis.length_squared(),0,1)
 var normal:Vector3=(point-nearest).normalized()
 if velocity.dot(normal)>=0: return {}
 var rebound:Vector3=(velocity-2*velocity.dot(normal)*normal)*0.68
 return {"position":point+normal*0.025,"velocity":rebound,"kind":kind}
