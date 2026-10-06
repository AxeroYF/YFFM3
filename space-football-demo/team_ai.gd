extends RefCounted
const Team=preload("res://team_config.gd")
const Pitch=preload("res://pitch_geometry.gd")
## Shared team plans; only the authority executes them. No reading human input.
## Public design references and tuning notes: AI跑位与球员差异说明.txt.
var targets:Array[Vector2]=[]
var jobs:Array[String]=[]
var marks:Array[int]=[]
var pressers:=[-1,-1]
var anchors:=[-1,-1]
var supports:=[-1,-1]
var modes:=["loose","loose"]
var transition:=[0.0,0.0]
var next_decision:Array[float]=[]
var last_passer:=[-1,-1]
var pass_time:=[-10.0,-10.0]
var owner_since:=0.0
var observed_owner:=-2
var possession_team:=-1
var plan_frame:=-1
var next_plan:=0.0
var tactics:=[-1,-1]
var reaction_until:Array=[]
var sprint_flags:Array=[]
var sprint_until:Array=[]
var observed_touch:=-1

func reset()->void:
 targets.clear();jobs.clear();marks.clear();next_decision.clear()
 reaction_until.clear();sprint_flags.clear();sprint_until.clear();observed_touch=-1
 for i in Team.COUNT:
  targets.append(Vector2.ZERO);jobs.append("hold");marks.append(-1);next_decision.append(0)
  reaction_until.append(0.0);sprint_flags.append(false);sprint_until.append(0.0)
 pressers=[-1,-1];anchors=[-1,-1];supports=[-1,-1];modes=["loose","loose"];transition=[0.0,0.0]
 last_passer=[-1,-1];pass_time=[-10.0,-10.0]
 observed_owner=-2;possession_team=-1;next_plan=0;plan_frame=-1;tactics=[-1,-1]

func state()->Dictionary:
 return {"reaction_until":reaction_until.duplicate(),"sprint_flags":sprint_flags.duplicate(),"sprint_until":sprint_until.duplicate(),"observed_touch":observed_touch,"targets":targets.duplicate(),"jobs":jobs.duplicate(),"marks":marks.duplicate(),"pressers":pressers.duplicate(),"anchors":anchors.duplicate(),"supports":supports.duplicate(),"modes":modes.duplicate(),"transition":transition.duplicate(),"next_decision":next_decision.duplicate(),"last_passer":last_passer.duplicate(),"pass_time":pass_time.duplicate(),"owner_since":owner_since,"observed_owner":observed_owner,"possession_team":possession_team,"plan_frame":plan_frame,"next_plan":next_plan,"tactics":tactics.duplicate()}

func restore(data:Dictionary)->void:
 reset()
 for key in data:
  if key=="targets": targets.assign(data[key])
  elif key=="jobs": jobs.assign(data[key])
  elif key=="marks": marks.assign(data[key])
  elif key=="next_decision": next_decision.assign(data[key])
  else: set(key,data[key].duplicate() if data[key] is Array else data[key])

func possession(s)->int:
 if s.owner>=0: return s.owner/Team.SIZE
 if not s.ball_is_shot and s.pass_receiver>=0 and s.kick_age<2.5: return s.last_touch/Team.SIZE
 return -1

