extends Node
const Pitch=preload("res://pitch_geometry.gd")
## One authoritative match, either player-hosted or a GPU-free dedicated server.
signal status_changed(value:String)
signal match_started
signal match_ended
signal session_lost(value:String)
const Match=preload("res://match_sim.gd")
const Campaign=preload("res://campaign.gd")
const Squad=preload("res://squad.gd")
var local_roster:Array=Squad.DEFAULT.duplicate()
var rosters:Array=[Squad.DEFAULT.duplicate(),Squad.DEFAULT.duplicate()]
var sim
var active:=false
var running:=false
var preparing:=false
var scene_flags:=[false,false]
var prepare_started:=0
var dedicated:=false
var local_team:=0
var peers:Dictionary={}
var ready_flags:=[false,false]
var commands:=[{},{}]
var input_ack:=[-1,-1]
var action_ack:=[-1,-1]
var input_seq:=0
var action_seq:=0
var pending_inputs:Array[Dictionary]=[]
var action_queue:Array[Dictionary]=[]
var prediction_pos:=Vector2.ZERO
var prediction_vel:=Vector2.ZERO
var prediction_dir:=Vector2.RIGHT
var prediction_index:=-1
var prediction_ready:=false
var last_snapshot:=-1
var remote_positions:Array[Vector2]=[]
var remote_velocities:Array[Vector2]=[]
var remote_ball:=Vector3.ZERO
var remote_ball_velocity:=Vector3.ZERO
var snapshot_age:=0.0
var ping_ms:=0
var last_receive:=0
var start_time:=0
var received_count:=0
var test_duration:=0.0
var online_duration:=180.0
var strict_rules:=false
var ice_mode:=false
var port:=28765
var delay_ms:=0
var loss_every:=0
var delayed:Array[Dictionary]=[]
var sent_count:=0
var round_id:=0
var waiting_connection:=false
var disconnect_handled:=false
var rules_test=preload("res://network_rules_verification.gd").new()
var mechanics_test=preload("res://network_mechanics_verification.gd").new()

func _ready()->void:
 multiplayer.peer_connected.connect(_peer_connected)
 multiplayer.peer_disconnected.connect(_peer_disconnected)
 multiplayer.connected_to_server.connect(_connected)
 multiplayer.connection_failed.connect(func(): fail("连接失败，请确认地址、端口与服务器状态"))
 multiplayer.server_disconnected.connect(func(): fail("服务器已断开；本场不计入战役奖励"))

func host(listen_port:int=28765,server_only:bool=false)->Error:
 close()
 port=listen_port
 dedicated=server_only
 var peer:=ENetMultiplayerPeer.new()
 var err:=peer.create_server(port,2 if dedicated else 1,3)
 if err!=OK: status_changed.emit("创建房间失败："+error_string(err)); return err
 multiplayer.multiplayer_peer=peer
 active=true
 local_team=-1 if dedicated else 0
 peers={1:0} if not dedicated else {}
 ready_flags=[false,false]
 start_time=Time.get_ticks_msec()
 status_changed.emit("服务器在线 · 等待两位玩家" if dedicated else "房间已创建 · 等待对手加入")
 return OK

func join(address:String,server_port:int=28765)->Error:
 close()
 var peer:=ENetMultiplayerPeer.new()
 var err:=peer.create_client(address,server_port,3)
 if err!=OK: status_changed.emit("连接失败："+error_string(err)); return err
 multiplayer.multiplayer_peer=peer
 active=true
 waiting_connection=true
 local_team=-1
 port=server_port
 start_time=Time.get_ticks_msec()
 last_receive=start_time
 status_changed.emit("正在连接 "+address+":"+str(port))
 return OK

func close()->void:
 active=false
 running=false
 preparing=false
 sim=null
 peers.clear()
 pending_inputs.clear()
 action_queue.clear()
 delayed.clear()
 remote_positions.clear()
 prediction_ready=false
 disconnect_handled=false
 waiting_connection=false
 if multiplayer.multiplayer_peer!=null: multiplayer.multiplayer_peer.close()
 multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()

