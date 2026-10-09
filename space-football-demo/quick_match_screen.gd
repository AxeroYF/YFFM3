extends RefCounted
const Palette=preload("res://ui_palette.gd")
## Pure screen construction; choices are submitted as explicit actions.
const Team=preload("res://team_config.gd")
const Match=preload("res://match_sim.gd")
const Conditions=preload("res://match_environment.gd")
const INK=Palette.INK
const MUTED=Palette.MUTED
const CYAN=Palette.CYAN
const GOLD=Palette.GOLD
const QuickMatch=preload("res://quick_match.gd")
const PlayerLibrary=preload("res://player_library.gd")
static func build(modal:Control,kit,fixture:Dictionary,environment:Dictionary,ice_mode:bool,camera_motion:bool,actions:Dictionary)->void:
 kit.panel(modal,Rect2(390,190,1780,1080))
 kit.text(modal,"冰球模式" if ice_mode else "快速比赛",Vector2(450,235),50,INK,true)
 kit.text(modal,"开发测试 · 玩家 vs AI · 双方随机阵容",Vector2(453,320),25,MUTED)
 kit.text(modal,"测试编号  %d" % fixture.seed,Vector2(1580,269),23,CYAN)
 for side_index in 2:
  var x:=460+side_index*840
  kit.panel(modal,Rect2(x,395,780,450),Color("102131"))
  kit.text(modal,"你的球队" if side_index==0 else "AI 测试队",Vector2(x+24,412),30,CYAN if side_index==0 else Color("ffa78c"),true)
  var ids:Array=fixture.home if side_index==0 else fixture.away
  for slot in Team.SIZE:
   var record:=PlayerLibrary.find(ids[slot])
   var y:=482+slot*55
   kit.text(modal,QuickMatch.LABELS[slot]+" · "+record.role,Vector2(x+26,y),23,MUTED)
   var label:Label=kit.text(modal,record.name,Vector2(x+235,y-2),28,INK,true,360)
   label.max_lines_visible=1
   label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
   kit.text(modal,str(int(record.overall)),Vector2(x+677,y-2),28,GOLD,true)
 kit.button(modal,"规则："+("冰球反弹" if ice_mode else "经典六人制"),Rect2(460,880,780,70),actions.rules)
 kit.button(modal,"镜头："+("跟随足球" if camera_motion else "固定"),Rect2(1300,880,780,70),actions.camera)
 kit.button(modal,"球场："+Conditions.label("stadium",environment.stadium),Rect2(460,969,520,70),actions.stadium)
 kit.button(modal,"天气："+Conditions.label("weather",environment.weather),Rect2(1010,969,520,70),actions.weather)
 kit.button(modal,Conditions.label("gravity",environment.gravity),Rect2(1560,969,520,70),actions.gravity)
 kit.text(modal,Conditions.description(environment),Vector2(464,1060),22,CYAN,false,1610)
 kit.button(modal,"开始比赛",Rect2(460,1120,880,82),actions.start,true)
 kit.button(modal,"重新随机",Rect2(1370,1120,340,82),actions.reroll)
 kit.button(modal,"返回",Rect2(1740,1120,340,82),actions.back)
 kit.text(modal,"%d 分钟比赛 · 1 门将 + 5 名场上球员 · 重赛保留环境 · 不修改存档" % int(Match.DEFAULT_DURATION/60),Vector2(464,1220),21,MUTED)
