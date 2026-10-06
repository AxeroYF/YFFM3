extends RefCounted
const Team=preload("res://team_config.gd")
const Pitch=preload("res://pitch_geometry.gd")
## Continuous authority-side retrieval and staging. No player placement jumps.
const STAGES=["fetch","lift","carry","place","organize","ready"]
const TITLES={"fetch":"取球中","lift":"拾球","carry":"前往开球点","place":"放球","organize":"球员就位中","ready":"可以开球"}
const LIFT_TIME:=0.55
const PLACE_TIME:=0.55
const TRAVEL_SCALE:=1.65
const HOLD_SECONDS:=0.85
const SKIP_DURATION:=0.44

static func ready(s)->bool:
 return s.phase=="restart" and s.restart_flow.get("stage","")=="ready" and (s.restart_flow.get("skip_time",-1.0)<0 or s.restart_flow.skip_time>=SKIP_DURATION)

static func facing(s)->Vector2:
 var q:float=s.side(s.restart_team)
 return Vector2(q*0.4,-signf(s.restart_spot.y)).normalized() if s.restart_kind=="kick_in" else (Vector2(Pitch.HALF_LENGTH*q,0)-s.restart_spot).normalized()

static func begin(s)->void:
 var targets:Array=[]
 var q:float=s.side(s.restart_team)
 var spot:Vector2=s.restart_spot
 var direction:=facing(s)
 var formation:=Pitch.FORMATION
 var wall:Array=[]
 for i in s.players.size():
  var p:Dictionary=s.players[i]
  var target:Vector2=p.pos if p.active else Vector2(-20*s.side(i/Team.SIZE),-8+(i%Team.SIZE)*4)
  if s.restart_kind=="kickoff": target=formation[i%Team.SIZE]*Vector2(s.side(i/Team.SIZE),1)
  elif s.restart_kind in ["penalty","accumulated"] and i%Team.SIZE!=0:
   target=Vector2(spot.x-q*(s.Rules.clearance(s)+0.5+i%3),-8+(i%Team.SIZE)*3)
  elif not s.Rules.is_free(s.restart_kind) and p.pos.distance_to(spot)<5.2: target=s.Rules.outside_radius(p.pos,spot)
  if i%Team.SIZE==0: target=Vector2((-Pitch.HALF_LENGTH+1.5)*s.side(i/Team.SIZE),0)
  if i%Team.SIZE==0 and p.team!=s.restart_team and s.restart_kind in ["free_kick","indirect","penalty","accumulated"]: target=Vector2(Pitch.HALF_LENGTH*q,0)
  if i==s.restart_taker: target=spot-direction*0.85
  elif p.team!=s.restart_team: target=s.Rules.legal_defender(s,target)
  targets.append(target)
 if s.Rules.is_free(s.restart_kind):
  var goal_distance:float=spot.distance_to(Vector2(Pitch.HALF_LENGTH*q,0))
  var count:=0 if goal_distance>25 or spot.x*q<0 else 1 if absf(spot.y)>11 else 2
  for n in count:
   var defender:int=(1-s.restart_team)*Team.SIZE+2+n
   if not s.players[defender].active: continue
   targets[defender]=(spot+direction*(s.Rules.FREE_DISTANCE+0.2)+direction.orthogonal()*((n-(count-1)*0.5)*1.45)).clamp(-Pitch.RESTART_LIMIT,Pitch.RESTART_LIMIT)
   targets[defender]=s.Rules.legal_defender(s,targets[defender]);wall.append(defender)
  var outlet:int=s.restart_team*Team.SIZE+Team.MIDFIELD_SLOT
  if outlet==s.restart_taker or not s.players[outlet].active:
   outlet=-1;var nearest:=INF
   for i in range(s.restart_team*Team.SIZE+1,(s.restart_team+1)*Team.SIZE):
    if i==s.restart_taker or not s.players[i].active: continue
    var distance:float=s.players[i].pos.distance_squared_to(spot)
    if distance<nearest: nearest=distance;outlet=i
  if outlet>=0:
   targets[outlet]=(spot+Vector2(-3*q,-2.5 if spot.y>0 else 2.5)).clamp(-Pitch.RESTART_LIMIT,Pitch.RESTART_LIMIT)
 # Resolve target overlap before movement; current positions are untouched.
 for iteration in 8:
  for i in s.players.size():
   if not s.players[i].active or i==s.restart_taker or i in wall or i%Team.SIZE==0: continue
   for j in s.players.size():
    if i==j or not s.players[j].active: continue
    var away:Vector2=targets[i]-targets[j]
    if away.length()>=1.6: continue
    if away.length()<0.01: away=Vector2.from_angle(i*2.4)
    targets[i]=(targets[i]+away.normalized()*0.3).clamp(-Pitch.RESTART_LIMIT,Pitch.RESTART_LIMIT)
   if i/Team.SIZE!=s.restart_team: targets[i]=s.Rules.legal_defender(s,targets[i])
 s.restart_flow={"stage":"fetch","time":0.0,"targets":targets,"wall":wall,"ball_from":Vector3(s.ball.x,s.ball_height,s.ball.y),"hold":[0.0,0.0],"skip_time":-1.0,"skipped":false}
 s.owner=-1;s.freeze=0;s.phase_time=0
 s.velocity*=0.18;s.vertical_speed=minf(s.vertical_speed,0)

