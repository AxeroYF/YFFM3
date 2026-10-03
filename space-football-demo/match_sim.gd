extends RefCounted
const Pitch=preload("res://pitch_geometry.gd")
## Fixed 60 Hz authority. Rendering, input devices and networking do not own match rules.
const TEAM_SIZE:=5
const Body=preload("res://player_body.gd")
const Motion=preload("res://football_motion.gd")
const GoalFrame=preload("res://goal_frame.gd")
const GoalNet=preload("res://goal_net.gd")
var goal_net:Dictionary=GoalNet.empty()
const PlayerCollision=preload("res://player_collision.gd")
const Library=preload("res://player_library.gd")
const Squad=preload("res://squad.gd")
const Ratings=preload("res://player_ratings.gd")
const Assistance=preload("res://play_assistance.gd")
const BallPhysics=preload("res://ball_physics.gd")
const Rules=preload("res://match_rules.gd")
const Style=preload("res://player_style.gd")
const TeamAI=preload("res://team_ai.gd")
const KeeperAI=preload("res://goalkeeper_ai.gd")
var brain=TeamAI.new()
const Mechanics=preload("res://match_mechanics.gd")
var mechanics=Mechanics.new()
var phase:="play"
var phase_time:=0.0
var restart_team:=0
var restart_taker:=1
var restart_spot:=Vector2.ZERO
var restart_flow:Dictionary={}
var restart_touch:=-1
var restart_origin:=""
var goal_team:=0
var goal_scorer:=1
var fouls:=[0,0]
const PLAYER_COUNT:=10
const HALF_LENGTH:=Pitch.HALF_LENGTH
const HALF_WIDTH:=Pitch.HALF_WIDTH
const GOAL_WIDTH:=Pitch.GOAL_HALF_WIDTH
const JERSEY_NUMBERS:=["01","09","10","05","04","01","09","07","08","04"]
var players:Array[Dictionary]=[]
var teams:Array[Dictionary]=[]
var view_team:=0
var ball:=Vector2.ZERO
var velocity:=Vector2.ZERO
var ball_height:=BallPhysics.FLOOR
var ball_spin:=0.0
var vertical_speed:=0.0
var owner:=1
var score:=[0,0]
var shots:=[0,0]
var passes:=[0,0]
var tackles:=[0,0]
var saves:=[0,0]
var possession:=[0.0,0.0]
var elapsed:=0.0
var duration:=100.0
var regulation:=100.0
var overtime_duration:=30.0
var freeze:=1.8
var pickup_lock:=0.0
var last_touch:=1
var kick_age:=0.0
var pass_receiver:=-1
var pass_destination:=Vector2.ZERO
var ball_is_shot:=false
var finished:=false
var overtime:=false
var stage:=0
var difficulty:=0
var message:="准备开球"
var event_serial:=0
var impact_id:=0
var impact_kind:=0
var impact_strength:=0.0
var impact_x:=1.0
var impact_y:=0.0
var event_kind:="kickoff"
var restart_kind:="kickoff"
var rng:=RandomNumberGenerator.new()
var strength:=0.82
var training:Array=[0,0,0,0]
var keeper_upgrade:=0
var arcade:=false
var ice_mode:=false
var frame:=0
# View-scoped accessors keep the presentation independent of the chosen side.
var selected:int:
 get: return int(teams[view_team].selected) if not teams.is_empty() else 1
 set(v): teams[view_team].selected=v
var human:bool:
 get: return teams[0].human
 set(v): teams[0].human=v
var tactic:int:
 get: return teams[view_team].tactic
 set(v): teams[view_team].tactic=v
var charge:float:
 get: return teams[view_team].charge
 set(v): teams[view_team].charge=v
var charging:bool:
 get: return teams[view_team].charging
 set(v): teams[view_team].charging=v
var energy:float:
 get: return players[selected].stamina
 set(v): players[selected].stamina=v
var dash:float:
 get: return teams[view_team].dash
var dash_cd:float:
 get: return teams[view_team].dash_cd
var boost:float:
 get: return 0.0

func setup(campaign,seed_value:int=0,home:Array=Squad.DEFAULT,away:Array=Squad.DEFAULT,competitive:bool=false)->void:
 stage=mini(campaign.stage,2)
 difficulty=campaign.difficulty
 strength=float(campaign.MISSIONS[stage].strength)+(0.10 if difficulty else 0.0)
 training=campaign.training.duplicate()
 keeper_upgrade=campaign.keeper
 if seed_value: rng.seed=seed_value
 else: rng.randomize()
 for team in 2:
  teams.append({"selected":team*5+1,"human":team==0,"tactic":1,"charge":0.0,"charging":false,"dash":0.0,"dash_cd":0.0,"move":Vector2.ZERO,"sprint":false,"jockey":false,"assist":1,"assist_active":true,"receive_cancelled":false})
  teams[-1].merge({"keeper_rush":false,"run_player":-1,"run_time":0.0})
 if not Squad.valid(home): home=Squad.DEFAULT
 if not Squad.valid(away): away=Squad.DEFAULT
 for i in PLAYER_COUNT:
  var record:=Library.find((home if i<5 else away)[i%5])
  var ratings:=Ratings.derive(record.attributes,float(record.get("heightCm",180)))
  var speed:float=ratings.speed
  if not competitive:
   if i>0 and i<5: speed+=float(training[[0,1,0,2,3][i]])*0.12*Ratings.MOVEMENT_SCALE
   if i==0: speed+=keeper_upgrade*0.5*Ratings.MOVEMENT_SCALE
  players.append({"pos":Vector2.ZERO,"vel":Vector2.ZERO,"dir":Vector2.RIGHT if i<5 else Vector2.LEFT,"team":i/5,"slot":i%5,"name":record.name,"cooldown":0.0,"speed":speed,"stamina":100.0,"action":"idle","action_time":0.0,"tackle_cd":0.0,"touch":0.0,"keeper_cd":0.0,"keeper_side":0.0,"keeper_height":0.0,"player_id":record.id,"attributes":record.attributes.duplicate(true),"ratings":ratings})
  players[-1]["body"]=Body.from_record(record,i%5)
  players[-1]["action_strength"]=0.0
  players[-1]["keeper_holding"]=false
  players[-1]["role"]=record.role
  players[-1]["preferred_foot"]=record.get("preferredFoot","right")
  players[-1]["style"]=Style.derive(record)
 mechanics.setup(self)
 reset_positions(0)

