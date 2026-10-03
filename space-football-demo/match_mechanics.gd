extends RefCounted
const Pitch=preload("res://pitch_geometry.gd")
## Authority-owned interaction layer. Devices only submit intentions.
const SWITCH=4096
const RUN=8192
const SUPPORT=16384
const SKILL=32768
const SUBSTITUTE=65536
const SET_PIECE=131072
const CANCEL=262144
const SHOT_BUFFER=524288
const MAX_ACTION=1048575
var buffered:Array=[{},{}]
var releases:Array=[{},{}]
var requests:Array=[{},{}]
var advantage:Dictionary={}
var benches:Array=[[],[]]
var sent_off:Dictionary={}
var last_keeper_pass:=[false,false]
var keeper_clock:=[0.0,0.0]
var keeper_owner:=-1
var strict_rules:=false
var clock:=0.0

func setup(s)->void:
 for p in s.players: initialize_player(p)
 for t in s.teams:
  t.merge({"contain":false,"contain_player":-1,"receive_assist":-1,"shot_assist":-1,"auto_switch":1,"pass_power":0.35,"pass_charging":false,"request_player":-1,"request_time":0.0,"sub_pending":-1,"corner_plan":0})
 var used:Array=[]
 for p in s.players: used.append(p.player_id)
 for team in 2:
  for role in ["GK","ST","RW","CB"]:
   var pool:Array=s.Library.all().filter(func(p): return p.role==role and p.id not in used)
   if pool.is_empty(): continue
   var record:Dictionary=pool[s.rng.randi_range(0,pool.size()-1)]
   benches[team].append({"id":record.id,"fatigue":0.0,"yellow":0});used.append(record.id)

func initialize_player(p:Dictionary)->void:
 p.action_dir=p.dir;p.contact_height=0.32
 p.merge({"active":true,"fatigue":0.0,"yellow":0,"sinbin":0.0,"jump_z":0.0,"jump_v":0.0,"jump_kind":"","jump_aim":0.0,"jump_direction":Vector2.ZERO,"landing":0.0,"balance":0.0,"release_wait":0.0,"touch_ready":0.0,"sub_revision":0},true)
 p.tackle_resolved=false;p.tackle_target=-1;p.slide_speed=0.0

func reset(s,reset_air:bool=true)->void:
 buffered=[{},{}];releases=[{},{}];advantage={};keeper_clock=[0.0,0.0];last_keeper_pass=[false,false]
 for p in s.players:
  if reset_air: p.jump_z=0;p.jump_v=0;p.landing=0
  p.jump_kind="";p.release_wait=0
 for t in s.teams: t.contain_player=-1;t.request_time=0;t.request_player=-1;t.pass_charging=false

func state()->Dictionary:
 return {"buffered":buffered.duplicate(true),"releases":releases.duplicate(true),"requests":requests.duplicate(true),"advantage":advantage.duplicate(true),"benches":benches.duplicate(true),"sent_off":sent_off.duplicate(true),"last_keeper_pass":last_keeper_pass.duplicate(),"keeper_clock":keeper_clock.duplicate(),"keeper_owner":keeper_owner,"strict_rules":strict_rules,"clock":clock}

func restore(data:Dictionary)->void:
 for key in data: set(key,data[key].duplicate(true) if data[key] is Array or data[key] is Dictionary else data[key])

func candidate(s,team:int,direction:Vector2=Vector2.ZERO)->int:
 var selected:int=s.teams[team].selected
 var best:=-1;var score:float=INF
 for i in range(team*5,team*5+5):
  if i==selected or not s.players[i].active: continue
  if i%5==0 and direction.length()<0.2: continue
  var offset:Vector2=s.players[i].pos-s.players[selected].pos
  var value:float=s.players[i].pos.distance_to(s.ball+s.velocity*0.20)
  if direction.length()>0.2:
   var angle:float=absf(direction.angle_to(offset))
   if angle>1.3: continue
   value=angle*22+offset.length()*0.12
  else: value+=maxf(0,(s.players[i].pos.x-s.ball.x)*s.side(team))*0.3
  if value<score: score=value;best=i
 return best

