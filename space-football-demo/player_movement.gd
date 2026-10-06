extends RefCounted
## Shared by authority, AI and client prediction. No input delay or hidden AI boost.

static func velocity(current:Vector2,movement:Vector2,speed:float,ratings:Dictionary,carrying:bool,dt:float,grip:float=1.0)->Vector2:
 if dt<=0: return current
 var input:=movement.limit_length()
 var brake:float=ratings.braking*grip
 if input.length()<=0.05: return current.move_toward(Vector2.ZERO,brake*dt)
 var axis:=input.normalized()
 var along:=current.dot(axis)
 var lateral:=current-axis*along
 var target:=input.length()*speed
 var remaining:=dt
 var acceleration:float=ratings.acceleration*(ratings.carry_acceleration if carrying else 1.0)*sqrt(grip)
 if along<0:
  # Spend the braking time first; only the remaining substep can accelerate
  # backwards. Changing the stick direction cannot rotate momentum instantly.
  var stopping:=minf(remaining,-along/brake)
  along=minf(0,along+brake*stopping)
  remaining-=stopping
 along=move_toward(along,target,(brake if along>target else acceleration)*remaining)
 lateral=lateral.move_toward(Vector2.ZERO,brake*float(ratings.cut_grip)*dt)
 # Independent longitudinal/lateral integration must not create diagonal boosts.
 return (axis*along+lateral).limit_length(maxf(current.length(),target))

static func turn_rate(ratings:Dictionary,current_velocity:Vector2,balanced_stance:bool=false)->float:
 var travel:=clampf(current_velocity.length()/maxf(0.1,float(ratings.speed)*1.42),0,1)
 var running:float=ratings.running_turn_scale
 if balanced_stance: running=lerpf(1.0,running,0.45)
 return float(ratings.turn_rate)*lerpf(1.0,running,travel)

static func reachable_distance(along:float,cap:float,ratings:Dictionary,time:float,grip:float=1.0)->float:
 # Signed travel towards an interception point, including momentum moving away.
 var remaining:=maxf(0,time)
 var distance:=0.0
 var brake:float=ratings.braking*grip
 var acceleration:float=ratings.acceleration*sqrt(grip)
 if along<0 or along>cap:
  var target:=0.0 if along<0 else cap
  var duration:=minf(remaining,absf(target-along)/brake)
  var end:=move_toward(along,target,brake*duration)
  distance+=(along+end)*0.5*duration
  along=end;remaining-=duration
 var accelerating:=minf(remaining,maxf(0,cap-along)/acceleration)
 distance+=along*accelerating+0.5*acceleration*accelerating*accelerating
 return maxf(0,distance+cap*(remaining-accelerating))