func side(team:int)->float:
 return 1.0 if team==0 else -1.0

func is_controlled(index:int)->bool:
 return teams[index/5].human and teams[index/5].selected==index

func reset_positions(kick_team:int)->void:
 goal_net=GoalNet.empty()
 brain.reset()
 mechanics.reset(self)
 phase="play";phase_time=0;restart_touch=-1;restart_origin="";restart_flow={}
 var formation:=Pitch.FORMATION
 for i in PLAYER_COUNT:
  if not players[i].active: continue
  players[i].pos=formation[i%5]*Vector2(side(i/5),1)
  players[i].vel=Vector2.ZERO
  players[i].dir=Vector2(side(i/5),0)
  players[i].cooldown=0.6
  players[i].action_time=0
  players[i].keeper_cd=0
  players[i].keeper_side=0
  players[i].keeper_holding=false
 for team in 2:
  teams[team].selected=team*5+1
  if not players[teams[team].selected].active:
   for i in range(team*5+1,team*5+5):
    if players[i].active: teams[team].selected=i;break
  teams[team].charging=false
  teams[team].charge=0
  teams[team].dash=0
  teams[team].receive_cancelled=false
  teams[team].run_player=-1;teams[team].run_time=0;teams[team].keeper_rush=false
 owner=teams[kick_team].selected
 players[owner].pos=Vector2(-1.5*side(kick_team),0)
 ball=players[owner].pos+Vector2(side(kick_team)*0.8,0)
 velocity=Vector2.ZERO
 ball_height=BallPhysics.FLOOR
 vertical_speed=0
 ball_spin=0
 pass_receiver=-1
 freeze=1.6
 restart_kind="kickoff"

func notify(kind:String,value:String)->void:
 event_kind=kind
 message=value
 event_serial+=1

func impact(kind:int,strength:float,direction:Vector2)->void:
 impact_id+=1;impact_kind=kind;impact_strength=clampf(strength,0,1)
 impact_x=direction.x;impact_y=direction.y

func wind_active()->bool:
 return arcade and stage==1 and fmod(elapsed,18.0)>12.0

func switch_player()->void:
 if phase!="play": return
 var best:int=mechanics.candidate(self,view_team)
 if best>=0: selected=best
 teams[view_team].receive_cancelled=true
 charging=false
 charge=0

func start_charge()->void:
 if owner==selected and freeze<=0 and not finished:
  charging=true
  charge=0.1

func shoot(aim:float=0.0,finesse:bool=false,chip:bool=false)->void:
 if owner!=selected or freeze>0 or finished:
  charging=false
  return
 if phase=="restart" and restart_kind in ["kick_in","goal_kick","indirect"]:
  charging=false;charge=0
  return
 var shot_assist:int=int(teams[view_team].shot_assist)
 if shot_assist<0: shot_assist=int(teams[view_team].assist)
 var target:=Vector2((HALF_LENGTH+1)*side(view_team),clampf(aim,-1,1)*[5.6,4.35,3.95][shot_assist])
 var index:=selected
 var amount:=clampf(charge,0,1)
 var kind:="chip" if chip else "finesse" if finesse else "normal"
 var profile:=Motion.shot(amount,kind,players[index].ratings)
 if not kick(index,target,profile.speed,true): return
 vertical_speed=profile.vertical
 if finesse and not chip:
  var bend_sign:float=signf(aim) if absf(aim)>0.1 else (-signf(players[selected].pos.y) if absf(players[selected].pos.y)>0.5 else 1.0)
  ball_spin=bend_sign*side(view_team)*(2.2+players[index].ratings.finishing_curve)*profile.spin_scale
  velocity=velocity.rotated(-ball_spin*0.055)
 players[index].action="chip" if chip else "finesse" if finesse else "power_shot" if amount>0.65 else "shoot"
 players[index].action_strength=amount;players[index].action_time=profile.duration
 if not chip and amount>=0.35 and velocity.length()>24:
  impact(1,clampf((velocity.length()-22)/18,0.20,1)*amount,velocity.normalized())
 charging=false
 charge=0

func pass_ball(through:bool=false,aim:Vector2=Vector2.ZERO,lobbed:bool=false,one_two:bool=false,power_amount:float=0.35,driven:bool=false)->void:
 if owner!=selected or freeze>0 or finished: return
 var plan:=pass_plan(selected,aim,through,int(teams[view_team].assist))
 var target:int=plan.receiver
 var passer:=selected
 var allow_run:bool=one_two and phase=="play" and passer%5!=0 and target>=0
 if not kick(selected,plan.destination,23,false): return
 if not lobbed:
  velocity*=lerpf(0.72,1.30,power_amount)*(1.30 if driven else 1.0)
  if driven:
   vertical_speed=0.12
   if players[passer].action=="pass": players[passer].action="driven_pass";players[passer].action_time=0.48
 if lobbed:
  var distance:float=players[passer].pos.distance_to(plan.destination)
  var flight_time:float=clampf(distance/lerpf(12,20,power_amount),0.55,1.6)
  velocity=plan.direction.rotated(rng.randf_range(-players[passer].ratings.cross_error,players[passer].ratings.cross_error))*(distance/flight_time*1.08)
  vertical_speed=BallPhysics.GRAVITY*flight_time*0.5
  if players[passer].action!="throw": players[passer].action="cross"
  players[passer].action_time=0.6
 pass_receiver=target
 players[passer].action_strength=power_amount
 if not lobbed and (driven or power_amount>0.70) and velocity.length()>22:
  impact(2,clampf((velocity.length()-18)/24,0.3,0.85),velocity.normalized())
 if target>=0 and int(teams[view_team].auto_switch)>0: selected=target
 if allow_run:
  teams[view_team].run_player=passer;teams[view_team].run_time=2.0
 teams[view_team].receive_cancelled=false
 charging=false
 charge=0
 notify("pass","二过一 · 传球者前插" if allow_run else "挑传 · 争抢落点" if lobbed else "直塞 · 跑向空当" if through else "短传 · 接应队友")