func can_buffer(s,index:int)->bool:
 if s.phase!="play" or s.owner>=0 or s.ball_is_shot: return false
 if s.last_touch/5!=index/5 or s.pass_receiver!=index: return false
 var distance:float=s.players[index].pos.distance_to(s.ball)
 return distance<maxf(3.0,s.velocity.length()*0.45)

func command(s,team:int,c:Dictionary)->bool:
 var t:Dictionary=s.teams[team];var index:int=t.selected
 t.contain=bool(c.get("contain",false))
 t.receive_assist=clampi(int(c.get("receive_assist",t.receive_assist)),-1,2)
 t.shot_assist=clampi(int(c.get("shot_assist",t.shot_assist)),-1,2)
 t.auto_switch=clampi(int(c.get("auto_switch",t.auto_switch)),0,2)
 var action:int=int(c.get("action",0))
 if action&(128|CANCEL):
  buffered[team]={};releases[team]={};s.players[index].release_wait=0;t.pass_charging=false
  if action&CANCEL: t.charging=false;t.charge=0;t.receive_cancelled=true;return true
 if action&SUBSTITUTE:
  var reserve:int=clampi(int(c.get("reserve",0)),0,maxi(0,benches[team].size()-1))
  var outgoing:int=team*5+clampi(int(c.get("out",index%5)),0,4)
  t.sub_pending=outgoing;requests[team]={"out":outgoing,"reserve":reserve}
  s.notify("pass","换人已申请 · 下一次死球执行")
 if action&SET_PIECE and s.phase=="restart" and s.restart_team==team:
  set_piece(s,team,c.get("direction",Vector2.ZERO));return true
 if s.phase not in ["play","restart"]: return false
 if s.phase=="restart" and not s.Rules.Flow.ready(s): return true
 if s.freeze>0: return true
 if s.phase=="restart" and s.restart_kind in ["kick_in","goal_kick","indirect"] and action&2:
  t.charging=false;t.charge=0;return true
 if action&SWITCH and s.phase=="play":
  var next:=candidate(s,team,c.get("direction",Vector2.ZERO))
  if next>=0: t.selected=next;t.receive_cancelled=true;buffered[team]={};releases[team]={};t.charging=false
 if action&(RUN|SUPPORT): request_run(s,team,action&SUPPORT!=0)
 if action&SKILL: skill(s,index,c.get("direction",Vector2.ZERO),bool(c.get("sprint",false)))
 if action&(16|SWITCH): buffered[team]={}
 if action&SHOT_BUFFER and can_buffer(s,index):
  buffered[team]={"index":index,"until":clock+0.40,"command":c.duplicate(true),"shot":true};return true
 var passing:int=action&(4|8|256)
 if passing and s.owner!=index:
  if s.owner<0 and s.ball_height>0.8:
   jump(s,index,"pass" if passing==4 else "clear",float(c.get("aim",0)),c.get("move",Vector2.ZERO));return true
  if can_buffer(s,index): buffered[team]={"index":index,"until":clock+0.40,"command":c.duplicate(true),"shot":false}
  return true
 if (passing or action&2) and s.owner==index and not c.get("immediate",false):
  if not releases[team].is_empty(): return true
  if s.phase=="restart" and s.freeze>0: return true
  var delay:float=(0.035+0.025*t.charge) if not passing else 0.07
  var intent:Dictionary=c.duplicate(true)
  if action&2: intent.shot_charge=t.charge;t.charging=false
  releases[team]={"index":index,"at":clock+delay,"command":intent}
  s.players[index].release_wait=delay
  s.players[index].action="windup";s.players[index].action_time=delay+0.08
  s.players[index].action_strength=clampf(float(c.get("power",0.35)),0,1) if passing else t.charge
  return true
 return false