static func travel(s,index:int,target:Vector2,dt:float,pace:float=1.0,face_travel:bool=true)->void:
 var p:Dictionary=s.players[index]
 var offset:Vector2=target-p.pos
 var speed:float=p.speed*pace*TRAVEL_SCALE
 var desired:Vector2=offset.normalized()*minf(speed,sqrt(maxf(0,2*p.ratings.braking*TRAVEL_SCALE*offset.length())))
 p.vel=p.vel.move_toward(desired,p.ratings.acceleration*TRAVEL_SCALE*dt)
 var displacement:Vector2=p.vel*dt
 if displacement.length()>offset.length() and displacement.dot(offset)>0:
  displacement=offset;p.vel=displacement/maxf(dt,0.00001)
 p.pos+=displacement;p.touch+=displacement.length()
 if offset.length()<0.08: p.vel=Vector2.ZERO
 var direction:Vector2=offset.normalized() if offset.length()>0.12 else (s.ball-p.pos).normalized()
 if face_travel and direction.length()>0.1: p.dir=p.dir.rotated(clampf(p.dir.angle_to(direction),-p.ratings.turn_rate*dt,p.ratings.turn_rate*dt)).normalized()

static func change_stage(s,stage:String)->void:
 s.restart_flow.stage=stage;s.restart_flow.time=0.0
 s.restart_flow.ball_from=Vector3(s.ball.x,s.ball_height,s.ball.y)

static func hold_point(p:Dictionary)->Vector3:
 return Vector3(p.pos.x+p.dir.x*0.45,p.body.height*0.52,p.pos.y+p.dir.y*0.45)

static func set_ball(s,point:Vector3)->void:
 s.ball=Vector2(point.x,point.z);s.ball_height=point.y;s.velocity=Vector2.ZERO;s.vertical_speed=0

static func tick(s,dt:float)->void:
 if s.restart_flow.is_empty(): begin(s)
 var f:Dictionary=s.restart_flow
 if skip_tick(s,dt): return
 var taker:int=s.restart_taker
 var p:Dictionary=s.players[taker]
 f.time+=dt
 for i in s.players.size():
  if i==taker or not s.players[i].active: continue
  travel(s,i,f.targets[i],dt)
  s.players[i].action="wall" if i in f.wall and s.players[i].pos.distance_to(f.targets[i])<0.25 else "idle"
  s.players[i].action_time=0.3 if s.players[i].action=="wall" else 0.0
 if f.stage=="fetch":
  var flight:Dictionary=s.BallPhysics.step(s.ball,s.velocity,s.ball_height,s.vertical_speed,0,false,dt,s.flight_conditions(0.0,false))
  set_ball(s,Vector3(flight.pos.x,flight.height,flight.pos.y))
  s.velocity=flight.velocity*exp(-dt*8);s.vertical_speed=flight.vertical
  var target:Vector2=s.ball-p.dir*0.55
  travel(s,taker,target,dt,1.12)
  p.action="idle";p.action_time=0
  if p.pos.distance_to(s.ball)<0.72 and s.ball_height<0.8 and p.vel.length()<1.7:
   s.velocity=Vector2.ZERO;s.vertical_speed=0;change_stage(s,"lift")
 elif f.stage=="lift":
  p.vel=p.vel.move_toward(Vector2.ZERO,dt*p.ratings.braking)
  p.action="retrieve_ball";p.action_time=maxf(0.001,LIFT_TIME-f.time)
  var amount:float=smoothstep(0.10,LIFT_TIME,f.time)
  set_ball(s,f.ball_from.lerp(hold_point(p),amount))
  if f.time>=LIFT_TIME: change_stage(s,"carry")
 elif f.stage=="carry":
  travel(s,taker,f.targets[taker],dt,0.78,p.pos.distance_to(f.targets[taker])>1.2)
  p.action="carry_ball";p.action_time=0.2
  var at_spot:bool=p.pos.distance_to(f.targets[taker])<0.12 and p.vel.length()<0.9
  if at_spot:
   var direction:=facing(s)
   p.dir=p.dir.rotated(clampf(p.dir.angle_to(direction),-p.ratings.turn_rate*dt,p.ratings.turn_rate*dt)).normalized()
  set_ball(s,hold_point(p))
  if at_spot and f.time>0.22 and p.dir.dot(facing(s))>0.995: change_stage(s,"place")
 elif f.stage=="place":
  p.vel=Vector2.ZERO;p.action="place_ball";p.action_time=maxf(0.001,PLACE_TIME-f.time)
  var amount:float=smoothstep(0,PLACE_TIME-0.08,f.time)
  set_ball(s,f.ball_from.lerp(Vector3(s.restart_spot.x,s.BallPhysics.FLOOR,s.restart_spot.y),amount))
  if f.time>=PLACE_TIME: change_stage(s,"organize")
 else:
  p.vel=Vector2.ZERO
  var direction:=facing(s)
  p.dir=p.dir.rotated(clampf(p.dir.angle_to(direction),-p.ratings.turn_rate*dt,p.ratings.turn_rate*dt)).normalized()
  if p.release_wait<=0 and not s.teams[s.restart_team].charging: p.action="set_piece";p.action_time=0.2
  if f.stage=="organize":
   var settled:=true
   for i in s.players.size():
    if not s.players[i].active: continue
    # A short free kick does not wait for every teammate to finish a long run.
    if s.Rules.is_free(s.restart_kind) and i/Team.SIZE==s.restart_team: continue
    if s.players[i].pos.distance_to(f.targets[i])>0.08: settled=false;break
   if settled and p.dir.dot(direction)>0.98:
    change_stage(s,"ready");s.owner=taker;s.phase_time=0