func pass_plan(index:int,aim:Vector2,through:bool,assist_level:int)->Dictionary:
 # Read-only preview and kick use exactly the same targeting; attribute error is
 # applied only by kick(), never by rendering this plan.
 var level:=Assistance.level(assist_level)
 var origin:Vector2=players[index].pos
 var direction:Vector2=aim.normalized() if aim.length()>0.2 else players[index].dir
 if direction.length()<0.1: direction=Vector2(side(index/5),0)
 var receiver:=-1
 var best:=-INF
 var cone:float=deg_to_rad([15.0,38.0,65.0][level])
 for i in range(index/5*5,index/5*5+5):
  if i==index or not players[i].active: continue
  var offset:Vector2=players[i].pos-origin
  var angle:float=absf(direction.angle_to(offset))
  if angle>cone and not (level>0 and aim.length()<=0.2): continue
  var score_value:float=(-angle*24 if aim.length()>0.2 else players[i].pos.x*side(index/5)*1.1)-offset.length()*0.18
  if level>0:
   score_value+=minf(closest_opponent(i),8)*float(level)*0.45
   for rival in range((1-index/5)*5,(1-index/5)*5+5):
    var point:=Geometry2D.get_closest_point_to_segment(players[rival].pos,origin,players[i].pos)
    if point.distance_to(players[rival].pos)<1.4: score_value-=4*level
  if score_value>best: best=score_value;receiver=i
 var destination:Vector2=origin+direction*(23.0 if through else 15.0)
 if receiver>=0:
  var target:Vector2=players[receiver].pos
  if through: target+=Vector2(side(index/5)*5,0)+players[receiver].vel*0.28
  var offset:Vector2=target-origin
  if level>0 and aim.length()<=0.2: direction=offset.normalized()
  var correction:float=[0.25,0.75,1.0][level]
  destination=origin+direction.rotated(direction.angle_to(offset)*correction)*offset.length()
 destination=destination.clamp(Vector2(-30,-16.5),Vector2(30,16.5))
 return {"receiver":receiver,"destination":destination,"direction":(destination-origin).normalized()}

func receiving_level(index:int,level_override:int=-1)->int:
 var team:int=index/5
 var level:int=Assistance.level(int(teams[team].receive_assist) if int(teams[team].receive_assist)>=0 else int(teams[team].assist))
 if level_override>=0: level=Assistance.level(level_override)
 return level

func receiving_pass(index:int,level:int)->bool:
 var t:Dictionary=teams[index/5]
 return level>0 and phase=="play" and owner<0 and players[index].active and t.assist_active and not t.receive_cancelled and pass_receiver==index and last_touch/5==index/5 and not ball_is_shot and kick_age<(1.4 if level==1 else 2.8)

func assisted_movement(index:int,raw:Vector2,position:Vector2,level_override:int=-1,current_velocity:Vector2=Vector2.INF,sprint_override:int=-1)->Vector2:
 var team:int=index/5
 var level:=receiving_level(index,level_override)
 if level==0 or phase!="play" or not teams[team].assist_active or teams[team].receive_cancelled or owner>=0: return raw
 var receiving:=receiving_pass(index,level)
 # Unrelated loose-ball help still yields completely to manual movement.
 var nearby:bool=level==2 and index%5!=0 and ball_height<1.3 and position.distance_to(ball)<4.0 and raw.length()<=0.15
 if not receiving and not nearby: return raw
 var p:Dictionary=players[index]
 if not p.active or p.jump_z>0.12 or p.landing>0 or (p.action in Motion.DEFENSIVE_ACTIONS and p.action_time>0): return raw
 # Earliest reachable, controllable-height point. Account for current momentum
 # and acceleration instead of assuming the receiver reaches top speed instantly.
 var travel_velocity:Vector2=p.vel if not current_velocity.is_finite() else current_velocity
 var sprinting:bool=teams[team].sprint if sprint_override<0 else sprint_override>0
 var speed:float=p.speed*(1-p.fatigue*0.14)*(1.42 if sprinting and p.stamina>2 else 1.0)
 var destination:=ball
 var predicted_velocity:=velocity
 var predicted_height:=ball_height
 var predicted_vertical:=vertical_speed
 var predicted_spin:=ball_spin
 var reachable:=false
 for step_index in range(1,26):
  var t:float=step_index*0.08
  var flight:=BallPhysics.advance(destination,predicted_velocity,predicted_height,predicted_vertical,predicted_spin,ball_is_shot,0.08,3.7 if wind_active() else 0.0)
  destination=flight.pos;predicted_velocity=flight.velocity;predicted_height=flight.height;predicted_vertical=flight.vertical;predicted_spin=flight.spin
  var along:float=clampf(travel_velocity.dot((destination-position).normalized()),-speed,speed)
  var accelerating:float=minf(t,(speed-along)/p.ratings.acceleration)
  var distance:float=maxf(0,along*accelerating+0.5*p.ratings.acceleration*accelerating*accelerating+speed*(t-accelerating))
  if predicted_height<=p.body.foot_height and position.distance_to(destination)<=distance+p.body.foot_reach:
   reachable=true;break
 if not reachable: return raw
 var offset:Vector2=destination-position
 var arrival:Vector2=offset.normalized()*clampf(offset.length()/0.7,0,1)
 if raw.length()<=0.15: return arrival
 # Moving away is an intentional breakaway, not a reason to permanently cancel
 # reception. Releasing the direction resumes assistance for this same pass.
 if raw.length()>0.65 and raw.normalized().dot(offset.normalized())< -0.65: return raw
 var weight:float=0.50 if level==1 else 0.85
 return raw.lerp(arrival,weight).limit_length()

func receiving_facing(index:int,raw:Vector2,position:Vector2,level_override:int=-1)->Vector2:
 var level:=receiving_level(index,level_override)
 if not receiving_pass(index,level): return Vector2.ZERO
 var offset:Vector2=ball-position
 if offset.length()>4.5 or offset.length()<0.1: return Vector2.ZERO
 if raw.length()>0.65 and raw.normalized().dot(offset.normalized())< -0.65: return Vector2.ZERO
 return offset.normalized()

func do_dash()->void:
 if energy>=22 and dash_cd<=0 and freeze<=0:
  energy-=22
  teams[view_team].dash=0.65
  teams[view_team].dash_cd=2.5

func overdrive()->void:
 teams[view_team].jockey=true