func prepare(s)->void:
 if targets.is_empty(): reset()
 var previous_targets:Array=targets.duplicate();var previous_jobs:Array=jobs.duplicate()
 if observed_owner==-2:
  for i in Team.COUNT: previous_targets[i]=s.players[i].pos;previous_jobs[i]="hold"
 if s.owner<0 and (observed_owner>=0 or observed_touch!=s.last_touch):
  for i in Team.COUNT:
   if i/Team.SIZE==s.last_touch/Team.SIZE: continue
   var p:Dictionary=s.players[i]
   var awareness:float=0.16+(1-p.ratings.decisions)*0.18+(0.08 if p.dir.dot((s.ball-p.pos).normalized())<0 else 0)
   reaction_until[i]=s.elapsed+awareness+(0.04 if s.difficulty==0 else 0)
 observed_touch=s.last_touch
 var team_with_ball:=possession(s)
 var changed:bool=team_with_ball!=possession_team
 var carrier_changed:bool=s.owner!=observed_owner
 if s.owner!=observed_owner:
  if s.owner>=0: owner_since=s.elapsed
  observed_owner=s.owner
 if changed:
  for team in 2: transition[team]=s.elapsed+0.9
 possession_team=team_with_ball
 plan_frame=s.frame
 if not changed and not carrier_changed and s.elapsed<next_plan and tactics==[s.teams[0].tactic,s.teams[1].tactic]: return
 next_plan=s.elapsed+0.12
 tactics=[s.teams[0].tactic,s.teams[1].tactic]
 for i in Team.COUNT: targets[i]=s.players[i].pos;marks[i]=-1;jobs[i]="keeper" if i%Team.SIZE==0 else "hold"
 for team in 2:
  modes[team]="attack" if team_with_ball==team else "defend" if team_with_ball>=0 else "loose"
  if modes[team]=="attack": attack(s,team)
  else: defend(s,team)
  if s.owner<0:
   var chaser:=choose_chaser(s,team)
   pressers[team]=chaser
   targets[chaser]=intercept(s,chaser).point;jobs[chaser]="receive" if s.pass_receiver==chaser else "intercept"
  elif modes[team]=="attack": pressers[team]=-1
 for i in Team.COUNT:
  if s.elapsed<float(reaction_until[i]): targets[i]=previous_targets[i];jobs[i]=previous_jobs[i]

func ensure(s)->void:
 if plan_frame!=s.frame: prepare(s)

func bounded(point:Vector2)->Vector2:
 return point.clamp(-Pitch.AI_LIMIT,Pitch.AI_LIMIT)

func engagement_point(s,index:int,point:Vector2)->Vector2:
 # Formation width is a tactical preference, never a boundary for pursuing a ball.
 var limit:Vector2=s.player_limit(index)
 return point.clamp(-limit,limit)

func point_space(s,team:int,point:Vector2)->float:
 var nearest:=12.0
 for i in range((1-team)*Team.SIZE,(1-team)*Team.SIZE+Team.SIZE):
  if s.players[i].active: nearest=minf(nearest,point.distance_to(s.players[i].pos))
 return nearest

func lane_safety(s,team:int,origin:Vector2,destination:Vector2,shooting:bool=false)->float:
 var path:=destination-origin
 var distance:=path.length()
 if distance<0.1: return 0
 var speed:=sqrt(16.0*distance+100)*0.9
 var safety:=1.0
 for i in range((1-team)*Team.SIZE,(1-team)*Team.SIZE+Team.SIZE):
  if not s.players[i].active or (shooting and i%Team.SIZE==0): continue
  var rival:Dictionary=s.players[i]
  var forecast:Vector2=rival.pos+rival.vel*0.12
  var t:=clampf((forecast-origin).dot(path)/path.length_squared(),0,1)
  if t<0.03: continue
  var reaction:float=0.18+(1-rival.ratings.positioning)*0.22
  var reach:float=rival.body.foot_reach+rival.speed*maxf(0,distance*t/speed-reaction)*0.55
  var clearance:float=forecast.distance_to(origin+path*t)
  safety=minf(safety,clampf((clearance-reach*0.35)/maxf(0.5,reach),0,1))
 return safety

func pick_role(s,candidates:Array,target:Vector2,kind:String,previous:int=-1)->int:
 var best:=-1;var cost:=INF
 for index in candidates:
  var p:Dictionary=s.players[index]
  var preference:float=p.style.defender if kind=="anchor" else p.style.creator if kind=="support" else p.style.runner
  var value:float=p.pos.distance_to(target)*0.35-preference*5
  if kind=="anchor" and index%Team.SIZE==4: value-=5
  if kind=="support" and index%Team.SIZE==Team.MIDFIELD_SLOT: value-=4
  if index==previous: value-=2.5
  if value<cost: cost=value;best=index
 return best

