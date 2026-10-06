extends RefCounted
const Palette=preload("res://ui_palette.gd")
## Match HUD consumes a view and emits audio cues; it cannot start or mutate matches.
const Team=preload("res://team_config.gd")
const Match=preload("res://match_sim.gd")
const Conditions=preload("res://match_environment.gd")
const INK=Palette.INK
const MUTED=Palette.MUTED
const CYAN=Palette.CYAN
const GOLD=Palette.GOLD
signal sound_requested(frequency:float,duration:float)
signal kick_requested(power:float)
var score_label: Label
var time_label: Label
var energy_label: Label
var event_label: Label
var player_label: Label
var charge_bar: ColorRect
var energy_bar: ColorRect
var rule_label: Label
var environment_label:Label
var network_label:Label
var action_hint:Label
var event_age := 0.0
var last_event := -1
func build(ui:Control,kit,sim,mission:Dictionary,online:bool,practice:bool,actions:Dictionary)->void:
 kit.panel(ui,Rect2(72,38,630,129))
 kit.text(ui,"ONLINE  /  1v1  /  6v6" if online else ("QUICK MATCH  /  开发测试" if practice else mission.tag),Vector2(101,57),18,CYAN)
 kit.text(ui,"冰球模式 · 反弹边界" if sim.ice_mode else "经典六人制 · 轨道球场" if not sim.arcade else mission.name+" / 星际规则",Vector2(99,97),29,INK,true)
 kit.panel(ui,Rect2(790,35,980,155),Color(0.016,0.03,0.055,0.96))
 kit.text(ui,"主队"+(" · 你" if sim.view_team==0 else ""),Vector2(833,74),31,CYAN,true)
 kit.text(ui,("客队" if online else "AI 测试队" if practice else mission.club)+(" · 你" if sim.view_team==1 else ""),Vector2(1440,80),27,Color("ffa78c"),true)
 score_label=kit.text(ui,"0  :  0",Vector2(1168,57),52,INK,true)
 time_label=kit.text(ui,"00 : 00",Vector2(1192,127),22,GOLD)
 var pause_control:Button=kit.button(ui,"菜单" if online else "暂停",Rect2(2255,43,233,65),actions.pause)
 kit.button_binding(pause_control,"pause")
 var help_control:Button=kit.button(ui,"操作说明",Rect2(2255,121,233,56),actions.help)
 kit.button_binding(help_control,"help")
 rule_label=kit.text(ui,"进攻方向  →     右侧球门",Vector2(929,215),24,MUTED)
 kit.panel(ui,Rect2(72,1184,620,190))
 kit.text(ui,"CONTROLLED PLAYER",Vector2(102,1203),17,GOLD)
 player_label=kit.text(ui,"哈兰德  /  持球",Vector2(100,1237),32,INK,true)
 kit.text(ui,"射门蓄力",Vector2(102,1307),20,MUTED)
 kit.panel(ui,Rect2(230,1318,420,9),Color("203649"),Color.TRANSPARENT)
 charge_bar=ColorRect.new()
 charge_bar.position=Vector2(230,1318)
 charge_bar.size=Vector2(0,9)
 charge_bar.color=GOLD
 ui.add_child(charge_bar)
 kit.panel(ui,Rect2(1880,1184,608,190))
 kit.text(ui,"球员体力",Vector2(1910,1207),23,CYAN,true)
 energy_label=kit.text(ui,"100%",Vector2(2360,1207),25,CYAN,true)
 kit.panel(ui,Rect2(1910,1266,538,11),Color("203649"),Color.TRANSPARENT)
 energy_bar=ColorRect.new()
 energy_bar.position=Vector2(1910,1266)
 energy_bar.size=Vector2(538,11)
 energy_bar.color=CYAN
 ui.add_child(energy_bar)
 kit.binding_hint(ui,"sprint","冲刺",Vector2(1910,1300))
 kit.binding_hint(ui,"jockey","横移",Vector2(2080,1300))
 kit.binding_hint(ui,"tackle","抢断",Vector2(2250,1300))
 kit.panel(ui,Rect2(725,1227,1118,146))
 kit.binding_hint(ui,"shoot","蓄力射门",Vector2(757,1242))
 kit.binding_hint(ui,"pass","短传",Vector2(1010,1242))
 kit.binding_hint(ui,"through","直塞",Vector2(1190,1242))
 kit.binding_hint(ui,"switch","换人",Vector2(1370,1242))
 kit.binding_hint(ui,"cross","挑传 / 滑铲",Vector2(1540,1242))
 kit.binding_text(ui,"%s 移动 / 瞄准",["move"],Vector2(757,1310),22,MUTED)
 kit.binding_text(ui,"%s + %s 弧线射门",["finesse","shoot"],Vector2(1230,1310),22,MUTED)
 event_label=kit.text(ui,"准备开球",Vector2(740,1090),34,GOLD,true,1080)
 event_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 kit.panel(ui,Rect2(72,177,805,89),Color(0.016,0.03,0.055,0.90))
 network_label=kit.text(ui,"",Vector2(90,187),20,CYAN)
 environment_label=kit.text(ui,Conditions.summary(sim.environment),Vector2(90,224),21,CYAN,false,780)
 action_hint=kit.text(ui,"",Vector2(1910,1150),20,GOLD)

