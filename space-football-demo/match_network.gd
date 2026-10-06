extends Node
const Team=preload("res://team_config.gd")
const Pitch=preload("res://pitch_geometry.gd")
## One authoritative match, either player-hosted or a GPU-free dedicated server.
signal status_changed(value:String)
signal match_started
signal match_ended
signal session_lost(value:String)
const Match=preload("res://match_sim.gd")
const Campaign=preload("res://campaign.gd")
const Squad=preload("res://squad.gd")
const Codec=preload("res://snapshot_codec.gd")
const PROTOCOL:=Codec.VERSION # A snapshot is independent of the receiver state.
const Command=preload("res://network_command.gd")
const Timeline=preload("res://network_timeline.gd")
const Prediction=preload("res://network_prediction.gd")
const Snapshots=preload("res://network_snapshots.gd")
const Link=preload("res://network_link.gd")
const Fragments=preload("res://network_fragments.gd")
var fragments=Fragments.new()
var timelines:Array=[Timeline.new(),Timeline.new()]
var preview=Prediction.new()
var snapshots=Snapshots.new()
var link=Link.new()
var history:Array=[]
var correction:=Vector2.ZERO
var correction_max:=0.0
var corrections:=0
var peer_rtt:=[-1,-1]
var probes:Dictionary={}
var next_probe:=0
var probe_serial:=0
var snapshot_every:=2
var metrics_at:=0
var tick_total_us:=0
var tick_peak_us:=0
var tick_count:=0
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
var input_ack:=[-1,-1]
var action_ack:=[-1,-1]
var input_seq:=0
var action_seq:=0
var pending_inputs:Array[Dictionary]=[]
var prediction_pos:=Vector2.ZERO
var prediction_vel:=Vector2.ZERO
var prediction_dir:=Vector2.RIGHT
var prediction_index:=-1
var prediction_ready:=false
var last_snapshot:=-1
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
var round_id:=0
var waiting_connection:=false
var disconnect_handled:=false
var rules_test=preload("res://network_rules_verification.gd").new()
var mechanics_test=preload("res://network_mechanics_verification.gd").new()
var latency_test=preload("res://network_latency_verification.gd").new()

func _ready()->void:
 snapshot_every=3 if "--snapshots=20" in OS.get_cmdline_user_args() else 2
 snapshots.period=snapshot_every
 multiplayer.peer_connected.connect(_peer_connected)
 multiplayer.peer_disconnected.connect(_peer_disconnected)
 multiplayer.connected_to_server.connect(_connected)
 multiplayer.connection_failed.connect(func(): fail("连接失败，请确认地址、端口与服务器状态"))
 multiplayer.server_disconnected.connect(func(): fail("服务器已断开；本场不计入战役奖励"))

func host(listen_port:int=28765,server_only:bool=false)->Error:
 close()
 if listen_port<1024 or listen_port>65535:
  status_changed.emit("比赛端口须为 1024–65535");return ERR_INVALID_PARAMETER
 port=listen_port
 dedicated=server_only
 var peer:=ENetMultiplayerPeer.new()
 var err:=peer.create_server(port,2 if dedicated else 1,4)
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
 var err:=peer.create_client(address,server_port,4)
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
 prediction_ready=false
 disconnect_handled=false
 waiting_connection=false
 reset_transport()
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
 assign_side.rpc_id(id,team,ice_mode or "--ice-mode" in OS.get_cmdline_user_args(),PROTOCOL)
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
func assign_side(team:int,rebound_mode:bool=false,protocol:int=0)->void:
 if protocol!=PROTOCOL: fail("比赛版本不一致，请双方更新至同一版本");return
 if team<0 or team>1: return
 ice_mode=rebound_mode
 local_team=team
 last_receive=Time.get_ticks_msec()
 status_changed.emit("已加入 · "+("冰球反弹 · " if ice_mode else "经典六人制 · ")+("主队（向右进攻）" if team==0 else "客队（向左进攻）"))