func open_support(s,index:int,base:Vector2,origin:Vector2,occupied:Array)->Vector2:
 var best:=bounded(base);var score:=-INF
 for offset in [Vector2.ZERO,Vector2(0,-2.5),Vector2(0,2.5),Vector2(-2.5,0),Vector2(2.5,0),Vector2(-2,-2),Vector2(-2,2),Vector2(2,-2),Vector2(2,2)]:
  var point:=bounded(base+offset)
  var value:float=lane_safety(s,index/Team.SIZE,origin,point)*4.0+minf(point_space(s,index/Team.SIZE,point),6)*0.32-point.distance_to(base)*0.5
  for other in occupied: value-=maxf(0,6.3-point.distance_to(other))*2.4
  for i in range(index/Team.SIZE*Team.SIZE+1,index/Team.SIZE*Team.SIZE+Team.SIZE):
   if i!=index: value-=maxf(0,4.2-point.distance_to(s.players[i].pos))*1.0
  if value>score: score=value;best=point
 return best

func attack(s,team:int)->void:
 var q:float=s.side(team)
 var carrier:int=s.owner if s.owner>=0 else s.pass_receiver
 var origin:Vector2=s.players[carrier].pos if s.owner>=0 else s.pass_destination
 var bx:=origin.x*q
 var tactic:int=s.teams[team].tactic
 var candidates:Array=[]
 for i in range(team*Team.SIZE+1,team*Team.SIZE+Team.SIZE):
  if i!=carrier and s.players[i].active: candidates.append(i)
 if candidates.is_empty(): return
 var keeper_ball:bool=carrier%Team.SIZE==0
 var anchor_point:=Vector2((-18 if keeper_ball else clampf(bx-(10 if tactic==0 else 8),-24,16))*q,origin.y*0.22)
 var anchor:=pick_role(s,candidates,anchor_point,"anchor",anchors[team]);anchors[team]=anchor
 jobs[anchor]="anchor";targets[anchor]=bounded(anchor_point);candidates.erase(anchor)
 var occupied:Array=[origin,targets[anchor]]
 # The manual player's actual location also occupies space in the team shape.
 var selected:int=s.teams[team].selected
 if s.teams[team].human and selected!=s.owner: occupied.append(s.players[selected].pos)
 var support_point:=Vector2((bx+1)*q,clampf(origin.y+(-8 if origin.y>=0 else 8),-Pitch.HALF_WIDTH+4,Pitch.HALF_WIDTH-4))
 var support:=pick_role(s,candidates,support_point,"support",supports[team]);supports[team]=support
 if support>=0:
  var lane:float=-1 if support%Team.SIZE==2 else 1 if support%Team.SIZE==3 else (-1 if origin.y>=0 else 1)
  support_point=Vector2((bx+(4 if keeper_ball else -1))*q,clampf(origin.y+lane*9,-Pitch.HALF_WIDTH+4,Pitch.HALF_WIDTH-4))
  if absf(support_point.y-origin.y)<5: support_point.y=origin.y-lane*9
  jobs[support]="support";targets[support]=open_support(s,support,support_point,origin,occupied)
  occupied.append(targets[support]);candidates.erase(support)
 for index in candidates:
  var p:Dictionary=s.players[index]
  var lane:float=-1 if index%Team.SIZE==2 else 1 if index%Team.SIZE==3 else 0
  var depth:float=6+float(tactic)*2+p.style.runner*2
  if s.elapsed<transition[team] and tactic==2: depth+=3
  var width:float=7.0+p.style.width*6
  var run_point:=Vector2(clampf(bx+depth,-13,Pitch.HALF_LENGTH-5)*q,lane*width+origin.y*0.10)
  if bx>16 and absf(origin.y)>6: run_point=Vector2(minf(Pitch.HALF_LENGTH-4,bx+4)*q,-signf(origin.y)*(2.7 if p.role=="ST" else 4.5))
  # A spare midfielder holds a diagonal recycling lane instead of duplicating ST.
  if index%Team.SIZE==Team.MIDFIELD_SLOT:
   run_point=Vector2(clampf(bx-5,-20,18)*q,-signf(origin.y+0.01)*5.5)
  jobs[index]="run";targets[index]=open_support(s,index,run_point,origin,occupied)
  occupied.append(targets[index])
 var runner:int=s.teams[team].run_player
 if runner>=0 and s.teams[team].run_time>0 and runner!=anchor and runner!=s.owner:
  targets[runner]=bounded(s.players[runner].pos+Vector2(7*q,-s.players[runner].pos.y*0.16));jobs[runner]="one_two"