func fail(reason:String)->void:
 if not active or disconnect_handled: return
 if sim!=null and sim.finished:
  active=false
  status_changed.emit("服务器已关闭，可重新创建或加入房间")
  return
 disconnect_handled=true
 active=false
 running=false
 preparing=false
 session_lost.emit(reason)

func _peer_connected(id:int)->void:
 if not active or not multiplayer.is_server(): return
 var team:=0 if dedicated and 0 not in peers.values() else 1
 if team in peers.values(): multiplayer.multiplayer_peer.disconnect_peer(id); return
 peers[id]=team
 assign_side.rpc_id(id,team,ice_mode or "--ice-mode" in OS.get_cmdline_user_args())
 status_changed.emit("对手已连接 · 双方准备后开球")

func _peer_disconnected(id:int)->void:
 if not active or not multiplayer.is_server() or not peers.has(id): return
 var team:int=peers[id]
 peers.erase(id)
 ready_flags[team]=false
 if running or preparing:
  running=false
  preparing=false
  for peer_id in peers:
   if peer_id!=1: remote_abandon.rpc_id(peer_id)
  if not dedicated: session_lost.emit("对手已离开，本场结束；战役进度不受影响")
  else: status_changed.emit("比赛结束：玩家离开，等待新玩家")
 else: status_changed.emit("对手离开房间")

func _connected()->void:
 waiting_connection=false
 status_changed.emit("已连接 · 等待队伍分配")

@rpc("authority","call_remote","reliable",0)
func assign_side(team:int,rebound_mode:bool=false)->void:
 if team<0 or team>1: return
 ice_mode=rebound_mode
 local_team=team
 last_receive=Time.get_ticks_msec()
 status_changed.emit("已加入 · "+("冰球反弹 · " if ice_mode else "经典五人制 · ")+("主队（向右进攻）" if team==0 else "客队（向左进攻）"))

func set_ready()->void:
 if not active or local_team<0 or running or preparing: return
 if multiplayer.is_server():
  rosters[local_team]=local_roster.duplicate() if Squad.valid(local_roster) else Squad.DEFAULT.duplicate()
  ready_flags[local_team]=true
  _try_start()
 else: ready_request.rpc_id(1,local_roster)
 status_changed.emit("已准备 · 等待对手准备")

@rpc("any_peer","call_remote","reliable",0)
func ready_request(roster:Array)->void:
 if not multiplayer.is_server() or running or preparing: return
 var sender:=multiplayer.get_remote_sender_id()
 if not peers.has(sender): return
 if not Squad.valid(roster): return
 rosters[int(peers[sender])]=roster.duplicate()
 ready_flags[int(peers[sender])]=true
 _try_start()

func _try_start()->void:
 if running or preparing or not ready_flags[0] or not ready_flags[1] or peers.size()!=2: return
 round_id+=1
 sim=Match.new()
 var campaign=Campaign.new()
 campaign.difficulty=0
 sim.setup(campaign,8147,rosters[0],rosters[1],true)
 sim.ice_mode=ice_mode or "--ice-mode" in OS.get_cmdline_user_args()
 sim.mechanics.strict_rules=strict_rules or "--strict-rules" in OS.get_cmdline_user_args()
 # Server resolves IDs into trusted local data; campaign bonuses never apply online.
 sim.teams[0].human=true
 sim.teams[1].human=true
 sim.duration=test_duration if test_duration>0 else online_duration
 if test_duration>0: sim.overtime_duration=5.0
 sim.regulation=sim.duration
 sim.view_team=maxi(0,local_team)
 sim.Rules.restart(sim,0,"kickoff",Vector2.ZERO)
 if "--rules-test" in OS.get_cmdline_user_args(): sim.duration=30;rules_test.seen.clear()
 if "--mechanics-test" in OS.get_cmdline_user_args(): sim.duration=30;mechanics_test.seen.clear();mechanics_test.sent.clear()
 commands=[{},{}]; input_ack=[-1,-1]; action_ack=[-1,-1]
 action_queue.clear(); pending_inputs.clear()
 input_seq=0; action_seq=0; last_snapshot=-1
 running=false;preparing=true;scene_flags=[false,false]
 prepare_started=Time.get_ticks_msec()
 ready_flags=[false,false]
 var state:Dictionary=sim.snapshot()
 for id in peers:
  if id!=1: begin_game.rpc_id(id,state,round_id)
 match_started.emit()
 print("NETWORK_MATCH_STARTED peers=",peers," duration=",sim.duration)

