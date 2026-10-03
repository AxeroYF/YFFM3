extends RefCounted
const Pitch=preload("res://pitch_geometry.gd")
## Short-match five-a-side rules. Authority owns all stoppages and restarts.
const TITLES={"kickoff":"中圈开球","kick_in":"界外球","corner":"角球","goal_kick":"球门球","free_kick":"直接任意球","indirect":"间接任意球","penalty":"点球","accumulated":"累计犯规罚球"}
const PHASES=["play","restart","foul","goal"]
const GOAL_DURATION:=5.5
const GOAL_INTRO:=1.10
const REPLAY_DURATION:=3.95
const Flow=preload("res://restart_flow.gd")
const NUMBERS=["phase_time","restart_team","restart_taker","restart_touch","goal_team","goal_scorer"]

static func state(s)->Dictionary:
 var data:Dictionary={}
 for key in NUMBERS+["phase","restart_spot","restart_origin","fouls","restart_flow"]: data[key]=s.get(key)
 return data.duplicate(true)

static func restore(s,data:Dictionary)->void:
 for key in data: s.set(key,data[key].duplicate(true) if data[key] is Array or data[key] is Dictionary else data[key])

static func pack(data:Dictionary)->PackedFloat32Array:
 var values:=PackedFloat32Array()
 for key in NUMBERS: values.append(float(data[key]))
 values.append(PHASES.find(data.phase))
 values.append(TITLES.keys().find(data.restart_origin))
 values.append(data.restart_spot.x);values.append(data.restart_spot.y)
 values.append(data.fouls[0]);values.append(data.fouls[1])
 values.append_array(Flow.pack(data.get("restart_flow",{})))
 return values

static func unpack(values:PackedFloat32Array)->Dictionary:
 var data:Dictionary={}
 for i in NUMBERS.size(): data[NUMBERS[i]]=values[i] if i==0 else int(values[i])
 data.phase=PHASES[int(values[6])]
 data.restart_origin=TITLES.keys()[int(values[7])] if values[7]>=0 else ""
 data.restart_spot=Vector2(values[8],values[9])
 data.fouls=[int(values[10]),int(values[11])]
 data.restart_flow=Flow.unpack(values.slice(12))
 return data

static func restart(s,team:int,kind:String,spot:Vector2)->void:
 s.goal_net=s.GoalNet.empty()
 s.brain.reset();s.mechanics.reset(s,false)
 s.phase="restart";s.phase_time=0;s.restart_kind=kind;s.restart_team=team
 s.restart_touch=-1;s.restart_origin=""
 var q:float=s.side(team)
 if kind=="kickoff": spot=Vector2.ZERO
 elif kind=="goal_kick": spot=Vector2((-Pitch.HALF_LENGTH+4)*q,0)
 elif kind=="corner": spot=Vector2((Pitch.HALF_LENGTH-1)*q,(Pitch.HALF_WIDTH-0.7)*(1 if spot.y>=0 else -1))
 elif kind=="kick_in": spot=Vector2(clampf(spot.x,-Pitch.HALF_LENGTH+2,Pitch.HALF_LENGTH-2),(Pitch.HALF_WIDTH-0.3)*(1 if spot.y>=0 else -1))
 elif kind=="penalty": spot=Vector2((Pitch.HALF_LENGTH-8)*q,0)
 elif kind=="accumulated": spot=Vector2((Pitch.HALF_LENGTH-12)*q,0)
 else: spot=spot.clamp(-Pitch.PLAYER_LIMIT+Vector2(2,1.3),Pitch.PLAYER_LIMIT-Vector2(2,1.3))
 var taker:int=team*5
 if kind!="goal_kick" or not s.players[taker].active:
  var nearest:=INF
  for i in range(team*5+1,team*5+5):
   if not s.players[i].active: continue
   var distance:float=s.players[i].pos.distance_squared_to(s.ball)
   if kind in ["penalty","accumulated"]: distance=100-s.players[i].attributes.setPieces
   if distance<nearest: nearest=distance;taker=i
 s.restart_taker=taker;s.restart_spot=spot
 s.pass_receiver=-1;s.ball_is_shot=false;s.ball_spin=0
 for p in s.players:
  if not p.active: continue
  p.cooldown=0;p.action_time=0;p.action="idle";p.keeper_holding=false
 for t in s.teams:
  t.charging=false;t.charge=0;t.run_time=0;t.run_player=-1;t.keeper_rush=false;t.skip_restart=false
 s.teams[team].selected=taker
 Flow.begin(s)
 s.notify("restart",("主队" if team==0 else "客队")+" · "+TITLES[kind])

static func outside_radius(position:Vector2,spot:Vector2)->Vector2:
 if position.distance_to(spot)>=5.2: return position
 var best:=Vector2.ZERO;var cost:=INF
 for i in 32:
  var candidate:=spot+Vector2.from_angle(i*TAU/32)*5.35
  if absf(candidate.x)>Pitch.RESTART_LIMIT.x or absf(candidate.y)>Pitch.RESTART_LIMIT.y: continue
  var distance:=candidate.distance_squared_to(position)
  if distance<cost: cost=distance;best=candidate
 return best if cost<INF else position