func release(s,team:int,c:Dictionary)->void:
 var old:int=s.view_team;s.view_team=team
 var action:int=c.action
 if action&2:
  s.charge=float(c.get("shot_charge",s.charge))
  s.shoot(float(c.get("aim",0)),bool(c.get("finesse",false)),bool(c.get("chip",false)))
 else:
  var index:int=s.selected
  var low_cross:bool=action&256!=0 and c.get("driven",false)
  s.pass_ball(action&8!=0,c.get("move",Vector2.ZERO),(action&256!=0 and not low_cross) or (action&8!=0 and c.get("chip",false)),action&4!=0 and c.get("chip",false),clampf(float(c.get("power",0.35)),0,1),bool(c.get("driven",false)))
  if s.owner<0 and index%5==0: last_keeper_pass[team]=true
 s.view_team=old

func tick(s,dt:float)->void:
 clock+=dt
 for team in 2:
  if not buffered[team].is_empty():
   var b:Dictionary=buffered[team]
   if clock>b.until or s.teams[team].selected!=b.index or (s.owner>=0 and s.owner/5!=team) or s.phase!="play": buffered[team]={}
   elif s.owner==b.index:
    var c:Dictionary=b.command.duplicate(true);c.action=2 if b.shot else c.action
    if b.shot: s.teams[team].charge=clampf(float(c.get("power",0.3)),0.1,0.65)
    buffered[team]={};command(s,team,c)
  if not releases[team].is_empty():
   var r:Dictionary=releases[team]
   if s.owner!=r.index or s.teams[team].selected!=r.index or s.phase not in ["play","restart"]: releases[team]={}
   elif clock>=r.at:
    releases[team]={};s.players[r.index].release_wait=0;release(s,team,r.command)
  if s.phase=="restart" and not requests[team].is_empty(): substitute(s,team)
  for reserve in benches[team]: reserve.fatigue=maxf(0,reserve.fatigue-dt*0.004)
  s.teams[team].request_time=maxf(0,s.teams[team].request_time-dt)
  if s.teams[team].request_time<=0 or (s.owner>=0 and s.owner/5!=team): s.teams[team].request_player=-1
  var t:Dictionary=s.teams[team]
  if t.human and int(t.auto_switch)==2 and s.phase=="play" and s.owner<0 and s.pass_receiver<0 and not t.receive_cancelled and t.move.length()<0.15 and clock>float(t.get("auto_switch_at",0)):
   var next:=candidate(s,team)
   if next>=0 and s.players[next].pos.distance_to(s.ball)<3.5 and s.players[next].pos.distance_to(s.ball)+1<s.players[t.selected].pos.distance_to(s.ball):
    t.selected=next;t.auto_switch_at=clock+0.7;buffered[team]={}
  if s.phase=="play" and not s.teams[team].human:
   for i in range(team*5+1,team*5+5):
    if s.players[i].fatigue>0.45 and requests[team].is_empty():
     for j in benches[team].size():
      if s.Library.find(benches[team][j].id).role!="GK" and benches[team][j].fatigue<s.players[i].fatigue-0.2:
       requests[team]={"out":i,"reserve":j};break
 for i in s.players.size():
  var p:Dictionary=s.players[i]
  if not p.active:
   if s.phase=="play": p.sinbin=maxf(0,p.sinbin-dt)
   p.pos=Vector2(-(Pitch.HALF_LENGTH+6)*s.side(i/5),Pitch.HALF_WIDTH+6+i%5)
   if p.sinbin<=0 and s.phase=="restart" and not benches[i/5].is_empty():
    for b in benches[i/5].size():
     if (s.Library.find(benches[i/5][b].id).role=="GK")==(i%5==0): requests[i/5]={"out":i,"reserve":b};substitute(s,i/5);break
   continue
  p.release_wait=maxf(0,p.release_wait-dt);p.landing=maxf(0,p.landing-dt);p.balance=maxf(0,p.balance-dt)
  if s.phase!="play": continue
  if p.vel.length()>p.speed*0.9: p.fatigue=minf(0.65,p.fatigue+dt*(0.0045-0.002*p.attributes.stamina/99.0))
  else: p.fatigue=maxf(0,p.fatigue-dt*0.0004)
  if p.jump_z>0 or p.jump_v>0:
   p.jump_v-=dt*13;p.jump_z=maxf(0,p.jump_z+p.jump_v*dt)
   if p.jump_z<=0: p.jump_v=0;p.jump_kind="";p.landing=0.12;p.action="land";p.action_time=0.20
   elif not p.jump_kind.is_empty() and s.owner<0 and s.pickup_lock<=0 and p.pos.distance_to(s.ball)<1.9 and absf(s.ball_height-(p.body.head_height+p.jump_z))<0.55:
    aerial_contact(s,i,p.jump_kind,p.jump_aim,p.jump_direction);p.jump_kind=""
 rules_tick(s,dt)