func set_ready()->void:
 if not active or local_team<0 or running or preparing: return
 if multiplayer.is_server():
  rosters[local_team]=local_roster.duplicate() if Squad.valid(local_roster) else Squad.DEFAULT.duplicate()
  ready_flags[local_team]=true
  _try_start()
 else: ready_request.rpc_id(1,local_roster,PROTOCOL)
 status_changed.emit("已准备 · 等待对手准备")

@rpc("any_peer","call_remote","reliable",0)
func ready_request(roster:Array,protocol:int=0)->void:
 if not multiplayer.is_server() or running or preparing: return
 var sender:=multiplayer.get_remote_sender_id()
 if not peers.has(sender): return
 if protocol!=PROTOCOL or not Squad.valid(roster):
  incompatible.rpc_id(sender);return
 rosters[int(peers[sender])]=roster.duplicate()
 ready_flags[int(peers[sender])]=true
 _try_start()

@rpc("authority","call_remote","reliable",0)
func incompatible()->void:
 fail("比赛版本或阵容不一致，需要六人制完整阵容")

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
 if "--latency-test" in OS.get_cmdline_user_args(): latency_test.setup(sim)
 input_ack=[-1,-1]; action_ack=[-1,-1]
 pending_inputs.clear()
 input_seq=0; action_seq=0; last_snapshot=-1
 reset_transport()
 if not dedicated: peer_rtt[0]=0
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
 latency_test.sent.clear()
 rules_test.seen.clear();mechanics_test.seen.clear();mechanics_test.sent.clear()
 round_id=game_id
 sim=Match.new()
 sim.restore(state)
 sim.view_team=local_team
 var resolved:Array=[]
 for i in range(local_team*Team.SIZE,local_team*Team.SIZE+Team.SIZE): resolved.append(sim.players[i].player_id)
 if resolved==local_roster: print("NETWORK_ROSTER_VERIFIED ",resolved)
 else: push_error("Server roster differs from submitted roster")
 running=false;preparing=true
 prepare_started=Time.get_ticks_msec()
 input_seq=0; action_seq=0
 pending_inputs.clear()
 last_snapshot=-1
 prediction_ready=false
 reset_transport()
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

func reset_transport()->void:
 timelines=[Timeline.new(),Timeline.new()];history.clear();link.reset();snapshots.reset()
 fragments.pending.clear()
 preview=Prediction.new();correction=Vector2.ZERO;correction_max=0;corrections=0
 peer_rtt=[-1,-1];probes.clear();next_probe=0;probe_serial=0
 metrics_at=Time.get_ticks_msec()+10000
 tick_total_us=0;tick_peak_us=0;tick_count=0
 var args:=OS.get_cmdline_user_args()
 var settings:={"--delay=":delay_ms,"--jitter=":0,"--loss-every=":loss_every,"--reorder-every=":0,"--burst-every=":0}
 for arg in args:
  for key in settings:
   if arg.begins_with(key): settings[key]=clampi(int(arg.trim_prefix(key)),0,2000)
 link.configure(settings["--delay="],settings["--jitter="],settings["--loss-every="],settings["--reorder-every="],settings["--burst-every="])

func input_state():
 return preview.sim if not multiplayer.is_server() and prediction_ready and snapshot_age<0.3 and sim.phase=="play" else sim

func submit_local(command:Dictionary,dt:float)->void:
 if not running or local_team<0 or sim==null: return
 input_seq+=1
 if int(command.get("action",0))!=0: action_seq+=1
 var bound:Dictionary=Command.bind(input_state(),local_team,command,input_seq,action_seq if int(command.get("action",0))!=0 else 0)
 if multiplayer.is_server():
  timelines[local_team].receive(bound,sim.frame)
  return
 pending_inputs.append({"seq":input_seq,"command":bound,"dt":dt})
 if pending_inputs.size()>180: pending_inputs.pop_front()
 history.append(Command.encode(bound))
 while history.size()>Command.REDUNDANCY: history.pop_front()
 var batch:=PackedFloat32Array()
 for sample in history: batch.append_array(sample)
 send_packet("input",1,[round_id,batch],false)
 if int(bound.action)!=0: send_packet("action",1,[round_id,Command.encode(bound)],true)
 if prediction_ready and snapshot_age<0.3:
  preview.step(bound,dt);sync_prediction()