func tackle(index:int=-1,sliding:bool=false)->void:
 if index<0: index=selected
 var p:Dictionary=players[index]
 if phase!="play" or freeze>0 or finished or not p.active or p.jump_z>0 or p.landing>0 or p.tackle_cd>0 or owner==index: return
 if owner>=0 and owner/5==index/5: return
 p.slide_speed=clampf(p.vel.dot(p.dir),0,p.speed*1.42) if sliding else 0.0
 var stationary:bool=sliding and p.slide_speed<1.2
 p.tackle_cd=p.ratings.tackle_recovery+(0.50 if stationary else 0.85 if sliding else 0)
 p.action="slide_still" if stationary else "slide" if sliding else "tackle"
 p.action_time=Motion.GROUND_TACKLE_DURATION if stationary else Motion.tackle_duration(sliding)
 p.tackle_resolved=false;p.tackle_target=owner
 p.cooldown=maxf(p.cooldown,p.action_time+0.05)
 p.stamina=maxf(0,p.stamina-(13 if sliding else 7))

func resolve_tackle(index:int,sliding:bool)->void:
 var p:Dictionary=players[index]
 if not p.active or p.get("tackle_resolved",false): return
 if owner==index or (owner>=0 and owner/5==index/5): return
 if owner>=0 and players[owner].keeper_holding: return
 var offset:Vector2=ball-p.pos
 var shield:float=0
 if owner>=0:
  shield=maxf(0,players[owner].ratings.shield-p.ratings.shield)*0.40
  if shielding(owner) and players[owner].dir.dot((p.pos-players[owner].pos).normalized())<0:
   shield+=0.25+players[owner].ratings.shield*0.4
 var reach:float=p.ratings.tackle_reach-shield+(minf(0.65,p.slide_speed*0.075) if sliding else 0.0)
 var ball_access:bool=offset.length()<reach and ball_height<(0.80 if sliding else 1.10) and (offset.length()<0.65 or p.dir.dot(offset.normalized())>(0.65 if sliding else 0.45))
 var victim:int=owner if owner>=0 else int(p.get("tackle_target",-1))
 if not arcade and victim>=0 and victim/5!=index/5 and players[victim].active:
  var body_offset:Vector2=players[victim].pos-p.pos
  var path_end:Vector2=p.pos+p.dir*minf(reach,offset.length())
  var path_point:=Geometry2D.get_closest_point_to_segment(players[victim].pos,p.pos,path_end)
  var body_first:bool=body_offset.length()+0.20<offset.length() and path_point.distance_to(players[victim].pos)<players[victim].body.body_radius+0.15
  var body_contact:bool=body_offset.length()<(reach if sliding else 1.35) and p.dir.dot(body_offset.normalized())>0.4
  if body_contact and (not ball_access or body_first):
   p.tackle_resolved=true
   Rules.foul(self,index,victim,sliding)
   return
 if not ball_access: return
 p.tackle_resolved=true
 var previous_owner:int=owner
 owner=-1
 var poke_direction:Vector2=p.dir.lerp(offset.normalized(),0.35).normalized()
 ball+=poke_direction*0.18
 velocity=poke_direction*((7.0+minf(p.vel.length()*0.35,3.5)) if sliding else (4.2+p.attributes.tackling/99.0*2.5))
 vertical_speed=0.35 if sliding else 0.20;ball_spin=0;ball_is_shot=false;pass_receiver=-1
 last_touch=index;restart_touch=-1;restart_origin="";pickup_lock=0.10
 if previous_owner>=0:
  players[previous_owner].cooldown=0.45 if sliding else 0.28
  teams[previous_owner/5].charging=false;teams[previous_owner/5].charge=0
 tackles[index/5]+=1
 if sliding: impact(3,clampf(0.30+p.slide_speed/12,0.30,0.9),poke_direction)
 notify("tackle","原地铲球 · 收腿后继续争抢" if p.action=="slide_still" else "滑铲解围 · 起身后继续争抢" if sliding else "伸脚抢断 · 争取球权")

func shielding(index:int)->bool:
 return teams[index/5].jockey if is_controlled(index) else players[index].action=="shield" and players[index].action_time>0

func aerial(index:int,aim:float)->void:
 mechanics.jump(self,index,"shot",aim,teams[index/5].move)

func legacy_aerial(index:int,aim:float)->void:
 if phase!="play" or owner>=0 or freeze>0 or finished or pickup_lock>0: return
 var p:Dictionary=players[index]
 if p.cooldown>0 or p.pos.distance_to(ball)>1.8 or ball_height<0.8 or ball_height>p.body.head_height+0.45: return
 var header:bool=ball_height>p.body.chest_height
 var height:=ball_height
 if not kick(index,Vector2((HALF_LENGTH+1)*side(index/5),clampf(aim,-1,1)*4),16+float(p.attributes.heading if header else p.attributes.finishing)*0.12,true): return
 ball_height=height;vertical_speed=-1.5 if header else 2.5
 p.action="header" if header else "volley";p.action_time=0.55
 notify("shot","头球攻门" if header else "凌空抽射")

func kick(index:int,target:Vector2,power:float,is_shot:bool)->bool:
 if phase in ["goal","foul"] or not players[index].active: return false
 if phase=="restart" and (index!=restart_taker or not Rules.Flow.ready(self)): return false
 if phase=="play" and restart_touch==index:
  Rules.restart(self,1-index/5,"indirect",ball)
  notify("foul","开球后连续触球 · 间接任意球")
  return false
 if phase=="play": restart_touch=-1;restart_origin=""
 var release_origin:=restart_spot
 var release_kind:=Rules.released(self,index)
 var from_hands:bool=players[index].keeper_holding
 players[index].keeper_holding=false
 for team in teams: team.receive_cancelled=false
 var keep_touch:bool=is_shot and owner==index and release_kind.is_empty() and not from_hands and ball.distance_to(players[index].pos)<1.8
 var direction:Vector2=(target-(ball if keep_touch else players[index].pos)).normalized()
 var rating:Dictionary=players[index].ratings
 var distance:float=players[index].pos.distance_to(target)
 var error:float=lerpf(rating.shot_error,rating.long_error,clampf((distance-16.0)/16.0,0,1)) if is_shot else rating.pass_error
 if is_shot and release_kind in ["free_kick","penalty","corner","accumulated"]: error=rating.set_piece_error
 # Seeded authority owns shot/pass spread; aim and charge still come from the human.
 direction=direction.rotated(rng.randf_range(-error,error))
 if index%5==0: mechanics.last_keeper_pass[index/5]=true
 ball_is_shot=is_shot
 ball_spin=0.0
 pass_receiver=-1
 if not is_shot:
  var best:=INF
  for i in range(index/5*5,index/5*5+5):
   if i==index or not players[i].active: continue
   var d:float=players[i].pos.distance_to(target)
   if d<best: best=d; pass_receiver=i
  pass_destination=target
  power=sqrt(16.0*players[index].pos.distance_to(target)+100.0)
 if not keep_touch: ball=players[index].pos+direction*1.1
 if not release_kind.is_empty(): ball=release_origin+direction*0.4
 velocity=direction*power*(1.15 if arcade and stage==2 else 1.0)
 ball_height=BallPhysics.FLOOR
 vertical_speed=1.8 if is_shot else 0.3
 owner=-1
 last_touch=index
 pickup_lock=0.17
 kick_age=0
 players[index].cooldown=0.4
 players[index].action="shoot" if is_shot else "pass"
 players[index].action_time=0.4
 players[index].action_strength=0.4
 players[index].action_dir=direction;players[index].contact_height=BallPhysics.FLOOR
 if from_hands and not is_shot:
  players[index].action="throw";players[index].action_time=0.5
  ball_height=players[index].body.height*0.65;vertical_speed=1.5
 if not release_kind.is_empty():
  players[index].action="set_kick";players[index].action_time=0.65
 if is_shot:
  shots[index/5]+=1
  notify("shot","射门！")
 else: passes[index/5]+=1
 return true