@rpc("authority","call_remote","reliable",0)
func begin_game(state:Dictionary,game_id:int)->void:
 rules_test.seen.clear();mechanics_test.seen.clear();mechanics_test.sent.clear()
 round_id=game_id
 sim=Match.new()
 sim.restore(state)
 sim.view_team=local_team
 var resolved:Array=[]
 for i in range(local_team*5,local_team*5+5): resolved.append(sim.players[i].player_id)
 if resolved==local_roster: print("NETWORK_ROSTER_VERIFIED ",resolved)
 else: push_error("Server roster differs from submitted roster")
 running=false;preparing=true
 prepare_started=Time.get_ticks_msec()
 input_seq=0; action_seq=0
 pending_inputs.clear()
 last_snapshot=-1
 prediction_ready=false
 ready_flags=[false,false]
 _receive_snapshot(state,-1)
 match_started.emit()
 print("NETWORK_CLIENT_STARTED team=",local_team)

func scene_ready()->void:
 if not active or not preparing or local_team<0: return
 if multiplayer.is_server():
  scene_flags[local_team]=true
  _try_release_match()
 else: scene_ready_request.rpc_id(1,round_id)

@rpc("any_peer","call_remote","reliable",0)
func scene_ready_request(game_id:int)->void:
 if not multiplayer.is_server() or not preparing or game_id!=round_id: return
 var sender:=multiplayer.get_remote_sender_id()
 if not peers.has(sender): return
 scene_flags[int(peers[sender])]=true
 _try_release_match()

func _try_release_match()->void:
 if not preparing or not scene_flags[0] or not scene_flags[1]: return
 preparing=false;running=true
 for id in peers:
  if id!=1: release_match.rpc_id(id,round_id)
 print("NETWORK_SCENES_READY frame=",sim.frame," elapsed=",sim.elapsed)

@rpc("authority","call_remote","reliable",0)
func release_match(game_id:int)->void:
 if not preparing or game_id!=round_id: return
 preparing=false;running=true;last_receive=Time.get_ticks_msec()

@rpc("authority","call_remote","reliable",0)
func loading_timeout(game_id:int)->void:
 if game_id==round_id: fail("对局加载超时，请返回主菜单重新连接")

func submit_local(command:Dictionary,dt:float)->void:
 if not running or local_team<0 or sim==null: return
 if multiplayer.is_server():
  commands[local_team]=command.duplicate()
  if int(command.action)!=0: action_queue.append({"team":local_team,"command":command.duplicate()})
 else:
  input_seq+=1
  pending_inputs.append({"seq":input_seq,"command":command.duplicate(),"dt":dt})
  if pending_inputs.size()>180: pending_inputs.pop_front()
  queue_input(input_seq,command)
  if int(command.action)!=0:
   action_seq+=1
   action_request.rpc_id(1,round_id,action_seq,int(command.action),float(command.aim),command.move,int(command.tactic),int(command.get("assist",1)),bool(command.get("finesse",false)),bool(command.get("chip",false)),extra_command(command))
  if prediction_ready and sim.freeze<=0 and not sim.finished: _predict(command,dt)

func queue_input(seq:int,command:Dictionary)->void:
 sent_count+=1
 if loss_every>0 and sent_count%loss_every==0: return
 if delay_ms>0:
  delayed.append({"due":Time.get_ticks_msec()+delay_ms,"seq":seq,"command":command.duplicate()})
 else: input_request.rpc_id(1,round_id,seq,command.move,command.sprint,command.jockey,int(command.get("assist",1)),bool(command.get("assist_active",true)),bool(command.get("keeper_rush",false)),extra_command(command))