func send_packet(kind:String,peer:int,payload:Array,reliable:bool)->void:
 link.send(kind,peer,payload,reliable,Time.get_ticks_msec())

func pump_link()->void:
 for item in link.take(Time.get_ticks_msec()):
  if multiplayer.is_server() and not peers.has(item.peer): continue
  var p:Array=item.payload
  match item.kind:
   "input": input_batch.rpc_id(item.peer,p[0],p[1])
   "action": action_backup.rpc_id(item.peer,p[0],p[1])
   "state": state_fragment.rpc_id(item.peer,p[0],p[1],p[2],p[3],p[4],p[5],p[6],p[7])
   "probe": probe_request.rpc_id(item.peer,p[0],p[1])
   "echo": probe_echo.rpc_id(item.peer,p[0],p[1])

@rpc("any_peer","call_remote","unreliable_ordered",1)
func input_batch(game_id:int,batch:PackedFloat32Array)->void:
 if not multiplayer.is_server() or not running or game_id!=round_id: return
 var sender:=multiplayer.get_remote_sender_id()
 if not peers.has(sender) or batch.is_empty() or batch.size()>Command.WIDTH*Command.REDUNDANCY or batch.size()%Command.WIDTH!=0: return
 var team:int=peers[sender]
 for offset in range(0,batch.size(),Command.WIDTH):
  timelines[team].receive(Command.decode(batch.slice(offset,offset+Command.WIDTH)),sim.frame)

@rpc("any_peer","call_remote","reliable",3)
func action_backup(game_id:int,sample:PackedFloat32Array)->void:
 if not multiplayer.is_server() or not running or game_id!=round_id: return
 var sender:=multiplayer.get_remote_sender_id()
 if not peers.has(sender): return
 var c:=Command.decode(sample)
 if not c.is_empty() and int(c.action)>0: timelines[int(peers[sender])].receive(c,sim.frame)

@rpc("authority","call_remote","unreliable",0)
func probe_request(game_id:int,nonce:int)->void:
 if game_id==round_id and running: send_packet("echo",1,[game_id,nonce],false)

@rpc("any_peer","call_remote","unreliable",0)
func probe_echo(game_id:int,nonce:int)->void:
 var sender:=multiplayer.get_remote_sender_id()
 if not multiplayer.is_server() or game_id!=round_id or not peers.has(sender) or not probes.has(sender): return
 var probe:Dictionary=probes[sender]
 if nonce!=int(probe.nonce): return
 peer_rtt[int(peers[sender])]=clampi(Time.get_ticks_msec()-int(probe.at),0,10000)
 probes.erase(sender)