static func foul(s,offender:int,victim:int,sliding:bool,recalled:bool=false,foul_spot:Vector2=Vector2.INF)->void:
 if s.phase!="play": return
 var team:int=victim/5
 var offender_name:String=s.players[offender].name
 var offender_id:String=s.players[offender].player_id
 if not recalled:
  if not s.mechanics.advantage.is_empty(): return
  s.fouls[offender/5]+=1
  var behind:bool=s.players[victim].dir.dot((s.players[offender].pos-s.players[victim].pos).normalized())< -0.45
  var dangerous:bool=sliding and behind and (s.players[offender].vel-s.players[victim].vel).length()>12
  s.mechanics.discipline(s,offender,sliding,dangerous)
  if s.finished: return
  if s.owner==victim and s.players[victim].vel.dot(Vector2(s.side(team),0))>1.5 and not sliding:
   s.mechanics.advantage={"team":team,"offender":offender,"victim":victim,"sliding":sliding,"spot":s.players[victim].pos,"until":s.mechanics.clock+1.4}
   s.notify("foul","进攻有利 · 继续比赛");return
 s.restart_team=team;s.restart_spot=s.players[victim].pos if foul_spot==Vector2.INF else foul_spot
 s.restart_kind="penalty" if s.restart_spot.x*s.side(team)>Pitch.HALF_LENGTH-9 and absf(s.restart_spot.y)<8 else "free_kick"
 if s.restart_kind!="penalty" and s.fouls[offender/5]>=6: s.restart_kind="accumulated"
 s.phase="foul";s.phase_time=1.2;s.freeze=0
 s.owner=-1;s.velocity=Vector2.ZERO;s.ball_spin=0;s.vertical_speed=0
 for p in s.players: p.vel=Vector2.ZERO
 for t in s.teams: t.charging=false;t.charge=0
 s.players[victim].action="fall";s.players[victim].action_time=1.2
 s.players[offender].action="slide" if sliding else "appeal";s.players[offender].action_time=1.2
 var card:String=" · 红牌" if offender_id in s.mechanics.sent_off else " · 黄牌" if sliding else ""
 s.notify("foul",offender_name+card+" 犯规 · "+TITLES[s.restart_kind])

static func goal(s,team:int)->void:
 if s.phase!="play": return
 s.mechanics.advantage={}
 s.score[team]+=1;s.goal_team=team;s.goal_scorer=s.last_touch
 var counts:=[0,0]
 for p in s.players:
  if p.active: counts[p.team]+=1
 if counts[1-team]<counts[team]:
  for i in range((1-team)*5,(1-team)*5+5):
   if not s.players[i].active: s.players[i].sinbin=0;break
 s.phase="goal";s.phase_time=GOAL_DURATION;s.freeze=0
 s.owner=-1;s.goal_net=s.GoalNet.empty()
 for t in s.teams: t.charging=false;t.charge=0
 for p in s.players:
  p.vel=Vector2.ZERO
 s.notify("goal",("主队" if team==0 else "客队")+"进球！ · "+s.players[s.last_touch].name+(" 乌龙球" if s.last_touch/5!=team else ""))

static func update(s,dt:float)->void:
 for p in s.players:
  p.action_time=maxf(0,p.action_time-dt)
  if p.action_time<=0: p.action="idle"
  if p.jump_z>0 or p.jump_v>0:
   p.jump_v-=13*dt;p.jump_z=maxf(0,p.jump_z+p.jump_v*dt)
   if p.jump_z<=0: p.jump_v=0
 if s.phase in ["goal","foul"]:
  if s.phase=="goal": s.GoalNet.tick(s,minf(dt,s.phase_time))
  s.phase_time=maxf(0,s.phase_time-dt)
  if s.phase_time>0: return
  if s.phase=="goal":
   if s.overtime: s.finished=true;s.notify("end","金球绝杀 · 比赛结束")
   else: restart(s,1-s.goal_team,"kickoff",Vector2.ZERO)
  else: restart(s,s.restart_team,s.restart_kind,s.restart_spot)
  return
 Flow.tick(s,dt)
 if not Flow.ready(s): return
 s.phase_time+=dt
 if s.teams[s.restart_team].charging:
  s.teams[s.restart_team].charge=minf(1,s.teams[s.restart_team].charge+dt*0.9)
  s.players[s.restart_taker].action="windup"
  s.players[s.restart_taker].action_time=0.15
  s.players[s.restart_taker].action_strength=s.teams[s.restart_team].charge
 var human:bool=s.teams[s.restart_team].human
 if (not human and s.phase_time>1.0) or (s.restart_kind in ["kickoff","penalty","accumulated"] and s.phase_time>8):
  var previous:int=s.view_team;s.view_team=s.restart_team
  if s.restart_kind in ["penalty","accumulated"]: s.charge=0.55;s.shoot(-0.65 if s.rng.randf()<0.5 else 0.65)
  else: s.pass_ball(false,Vector2.ZERO,s.restart_kind=="corner")
  s.view_team=previous
 elif s.phase_time>=4 and s.restart_kind not in ["kickoff","penalty","accumulated"]:
  var next_kind:String="kick_in" if s.restart_kind=="kick_in" else "goal_kick" if s.restart_kind=="corner" else "indirect"
  restart(s,1-s.restart_team,next_kind,s.restart_spot)
  s.notify("restart","开球超时 · "+TITLES[next_kind])

static func released(s,index:int)->String:
 if s.phase!="restart": return ""
 var kind:String=s.restart_kind
 s.restart_touch=index;s.restart_origin=kind
 s.phase="play";s.phase_time=0;s.freeze=0;s.restart_flow={}
 for p in s.players:
  if p.action in ["wall","set_piece"]: p.action="idle";p.action_time=0
 return kind