func after_receive(s,index:int,incoming:float,incoming_direction:Vector2)->void:
 var p:Dictionary=s.players[index];var team:int=index/5
 if p.keeper_holding or index%5==0: return
 var move:Vector2=s.teams[team].move if s.is_controlled(index) else p.dir
 var pressure:float=clampf(1-s.closest_opponent(index)/3.0,0,1)
 var awkward:float=clampf(1-p.dir.dot(-incoming_direction),0,2)*0.5
 var error:float=(1-p.attributes.firstTouch/99.0)*incoming*0.065+pressure*0.22+awkward*incoming*0.008
 if move.length()>0.15:
  var touch_direction:Vector2=p.dir.rotated(clampf(p.dir.angle_to(move),-0.75,0.75))
  s.ball=p.pos+touch_direction*(0.7+error)
 p.touch_ready=clock+p.ratings.control
 if incoming>18 and error>0.62 and buffered[team].is_empty():
  s.owner=-1;s.velocity=(move.normalized() if move.length()>0.15 else incoming_direction)*(2.5+error*2)
  s.ball=p.pos+s.velocity.normalized()*1.1;s.pickup_lock=0.09;p.cooldown=0.10
  s.pass_receiver=index;s.pass_destination=s.ball+s.velocity*0.4;s.notify("pass","停球稍大 · 争取下一脚")

func request_run(s,team:int,support:bool)->void:
 if s.owner<0 or s.owner/5!=team: return
 var best:=-1;var value:float=INF
 var facing:Vector2=s.teams[team].move.normalized()
 if facing.length()<0.1: facing=s.players[s.owner].dir
 for i in range(team*5+1,team*5+5):
  if i==s.owner or not s.players[i].active: continue
  var offset:Vector2=s.players[i].pos-s.players[s.owner].pos
  var cost:float=absf(facing.angle_to(offset))*12+offset.length()*0.2
  if cost<value: value=cost;best=i
 if best<0: return
 var origin:Vector2=s.players[s.owner].pos
 s.teams[team].request_player=best;s.teams[team].request_time=2.2
 s.teams[team]["request_support"]=support
 s.teams[team]["request_target"]=(origin+Vector2(-1*s.side(team),-5 if origin.y>0 else 5)) if support else (s.players[best].pos+Vector2(9*s.side(team),-s.players[best].pos.y*0.25))
 s.notify("pass",s.players[best].name+(" 靠近接应" if support else " 向前跑位"))

func plan(s)->void:
 for team in 2:
  var t:Dictionary=s.teams[team]
  var req:int=t.request_player
  if req>=0 and t.request_time>0 and s.players[req].active and req!=t.selected:
   s.brain.targets[req]=s.brain.bounded(t.request_target);s.brain.jobs[req]="support" if t.get("request_support",false) else "run"
  t.contain_player=-1
  if not t.contain or s.owner<0 or s.owner/5==team: continue
  var best:=-1;var distance:float=INF
  for i in range(team*5+1,team*5+5):
   if i==t.selected or not s.players[i].active or s.players[i].stamina<15: continue
   var d:float=s.players[i].pos.distance_to(s.ball)
   if d<distance: distance=d;best=i
  if best>=0:
   var old:int=s.brain.pressers[team]
   if old>=0 and old!=best and old!=t.selected:
    s.brain.jobs[old]="cover"
    s.brain.targets[old]=s.brain.bounded(s.ball+Vector2(-6*s.side(team),-4 if s.ball.y>0 else 4))
   t.contain_player=best;s.brain.pressers[team]=best;s.brain.jobs[best]="press"
   s.brain.targets[best]=s.ball+(Vector2(-Pitch.HALF_LENGTH*s.side(team),0)-s.ball).normalized()*1.6