func update(sim,view,controls,desktop_input,diagnostics:String,dt:float)->void:
 var selected:int=view.selected
 score_label.text="%d  :  %d" % [sim.score[0],sim.score[1]]
 var remaining: int=maxi(0,int(ceil(sim.duration-sim.elapsed)))
 time_label.text=("金球 " if sim.overtime else "")+"%02d : %02d" % [remaining/60,remaining%60]
 player_label.text=sim.players[selected].name+(" / 持球" if sim.owner==selected else " / 接应" if sim.owner>=0 and sim.owner/Team.SIZE==sim.view_team else " / 回防")
 if sim.phase=="restart": player_label.text=sim.players[selected].name+(" / 主罚" if sim.Rules.Flow.ready(sim) else " / 取球") if selected==sim.restart_taker else sim.players[selected].name+" / 就位"
 energy_label.text="%d%% / 疲劳 %d%%" % [int(sim.energy),int(sim.players[selected].get("fatigue",0)*100)]
 energy_bar.size.x=538*sim.energy/100
 var pass_charge:float=clampf(0.28+float(Time.get_ticks_msec()-controls.pass_started)/800,0,1) if controls.pass_held else 0
 charge_bar.size.x=420*(pass_charge if controls.pass_held else view.charge)
 charge_bar.color=Color("ff967e") if view.charge>0.85 else GOLD
 rule_label.text="太阳风活跃 ↓" if sim.wind_active() else ("你的进攻方向  →  右侧球门" if sim.view_team==0 else "你的进攻方向  ←  左侧球门")+"  /  "+["稳固防守","均衡推进","全线压上"][sim.tactic]
 network_label.text=diagnostics
 var defender:Dictionary=sim.players[selected]
 action_hint.text="抢断恢复 %.1f 秒" % defender.tackle_cd if defender.tackle_cd>0 else desktop_input.symbol("tackle")+" 抢断 / "+desktop_input.symbol("cross")+" 铲球"
 if defender.action_time>0 and defender.action in Match.Motion.DEFENSIVE_ACTIONS:
  action_hint.text={"tackle":"伸脚抢断 · 收腿后恢复移动","slide_still":"原地铲球 · 收腿起身","slide":"跑动滑铲 · 减速后起身"}[defender.action]
 if sim.owner==selected:
  action_hint.text="蓄力 %d%% · " % int(view.charge*100)+("高射 · 注意横梁" if view.charge>0.85 else "有力射门" if view.charge>0.4 else "低平射门") if view.charging else desktop_input.symbol("jockey")+" 护球 / "+desktop_input.symbol("shoot")+" 蓄力射门"
  if selected%Team.SIZE==0 and not view.charging:
   action_hint.text=("手持球" if sim.players[selected].keeper_holding else "脚下控球")+" · 方向 + "+desktop_input.symbol("pass")+" 传球 / "+desktop_input.symbol("cross")+" 长传"
 elif sim.teams[sim.view_team].keeper_rush: action_hint.text="门将出击 · 松开 "+desktop_input.symbol("through")+" 回位"
 if controls.pass_held: action_hint.text="传球蓄力 %d%% · 松开出球" % int(pass_charge*100)
 if sim.teams[sim.view_team].contain_player>=0: action_hint.text="队友协防 · 松开 "+desktop_input.symbol("finesse")+" 结束"
 if not sim.mechanics.buffered[sim.view_team].is_empty(): action_hint.text="已预输入 · 等待触球"
 if sim.phase in ["foul","goal"]: action_hint.text=""
 rule_label.modulate=Color("ffbf8c") if sim.wind_active() else Color.WHITE
 environment_label.text=Conditions.summary(sim.environment)
 if sim.event_serial!=last_event:
  last_event=sim.event_serial
  event_age=0
  event_label.text=sim.message
  if sim.event_kind=="goal": sound_requested.emit(780,0.5)
  elif sim.event_kind=="shot": kick_requested.emit(float(sim.players[maxi(0,sim.last_touch)].action_strength))
  elif sim.event_kind=="save": sound_requested.emit(270,0.1)
  elif sim.event_kind=="post": sound_requested.emit(940,0.18)
 event_age+=dt
 event_label.modulate.a=clampf(3.5-event_age,0,1)
 if sim.freeze>0:
  event_label.modulate.a=1
  if sim.event_serial==0: event_label.text="准备开球  /  %d" % maxi(1,int(ceil(sim.freeze)))
 if sim.phase!="play" or sim.event_kind in ["restart","foul"]: event_label.modulate.a=0