func advance(dt:float)->void:
 if not active: return
 pump_link()
 if running and Time.get_ticks_msec()>=metrics_at:
  print_metrics();metrics_at=Time.get_ticks_msec()+10000
 if preparing:
  if Time.get_ticks_msec()-prepare_started>45000:
   if multiplayer.is_server():
    for id in peers:
     if id!=1: loading_timeout.rpc_id(id,round_id)
   fail("对局加载超时，请返回主菜单重新连接")
  return
 if not multiplayer.is_server():
  if not running and not waiting_connection: return
  snapshot_age+=dt;snapshots.advance(dt);correction*=exp(-dt*18)
  if snapshot_age>=0.3: preview.ball_visible=false
  if (running or waiting_connection) and Time.get_ticks_msec()-last_receive>10000: fail("连接超时，请返回房间重新连接")
  return
 if not running: return
 var tick_started:=Time.get_ticks_usec()
 var now:=Time.get_ticks_msec()
 if now>=next_probe:
  next_probe=now+500;probe_serial+=1
  for id in peers:
   if id!=1:
    probes[id]={"nonce":probe_serial,"at":now}
    send_packet("probe",id,[round_id,probe_serial],false)
 for team in 2:
  var timeline=timelines[team]
  var cmd:Dictionary=timeline.tick(sim.frame)
  if cmd.has("player") and not Command.matches(sim,team,cmd): cmd=Command.neutral()
  sim.apply_command(team,cmd)
  for action in timeline.ready_actions(): timeline.apply_action(sim,team,action)
  input_ack[team]=timeline.cursor;action_ack[team]=timeline.action_ack
 if "--rules-test" in OS.get_cmdline_user_args(): rules_test.step(self)
 if "--mechanics-test" in OS.get_cmdline_user_args(): mechanics_test.step(self)
 sim.step(dt)
 if "--latency-test" in OS.get_cmdline_user_args() and sim.frame>=240: sim.finished=true
 if "--rules-test" in OS.get_cmdline_user_args(): rules_test.observe(sim)
 if "--mechanics-test" in OS.get_cmdline_user_args(): mechanics_test.observe(sim)
 if sim.frame%snapshot_every==0 and not sim.finished:
  var wire:=pack_state(sim.snapshot())
  var parts:=Fragments.split(wire.compressed)
  for id in peers:
   if id!=1:
    var team:int=peers[id]
    for part in parts.size():
     send_packet("state",id,[parts[part],sim.frame,part,parts.size(),int(input_ack[team]),round_id,int(action_ack[team]),peer_rtt.duplicate()],false)
 var tick_us:=Time.get_ticks_usec()-tick_started
 tick_total_us+=tick_us;tick_peak_us=maxi(tick_peak_us,tick_us);tick_count+=1
 if sim.finished:
  if "--latency-test" in OS.get_cmdline_user_args(): latency_test.verify(sim)
  if "--rules-test" in OS.get_cmdline_user_args(): rules_test.verify()
  if "--mechanics-test" in OS.get_cmdline_user_args(): mechanics_test.verify()
  running=false
  # Reliable lifecycle messages are outside the application fault model.
  for id in peers:
   if id!=1: final_state.rpc_id(id,sim.snapshot(),round_id)
  print_metrics()
  match_ended.emit()
  print("NETWORK_FINAL score=",sim.score," frame=",sim.frame)

@rpc("authority","call_remote","unreliable",2)
func state_fragment(bytes:PackedByteArray,frame:int,index:int,count:int,ack:int,game_id:int,ack_action:int,rtts:Array)->void:
 if sim==null or game_id!=round_id or not running: return
 if frame<=last_snapshot: return
 var complete:PackedByteArray=fragments.accept(frame,index,count,bytes,Time.get_ticks_msec())
 if complete.is_empty(): return
 var state:=unpack_state({"compressed":complete})
 if state.is_empty() or int(state.frame)<=last_snapshot: return
 if rtts.size()==2:
  peer_rtt=[int(rtts[0]),int(rtts[1])];ping_ms=peer_rtt[maxi(0,local_team)]
 _receive_snapshot(state,ack,ack_action)

func _receive_snapshot(state:Dictionary,ack:int,ack_action:int=0)->void:
 var previous_index:=prediction_index
 var previous_pos:=prediction_pos+correction
 var old_phase:String=sim.phase
 last_snapshot=int(state.frame);last_receive=Time.get_ticks_msec();snapshot_age=0;received_count+=1
 sim.restore(state);sim.view_team=local_team
 if "--rules-test" in OS.get_cmdline_user_args(): rules_test.observe(sim)
 if "--mechanics-test" in OS.get_cmdline_user_args(): mechanics_test.observe(sim)
 snapshots.push(state,last_receive)
 while not pending_inputs.is_empty() and pending_inputs[0].seq<=ack: pending_inputs.pop_front()
 preview.reset(state,local_team)
 for item in pending_inputs:
  var c:Dictionary=item.command.duplicate(true)
  if int(c.action_id)<=ack_action: c.action=0
  preview.step(c,item.dt)
 sync_prediction()
 var error:=previous_pos-prediction_pos
 correction=error if prediction_ready and previous_index==prediction_index and old_phase==sim.phase and error.length()<2.5 else Vector2.ZERO
 if prediction_ready and previous_index==prediction_index and old_phase==sim.phase and error.length()>0.1:
  corrections+=1;correction_max=maxf(correction_max,error.length())
 prediction_ready=true

func sync_prediction()->void:
 prediction_index=preview.index()
 var p:Dictionary=preview.sim.players[prediction_index]
 prediction_pos=p.pos;prediction_vel=p.vel;prediction_dir=p.dir