@rpc("any_peer","call_remote","unreliable_ordered",1)
func input_request(game_id:int,seq:int,move:Vector2,sprint:bool,jockey:bool,assist:int,assist_active:bool,keeper_rush:bool,extra:Dictionary={})->void:
 if not multiplayer.is_server() or not running or game_id!=round_id: return
 var sender:=multiplayer.get_remote_sender_id()
 if not peers.has(sender) or not move.is_finite(): return
 var team:int=peers[sender]
 if seq<=input_ack[team] or seq>input_ack[team]+600: return
 input_ack[team]=seq
 commands[team]={"move":move.limit_length(),"sprint":sprint,"jockey":jockey,"action":0,"aim":0.0,"tactic":sim.teams[team].tactic,"assist":clampi(assist,0,2),"assist_active":assist_active,"received":Time.get_ticks_msec()}
 commands[team].keeper_rush=keeper_rush
 commands[team].merge(extra_command(extra),true)

@rpc("any_peer","call_remote","reliable",0)
func action_request(game_id:int,seq:int,action:int,aim:float,move:Vector2,tactic:int,assist:int,finesse:bool,chip:bool,extra:Dictionary={})->void:
 if not multiplayer.is_server() or not running or game_id!=round_id: return
 var sender:=multiplayer.get_remote_sender_id()
 if not peers.has(sender) or not is_finite(aim) or not move.is_finite(): return
 var team:int=peers[sender]
 if seq<=action_ack[team] or seq>action_ack[team]+64 or action<0 or action>sim.Mechanics.MAX_ACTION or action_queue.size()>24: return
 action_ack[team]=seq
 action_queue.append({"team":team,"command":{"move":move.limit_length(),"action":action,"aim":clampf(aim,-1,1),"tactic":clampi(tactic,0,2),"assist":clampi(assist,0,2),"finesse":finesse,"chip":chip}})
 action_queue[-1].command.merge(extra_command(extra),true)

func advance(dt:float)->void:
 if not active: return
 if preparing:
  if Time.get_ticks_msec()-prepare_started>45000:
   if multiplayer.is_server():
    for id in peers:
     if id!=1: loading_timeout.rpc_id(id,round_id)
   fail("对局加载超时，请返回主菜单重新连接")
  return
 if not multiplayer.is_server():
  if not running and not waiting_connection: return
  while not delayed.is_empty() and delayed[0].due<=Time.get_ticks_msec():
   var item:Dictionary=delayed.pop_front()
   var c:Dictionary=item.command
   input_request.rpc_id(1,round_id,item.seq,c.move,c.sprint,c.jockey,int(c.get("assist",1)),bool(c.get("assist_active",true)),bool(c.get("keeper_rush",false)),extra_command(c))
  snapshot_age+=dt
  if (running or waiting_connection) and Time.get_ticks_msec()-last_receive>10000: fail("连接超时，请返回房间重新连接")
  return
 if not running: return
 for team in 2:
  var cmd:Dictionary=commands[team].duplicate()
  if cmd.has("received") and Time.get_ticks_msec()-int(cmd.received)>300:
   cmd.move=Vector2.ZERO; cmd.sprint=false; cmd.jockey=false
   cmd.assist_active=false
   cmd.keeper_rush=false;cmd.contain=false;cmd.skip_restart=false
  cmd.action=0
  sim.apply_command(team,cmd)
 for item in action_queue:
  var c:Dictionary=item.command.duplicate()
  c.sprint=sim.teams[item.team].sprint
  if int(c.action)&sim.Mechanics.SKILL: c.sprint=bool(c.get("skill_sprint",c.sprint))
  c.jockey=sim.teams[item.team].jockey
  c.assist_active=sim.teams[item.team].assist_active
  c.keeper_rush=sim.teams[item.team].keeper_rush
  sim.apply_command(item.team,c)
 action_queue.clear()
 if "--rules-test" in OS.get_cmdline_user_args(): rules_test.step(self)
 if "--mechanics-test" in OS.get_cmdline_user_args(): mechanics_test.step(self)
 sim.step(dt)
 if "--rules-test" in OS.get_cmdline_user_args(): rules_test.observe(sim)
 if "--mechanics-test" in OS.get_cmdline_user_args(): mechanics_test.observe(sim)
 if sim.frame%3==0 or sim.finished:
  var state:Dictionary=sim.snapshot()
  for id in peers:
   if id!=1: state_update.rpc_id(id,pack_state(state),int(input_ack[int(peers[id])]),round_id)
 if sim.finished:
  if "--rules-test" in OS.get_cmdline_user_args(): rules_test.verify()
  if "--mechanics-test" in OS.get_cmdline_user_args(): mechanics_test.verify()
  running=false
  for id in peers:
   if id!=1: final_state.rpc_id(id,sim.snapshot(),round_id)
  match_ended.emit()
  print("NETWORK_FINAL score=",sim.score," frame=",sim.frame)