static func change_taker(s,next:int)->void:
 if not ready(s): return
 var previous:int=s.restart_taker
 var targets:Array=s.restart_flow.targets
 var previous_target:Vector2=targets[next]
 targets[next]=targets[previous];targets[previous]=previous_target
 s.players[previous].action="idle";s.players[previous].action_time=0
 s.restart_taker=next;s.teams[s.restart_team].selected=next;s.owner=-1;s.phase_time=0
 s.teams[s.restart_team].charging=false;s.teams[s.restart_team].charge=0
 s.mechanics.releases[s.restart_team]={};change_stage(s,"fetch")
 s.restart_flow.hold=[0.0,0.0];s.restart_flow.skip_time=-1.0;s.restart_flow.skipped=false

static func skip_tick(s,dt:float)->bool:
 var f:Dictionary=s.restart_flow
 if f.skip_time>=0:
  f.skip_time+=dt
  # An explicitly requested cut is covered by the full-screen fade on all peers.
  if f.skip_time>=0.14 and not f.skipped:
   for i in s.players.size():
    var p:Dictionary=s.players[i]
    if not p.active: continue
    p.pos=f.targets[i];p.vel=Vector2.ZERO;p.jump_z=0;p.jump_v=0
    p.dir=facing(s) if i==s.restart_taker else (s.restart_spot-p.pos).normalized()
    p.action="set_piece" if i==s.restart_taker else "wall" if i in f.wall else "idle";p.action_time=0.2
   set_ball(s,Vector3(s.restart_spot.x,s.BallPhysics.FLOOR,s.restart_spot.y))
   f.stage="ready";f.time=0;f.skipped=true;s.owner=s.restart_taker;s.phase_time=0
  return f.skip_time<SKIP_DURATION
 if f.stage=="ready": return false
 for team in 2:
  f.hold[team]=minf(HOLD_SECONDS,f.hold[team]+dt) if s.teams[team].human and s.teams[team].get("skip_restart",false) else 0.0
  if f.hold[team]>=HOLD_SECONDS: f.skip_time=0;return true
 return false

static func fade(s)->float:
 var age:float=s.restart_flow.get("skip_time",-1.0)
 return clampf(minf(age/0.10,(SKIP_DURATION-age)/0.14),0,1) if age>=0 else 0.0

static func pack(flow:Dictionary)->PackedFloat32Array:
 if flow.is_empty(): return PackedFloat32Array()
 var data:=PackedFloat32Array([float(STAGES.find(flow.stage)),flow.time,flow.ball_from.x,flow.ball_from.y,flow.ball_from.z])
 for target in flow.targets: data.append(target.x);data.append(target.y)
 var walls:=0
 for i in flow.wall: walls|=1<<i
 data.append(walls)
 data.append(flow.hold[0]);data.append(flow.hold[1]);data.append(flow.skip_time);data.append(float(flow.skipped))
 return data

static func unpack(data:PackedFloat32Array)->Dictionary:
 var wall_offset:=5+2*Team.COUNT
 if data.size()<wall_offset+5: return {}
 var targets:Array=[];var wall:Array=[]
 for i in Team.COUNT:
  targets.append(Vector2(data[5+i*2],data[6+i*2]))
  if int(data[wall_offset])&(1<<i): wall.append(i)
 return {"stage":STAGES[clampi(int(data[0]),0,5)],"time":data[1],"ball_from":Vector3(data[2],data[3],data[4]),"targets":targets,"wall":wall,"hold":[data[wall_offset+1],data[wall_offset+2]],"skip_time":data[wall_offset+3],"skipped":bool(data[wall_offset+4])}
