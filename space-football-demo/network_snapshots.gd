extends RefCounted
## A monotonic playback clock with a small adaptive interpolation buffer.
var frames:Array=[]
var playhead:=0.0
var age:=0.0
var jitter_ms:=0.0
var buffer_ticks:=4.0
var last_arrival:=-1
var gaps:=0
var received:=0
var period:=2

func reset()->void:
 frames.clear();playhead=0;age=0;jitter_ms=0;buffer_ticks=4;last_arrival=-1;gaps=0;received=0

func push(state:Dictionary,now:int)->void:
 var frame:int=state.frame
 if not frames.is_empty() and frame<=int(frames.back().frame): return
 if not frames.is_empty():
  var gap:int=frame-int(frames.back().frame)
  gaps+=maxi(0,gap/period-1)
  if last_arrival>=0:
   var variation:=absf(float(now-last_arrival)-gap*1000.0/60)
   jitter_ms=lerpf(jitter_ms,minf(variation,150),0.12)
  if frames.back().rules.phase!=state.rules.phase: frames.clear()
 buffer_ticks=clampf(3.0+jitter_ms*0.12,3,7)
 if frames.is_empty(): playhead=frame-buffer_ticks
 frames.append(state);received+=1;last_arrival=now;age=0
 while frames.size()>12: frames.pop_front()

func advance(dt:float)->void:
 if frames.is_empty(): return
 age+=dt
 var latest:float=frames.back().frame
 var target:=latest+minf(age*60,3)-buffer_ticks
 playhead=minf(latest+3,playhead+dt*60*clampf(1+(target-playhead)*0.06,0.9,1.1))

func bracket()->Array:
 if frames.is_empty(): return []
 for i in range(1,frames.size()):
  if float(frames[i].frame)>=playhead: return [frames[i-1],frames[i]]
 return [frames.back(),frames.back()]

func player(index:int,fallback:Dictionary)->Dictionary:
 var pair:=bracket()
 if pair.is_empty(): return fallback
 var a:Dictionary=pair[0];var b:Dictionary=pair[1]
 var amount:=clampf((playhead-float(a.frame))/maxf(1,float(b.frame)-float(a.frame)),0,1)
 var p:Dictionary=a.players[index].duplicate()
 var next:Dictionary=b.players[index]
 if p.player_id!=next.player_id or p.sub_revision!=next.sub_revision: return next
 p.pos=p.pos.lerp(next.pos,amount);p.vel=p.vel.lerp(next.vel,amount);p.dir=p.dir.slerp(next.dir,amount)
 p.jump_z=lerpf(p.jump_z,next.jump_z,amount)
 p.action_time=maxf(0,float(p.action_time)-maxf(0,playhead-float(a.frame))/60)
 if playhead>float(b.frame): p.pos+=p.vel*minf((playhead-float(b.frame))/60,0.05)
 return p

func ball(fallback:Vector3)->Vector3:
 var pair:=bracket()
 if pair.is_empty(): return fallback
 var a:Dictionary=pair[0];var b:Dictionary=pair[1]
 var start:=Vector3(a.ball.x,a.height,a.ball.y);var end:=Vector3(b.ball.x,b.height,b.ball.y)
 var amount:=clampf((playhead-float(a.frame))/maxf(1,float(b.frame)-float(a.frame)),0,1)
 # Never extrapolate a goal or invent a collision beyond the last authority sample.
 return start.lerp(end,amount)