func jump(s,index:int,kind:String,aim:float,direction:Vector2)->void:
 var p:Dictionary=s.players[index]
 if s.owner>=0 or p.jump_z>0 or p.landing>0 or p.cooldown>0 or not p.active: return
 if p.pos.distance_to(s.ball)>4.5 or s.ball_height<0.8: return
 if s.ball_height<p.body.chest_height:
  aerial_contact(s,index,kind,aim,direction);return
 p.jump_v=3.0+p.attributes.jumping/99.0*1.7
 p.jump_z=0.01;p.jump_kind=kind;p.jump_aim=aim;p.jump_direction=direction;p.stamina=maxf(0,p.stamina-5)
 p.action="jump";p.action_time=0.75

func aerial_contact(s,index:int,kind:String,aim:float,direction:Vector2)->void:
 if s.owner>=0 or s.pickup_lock>0: return
 var p:Dictionary=s.players[index]
 if p.pos.distance_to(s.ball)>1.9: return
 var height:float=s.ball_height
 var target:=Vector2((Pitch.HALF_LENGTH+1)*s.side(index/5),aim*4)
 var power:float=16+p.attributes.heading*0.12
 if kind=="pass": target=s.pass_plan(index,direction,false,int(s.teams[index/5].assist)).destination
 elif kind=="clear": target=p.pos+(direction.normalized() if direction.length()>0.15 else Vector2(s.side(index/5),0))*24
 if not s.kick(index,target,power,kind=="shot"): return
 s.ball_height=height;s.vertical_speed=-1.3 if kind!="clear" else 4.5
 if kind=="clear": s.velocity=(target-p.pos).normalized()*24
 p.action="header" if height>p.body.chest_height else "volley";p.action_time=0.55
 p.contact_height=height-p.jump_z

func skill(s,index:int,direction:Vector2,sprinting:bool)->void:
 var p:Dictionary=s.players[index]
 if s.owner!=index or p.cooldown>0 or direction.length()<0.3: return
 var dir:=direction.normalized()
 if sprinting:
  s.owner=-1;s.ball=p.pos+dir*1.15;s.velocity=dir*(9+p.attributes.pace/99.0*3)
  s.pass_receiver=index;s.pass_destination=p.pos+dir*5;s.last_touch=index;s.ball_is_shot=false;s.kick_age=0;s.pickup_lock=0.18
  s.notify("pass","趟球突破")
 else:
  p.dir=p.dir.rotated(clampf(p.dir.angle_to(dir),-1.3,1.3));s.ball=p.pos+dir*(0.7+p.ratings.stride*0.15)
  p.vel=dir*p.speed*0.45;s.notify("pass","拉球变向")
 p.action="feint";p.action_time=0.35;p.cooldown=0.30;p.stamina=maxf(0,p.stamina-3)

func contact(s,i:int,j:int)->void:
 if i/5==j/5 or s.owner not in [i,j]: return
 var defender:int=j if s.owner==i else i
 var carrier:int=s.owner
 var d:Dictionary=s.players[defender];var p:Dictionary=s.players[carrier]
 if not s.teams[defender/5].jockey or d.balance>0 or p.balance>0: return
 var side_contact:float=absf(p.dir.dot((d.pos-p.pos).normalized()))
 if side_contact>0.65: return
 var strength:float=d.ratings.shield-p.ratings.shield+(0.1 if d.vel.length()>p.vel.length()+1 else 0)
 if strength>0.12:
  p.balance=0.20;p.vel*=0.65;d.balance=0.4;p.action="stumble";p.action_time=0.25
  if not s.shielding(carrier) and s.ball.distance_to(d.pos)<d.body.foot_reach:
   s.owner=-1;s.velocity=p.dir*3;s.pickup_lock=0.10;s.pass_receiver=-1;s.notify("tackle","身体卡位 · 足球脱离控制")

