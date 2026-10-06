extends RefCounted
const Team=preload("res://team_config.gd")
const Pitch=preload("res://pitch_geometry.gd")
## Goal-area awareness shares the same ball flight and acceleration as the match.
const Physics=preload("res://ball_physics.gd")
const Motion=preload("res://football_motion.gd")

static func in_area(point:Vector2,side:float)->bool:
 return point.x*side<=-Pitch.HALF_LENGTH+9 and point.x*side>=-Pitch.HALF_LENGTH-0.3 and absf(point.y)<=8.0

static func threat(s,index:int)->bool:
 var q:float=s.side(index/Team.SIZE)
 if s.owner>=0 or s.velocity.x*q>=-0.5: return false
 var arrival:float=(-Pitch.HALF_LENGTH*q-s.ball.x)/s.velocity.x
 return arrival>=0 and arrival<1.8 and absf(s.ball.y+s.velocity.y*arrival)<5.4

static func hands_allowed(s,index:int)->bool:
 if index%Team.SIZE!=0 or s.last_touch/Team.SIZE==index/Team.SIZE: return false
 var p:Dictionary=s.players[index]
 var q:float=s.side(index/Team.SIZE)
 # A sweep may end just beyond the line; only pre-line contacts are accepted.
 return in_area(p.pos,q) and s.ball.x*q<=-Pitch.HALF_LENGTH+9 and absf(s.ball.y)<=8 and (s.ball_is_shot or s.ball_height>p.body.foot_height or s.teams[index/Team.SIZE].keeper_rush or threat(s,index))

static func radius(p:Dictionary,hands:bool)->float:
 if not hands: return p.body.foot_reach*1.20
 return (p.body.shoulder*0.85+0.95)*p.ratings.keeper_radius

static func contact_center(p:Dictionary)->Vector2:
 if p.action in Motion.DIVES and p.action_time>0.28:
  var extension:float=sin(clampf((0.8-p.action_time)/0.22,0,1)*PI*0.5)*p.body.height*0.24
  return p.pos+Vector2(p.dir.y,-p.dir.x)*p.keeper_side*extension
 return p.pos

static func target(s,index:int)->Vector2:
 var p:Dictionary=s.players[index]
 var team:int=index/Team.SIZE
 var q:float=s.side(team)
 var depth:float=clampf((s.ball.x*q+Pitch.HALF_LENGTH)*0.14,1.8,3.6)
 var home:=Vector2((-Pitch.HALF_LENGTH+depth)*q,clampf(s.ball.y*depth/maxf(2,s.ball.x*q+Pitch.HALF_LENGTH),-4.5,4.5))
 if p.action in Motion.DIVES and p.action_time>0:
  return p.pos if p.action_time<0.28 else p.pos+Vector2(p.dir.y,-p.dir.x)*p.keeper_side*1.5
 var rushing:bool=s.teams[team].keeper_rush
 if s.owner>=0:
  if rushing and s.owner/Team.SIZE!=team:
   if p.action_time<=0 or p.action=="rush": p.action="rush";p.action_time=0.15
   return Vector2(clampf(s.ball.x*q,-Pitch.HALF_LENGTH+0.9,-Pitch.HALF_LENGTH+8.5)*q,clampf(s.ball.y,-7,7))
  return home
 if s.ball.x*q-(s.velocity.length()+6)*1.6> -Pitch.HALF_LENGTH+9: return home
 var dangerous:bool=threat(s,index)
 var hands:bool=s.last_touch/Team.SIZE!=team and (s.ball_is_shot or s.ball_height>p.body.foot_height or dangerous or rushing)
 var reach:float=radius(p,hands)
 var maximum_height:float=p.body.hand_reach if hands else p.body.foot_height
 var pos:Vector2=s.ball;var velocity:Vector2=s.velocity
 var height:float=s.ball_height;var vertical:float=s.vertical_speed;var spin:float=s.ball_spin
 var best:Dictionary={}
 var fallback:Vector2=home
 var max_speed:float=p.speed*(1-p.fatigue*0.14)
 for step in range(1,33):
  var t:float=step*0.05
  var flight:Dictionary=s.advance_ball(pos,velocity,height,vertical,spin,s.ball_is_shot,0.05,t-0.05)
  pos=flight.pos;velocity=flight.velocity;height=flight.height;vertical=flight.vertical;spin=flight.spin
  if pos.x*q< -Pitch.HALF_LENGTH: break
  if not in_area(pos,q) or height>maximum_height: continue
  var destination:=Vector2(clampf(pos.x*q,-Pitch.HALF_LENGTH+0.9,-Pitch.HALF_LENGTH+8.8)*q,clampf(pos.y,-7.2,7.2))
  # Protect the goal line while a shot approaches; do not step forward into it.
  if dangerous: destination.x=minf(destination.x*q,clampf(p.pos.x*q,-Pitch.HALF_LENGTH+0.9,-Pitch.HALF_LENGTH+3.8))*q
  if dangerous: fallback=Vector2(destination.x,clampf(pos.y,-4.8,4.8))
  var distance:float=p.pos.distance_to(pos)
  var initial:float=clampf(p.vel.dot((pos-p.pos).normalized()),-max_speed,max_speed)
  var accelerating:float=minf(t,(max_speed-initial)/p.ratings.acceleration)
  var travel:float=maxf(0,initial*accelerating+0.5*p.ratings.acceleration*accelerating*accelerating+max_speed*(t-accelerating))
  if s.surface_grip()<1.0: travel=s.Movement.reachable_distance(initial,max_speed,p.ratings,t,s.surface_grip())
  var dive_reach:float=p.body.height*0.24 if hands and dangerous else 0
  if distance>travel+reach+dive_reach: continue
  # Loose-ball sweeping is deliberate: stay home if an opponent clearly wins.
  var safe:bool=dangerous or rushing or s.pass_receiver==index
  if not safe:
   safe=true
   for rival in range((1-team)*Team.SIZE,(1-team)*Team.SIZE+Team.SIZE):
    var opponent:Dictionary=s.players[rival]
    if opponent.active and opponent.pos.distance_to(pos)/maxf(1,opponent.speed)<t-0.12:
     safe=false;break
  if not safe: continue
  best={"target":destination,"point":pos,"height":height,"time":t,"speed":velocity.length()}
  break
 if best.is_empty(): return fallback
 var lateral:float=(best.point-p.pos).dot(Vector2(p.dir.y,-p.dir.x))
 if hands and p.keeper_cd<=0 and p.cooldown<=0 and best.time<0.48 and s.kick_age>0.05+(0.25-p.ratings.keeper_anticipation):
  p.keeper_side=signf(lateral);p.keeper_height=best.height
  p.action=Motion.keeper_action(best.height,best.speed,absf(lateral),p.body,p.ratings.keeper_hold)
  p.action_time=0.8;p.keeper_cd=1.05
 elif rushing and (p.action_time<=0 or p.action=="rush"):
  p.action="rush";p.action_time=0.15
 return best.target