func choose_presser(s,team:int)->int:
 var best:=team*Team.SIZE+1;var cost:=INF
 var target:Vector2=s.ball+s.players[s.owner].vel*0.16 if s.owner>=0 else s.ball
 for i in range(team*Team.SIZE+1,team*Team.SIZE+Team.SIZE):
  if not s.players[i].active: continue
  var p:Dictionary=s.players[i]
  var value:float=p.pos.distance_to(target)+maxf(0,(p.pos.x-target.x)*s.side(team))*0.4-p.style.press*0.8
  if i==pressers[team] and p.pos.distance_to(target)<8: value-=1.25
  if s.is_controlled(i) and p.pos.distance_to(target)<5: value-=1.4
  if value<cost: best=i;cost=value
 return best

func defend(s,team:int)->void:
 var q:float=s.side(team)
 if s.owner<0:
  for slot in range(1,Team.SIZE):
   var index:int=team*Team.SIZE+slot
   var lane:float=-10 if slot==2 else 10 if slot==3 else 0
   var depth:float=11 if slot==4 else 3 if slot==1 else 7 if slot==Team.MIDFIELD_SLOT else 5
   jobs[index]="cover" if slot==4 else "recover"
   targets[index]=bounded(Vector2(clampf(s.ball.x*q-depth,-Pitch.HALF_LENGTH+5,10)*q,clampf(lane+s.ball.y*0.2,-Pitch.HALF_WIDTH+3,Pitch.HALF_WIDTH-3)))
  return
 var primary:=choose_presser(s,team);pressers[team]=primary
 var carrier:Vector2=s.players[s.owner].pos if s.owner>=0 else s.ball
 var bx:=carrier.x*q
 var forecast:Vector2=carrier+s.players[s.owner].vel*0.16 if s.owner>=0 else carrier
 var own_goal:=Vector2(-Pitch.HALF_LENGTH*q,0)
 jobs[primary]="press";targets[primary]=engagement_point(s,primary,forecast+(own_goal-carrier).normalized()*0.85)
 var available:Array=[]
 for i in range(team*Team.SIZE+1,team*Team.SIZE+Team.SIZE):
  if i!=primary and s.players[i].active: available.append(i)
 var cover_point:=Vector2(clampf(bx-(6 if s.teams[team].tactic==0 else 4.5),-Pitch.HALF_LENGTH+4,4)*q,clampf(carrier.y*0.48,-5.5,5.5))
 if available.is_empty(): return
 var cover:=pick_role(s,available,cover_point,"anchor",anchors[team]);anchors[team]=cover
 jobs[cover]="cover";targets[cover]=bounded(cover_point);available.erase(cover)
 var threats:Array=[]
 for i in range((1-team)*Team.SIZE+1,(1-team)*Team.SIZE+Team.SIZE):
  if i==s.owner or not s.players[i].active: continue
  var pos:Vector2=s.players[i].pos+s.players[i].vel*0.22
  var danger:float=-pos.x*q-absf(pos.y)*0.3
  threats.append({"index":i,"danger":danger,"pos":pos})
 threats.sort_custom(func(a,b): return a.danger>b.danger)
 for threat in threats:
  if available.is_empty(): break
  var point:Vector2=threat.pos
  point+=(own_goal-point).normalized()*1.4
  point.x=minf(point.x*q,bx-1.5)*q
  point=bounded(point)
  var defender:=pick_role(s,available,point,"anchor")
  marks[defender]=threat.index;jobs[defender]="mark"
  # Goal side first, with a small step into the ball-to-runner passing lane.
  var lane_point:Vector2=threat.pos+(carrier-threat.pos).normalized()*1.6
  var lane:float=-1 if defender%Team.SIZE==2 else 1 if defender%Team.SIZE==3 else (-1 if threat.pos.y<carrier.y else 1)
  var zone:=Vector2(clampf(bx-3,-Pitch.HALF_LENGTH+5,5)*q,clampf(lane*8+carrier.y*0.25,-Pitch.HALF_WIDTH+4,Pitch.HALF_WIDTH-4))
  var tracking:float=1.0 if threat.pos.x*q<bx-2 else 0.32+s.players[defender].ratings.marking*0.15
  targets[defender]=bounded(zone.lerp(point.lerp(lane_point,0.18*s.players[defender].ratings.marking),tracking))
  if targets[defender].distance_to(carrier)<5.0 and bx>-Pitch.HALF_LENGTH+7:
   var away:Vector2=(targets[defender]-carrier).normalized()
   if away.length()<0.1: away=(own_goal-carrier).normalized()
   targets[defender]=bounded(carrier+away*5.0)
  available.erase(defender)