@rpc("authority","call_remote","unreliable_ordered",2)
func state_update(wire:Dictionary,ack:int,game_id:int)->void:
 if sim==null or game_id!=round_id: return
 var state:=unpack_state(wire)
 if int(state.frame)<=last_snapshot: return
 _receive_snapshot(state,ack)

func _receive_snapshot(state:Dictionary,ack:int)->void:
 last_snapshot=int(state.frame)
 last_receive=Time.get_ticks_msec()
 snapshot_age=0
 received_count+=1
 sim.restore(state)
 sim.view_team=local_team
 if "--rules-test" in OS.get_cmdline_user_args(): rules_test.observe(sim)
 if "--mechanics-test" in OS.get_cmdline_user_args(): mechanics_test.observe(sim)
 remote_positions.clear(); remote_velocities.clear()
 for p in sim.players:
  remote_positions.append(p.pos)
  remote_velocities.append(p.vel)
 remote_ball=Vector3(sim.ball.x,sim.ball_height,sim.ball.y)
 remote_ball_velocity=Vector3(sim.velocity.x,sim.vertical_speed,sim.velocity.y)
 prediction_index=sim.selected
 prediction_pos=sim.players[prediction_index].pos
 prediction_vel=sim.players[prediction_index].vel
 prediction_dir=sim.players[prediction_index].dir
 prediction_ready=true
 while not pending_inputs.is_empty() and pending_inputs[0].seq<=ack: pending_inputs.pop_front()
 if sim.freeze<=0 and not sim.finished:
  for item in pending_inputs: _predict(item.command,item.dt)
 if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
  var peer=multiplayer.multiplayer_peer.get_peer(1)
  if peer: ping_ms=int(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))

func _predict(command:Dictionary,dt:float)->void:
 if sim.phase!="play": return
 if prediction_index<0: return
 var p:Dictionary=sim.players[prediction_index]
 var speed:float=p.speed*(1-float(p.get("fatigue",0))*0.14)
 if not p.get("active",true): return
 if p.get("jump_z",0)>0: speed*=0.7
 if p.get("landing",0)>0 or p.get("balance",0)>0: speed*=0.65
 if p.get("release_wait",0)>0: speed*=0.55
 if p.action in sim.Motion.DEFENSIVE_ACTIONS and p.action_time>0:
  prediction_vel=prediction_vel.move_toward(sim.Motion.defensive_velocity(p.action,p.action_time,prediction_dir,speed,p.get("slide_speed",0)),dt*32)
  prediction_pos=(prediction_pos+prediction_vel*dt).clamp(-sim.player_limit(prediction_index),sim.player_limit(prediction_index))
  return
 if command.sprint and p.stamina>2: speed*=1.42
 if command.jockey: speed*=0.58
 if sim.owner==prediction_index: speed*=p.ratings.dribble_speed
 if p.action_time>0 and p.action=="tackle": speed*=0.32
 if p.action_time>0 and p.action=="receive": speed*=0.7
 var move:Vector2=command.move
 var receiving_assist:int=int(command.get("receive_assist",sim.teams[prediction_index/5].receive_assist))
 if receiving_assist<0: receiving_assist=int(command.get("assist",sim.teams[prediction_index/5].assist))
 if p.action_time>0 and p.action=="slide":
  move=p.dir if p.action_time>0.3 else Vector2.ZERO
  speed=p.speed*1.15
 if bool(command.get("assist_active",true)):
  move=sim.assisted_movement(prediction_index,move,prediction_pos,receiving_assist,prediction_vel,int(command.sprint))
 if (prediction_index%5!=0 or sim.owner==prediction_index) and not command.jockey and p.action!="slide":
  speed*=sim.Motion.turn_scale(prediction_dir,move,p.ratings)
 var acceleration:float=p.ratings.acceleration*(p.ratings.carry_acceleration if sim.owner==prediction_index else 1.0)
 prediction_vel=prediction_vel.move_toward(move.limit_length()*speed,dt*(acceleration if move.length()>0.05 else p.ratings.braking))
 prediction_pos=(prediction_pos+prediction_vel*dt).clamp(-sim.player_limit(prediction_index),sim.player_limit(prediction_index))
 var facing:Vector2=(sim.ball-prediction_pos).normalized() if (command.jockey or prediction_index%5==0) and sim.owner!=prediction_index else move.normalized()
 if bool(command.get("assist_active",true)):
  var reception:Vector2=sim.receiving_facing(prediction_index,command.move,prediction_pos,receiving_assist)
  if reception.length()>0.1: facing=reception
 if facing.length()>0.1: prediction_dir=prediction_dir.rotated(clampf(prediction_dir.angle_to(facing),-dt*p.ratings.turn_rate,dt*p.ratings.turn_rate)).normalized()

