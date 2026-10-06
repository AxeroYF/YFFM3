extends RefCounted
const Team=preload("res://team_config.gd")
signal sound_requested(frequency:float,duration:float)
## Presentation consumes authority phases; it never advances match rules.
var banner:Panel
var title:Label
var subtitle:Label
var goal_overlay:Panel
var goal_title:Label
var goal_detail:Label
var goal_line:ColorRect
var previous_phase:=""
var skip_prompt:Control
var skip_fade:ColorRect

func build(ui:Control,kit,router)->void:
 banner=kit.panel(ui,Rect2(765,285,1030,145),Color(0.02,0.04,0.07,0.92))
 title=kit.text(banner,"",Vector2(24,16),40,kit.GOLD,true,982)
 subtitle=kit.text(banner,"",Vector2(24,83),23,kit.INK,false,982)
 title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
 banner.visible=false
 goal_overlay=kit.panel(ui,Rect2(730,480,1100,300),Color(0.015,0.03,0.055,0.96))
 goal_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
 goal_title=kit.text(goal_overlay,"GOAL",Vector2(40,22),118,kit.INK,true,1020)
 goal_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 goal_detail=kit.text(goal_overlay,"",Vector2(40,207),30,kit.GOLD,true,1020)
 goal_detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 goal_line=ColorRect.new();goal_line.position=Vector2(40,284);goal_line.size=Vector2(1020,5)
 goal_line.color=kit.CYAN;goal_line.mouse_filter=Control.MOUSE_FILTER_IGNORE;goal_overlay.add_child(goal_line)
 goal_overlay.pivot_offset=goal_overlay.size*0.5;goal_overlay.visible=false
 previous_phase=""
 skip_prompt=preload("res://hold_skip_prompt.gd").new();ui.add_child(skip_prompt);skip_prompt.build(kit,router)
 skip_fade=ColorRect.new();skip_fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 skip_fade.size=Vector2(2560,1440);skip_fade.color=Color("03060b");skip_fade.visible=false;skip_fade.z_index=20;ui.add_child(skip_fade)

func update(s,hud,router,replaying:bool,playing:bool)->void:
 var phase:String=s.phase
 skip_prompt.refresh(s,router,playing)
 skip_fade.color.a=s.Rules.Flow.fade(s) if phase=="restart" else 0.0
 skip_fade.visible=skip_fade.color.a>0
 banner.visible=false
 goal_overlay.visible=false
 banner.position=Vector2(765,285);banner.size=Vector2(1030,145)
 title.position=Vector2(24,16);title.size.x=982;subtitle.position=Vector2(24,83);subtitle.size.x=982
 title.add_theme_font_size_override("font_size",40)
 if phase=="restart":
  var ready:bool=s.Rules.Flow.ready(s)
  hud.rule_label.text=("我方" if s.restart_team==s.view_team else "对方")+" · "+s.Rules.TITLES[s.restart_kind]+"  /  "+s.Rules.Flow.TITLES.get(s.restart_flow.get("stage","fetch"),"")
  if ready and s.Rules.ready_limit(s)>0: hud.rule_label.text+="  %d 秒" % maxi(0,ceili(s.Rules.ready_limit(s)-s.phase_time))
  elif ready and s.Rules.is_free(s.restart_kind): hud.rule_label.text+=" · %d 秒后自动开球" % maxi(0,ceili(s.Rules.AUTO_FREE_SECONDS-s.phase_time))+(" · 需另一人触球" if s.restart_kind=="indirect" else "")
  if not ready: hud.action_hint.text=""
  elif s.restart_team!=s.view_team: hud.action_hint.text="等待对手开球"
  else:
   hud.action_hint.text=router.symbol("move")+" 瞄准 / "+router.symbol("pass")+" 短传 / "+router.symbol("cross")+" 挑传"
 elif phase=="foul":
  hud.rule_label.text="犯规 · "+s.Rules.TITLES[s.restart_kind]+"  /  累计 %d : %d" % s.fouls
 elif phase=="goal":
  var age:float=s.Rules.GOAL_DURATION-s.phase_time
  goal_overlay.visible=age<s.Rules.GOAL_INTRO
  banner.visible=not goal_overlay.visible
  if goal_overlay.visible:
   var enter:float=1-pow(1-clampf(age/0.22,0,1),3)
   goal_overlay.scale=Vector2.ONE*lerpf(0.90,1.0,enter)
   goal_overlay.modulate.a=enter*clampf((s.Rules.GOAL_INTRO-age)/0.12,0,1)
   goal_line.size.x=1020*enter
   goal_detail.text="%s   ·   %s   ·   %d : %d" % ["主队" if s.goal_team==0 else "客队",s.players[s.goal_scorer].name+("（乌龙）" if s.goal_scorer/Team.SIZE!=s.goal_team else ""),s.score[0],s.score[1]]
  else:
   banner.position=Vector2(855,245);banner.size=Vector2(850,125)
   title.size.x=802;subtitle.size.x=802;subtitle.position.y=75
   title.add_theme_font_size_override("font_size",34)
   title.text="进球回放   %d : %d" % s.score if replaying else "GOAL   %d : %d" % s.score
   subtitle.text=router.symbol("pass")+" / "+router.symbol("shoot")+" 跳过回放" if replaying else ("比赛结束" if s.overtime else "准备中圈开球")
 if previous_phase!=phase:
  if phase in ["foul","restart"]: sound_requested.emit(1150,0.16)
  previous_phase=phase

func hide()->void:
 if is_instance_valid(skip_prompt): skip_prompt.visible=false
 if is_instance_valid(skip_fade): skip_fade.visible=false
 if is_instance_valid(banner): banner.visible=false
 if is_instance_valid(goal_overlay): goal_overlay.visible=false