func intercept(s,index:int)->Dictionary:
 var p:Dictionary=s.players[index]
 var point:Vector2=s.ball;var speed:Vector2=s.velocity
 var height:float=s.ball_height;var vertical:float=s.vertical_speed;var spin:float=s.ball_spin
 var arrival:=2.4
 for step in range(1,25):
  var t:float=step*0.10
  var flight:Dictionary=s.advance_ball(point,speed,height,vertical,spin,s.ball_is_shot,0.10,t-0.10)
  point=flight.pos;speed=flight.velocity;height=flight.height;vertical=flight.vertical;spin=flight.spin
  if s.ice_mode or s.arcade:
   var bounce:Dictionary=s.BallPhysics.rebound(point,speed,height)
   point=bounce.pos;speed=bounce.velocity
  var delta:Vector2=point-p.pos
  var reaction:float=maxf(0,float(reaction_until[index])-s.elapsed)
  var turn:float=absf(p.dir.angle_to(delta))/s.Movement.turn_rate(p.ratings,p.vel)*0.35
  var available:float=maxf(0,t-reaction-turn)
  var cap:float=p.speed*(1-p.fatigue*0.14)*(1.42 if sprint_flags[index] else 1.0)
  var initial:float=p.vel.dot(delta.normalized())
  var reachable:float=s.Movement.reachable_distance(initial,cap,p.ratings,available,s.surface_grip())
  if delta.length()<=reachable+p.body.foot_reach*0.85 and height<=p.body.foot_height:
   arrival=t;break
 return {"point":engagement_point(s,index,point),"time":arrival+maxf(0,p.pos.distance_to(point)-p.speed*arrival)/maxf(0.1,p.speed)}

func choose_chaser(s,team:int)->int:
 var best:=team*Team.SIZE+1;var cost:=INF
 for i in range(team*Team.SIZE+1,team*Team.SIZE+Team.SIZE):
  if not s.players[i].active: continue
  var value:float=intercept(s,i).time
  if i==pressers[team]: value-=0.16
  if i==s.pass_receiver: value-=0.35
  if s.is_controlled(i) and s.players[i].pos.distance_to(s.ball)<5: value-=0.18
  if value<cost: cost=value;best=i
 return best