func apply_command(team:int,command:Dictionary)->void:
 if team<0 or team>1 or finished: return
 var previous:=view_team
 view_team=team
 teams[team].move=command.get("move",Vector2.ZERO).limit_length()
 teams[team].sprint=bool(command.get("sprint",false))
 teams[team].jockey=bool(command.get("jockey",false))
 teams[team].keeper_rush=bool(command.get("keeper_rush",false))
 teams[team].skip_restart=bool(command.get("skip_restart",false))
 teams[team].assist=Assistance.level(int(command.get("assist",teams[team].assist)))
 teams[team].assist_active=bool(command.get("assist_active",true))
 if phase in ["goal","foul"]:
  mechanics.command(self,team,command)
  view_team=previous
  return
 if phase=="restart" and team!=restart_team:
  mechanics.command(self,team,command)
  view_team=previous
  return
 var action:int=int(command.get("action",0))
 if mechanics.command(self,team,command):
  view_team=previous
  return
 if action&128: charging=false; charge=0
 if action&1: start_charge()
 if action&2: shoot(float(command.get("aim",0.0)),bool(command.get("finesse",false)),bool(command.get("chip",false)))
 if action&4: pass_ball(false,teams[team].move,false,bool(command.get("chip",false)))
 if action&8: pass_ball(true,teams[team].move,bool(command.get("chip",false)))
 if action&16: switch_player()
 if action&32: tackle()
 if action&64: tactic=clampi(int(command.get("tactic",1)),0,2)
 if action&256: pass_ball(false,teams[team].move,true)
 if action&512: tackle(-1,true)
 if action&1024: aerial(selected,float(command.get("aim",0.0)))
 if action&2048 and owner==selected and phase=="play":
  charging=false;charge=0
  players[selected].action="feint";players[selected].action_time=0.4
 view_team=previous

func tick(dt:float,movement:Vector2)->void:
 teams[view_team].move=movement.limit_length()
 step(dt)

func move_player(index:int,dt:float,movement:Vector2,sprinting:bool,jockeying:bool)->void:
 var p:Dictionary=players[index]
 if not p.active: return
 var limit:=player_limit(index)
 var speed:float=p.speed*(1-p.fatigue*0.14)
 if p.jump_z>0: speed*=0.7
 if p.landing>0 or p.balance>0: speed*=0.65
 if p.release_wait>0: speed*=0.55
 if p.action in Motion.DEFENSIVE_ACTIONS and p.action_time>0:
  p.vel=p.vel.move_toward(Motion.defensive_velocity(p.action,p.action_time,p.dir,speed,p.slide_speed),dt*32)
  p.pos=(p.pos+p.vel*dt).clamp(-limit,limit)
  return
 if sprinting and p.stamina>2 and movement.length()>0.1:
  speed*=1.42
  p.stamina=maxf(0,p.stamina-dt*p.ratings.drain)
 else: p.stamina=minf(100,p.stamina+dt*p.ratings.recovery)
 if jockeying: speed*=0.58
 if jockeying and owner==index and index%5!=0:
  p.stamina=maxf(0,p.stamina-dt*8)
  if p.action_time<=0 or p.action=="shield": p.action="shield";p.action_time=0.15
 if p.action_time>0 and p.action=="tackle": speed*=0.32
 if p.action_time>0 and p.action=="receive": speed*=0.7
 if p.action_time>0 and p.action in Motion.DIVES: speed*=1.25 if p.action_time>0.28 else 0.25
 if owner==index: speed*=p.ratings.dribble_speed
 if (index%5!=0 or owner==index) and not jockeying and p.action!="slide":
  speed*=Motion.turn_scale(p.dir,movement,p.ratings)
 var acceleration:float=p.ratings.acceleration*(p.ratings.carry_acceleration if owner==index else 1.0)
 p.vel=p.vel.move_toward(movement.limit_length()*speed,dt*(acceleration if movement.length()>0.05 else p.ratings.braking))
 p.pos+=p.vel*dt
 p.pos=p.pos.clamp(-limit,limit)
 var facing:Vector2=(ball-p.pos).normalized() if (jockeying or index%5==0) and owner!=index else movement.normalized()
 if is_controlled(index):
  var reception:Vector2=receiving_facing(index,teams[index/5].move,p.pos)
  if reception.length()>0.1: facing=reception
 if jockeying and owner==index and movement.length()<0.15:
  var nearest:=INF
  for rival in range((1-index/5)*5,(1-index/5)*5+5):
   var away:Vector2=p.pos-players[rival].pos
   if away.length()<nearest: nearest=away.length();facing=away.normalized()
 if p.action in Motion.DIVES and p.action_time>0: facing=p.dir
 if facing.length()>0.1:
  p.dir=p.dir.rotated(clampf(p.dir.angle_to(facing),-dt*p.ratings.turn_rate,dt*p.ratings.turn_rate)).normalized()

func player_limit(index:int)->Vector2:
 return Pitch.movement_limit(players[index].body,ice_mode or arcade)