@rpc("authority","call_remote","reliable",0)
func final_state(state:Dictionary,game_id:int)->void:
 if sim==null or game_id!=round_id: return
 _receive_snapshot(state,input_seq)
 if "--rules-test" in OS.get_cmdline_user_args(): rules_test.verify()
 if "--mechanics-test" in OS.get_cmdline_user_args(): mechanics_test.verify()
 delayed.clear()
 running=false
 match_ended.emit()
 print("NETWORK_FINAL score=",sim.score," frame=",sim.frame)

@rpc("authority","call_remote","reliable",0)
func remote_abandon()->void:
 running=false
 preparing=false
 session_lost.emit("对手已离开，本场结束；战役进度不受影响")



const META_FIELDS=["ice_mode","arcade","elapsed","duration","regulation","freeze","owner","height","vertical","finished","overtime","event","frame","pass_receiver","last_touch","kick_age","ball_is_shot","spin","impact_id","impact_kind","impact_strength","impact_x","impact_y"]
const TEAM_FIELDS=["selected","tactic","charge","charging","dash","dash_cd","sprint","jockey","human","assist","assist_active","receive_cancelled","keeper_rush","run_player","run_time"]
const ACTIONS=["idle","shoot","pass","tackle","save","receive","block","dive","catch","throw","slide","cross","chip","header","volley","feint","fall","appeal","wall","set_piece","set_kick","celebrate","disappointed","windup","power_shot","finesse","dive_low","dive_high","scoop","foot_save","parry","tip","catch_high","shield","smother","rush","jump","land","stumble","slide_still","retrieve_ball","carry_ball","place_ball","driven_pass","block_chest","block_head"]
const EVENTS=["kickoff","pass","shot","tackle","goal","overtime","end","save","block","restart","foul","post"]
const RESTARTS=["kickoff","kick_in","corner","goal_kick","free_kick","indirect","penalty","accumulated"]

func pack_state(state:Dictionary)->Dictionary:
 var data:=PackedFloat32Array()
 for key in META_FIELDS: data.append(float(state[key]))
 for key in ["ball","velocity","pass_destination"]: data.append(state[key].x); data.append(state[key].y)
 for key in ["score","shots","passes","tackles","saves","possession"]:
  data.append(float(state[key][0])); data.append(float(state[key][1]))
 data.append(EVENTS.find(state.kind))
 data.append(RESTARTS.find(state.restart))
 for team in state.teams:
  for key in TEAM_FIELDS: data.append(float(team[key]))
  data.append(team.move.x); data.append(team.move.y)
 for p in state.players:
  for key in ["pos","vel","dir","action_dir"]: data.append(p[key].x); data.append(p[key].y)
  for key in ["cooldown","stamina","action_time","tackle_cd","touch","action_strength","contact_height"]: data.append(float(p[key]))
  if p.slot==0:
   for key in ["keeper_cd","keeper_side","keeper_height","keeper_holding"]: data.append(float(p[key]))
  data.append(ACTIONS.find(p.action))
 var payload:Dictionary={"values":data,"message":state.message,"rules":sim.Rules.pack(state.rules),"extra":sim.mechanics.wire(sim),"net":sim.GoalNet.pack(state.goal_net)}
 return {"compressed":var_to_bytes(payload).compress(FileAccess.COMPRESSION_DEFLATE)}