func movement(s,index:int)->Vector2:
 ensure(s)
 var p:Dictionary=s.players[index]
 var target:Vector2=targets[index]
 if s.owner<0 and s.pass_receiver==index: target=intercept(s,index).point
 var offset:Vector2=target-p.pos
 var avoid:=Vector2.ZERO
 for i in Team.COUNT:
  if i==index or (i/Team.SIZE!=index/Team.SIZE and jobs[index] in ["press","intercept","receive"]): continue
  var delta:Vector2=(p.pos+p.vel*0.16)-(s.players[i].pos+s.players[i].vel*0.16)
  var space:float=4.8 if i/Team.SIZE==index/Team.SIZE else 1.3
  if delta.length()>0.01 and delta.length()<space: avoid+=delta.normalized()*(space-delta.length())*1.1
 var pace:float=(0.84+p.ratings.work_rate*0.16)*clampf(offset.length()/1.8,0,1)
 if jobs[index] in ["intercept","receive"] and s.owner<0 and p.pos.distance_to(s.ball)>p.body.foot_reach*0.8:
  pace=maxf(pace,minf(0.55,offset.length()/0.35))
 return (offset.normalized()*pace+avoid.limit_length(0.95)).limit_length() if offset.length()>0.20 else avoid.limit_length(0.6)

func sprint(s,index:int)->bool:
 if index%Team.SIZE==0 or s.owner==index or s.players[index].stamina<22: sprint_flags[index]=false;return false
 if s.elapsed<float(reaction_until[index]): return sprint_flags[index]
 var distance:float=s.players[index].pos.distance_to(targets[index])
 var recovering:bool=modes[index/Team.SIZE]!="attack" and (s.players[index].pos.x-s.ball.x)*s.side(index/Team.SIZE)>2
 var wants:bool=distance>(3.8 if sprint_flags[index] else 7.0) and (recovering or jobs[index] in ["run","one_two","intercept","receive"])
 if s.elapsed>=float(sprint_until[index]) and wants!=sprint_flags[index]:
  sprint_flags[index]=wants;sprint_until[index]=s.elapsed+0.40
 return sprint_flags[index]

func jockey(s,index:int)->bool:
 if s.owner==index and index%Team.SIZE!=0:
  var p:Dictionary=s.players[index]
  if p.style.power<0.84: return false
  for rival in range((1-index/Team.SIZE)*Team.SIZE,(1-index/Team.SIZE)*Team.SIZE+Team.SIZE):
   var delta:Vector2=s.players[rival].pos-p.pos
   if delta.length()<3 and p.dir.dot(delta.normalized())< -0.25: return true
  return false
 return s.owner>=0 and s.owner/Team.SIZE!=index/Team.SIZE and jobs[index] in ["press","mark","cover"] and s.players[index].pos.distance_to(targets[index])<2.8

func may_tackle(s,index:int)->bool:
 if not s.players[index].active or s.owner<0 or s.owner/Team.SIZE==index/Team.SIZE or s.players[s.owner].keeper_holding: return false
 if index%Team.SIZE!=0 and pressers[index/Team.SIZE]!=index: return false
 var p:Dictionary=s.players[index]
 var offset:Vector2=s.ball-p.pos
 var victim:Dictionary=s.players[s.owner]
 var behind:bool=victim.dir.dot((p.pos-victim.pos).normalized())< -0.4
 return offset.length()<p.ratings.tackle_reach*(0.76+p.style.press*0.10) and p.dir.dot(offset.normalized())>0.45 and (not behind or offset.length()<0.65+(1-p.style.discipline)*0.35)

