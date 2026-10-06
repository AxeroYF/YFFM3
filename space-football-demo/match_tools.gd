extends RefCounted
const Team=preload("res://team_config.gd")
const Pitch=preload("res://pitch_geometry.gd")
## Local presentation/tools. Replay never restores or advances authoritative state.
var history:Array=[]
var replay:Array=[]
var sample_clock:=0.0
var replay_time:=0.0
var last_phase:=""
var checkpoint:Dictionary={}
var return_screen:="match"
var last_feedback:=-1
var intro_finished:=false

func capture_frame(sim,stadium)->Dictionary:
 var poses:Array=[];var states:Array=[]
 for actor in stadium.actors: poses.append(actor.transform)
 for p in sim.players: states.append(p.duplicate(true))
 return {"actors":poses,"ball":stadium.football.transform,"states":states,"owner":sim.owner,"net":sim.goal_net.duplicate(true)}

func showing_replay(sim)->bool:
 return not replay.is_empty() and sim.phase=="goal" and sim.Rules.GOAL_DURATION-sim.phase_time>=sim.Rules.GOAL_INTRO

func skip_replay()->void:
 replay.clear()

func reset()->void:
 history.clear();replay.clear();checkpoint={};sample_clock=0;last_phase="";last_feedback=-1

func save_scenario(session,notify:Callable)->void:
 if session.online or not session.practice: return
 checkpoint={"state":session.sim.snapshot(),"rng":session.sim.rng.state}
 notify.call("训练场景已保存 · F3 重试")

func retry_scenario(session,controls,notify:Callable)->void:
 if session.online or not session.practice or checkpoint.is_empty(): return
 session.sim.restore(checkpoint.state);session.sim.rng.state=checkpoint.rng
 session.sim.apply_command(session.sim.view_team,{"action":session.sim.Mechanics.CANCEL})
 controls.reset();history.clear();replay.clear();last_phase="";notify.call("已恢复训练场景")

func update(s,stadium,controls,router,hud,dt:float)->void:
 if s==null or stadium.actors.size()!=Team.COUNT: return
 if s.phase=="play":
  sample_clock+=dt
  if sample_clock>=0.05:
   sample_clock=0
   history.append(capture_frame(s,stadium))
   if history.size()>75: history.pop_front()
 if s.phase=="goal" and last_phase!="goal" and router.options.replay and history.size()>8:
  replay=history.duplicate(true);replay_time=0;intro_finished=false;sample_clock=0
  # Include the crossing itself, even when it happened between history samples.
  var finish:Dictionary=capture_frame(s,stadium)
  finish.ball.origin=Vector3(s.ball.x,s.ball_height,s.ball.y)
  replay.append(finish)
 elif s.phase=="goal" and not replay.is_empty() and not intro_finished:
  sample_clock+=dt
  if sample_clock>=0.05 or showing_replay(s):
   sample_clock=0;replay.append(capture_frame(s,stadium))
  intro_finished=showing_replay(s)
 if s.phase!="goal": replay.clear()
 if s.phase not in ["play","goal"]: history.clear();sample_clock=0
 if showing_replay(s):
  stadium.indicator.visible=false;stadium.pass_arrow.visible=false;stadium.ball_shadow.visible=false
  stadium.aim_marker.visible=false
  for label in stadium.selected_labels: label.visible=false
  for segment in stadium.trail: segment.visible=false
  replay_time=s.Rules.GOAL_DURATION-s.phase_time-s.Rules.GOAL_INTRO
  var position:float=clampf(replay_time/s.Rules.REPLAY_DURATION,0,1)*(replay.size()-1)
  var frame:int=mini(replay.size()-1,int(position))
  var next:int=mini(frame+1,replay.size()-1)
  var blend:float=position-frame
  for i in Team.COUNT:
   var pose:Transform3D=replay[frame].actors[i].interpolate_with(replay[next].actors[i],blend)
   var state:Dictionary=replay[frame].states[i].duplicate()
   if state.action==replay[next].states[i].action: state.action_time=lerpf(state.action_time,replay[next].states[i].action_time,blend)
   stadium.actors[i].transform=pose;stadium.actors[i].visible=state.active
   var velocity:Vector3=(replay[next].actors[i].origin-replay[frame].actors[i].origin)/0.05
   stadium.rigs[i].animate_player(state,dt,replay[frame].owner==i,pose.basis.inverse()*velocity)
  stadium.football.transform=replay[frame].ball.interpolate_with(replay[next].ball,blend)
  var net:Dictionary=replay[frame].net.duplicate(true)
  if net.serial==replay[next].net.serial: net.age=lerpf(net.age,replay[next].net.age,blend)
  for mesh in stadium.goal_nets: mesh.show_state(net)
  # Stable broadcast view shows the shot, keeper and goal throughout the replay.
  stadium.camera.position=Pitch.CAMERA;stadium.camera.look_at(Vector3(0,0,-1))
  hud.event_label.modulate.a=0
  # Hold the final crossing briefly; never jump back to a scorer celebration.
 if s.phase=="goal": hud.event_label.modulate.a=0
 last_phase=s.phase
 if s.event_serial!=last_feedback:
  last_feedback=s.event_serial
  if s.event_kind in ["pass","tackle"]: hud.sound_requested.emit(320 if s.event_kind=="pass" else 130,0.045)
  if router.options.vibration and controls.gamepad>=0 and s.event_kind in ["shot","save","post","tackle"]:
   var amount:float=s.players[s.last_touch].action_strength if s.event_kind=="shot" and s.last_touch>=0 else 0.35
   Input.start_joy_vibration(controls.gamepad,0.10+amount*0.12,0.35 if s.event_kind=="post" else 0.12+amount*0.20,0.07+amount*0.05)
