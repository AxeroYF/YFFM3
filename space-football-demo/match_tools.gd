extends RefCounted
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
var outgoing_slot:=1
var intro_finished:=false

func capture_frame(game)->Dictionary:
 var poses:Array=[];var states:Array=[]
 for actor in game.actors: poses.append(actor.transform)
 for p in game.sim.players: states.append(p.duplicate(true))
 return {"actors":poses,"ball":game.football.transform,"states":states,"owner":game.sim.owner,"net":game.sim.goal_net.duplicate(true)}

func showing_replay(game)->bool:
 return not replay.is_empty() and game.sim.phase=="goal" and game.sim.Rules.GOAL_DURATION-game.sim.phase_time>=game.sim.Rules.GOAL_INTRO

func skip_replay()->void:
 replay.clear()

func reset()->void:
 history.clear();replay.clear();checkpoint={};sample_clock=0;last_phase="";last_feedback=-1

func advanced_settings(game)->void:
 game.clear_modal();game.dim_modal()
 game.panel(game.modal,Rect2(560,235,1440,990))
 game.text(game.modal,"操作与比赛选项",Vector2(625,282),44,game.INK,true)
 var router=game.desktop_input
 var labels={"receive_assist":"接球跑位辅助","shot_assist":"射门辅助","auto_switch":"自动切人","vibration":"手柄震动","replay":"进球回放","strict_rules":"门将 4 秒 / 重复回传限制","camera_impact":"镜头冲击","alternate_directions":"方向操作键盘布局"}
 var values={"receive_assist":["低","标准","高"],"shot_assist":["低","标准","高"],"auto_switch":["手动","接球队员","接球与自由球"],"vibration":["关","开"],"replay":["关","开"],"strict_rules":["关","开（下场生效）"],"camera_impact":["关","轻微（默认）","标准"],"alternate_directions":["小键盘 8/2/4/6","I / K / J / L"]}
 var n:=0
 for key in labels:
  var setting:String=key
  var current:int=int(router.options[setting])
  game.button(game.modal,labels[setting]+"："+values[setting][current],Rect2(625,385+n*80,1310,66),func():
   router.options[setting]=(int(router.options[setting])+1)%values[setting].size()
   router.update_prompts();router.save_preferences();advanced_settings(game))
  n+=1
 game.text(game.modal,"黄红牌与累计犯规已启用。辅助与反馈设置自动保存。",Vector2(625,1055),23,game.MUTED)
 game.button(game.modal,"返回辅助设置",Rect2(625,1110,1310,68),game.show_assistance_settings)

func substitutions(game)->void:
 game.controls.reset()
 game.screen="substitutions"
 game.clear_modal();game.dim_modal()
 game.panel(game.modal,Rect2(450,250,1660,900))
 game.text(game.modal,"替补席",Vector2(510,295),46,game.INK,true)
 var s=game.sim;var team:int=s.view_team
 game.text(game.modal,"选择场上球员，再选择替补；重新开球准备时执行。",Vector2(510,365),26,game.MUTED)
 for i in range(team*5,team*5+5):
  var index:int=i
  var status:String=" · 疲劳 %d%%" % int(s.players[index].fatigue*100) if s.players[index].active else " · 减员 %d 秒" % ceili(s.players[index].sinbin)
  game.button(game.modal,("✓ " if index%5==outgoing_slot else "")+s.players[index].name+status,Rect2(510,440+i%5*100,665,75),func():
   outgoing_slot=index%5
   substitutions(game))
 for j in s.mechanics.benches[team].size():
  var slot:int=j;var record:Dictionary=s.Library.find(s.mechanics.benches[team][j].id)
  var b=game.button(game.modal,record.name+" · "+record.role,Rect2(1210,440+j*100,830,75),func():
   send(game,{"action":s.Mechanics.SUBSTITUTE,"reserve":slot,"out":outgoing_slot})
   close(game))
  b.disabled=(record.role=="GK")!=(outgoing_slot==0) or (not s.players[team*5+outgoing_slot].active and s.players[team*5+outgoing_slot].sinbin>0)
 game.button(game.modal,"返回比赛",Rect2(510,1010,1530,75),func(): close(game))