func unpack_state(wire:Dictionary)->Dictionary:
 if wire.has("compressed"): wire=bytes_to_var(wire.compressed.decompress_dynamic(65536,FileAccess.COMPRESSION_DEFLATE))
 var state:Dictionary=sim.snapshot()
 var data:PackedFloat32Array=wire.values
 var cursor:=0
 for key in META_FIELDS:
  state[key]=data[cursor]
  cursor+=1
 for key in ["owner","frame","event","pass_receiver","last_touch","impact_id","impact_kind"]: state[key]=int(state[key])
 for key in ["finished","overtime","ball_is_shot"]: state[key]=bool(state[key])
 for key in ["ball","velocity","pass_destination"]:
  state[key]=Vector2(data[cursor],data[cursor+1]); cursor+=2
 for key in ["score","shots","passes","tackles","saves","possession"]:
  state[key]=[data[cursor],data[cursor+1]] if key=="possession" else [int(data[cursor]),int(data[cursor+1])]
  cursor+=2
 state.kind=EVENTS[int(data[cursor])]; cursor+=1
 state.restart=RESTARTS[int(data[cursor])]; cursor+=1
 for team in state.teams:
  for key in TEAM_FIELDS:
   team[key]=data[cursor]; cursor+=1
  for key in ["selected","tactic","assist","run_player"]: team[key]=int(team[key])
  for key in ["charging","sprint","jockey","human","assist_active","receive_cancelled","keeper_rush"]: team[key]=bool(team[key])
  team.move=Vector2(data[cursor],data[cursor+1]); cursor+=2
 for p in state.players:
  for key in ["pos","vel","dir","action_dir"]:
   p[key]=Vector2(data[cursor],data[cursor+1]); cursor+=2
  for key in ["cooldown","stamina","action_time","tackle_cd","touch","action_strength","contact_height"]:
   p[key]=data[cursor]; cursor+=1
  if p.slot==0:
   for key in ["keeper_cd","keeper_side","keeper_height","keeper_holding"]: p[key]=data[cursor];cursor+=1
   p.keeper_holding=bool(p.keeper_holding)
  p.action=ACTIONS[int(data[cursor])]; cursor+=1
 state.message=wire.message
 state.goal_net=sim.GoalNet.unpack(wire.get("net",PackedFloat32Array()))
 state.rules=sim.Rules.unpack(wire.rules)
 if wire.has("extra"): sim.mechanics.read_wire(sim,wire.extra,state)
 return state


func extra_command(c:Dictionary)->Dictionary:
 var direction:Vector2=c.get("direction",Vector2.ZERO)
 if not direction.is_finite(): direction=Vector2.ZERO
 var power:float=float(c.get("power",0.35))
 if not is_finite(power): power=0.35
 return {"direction":direction.limit_length(),"power":clampf(power,0,1),"skip_restart":bool(c.get("skip_restart",false)),"skill_sprint":bool(c.get("skill_sprint",c.get("sprint",false))),"driven":bool(c.get("driven",false)),"contain":bool(c.get("contain",false)),"receive_assist":clampi(int(c.get("receive_assist",-1)),-1,2),"shot_assist":clampi(int(c.get("shot_assist",-1)),-1,2),"auto_switch":clampi(int(c.get("auto_switch",1)),0,2),"reserve":clampi(int(c.get("reserve",0)),0,3),"out":clampi(int(c.get("out",1)),0,4)}