func step(dt:float)->void:
 if finished: return
 frame+=1
 mechanics.tick(self,dt)
 if finished: return
 if phase!="play":
  Rules.update(self,dt)
  return
 if freeze>0:
  freeze-=dt
  return
 elapsed+=dt
 pickup_lock=maxf(0,pickup_lock-dt)
 kick_age+=dt
 for team in 2:
  teams[team].dash=maxf(0,teams[team].dash-dt)
  teams[team].dash_cd=maxf(0,teams[team].dash_cd-dt)
  teams[team].run_time=maxf(0,teams[team].run_time-dt)
  if (owner>=0 and owner/5!=team) or (teams[team].selected==teams[team].run_player and teams[team].move.length()>0.15): teams[team].run_time=0
  if teams[team].run_time<=0: teams[team].run_player=-1
  if teams[team].charging:
   teams[team].charge=minf(1,teams[team].charge+dt*0.9)
   players[teams[team].selected].action="windup"
   players[teams[team].selected].action_strength=teams[team].charge
   players[teams[team].selected].action_time=0.15
 if owner>=0: possession[owner/5]+=dt
 if elapsed>=duration and not overtime:
  if score[0]!=score[1]: finished=true; notify("end","终场哨响"); return
  overtime=true
  duration+=overtime_duration
  notify("overtime","金球加时 · 下一粒进球决定胜负")
 elif elapsed>=duration:
  finished=true; notify("end","终场 · 平局"); return
 brain.prepare(self)
 mechanics.plan(self)
 for i in PLAYER_COUNT:
  var p:Dictionary=players[i]
  if not p.active: continue
  p.cooldown=maxf(0,p.cooldown-dt)
  p.tackle_cd=maxf(0,p.tackle_cd-dt)
  p.action_time=maxf(0,p.action_time-dt)
  p.keeper_cd=maxf(0,p.keeper_cd-dt)
  if owner!=i: p.keeper_holding=false
  p.touch+=dt*p.vel.length()
  var controlled:=is_controlled(i)
  if not controlled and i%5!=0 and ball_height>0.8 and owner<0 and p.pos.distance_to(ball)<3.5 and brain.wants_aerial(self,i):
   aerial(i,clampf(ball.y*0.1,-1,1))
  var movement:Vector2=teams[i/5].move if controlled else ai_direction(i)
  if controlled: movement=assisted_movement(i,movement,p.pos)
  var sprinting:bool=(teams[i/5].sprint or teams[i/5].dash>0) if controlled else brain.sprint(self,i)
  var jockeying:bool=teams[i/5].jockey if controlled else brain.jockey(self,i)
  move_player(i,dt,movement,sprinting,jockeying)
  if Motion.tackle_contact(p.action,p.action_time):
   resolve_tackle(i,p.action!="tackle")
   if phase!="play": return
  if not controlled and brain.may_tackle(self,i):
   tackle(i)
   if phase!="play": return
 var separation_budget:Array=[]
 for p in players: separation_budget.append(p.speed*0.20*dt)
 for i in PLAYER_COUNT:
  for j in range(i+1,PLAYER_COUNT):
   if not players[i].active or not players[j].active: continue
   var diff:Vector2=players[i].pos-players[j].pos
   var length:=diff.length()
   var spacing:float=players[i].body.body_radius+players[j].body.body_radius
   if length>0.01 and length<spacing:
    var push:=diff/length*minf((spacing-length)*0.35,minf(separation_budget[i],separation_budget[j]))
    players[i].pos+=push
    players[j].pos-=push
    separation_budget[i]-=push.length();separation_budget[j]-=push.length()
    mechanics.contact(self,i,j)
 if owner>=0:
  var p:Dictionary=players[owner]
  var stride:float=p.ratings.stride+absf(sin(p.touch*1.7))*p.ratings.touch_wave
  if p.keeper_holding: stride=0.65
  elif shielding(owner): stride=0.76
  if teams[owner/5].sprint and is_controlled(owner): stride+=p.ratings.sprint_touch
  var desired:Vector2=p.pos+p.dir*stride
  ball=ball.lerp(desired,minf(1,dt*p.ratings.touch_follow))
  velocity=p.vel
  ball_height=lerpf(p.keeper_height,p.body.height*0.65,1-clampf(p.cooldown/1.1,0,1)) if p.keeper_holding else BallPhysics.FLOOR+absf(sin(p.touch*1.7))*0.04
  ball_spin=0
  vertical_speed=0
  last_touch=owner
  if resolve_boundary(): return
 else:
  var previous_ball:=Vector3(ball.x,ball_height,ball.y)
  var flight:=BallPhysics.advance(ball,velocity,ball_height,vertical_speed,ball_spin,ball_is_shot,dt,3.7 if wind_active() else 0.0)
  ball=flight.pos;velocity=flight.velocity;ball_height=flight.height;vertical_speed=flight.vertical;ball_spin=flight.spin
  var frame_hit:=GoalFrame.collide(previous_ball,Vector3(ball.x,ball_height,ball.y),Vector3(velocity.x,vertical_speed,velocity.y))
  if not frame_hit.is_empty():
   ball=Vector2(frame_hit.position.x,frame_hit.position.z);ball_height=maxf(BallPhysics.FLOOR,frame_hit.position.y)
   velocity=Vector2(frame_hit.velocity.x,frame_hit.velocity.z);vertical_speed=frame_hit.velocity.y
   ball_spin*=0.6;pickup_lock=maxf(pickup_lock,0.05)
   notify("post","击中横梁！" if frame_hit.kind=="bar" else "击中门柱！")
  # Resolve a save before a later goal-line crossing within the same tick.
  resolve_player_contacts(Vector2(previous_ball.x,previous_ball.z),previous_ball.y)
  if phase!="play": return
  if resolve_boundary(previous_ball): return

func keeper_can_save(index:int)->bool:
 return KeeperAI.hands_allowed(self,index)