func send(game,c:Dictionary)->void:
 c.merge({"move":Vector2.ZERO,"sprint":false,"jockey":false,"aim":0.0,"tactic":game.sim.tactic,"assist_active":false},false)
 if game.online: game.network.submit_local(c,1.0/60)
 else: game.sim.apply_command(game.sim.view_team,c)

func close(game)->void:
 game.clear_modal();game.screen="match";game.controls.reset()

func extra_help(game)->void:
 game.clear_modal();game.dim_modal()
 game.panel(game.modal,Rect2(450,180,1660,1080))
 game.text(game.modal,"进阶操作",Vector2(515,230),46,game.INK,true)
 var pad:bool=game.desktop_input.kind=="gamepad"
 var glyph=game.desktop_input
 var short_pass:String=glyph.symbol("pass");var shot:String=glyph.symbol("shoot");var cross:String=glyph.symbol("cross")
 var left:String=glyph.symbol("switch");var right:String=glyph.symbol("finesse")
 var entries:Array=[
  ["右摇杆方向" if pad else "小键盘方向 / IJKL（设置切换）","无球方向切人；持球拉球变向"],
  [glyph.symbol("sprint")+(" + 右摇杆" if pad else " + 方向操作键"),"趟球突破；足球可被对方抢走"],
  ["轻点 "+left+" / 轻点 "+right,"呼叫前插 / 呼叫靠近接应"],
  ["无球按住 "+right,"呼叫一名队友协防"],
  ["按住 "+short_pass+" / "+glyph.symbol("through")+" / "+cross+" 再松开","控制传球力度；"+right+" 修饰为大力地滚球或低平传中"],
  ["接球前 "+short_pass+" / "+shot,"预输入一脚传球 / 射门，短时有效"],
  ["高球 "+short_pass+" / "+cross+" / "+shot,"头球摆渡 / 解围 / 攻门，适时起跳"],
  ["按下右摇杆" if pad else "Backspace","取消待执行动作；进球回放时任意传射键跳过"],
  ["定位球十字键 上 / 下" if pad else "定位球 4 / 5","更换主罚 / 切换短接应、近点、后点配合"],
  ["比赛菜单 → 替补席","申请换人；红牌席位减员后按规则补员"],
  ["快速比赛 F2 / F3","保存当前训练场景 / 重试（仅本地开发模式）"]]
 for i in entries.size():
  game.text(game.modal,entries[i][0],Vector2(515,340+i*66),25,game.CYAN,false,650)
  game.text(game.modal,entries[i][1],Vector2(1175,340+i*66),24,game.INK,false,860)
 game.button(game.modal,"返回基础操作",Rect2(515,1140,1530,72),func():game.show_help(game.previous_screen))

func save_scenario(game)->void:
 if game.online or not game.practice: return
 checkpoint={"state":game.sim.snapshot(),"rng":game.sim.rng.state}
 game.toast("训练场景已保存 · F3 重试")

func retry_scenario(game)->void:
 if game.online or not game.practice or checkpoint.is_empty(): return
 game.sim.restore(checkpoint.state);game.sim.rng.state=checkpoint.rng
 game.sim.apply_command(game.sim.view_team,{"action":game.sim.Mechanics.CANCEL})
 game.controls.reset();history.clear();replay.clear();last_phase="";game.toast("已恢复训练场景")