func wants_aerial(s,index:int)->bool:
 if s.pickup_lock>0 or s.owner>=0: return false
 var pos:Vector2=s.players[index].pos
 return (pos.x*s.side(index/Team.SIZE)>13 and absf(pos.y)<10) or (pos.x*s.side(index/Team.SIZE)<-22 and s.ball_is_shot and s.last_touch/Team.SIZE!=index/Team.SIZE)

func shot_quality(s,index:int,point:Vector2)->float:
 var q:float=s.side(index/Team.SIZE)
 var distance:=point.distance_to(Vector2(Pitch.HALF_LENGTH*q,0))
 var angle:=clampf(1.0-absf(point.y)/18,0.1,1)
 return clampf(1-distance/31,0,1)*angle

func pass_option(s,index:int)->Dictionary:
 var p:Dictionary=s.players[index]
 var tactic:int=s.teams[index/Team.SIZE].tactic
 var best:={"receiver":-1,"score":-INF,"safety":0.0,"target":p.pos,"progress":0.0,"kind":"feet"}
 for i in range(index/Team.SIZE*Team.SIZE,index/Team.SIZE*Team.SIZE+Team.SIZE):
  if i==index or not s.players[i].active: continue
  var mate:Dictionary=s.players[i]
  var distance:float=p.pos.distance_to(mate.pos)
  if distance<3 or distance>(38 if index%Team.SIZE==0 else 18+p.style.vision*17): continue
  for kind in ["feet","through","lob"]:
   if kind!="feet" and (i%Team.SIZE==0 or index%Team.SIZE==0 or (mate.pos.x-p.pos.x)*s.side(index/Team.SIZE)<2): continue
   if kind=="lob" and (distance<12 or p.style.vision<0.5): continue
   var target:Vector2=bounded(mate.pos+mate.vel*clampf(distance/35,0.1,0.55))
   if kind!="feet": target=bounded(target+Vector2(s.side(index/Team.SIZE)*(2.5+mate.style.runner*2),0))
   var safety:=lane_safety(s,index/Team.SIZE,p.pos,target)
   if kind=="lob": safety=clampf((point_space(s,index/Team.SIZE,target)-0.8)/4,0,1)
   var progress:float=(target.x-p.pos.x)*s.side(index/Team.SIZE)
   var value:float=safety*(2.7-float(tactic)*0.35)+clampf(progress,-15,15)*[0.065,0.11,0.16][tactic]+minf(point_space(s,index/Team.SIZE,target),7)*0.11-distance*0.016+shot_quality(s,i,target)*1.8
   if kind=="lob": value-=0.35+(1-p.style.creator)*0.3
   elif kind=="through": value-=0.12
   if i%Team.SIZE==0: value-=0.9
   if i==last_passer[index/Team.SIZE] and s.elapsed-pass_time[index/Team.SIZE]<2: value-=0.55
   if value>best.score: best={"receiver":i,"score":value,"safety":safety,"target":target,"progress":progress,"kind":kind}
 return best