func resolve_player_contacts(previous_ball:Vector2,previous_height:float=-1.0)->void:
 if owner>=0 or pickup_lock>0: return
 if previous_height<0: previous_height=ball_height
 var start3:=Vector3(previous_ball.x,previous_height,previous_ball.y)
 var finish3:=Vector3(ball.x,ball_height,ball.y)
 var contacts:Array[Dictionary]=[]
 var boundary_time:=1.0
 var travel:Vector2=ball-previous_ball
 for axis in 2:
  var limit:float=HALF_LENGTH if axis==0 else HALF_WIDTH
  if axis==0 and absf(ball.y)<GOAL_WIDTH and ball_height<Pitch.GOAL_HEIGHT: limit+=BallPhysics.RADIUS
  if absf(previous_ball[axis])>limit: boundary_time=0;continue
  if absf(ball[axis])>limit and absf(travel[axis])>0.00001:
   boundary_time=minf(boundary_time,(signf(ball[axis])*limit-previous_ball[axis])/travel[axis])
 for i in PLAYER_COUNT:
  var p:Dictionary=players[i]
  if p.cooldown>0 or not p.active or p.landing>0: continue
  var saving:=keeper_can_save(i)
  var hit:Dictionary=PlayerCollision.sweep(p,start3,finish3)
  # A prepared first touch has extra foot reach; a passive head/body block does not.
  var prepared:bool=i==pass_receiver or p.dir.dot((previous_ball-p.pos).normalized())>0.15
  if not is_controlled(i) and not brain.reaction_until.is_empty() and elapsed<float(brain.reaction_until[i]): prepared=false
  if not ball_is_shot and prepared and p.jump_z<0.12:
   var control_hit:=BallPhysics.player_contact(previous_ball,ball,p.pos,p.body.foot_reach)
   if not control_hit.is_empty() and lerpf(previous_height,ball_height,control_hit.time)<=p.body.foot_height:
    if hit.is_empty() or control_hit.time<hit.time: hit=control_hit;hit.zone="foot"
  if i%5==0 and KeeperAI.in_area(p.pos,side(i/5)):
   var keeper_hit:=BallPhysics.player_contact(previous_ball,ball,KeeperAI.contact_center(p) if saving else p.pos,KeeperAI.radius(p,saving))
   if not keeper_hit.is_empty():
    var zone:=Body.contact_zone(p.body,lerpf(previous_height,ball_height,keeper_hit.time),p.jump_z,saving)
    if zone!="none" and (saving or zone=="foot"):
     if hit.is_empty() or keeper_hit.time<=hit.time: hit=keeper_hit;hit.zone=zone
  if hit.is_empty(): continue
  if hit.time>boundary_time: continue
  hit.merge({"index":i,"saving":saving})
  contacts.append(hit)
 contacts.sort_custom(func(a,b): return a.time<b.time)
 for hit in contacts:
  var i:int=hit.index
  var p:Dictionary=players[i]
  var saving:bool=hit.saving
  var zone:String=hit.zone
  var incoming_direction:=velocity.normalized()
  var incoming:=velocity.length()
  var rebound:bool=(saving and incoming>p.ratings.keeper_hold) or (not saving and (zone in ["chest","head"] or (incoming>12 and ball_is_shot)))
  # A separating overlap gets position correction only; it cannot kick again.
  var approach:float=Vector3(velocity.x,vertical_speed,velocity.y).dot(hit.normal3) if hit.has("normal3") else velocity.dot(hit.normal)
  if rebound and approach>=0 and absf(vertical_speed)<0.1:
   if contacts.size()==1: ball=hit.position
   continue
  if restart_touch==i:
   Rules.restart(self,1-i/5,"indirect",ball)
   notify("foul","开球后连续触球 · 间接任意球")
   return
  restart_touch=-1;restart_origin=""
  var prior_touch:int=last_touch
  last_touch=i
  p.keeper_holding=false
  if rebound:
   var energy_speed:=Vector3(velocity.x,vertical_speed,velocity.y).length()
   var restitution:float=1.0-p.ratings.header_control if zone=="head" else 0.5 if saving else 0.35
   if hit.has("normal3") and not saving:
    var bounced:=PlayerCollision.deflect(Vector3(velocity.x,vertical_speed,velocity.y),hit.normal3,restitution)
    velocity=Vector2(bounced.x,bounced.z);vertical_speed=bounced.y
    ball_height=maxf(BallPhysics.FLOOR,hit.point3.y)
   else:
    velocity=BallPhysics.deflect(velocity,hit.normal,restitution)
    vertical_speed*=0.6 if saving else 0.35
   if saving:
    var wide:=Vector2(side(i/5)*0.7,(-1.0 if ball.y<0 else 1.0))
    velocity=velocity.normalized().lerp(wide.normalized(),0.35+p.attributes.goalkeeping/99.0*0.25).normalized()*velocity.length()
   ball=hit.position
   pickup_lock=0.14;ball_spin*=0.25;p.cooldown=0.18
   if saving:
    p.keeper_height=ball_height
    p.action=p.action if p.action in Motion.DIVES else Motion.keeper_action(ball_height,incoming,0,p.body,p.ratings.keeper_hold)
    if p.action in ["tip","dive_high"]:
     var deflected:=Vector3(velocity.x,minf(4.5,energy_speed*0.45),velocity.y).limit_length(energy_speed*0.85)
     velocity=Vector2(deflected.x,deflected.z);vertical_speed=deflected.y
    saves[i/5]+=1
   else: p.action="block_head" if zone=="head" else "block_chest" if zone=="chest" else "block"
   p.action_dir=-incoming_direction;p.contact_height=ball_height-p.jump_z
   p.action_time=0.8 if saving and p.action in Motion.DIVES else 0.6 if saving else 0.3
   ball_is_shot=false;pass_receiver=-1
   notify("block","封堵 · 足球折射")
   return
  if mechanics.strict_rules and i%5==0 and mechanics.last_keeper_pass[i/5] and prior_touch/5==i/5 and p.pos.x*side(i/5)<0:
   Rules.restart(self,1-i/5,"indirect",ball);notify("foul","门将重复回传触球");return
  for team in 2:
   if i/5!=team: mechanics.last_keeper_pass[team]=false
  owner=i;pass_receiver=-1;velocity=Vector2.ZERO;vertical_speed=0;ball_spin=0
  p.keeper_holding=saving
  p.keeper_height=ball_height if saving else BallPhysics.FLOOR
  ball_height=p.keeper_height if saving else BallPhysics.FLOOR
  p.cooldown=1.1 if saving else 0.3
  p.action=Motion.keeper_action(p.keeper_height,incoming,0,p.body,p.ratings.keeper_hold) if saving else "receive"
  if saving and teams[i/5].keeper_rush and p.keeper_height<p.body.height*0.4: p.action="smother"
  p.action_time=0.7 if saving else p.ratings.control
  p.action_dir=-incoming_direction;p.contact_height=ball_height-p.jump_z
  teams[i/5].charging=false;teams[i/5].charge=0
  if teams[i/5].auto_switch>0 or not teams[i/5].human: teams[i/5].selected=i
  mechanics.after_receive(self,i,incoming,incoming_direction)
  ball_is_shot=false
  if saving:
   saves[i/5]+=1
   notify("save","门将扑救 · 选择方向出球")
  elif i%5==0: notify("pass","门将脚下控球 · 选择方向传球")
  return