func render_player(index:int)->Dictionary:
 if prediction_ready and snapshot_age<0.3 and sim.phase=="play" and index==prediction_index:
  var p:Dictionary=preview.sim.players[index].duplicate()
  p.pos+=correction
  return p
 return snapshots.player(index,sim.players[index])

func render_ball()->Vector3:
 if prediction_ready and snapshot_age<0.3 and sim.phase=="play" and preview.ball_visible: return preview.ball()
 return snapshots.ball(Vector3(sim.ball.x,sim.ball_height,sim.ball.y))

func diagnostics()->String:
 var home:=str(peer_rtt[0]) if peer_rtt[0]>=0 else "--"
 var away:=str(peer_rtt[1]) if peer_rtt[1]>=0 else "--"
 return "主队 %s / 客队 %s ms · 抖动 %d ms%s" % [home,away,int(snapshots.jitter_ms)," · 等待同步" if snapshot_age>=0.3 else ""]

func print_metrics()->void:
 var result:={"protocol":PROTOCOL,"round":round_id,"team":local_team,"rtt_ms":peer_rtt,"jitter_ms":snappedf(snapshots.jitter_ms,0.1),"snapshot_gaps":snapshots.gaps,"corrections":corrections,"max_correction":snappedf(correction_max,0.01),"pending":pending_inputs.size(),"sent":link.sent,"dropped":link.dropped,"retried":link.retried}
 result["fault_profile"]=[link.delay_ms,link.jitter_ms,link.loss_every,link.reorder_every,link.burst_every]
 result["packet_kinds"]=link.kinds;result["payload_bytes"]=link.payload_bytes
 result["simulation_hz"]=Engine.physics_ticks_per_second
 if tick_count>0:
  result["tick_mean_ms"]=snappedf(tick_total_us/float(tick_count)/1000,0.01)
  result["tick_peak_ms"]=snappedf(tick_peak_us/1000.0,0.01)
 if multiplayer.is_server(): result["rejected_actions"]=[timelines[0].rejected,timelines[1].rejected]
 print("NETWORK_METRICS ",JSON.stringify(result))

@rpc("authority","call_remote","reliable",0)
func final_state(state:Dictionary,game_id:int)->void:
 if sim==null or game_id!=round_id: return
 _receive_snapshot(state,input_seq)
 if "--latency-test" in OS.get_cmdline_user_args(): latency_test.verify(sim)
 if "--rules-test" in OS.get_cmdline_user_args(): rules_test.verify()
 if "--mechanics-test" in OS.get_cmdline_user_args(): mechanics_test.verify()
 running=false
 print_metrics()
 match_ended.emit()
 print("NETWORK_FINAL score=",sim.score," frame=",sim.frame)

@rpc("authority","call_remote","reliable",0)
func remote_abandon()->void:
 running=false
 preparing=false
 session_lost.emit("对手已离开，本场结束；战役进度不受影响")



func pack_state(state:Dictionary)->Dictionary:
 return Codec.encode(state)

func unpack_state(wire:Dictionary)->Dictionary:
 return Codec.decode(wire)

func extra_command(c:Dictionary)->Dictionary:
 var direction:Vector2=c.get("direction",Vector2.ZERO)
 if not direction.is_finite(): direction=Vector2.ZERO
 var power:float=float(c.get("power",0.35))
 if not is_finite(power): power=0.35
 return {"direction":direction.limit_length(),"power":clampf(power,0,1),"skip_restart":bool(c.get("skip_restart",false)),"skill_sprint":bool(c.get("skill_sprint",c.get("sprint",false))),"driven":bool(c.get("driven",false)),"contain":bool(c.get("contain",false)),"receive_assist":clampi(int(c.get("receive_assist",-1)),-1,2),"shot_assist":clampi(int(c.get("shot_assist",-1)),-1,2),"auto_switch":clampi(int(c.get("auto_switch",1)),0,2),"reserve":clampi(int(c.get("reserve",0)),0,3),"out":clampi(int(c.get("out",1)),0,Team.SIZE-1)}