func on_ball(s,index:int)->Vector2:
 var p:Dictionary=s.players[index]
 var q:float=s.side(index/Team.SIZE)
 var team:int=index/Team.SIZE
 var pressure:float=s.closest_opponent(index)
 var goal:=Vector2((Pitch.HALF_LENGTH-1)*q,clampf(p.pos.y*0.35,-3,3))
 var route:=goal
 # Evaluate a few actual driving lanes, not an unconditional run at goal centre.
 var route_score:=-INF
 for lane in [-1,0,1]:
  var point:=bounded(p.pos+Vector2(5*q,lane*(2.2+p.style.technical*1.3)))
  var value:=point_space(s,team,point)*0.55-point.distance_to(goal)*0.50
  if p.pos.x*q>12: value-=absf(point.y)*0.22
  for mate in range(team*Team.SIZE+1,team*Team.SIZE+Team.SIZE):
   if mate!=index: value-=maxf(0,4-point.distance_to(s.players[mate].pos))*1.2
  if lane==0: value+=0.3
  if value>route_score: route_score=value;route=point
 if p.cooldown<=0 and s.elapsed>=next_decision[index]:
  next_decision[index]=s.elapsed+0.16+(1-p.ratings.decisions)*0.20
  var option:=pass_option(s,index)
  var quality:=shot_quality(s,index,p.pos)
  var keeper:Dictionary=s.players[(1-team)*Team.SIZE]
  var aim:=0.9;var best_shot:=-INF
  for candidate in [-0.9,-0.45,0.45,0.9]:
   var point:=Vector2(Pitch.HALF_LENGTH*q,candidate*4.35)
   var value:float=lane_safety(s,team,p.pos,point,true)*2+absf(point.y-keeper.pos.y)*0.10
   if value>best_shot: aim=candidate;best_shot=value
  var shot_target:=Vector2(Pitch.HALF_LENGTH*q,aim*4.35)
  var tactic:int=s.teams[team].tactic
  var shootable:bool=index%Team.SIZE!=0 and quality>[0.28,0.23,0.18][tactic] and absf(p.pos.y)<10 and lane_safety(s,team,p.pos,shot_target,true)>0.10
  if s.teams[team].charging and s.teams[team].selected==index:
   if s.teams[team].charge>0.28+clampf(p.pos.distance_to(shot_target)/35,0,1)*0.25:
    var previous:int=s.view_team;s.view_team=team
    s.shoot(aim,p.style.technical>0.85 and absf(p.pos.y)>3,absf(keeper.pos.x)<Pitch.HALF_LENGTH-6 and p.pos.distance_to(keeper.pos)>8)
    s.view_team=previous
  elif shootable and (quality>0.32 or option.score<3.25 or pressure<3.5 or s.elapsed-owner_since>1):
   s.teams[team].selected=index;s.teams[team].charging=true;s.teams[team].charge=0.10
  elif option.receiver>=0 and option.safety>[0.40,0.25,0.12][tactic] and (index%Team.SIZE==0 or pressure<2.5 or (pressure<4.2+(1-p.style.composure)*1.8 and s.elapsed-owner_since>0.7) or (option.progress>3 and s.elapsed-owner_since>0.65+(1-p.style.creator)*0.55) or (s.elapsed-owner_since>2.0 and (pressure<6 or option.progress>0))):
   if s.kick(index,option.target,23,false):
    s.pass_receiver=option.receiver;s.pass_destination=option.target
    if option.kind=="lob":
     var distance:float=p.pos.distance_to(option.target)
     var flight_time:=clampf(distance/16.0,0.7,1.6)
     var direction:Vector2=(option.target-p.pos).normalized().rotated(s.rng.randf_range(-p.ratings.cross_error,p.ratings.cross_error))
     s.velocity=direction*(distance/flight_time*1.08);s.vertical_speed=s.BallPhysics.GRAVITY*flight_time*0.5
     p.action="cross";p.action_time=0.6
    if not s.teams[team].human: s.teams[team].selected=option.receiver
    last_passer[team]=index;pass_time[team]=s.elapsed
    if option.kind=="feet" and index%Team.SIZE not in [0,4] and p.pos.x*q>4 and pressure>2 and pressure<4.2 and option.progress>-2 and option.progress<6 and point_space(s,team,p.pos+Vector2(q*6,0))>4:
     s.teams[team].run_player=index;s.teams[team].run_time=1.6
    s.teams[team].charging=false;s.teams[team].charge=0
  elif index%Team.SIZE==0 and s.elapsed-owner_since>2.5 and option.receiver>=0:
   s.kick(index,option.target,23,false)
   s.pass_receiver=option.receiver;s.pass_destination=option.target
 if index%Team.SIZE==0: return Vector2.ZERO
 var direction:Vector2=route-p.pos
 return direction.normalized()*(0.86+p.style.technical*0.14)