func substitute(s,team:int)->void:
 if requests[team].is_empty(): return
 var request:Dictionary=requests[team];requests[team]={};s.teams[team].sub_pending=-1
 var index:int=request.out;var slot:int=request.reserve
 if slot<0 or slot>=benches[team].size(): return
 var reserve:Dictionary=benches[team][slot];var record:Dictionary=s.Library.find(reserve.id)
 var p:Dictionary=s.players[index]
 if (record.role=="GK")!=(index%5==0) or reserve.id in sent_off: return
 if not p.active and p.sinbin>0: s.notify("foul","红牌减员期间暂不能补员");return
 var was_active:bool=p.active;var previous:Dictionary={"id":p.player_id,"fatigue":p.fatigue,"yellow":p.yellow}
 var revision:int=p.sub_revision+1
 initialize_player(p)
 p.player_id=record.id;p.name=record.name;p.attributes=record.attributes.duplicate(true);p.role=record.role;p.preferred_foot=record.get("preferredFoot","right")
 p.ratings=s.Ratings.derive(record.attributes,float(record.heightCm));p.speed=p.ratings.speed;p.style=s.Style.derive(record);p.body=s.Body.from_record(record,index%5)
 p.stamina=100;p.fatigue=reserve.fatigue;p.yellow=reserve.yellow;p.sub_revision=revision
 p.action="idle";p.action_time=0;p.cooldown=0.2;p.keeper_holding=false;p.vel=Vector2.ZERO
 p.tackle_cd=0;p.keeper_cd=0;p.keeper_side=0;p.keeper_height=0;p.touch=0
 if not was_active:
  # A dismissed slot was hidden off-pitch; its replacement enters at the touchline.
  p.pos=Vector2(-20*s.side(team),Pitch.HALF_WIDTH+1.8);benches[team].remove_at(slot)
  if not s.restart_flow.is_empty():
   var target:=Vector2(-28*s.side(team),0) if index%5==0 else Vector2(-20*s.side(team),-8+(index%5)*4)
   if team!=s.restart_team: target=s.Rules.outside_radius(target,s.restart_spot)
   s.restart_flow.targets[index]=target
   if s.Rules.Flow.ready(s): s.owner=-1;s.phase_time=0;s.Rules.Flow.change_stage(s,"organize")
 else: benches[team][slot]=previous
 s.brain.reset();s.notify("pass","换人 · "+p.name+" 登场")

func set_piece(s,team:int,direction:Vector2)->void:
 if direction.x< -0.2:
  var current:int=s.restart_taker
  for n in range(1,5):
   var next:int=team*5+1+(current%5-1+n)%4
   if not s.players[next].active: continue
   s.Rules.Flow.change_taker(s,next);break
 else:
  s.teams[team].corner_plan=(s.teams[team].corner_plan+1)%3
  restart_movement(s,0)
  s.notify("restart",["定位球 · 短接应","定位球 · 近点跑动","定位球 · 后点跑动"][s.teams[team].corner_plan])

func restart_movement(s,dt:float)->void:
 var team:int=s.restart_team;var plan:int=s.teams[team].corner_plan
 if s.restart_kind in ["penalty","accumulated"]: return
 var n:=0
 for i in range(team*5+1,team*5+5):
  if i==s.restart_taker or not s.players[i].active: continue
  var target:Vector2=s.restart_spot+Vector2(-5*s.side(team),(-1 if s.restart_spot.y>0 else 1)*(4+n*3))
  if plan>0: target=Vector2((25-n*3)*s.side(team),(1 if s.restart_spot.y>0 else -1)*(3 if plan==1 else -4)+n*2)
  if not s.restart_flow.is_empty(): s.restart_flow.targets[i]=target.clamp(-Pitch.AI_LIMIT,Pitch.AI_LIMIT)
  n+=1

func rules_tick(s,dt:float)->void:
 if not advantage.is_empty() and s.phase=="play":
  if s.owner>=0 and s.owner/5!=advantage.team:
   var f:Dictionary=advantage.duplicate();advantage={};s.Rules.foul(s,f.offender,f.victim,f.sliding,true,f.spot)
  elif clock>advantage.until: advantage={}
 if not strict_rules or s.arcade or s.phase!="play": return
 if s.owner>=0 and s.owner%5==0 and s.players[s.owner].pos.x*s.side(s.owner/5)<0:
  var team:int=s.owner/5
  keeper_clock[team]+=dt
  if keeper_clock[team]>4:
   keeper_clock[team]=0;s.Rules.restart(s,1-team,"indirect",s.ball);s.notify("foul","门将控球超过 4 秒")
 else: keeper_clock=[0.0,0.0]