func resolve_boundary(previous:Vector3=Vector3.INF)->bool:
 if absf(ball.x)>HALF_LENGTH:
  var crossing:=Vector3(ball.x,ball_height,ball.y)
  var goal_side:=signf(ball.x)
  var plane:float=(HALF_LENGTH+BallPhysics.RADIUS)*goal_side
  if previous!=Vector3.INF and previous.x*goal_side<=HALF_LENGTH+BallPhysics.RADIUS and crossing.x*goal_side>HALF_LENGTH+BallPhysics.RADIUS:
   crossing=previous.lerp(crossing,clampf((plane-previous.x)/(crossing.x-previous.x),0,1))
  var in_mouth:bool=absf(crossing.z)<GOAL_WIDTH-BallPhysics.RADIUS and crossing.y<Pitch.GOAL_HEIGHT-BallPhysics.RADIUS
  if in_mouth:
   if absf(ball.x)<=HALF_LENGTH+BallPhysics.RADIUS: return false
   var team:=0 if ball.x>0 else 1
   if restart_touch>=0 and restart_origin in ["kick_in","goal_kick","indirect"]:
    var own_goal:bool=restart_touch/5!=team
    Rules.restart(self,team if own_goal else 1-team,"corner" if own_goal else "goal_kick",ball)
    notify("restart","此类开球不能直接得分 · "+("角球" if own_goal else "球门球"))
   else: Rules.goal(self,team)
   return true
  if arcade or ice_mode:
   var wall_side:=signf(ball.x)
   ball.x=wall_side*(HALF_LENGTH-0.02)
   if velocity.x*wall_side>0: velocity.x*=-0.78
   if owner>=0: owner=-1;pickup_lock=0.12;pass_receiver=-1
  else:
   var attacking:=0 if ball.x>0 else 1
   var corner:bool=last_touch/5!=attacking
   restart_play(attacking if corner else 1-attacking,"corner" if corner else "goal_kick")
   return true
 if absf(ball.y)>HALF_WIDTH:
  if arcade or ice_mode:
   var wall_side:=signf(ball.y)
   ball.y=wall_side*(HALF_WIDTH-0.02)
   if velocity.y*wall_side>0: velocity.y*=-0.82
   if owner>=0: owner=-1;pickup_lock=0.12;pass_receiver=-1
  else:
   restart_play(1-last_touch/5,"kick_in")
   return true
 return false

func restart_play(team:int,kind:String)->void:
 Rules.restart(self,team,kind,ball)

func keeper_target(index:int)->Vector2:
 return KeeperAI.target(self,index)

func ai_direction(index:int)->Vector2:
 brain.ensure(self)
 if owner==index: return brain.on_ball(self,index)
 if index%5==0:
  var offset:Vector2=keeper_target(index)-players[index].pos
  return offset.normalized()*clampf(offset.length()/0.8,0,1)
 return brain.movement(self,index)

func best_outfield_receiver(index:int,aim:Vector2=Vector2.ZERO)->int:
 var option:Dictionary=brain.pass_option(self,index)
 return option.receiver if option.receiver>=0 else index/5*5+1
func closest_opponent(index:int)->float:
 var best:=INF
 for i in PLAYER_COUNT:
  if i/5==index/5 or not players[i].active: continue
  best=minf(best,players[index].pos.distance_to(players[i].pos))
 return best

func snapshot()->Dictionary:
 return {"goal_net":goal_net.duplicate(true),"ice_mode":ice_mode,"arcade":arcade,"players":players.duplicate(true),"teams":teams.duplicate(true),"ball":ball,"velocity":velocity,"height":ball_height,"vertical":vertical_speed,"owner":owner,"score":score.duplicate(),"shots":shots.duplicate(),"passes":passes.duplicate(),"tackles":tackles.duplicate(),"saves":saves.duplicate(),"possession":possession.duplicate(),"elapsed":elapsed,"duration":duration,"regulation":regulation,"freeze":freeze,"finished":finished,"overtime":overtime,"impact_id":impact_id,"impact_kind":impact_kind,"impact_strength":impact_strength,"impact_x":impact_x,"impact_y":impact_y,"event":event_serial,"kind":event_kind,"message":message,"frame":frame,"restart":restart_kind,"pass_receiver":pass_receiver,"pass_destination":pass_destination,"last_touch":last_touch,"kick_age":kick_age,"ball_is_shot":ball_is_shot,"spin":ball_spin,"rules":Rules.state(self),"ai":brain.state(),"mechanics":mechanics.state()}

func restore(state:Dictionary)->void:
 goal_net=state.get("goal_net",GoalNet.empty()).duplicate(true)
 ice_mode=bool(state.get("ice_mode",false));arcade=bool(state.get("arcade",false))
 for key in ["impact_id","impact_kind","impact_strength","impact_x","impact_y"]: set(key,state.get(key,0))
 players.assign(state.players.duplicate(true))
 teams.assign(state.teams.duplicate(true))
 ball=state.ball; velocity=state.velocity; ball_height=state.height; vertical_speed=state.vertical
 owner=state.owner; score=state.score.duplicate(); shots=state.shots.duplicate(); passes=state.passes.duplicate()
 tackles=state.tackles.duplicate(); saves=state.saves.duplicate(); possession=state.possession.duplicate()
 elapsed=state.elapsed; duration=state.duration; regulation=state.regulation; freeze=state.freeze
 finished=state.finished; overtime=state.overtime; event_serial=state.event; event_kind=state.kind
 message=state.message; frame=state.frame; restart_kind=state.restart
 pass_receiver=state.pass_receiver;pass_destination=state.pass_destination;last_touch=state.last_touch
 kick_age=state.kick_age;ball_is_shot=state.ball_is_shot;ball_spin=state.spin
 Rules.restore(self,state.rules)
 brain.restore(state.get("ai",{}))
 mechanics.restore(state.get("mechanics",{}))


