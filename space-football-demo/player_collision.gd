extends RefCounted
## Ball-centre sweep against anatomical capsules, including the ball radius.
const Frame=preload("res://goal_frame.gd")
const RADIUS:=0.30

static func capsule(start:Vector3,finish:Vector3,a:Vector3,b:Vector3,radius:float)->Dictionary:
 var axis:=b-a
 var nearest:=a+axis*clampf((start-a).dot(axis)/maxf(0.000001,axis.length_squared()),0,1)
 var t:=0.0 if start.distance_squared_to(nearest)<=radius*radius else Frame.capsule_time(start,finish-start,a,b,radius)
 if t==INF: return {}
 var point:=start.lerp(finish,t)
 nearest=a+axis*clampf((point-a).dot(axis)/maxf(0.000001,axis.length_squared()),0,1)
 var normal:Vector3=(point-nearest).normalized()
 if normal.length_squared()<0.5: normal=(start-finish).normalized()
 if normal.length_squared()<0.5: normal=Vector3.RIGHT
 return {"time":t,"normal3":normal,"point3":nearest+normal*(radius+0.015)}

static func sweep(p:Dictionary,start:Vector3,finish:Vector3)->Dictionary:
 var body:Dictionary=p.body
 var h:float=body.height
 var origin:=Vector3(p.pos.x,p.jump_z,p.pos.y)
 var lateral:Vector3=Vector3(-p.dir.y,0,p.dir.x)*body.hip_width*0.30
 var parts:Array=[]
 for sign_value in [-1,1]:
  parts.append([origin+lateral*sign_value+Vector3(0,h*0.09,0),origin+lateral*sign_value+Vector3(0,h*0.46,0),h*0.07,"foot"])
 parts.append([origin+Vector3(0,h*0.49,0),origin+Vector3(0,h*0.78,0),body.shoulder*0.38,"chest"])
 var head:=origin+Vector3(0,body.head_height,0)
 parts.append([head,head+Vector3(0,0.001,0),body.head_size*0.48,"head"])
 var best:Dictionary={}
 for part in parts:
  var hit:=capsule(start,finish,part[0],part[1],part[2]+RADIUS)
  if not hit.is_empty() and (best.is_empty() or hit.time<best.time):
   best=hit;best.zone=part[3]
 if not best.is_empty():
  best.normal=Vector2(best.normal3.x,best.normal3.z).normalized()
  best.position=Vector2(best.point3.x,best.point3.z)
 return best

static func deflect(velocity:Vector3,normal:Vector3,restitution:float)->Vector3:
 var approach:=velocity.dot(normal)
 if approach>=0: return velocity
 return (velocity-normal*approach)*0.82-normal*approach*clampf(restitution,0,1)