func discipline(s,offender:int,sliding:bool,straight_red:bool=false)->void:
 var p:Dictionary=s.players[offender]
 if not sliding: return
 p.yellow+=1
 if p.yellow<2 and not straight_red: return
 p.active=false;p.sinbin=120;sent_off[p.player_id]=true;p.pos=Vector2(-(Pitch.HALF_LENGTH+6)*s.side(offender/5),Pitch.HALF_WIDTH+6);p.vel=Vector2.ZERO
 if offender%5==0:
  # Reserve keeper enters for an outfielder; the removed outfield slot carries the reduction.
  for i in range(offender+1,offender+5):
   if not s.players[i].active: continue
   for b in benches[offender/5].size():
    if s.Library.find(benches[offender/5][b].id).role!="GK": continue
    benches[offender/5].append({"id":s.players[i].player_id,"fatigue":s.players[i].fatigue,"yellow":s.players[i].yellow})
    s.players[i].active=false;s.players[i].sinbin=120;s.players[i].vel=Vector2.ZERO
    s.players[i].pos=Vector2(-(Pitch.HALF_LENGTH+6)*s.side(offender/5),Pitch.HALF_WIDTH+6+i%5)
    p.sinbin=0;requests[offender/5]={"out":offender,"reserve":b};substitute(s,offender/5)
    break
   break
 if not s.players[s.teams[offender/5].selected].active:
  var next:=candidate(s,offender/5)
  if next>=0: s.teams[offender/5].selected=next
 var remaining:=0
 for i in range(offender/5*5,offender/5*5+5):
  if s.players[i].active: remaining+=1
 if remaining<3: s.finished=true;s.notify("end","人数不足 · 比赛终止")

func wire(s)->PackedByteArray:
 var rows:Array=[]
 for p in s.players:
  rows.append([s.Library.indices[p.player_id],p.active,p.fatigue,p.yellow,p.sinbin,p.jump_z,p.jump_v,p.landing,p.balance,p.release_wait,p.sub_revision,p.slide_speed])
 var trows:Array=[]
 for t in s.teams: trows.append([t.contain,t.contain_player,t.receive_assist,t.shot_assist,t.auto_switch,t.request_player,t.request_time,t.sub_pending,t.corner_plan])
 return var_to_bytes([rows,trows,benches,strict_rules]).compress(FileAccess.COMPRESSION_DEFLATE)

func read_wire(s,bytes:PackedByteArray,state_value:Dictionary)->void:
 s.Library.load_catalog()
 var data=bytes_to_var(bytes.decompress_dynamic(65536,FileAccess.COMPRESSION_DEFLATE))
 if not data is Array or data.size()!=4: return
 for i in 10:
  var row:Array=data[0][i];var p:Dictionary=state_value.players[i]
  var record:Dictionary=s.Library.records[int(row[0])]
  if p.player_id!=record.id:
   p.player_id=record.id;p.name=record.name;p.attributes=record.attributes.duplicate(true);p.ratings=s.Ratings.derive(record.attributes,float(record.heightCm));p.speed=p.ratings.speed;p.body=s.Body.from_record(record,i%5);p.style=s.Style.derive(record);p.role=record.role;p.preferred_foot=record.get("preferredFoot","right")
  var keys=["active","fatigue","yellow","sinbin","jump_z","jump_v","landing","balance","release_wait","sub_revision","slide_speed"]
  for j in keys.size(): p[keys[j]]=row[j+1]
 for i in 2:
  var keys=["contain","contain_player","receive_assist","shot_assist","auto_switch","request_player","request_time","sub_pending","corner_plan"]
  for j in keys.size(): state_value.teams[i][keys[j]]=data[1][i][j]
 state_value.mechanics.benches=data[2];state_value.mechanics.strict_rules=data[3]