func update(game,dt:float)->void:
 var s=game.sim
 if s==null or game.actors.size()!=10: return
 if s.phase=="play":
  sample_clock+=dt
  if sample_clock>=0.05:
   sample_clock=0
   history.append(capture_frame(game))
   if history.size()>75: history.pop_front()
 if s.phase=="goal" and last_phase!="goal" and game.desktop_input.options.replay and history.size()>8:
  replay=history.duplicate(true);replay_time=0;intro_finished=false;sample_clock=0
  # Include the crossing itself, even when it happened between history samples.
  var finish:Dictionary=capture_frame(game)
  finish.ball.origin=Vector3(s.ball.x,s.ball_height,s.ball.y)
  replay.append(finish)
 elif s.phase=="goal" and not replay.is_empty() and not intro_finished:
  sample_clock+=dt
  if sample_clock>=0.05 or showing_replay(game):
   sample_clock=0;replay.append(capture_frame(game))
  intro_finished=showing_replay(game)
 if s.phase!="goal": replay.clear()
 if s.phase not in ["play","goal"]: history.clear();sample_clock=0
 if showing_replay(game):
  game.indicator.visible=false;game.pass_arrow.visible=false;game.ball_shadow.visible=false
  game.aim_marker.visible=false
  for label in game.selected_labels: label.visible=false
  for segment in game.trail: segment.visible=false
  replay_time=s.Rules.GOAL_DURATION-s.phase_time-s.Rules.GOAL_INTRO
  var position:float=clampf(replay_time/s.Rules.REPLAY_DURATION,0,1)*(replay.size()-1)
  var frame:int=mini(replay.size()-1,int(position))
  var next:int=mini(frame+1,replay.size()-1)
  var blend:float=position-frame
  for i in 10:
   var pose:Transform3D=replay[frame].actors[i].interpolate_with(replay[next].actors[i],blend)
   var state:Dictionary=replay[frame].states[i].duplicate()
   if state.action==replay[next].states[i].action: state.action_time=lerpf(state.action_time,replay[next].states[i].action_time,blend)
   game.actors[i].transform=pose;game.actors[i].visible=state.active
   var velocity:Vector3=(replay[next].actors[i].origin-replay[frame].actors[i].origin)/0.05
   game.rigs[i].animate_player(state,dt,replay[frame].owner==i,pose.basis.inverse()*velocity)
  game.football.transform=replay[frame].ball.interpolate_with(replay[next].ball,blend)
  var net:Dictionary=replay[frame].net.duplicate(true)
  if net.serial==replay[next].net.serial: net.age=lerpf(net.age,replay[next].net.age,blend)
  for mesh in game.goal_nets: mesh.show_state(net)
  # Stable broadcast view shows the shot, keeper and goal throughout the replay.
  game.camera.position=Pitch.CAMERA;game.camera.look_at(Vector3(0,0,-1))
  game.event_label.modulate.a=0
  # Hold the final crossing briefly; never jump back to a scorer celebration.
 if s.phase=="goal": game.event_label.modulate.a=0
 last_phase=s.phase
 if s.event_serial!=last_feedback:
  last_feedback=s.event_serial
  if s.event_kind in ["pass","tackle"]: game.beep(320 if s.event_kind=="pass" else 130,0.045)
  if game.desktop_input.options.vibration and game.controls.gamepad>=0 and s.event_kind in ["shot","save","post","tackle"]:
   var amount:float=s.players[s.last_touch].action_strength if s.event_kind=="shot" and s.last_touch>=0 else 0.35
   Input.start_joy_vibration(game.controls.gamepad,0.10+amount*0.12,0.35 if s.event_kind=="post" else 0.12+amount*0.20,0.07+amount*0.05)

func rig_sync(game,index:int)->void:
 var p:Dictionary=game.sim.players[index]
 if game.rigs[index].get_meta("player_id",p.player_id)==p.player_id:
  game.rigs[index].set_meta("player_id",p.player_id);return
 var old=game.rigs[index];game.actors[index].remove_child(old);old.queue_free()
 var rig=game.FootballActor.new();game.actors[index].add_child(rig)
 var color:Color=game.CYAN if index<5 else Color("ff866c")
 if index%5==0: color=game.GOLD if index<5 else Color("b79bff")
 rig.build(color,game.Match.JERSEY_NUMBERS[index],index%5==0,p.body)
 rig.set_meta("player_id",p.player_id);game.rigs[index]=rig
