extends RefCounted
const Team=preload("res://team_config.gd")
const Library=preload("res://player_library.gd")
const Squad=preload("res://squad.gd")
const Ratings=preload("res://player_ratings.gd")
const LABELS={"passing":"传球","firstTouch":"停球","dribbling":"盘带","crossing":"传中","finishing":"射门","longShots":"远射","heading":"头球","setPieces":"定位球","tackling":"抢断","marking":"盯人","positioning":"站位","vision":"视野","decisions":"决策","composure":"冷静","offBall":"无球","discipline":"纪律","pace":"速度","acceleration":"加速","strength":"力量","stamina":"耐力","agility":"灵活","jumping":"弹跳","workRate":"投入","aggression":"侵略性","goalkeeping":"守门","reflexes":"反应"}
## Navigation is requested through signals; this view only owns its widgets and filters.
signal page_requested(screen:String,title:String)
signal modal_requested
signal close_requested
signal menu_requested
signal toast_requested(message:String)
var kit
var ui:Control
var modal:Control
var page:=0
var query:=""
var picking:=-1
var role_filter:="全部"

func configure(widget_kit,page_root:Control,modal_root:Control)->void:
 kit=widget_kit;ui=page_root;modal=modal_root

func open_catalog()->void:
 picking=-1
 page=0
 query=""
 role_filter="全部"
 show_library()

func show_squad()->void:
 page_requested.emit("squad","我的球队")
 kit.text(ui,"首发阵容",Vector2(76,175),52,kit.INK,true)
 kit.text(ui,"1 门将 · 5 名场上球员",Vector2(78,255),25,kit.MUTED)
 kit.button(ui,"返回主菜单",Rect2(2110,185,375,65),menu_requested.emit)
 for i in Team.SIZE:
  var p:=Library.find(Squad.ids[i])
  var x:=76+i*405
  var card=kit.panel(ui,Rect2(x,378,384,765))
  kit.text(card,Squad.SLOTS[i],Vector2(26,25),25,kit.CYAN)
  var picture:=TextureRect.new()
  picture.position=Vector2(26,84)
  picture.size=Vector2(332,395)
  picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  picture.texture=load(p.portrait)
  card.add_child(picture)
  kit.text(card,p.name,Vector2(26,501),32,kit.INK,true,332)
  kit.text(card,"%s  /  %d cm" % [p.role,p.heightCm],Vector2(26,564),25,kit.MUTED)
  kit.button(card,"更换球员",Rect2(26,652,332,72),func(): picking=i;page=0;query="";role_filter="全部";show_library(),true)
 kit.text(ui,"阵容自动保存 · 用于星际杯与联机对战",Vector2(78,1230),25,kit.MUTED)

func show_library()->void:
 page_requested.emit("library","球员库")
 kit.text(ui,"选择"+Squad.SLOTS[picking] if picking>=0 else "球员库",Vector2(76,160),48,kit.INK,true)
 var list:Array=Library.all().filter(func(p): return (picking<0 or (p.role=="GK")== (picking==0)) and (role_filter=="全部" or p.role==role_filter) and (query.is_empty() or (str(p.name)+str(p.get("sourceName",""))+str(p.club)+str(p.role)).to_lower().contains(query.to_lower())))
 var pages:=maxi(1,ceili(list.size()/12.0))
 page=clampi(page,0,pages-1)
 kit.text(ui,"%d 名球员" % Library.all().size(),Vector2(78,234),25,kit.MUTED)
 var filter:=OptionButton.new()
 filter.position=Vector2(650,172)
 filter.size=Vector2(310,65)
 filter.add_theme_font_override("font",kit.font)
 filter.add_theme_font_size_override("font_size",25)
 var roles:=["全部","GK","CB","RB","LB","DM","AM","RM","LM","RW","LW","ST"]
 for role in roles: filter.add_item("位置："+role)
 filter.select(roles.find(role_filter))
 filter.item_selected.connect(func(index): role_filter=roles[index];page=0;show_library())
 ui.add_child(filter)
 var search:=LineEdit.new()
 search.position=Vector2(1000,172)
 search.size=Vector2(760,65)
 search.text=query
 search.placeholder_text="搜索姓名、俱乐部或位置"
 search.add_theme_font_override("font",kit.font)
 search.add_theme_font_size_override("font_size",28)
 ui.add_child(search)
 search.text_submitted.connect(func(value): query=value.strip_edges();page=0;show_library())
 kit.button(ui,"搜索",Rect2(1780,172,185,65),func(): query=search.text.strip_edges();page=0;show_library())
 kit.button(ui,"返回球队" if picking>=0 else "返回主菜单",Rect2(2110,172,375,65),show_squad if picking>=0 else menu_requested.emit)
 for i in mini(12,list.size()-page*12):
  var p:Dictionary=list[page*12+i]
  var x:=76+(i%4)*610
  var y:=320+(i/4)*286
  var card=kit.panel(ui,Rect2(x,y,572,258))
  var picture:=TextureRect.new()
  picture.position=Vector2(10,10)
  picture.size=Vector2(170,226)
  picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  picture.texture=load(p.portrait)
  card.add_child(picture)
  kit.text(card,p.name,Vector2(194,22),29,kit.INK,true)
  kit.text(card,"%s · %s · %d OVR" % [p.role,p.grade,p.overall],Vector2(194,70),22,kit.CYAN)
  kit.text(card,"%s / %d cm" % [p.nationality,p.heightCm],Vector2(194,112),20,kit.MUTED)
  kit.text(card,p.club,Vector2(194,149),20,kit.MUTED,false,346)
  kit.button(card,"球员资料",Rect2(194,195,345,48),func(): details(p)).set_meta("preferred_focus",i==0)
 if list.is_empty(): kit.text(ui,"没有符合条件的球员",Vector2(900,680),36,kit.MUTED)
 kit.button(ui,"上一页",Rect2(76,1225,260,65),func(): page=maxi(0,page-1);show_library())
 kit.text(ui,"%d / %d 页   ·   %d 条结果" % [page+1,pages,list.size()],Vector2(390,1238),27,kit.INK)
 kit.button(ui,"下一页",Rect2(840,1225,260,65),func(): page=mini(pages-1,page+1);show_library())
 kit.text(ui,"总评为档案评级 · 比赛表现由单项能力与操作决定",Vector2(1310,1242),23,kit.MUTED)

func details(p:Dictionary)->void:
 modal_requested.emit()
 kit.panel(modal,Rect2(360,190,1840,1090))
 kit.text(modal,p.name+"  /  "+str(p.get("sourceName","")),Vector2(420,220),38,kit.INK,true)
 kit.text(modal,"%s · %s · %d cm · %s" % [p.club,p.role,p.heightCm,"左脚" if p.preferredFoot=="left" else ("双脚" if p.preferredFoot=="both" else "右脚")],Vector2(420,284),25,kit.CYAN)
 var picture:=TextureRect.new()
 picture.position=Vector2(410,380)
 picture.size=Vector2(530,710)
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.texture=load(p.portrait)
 modal.add_child(picture)
 var i:=0
 for key in LABELS:
  var x:=1030+(i/13)*530
  var y:=360+(i%13)*55
  kit.text(modal,LABELS[key],Vector2(x,y),27,kit.MUTED if key in Ratings.ACTIVE else kit.GOLD)
  kit.text(modal,str(int(p.attributes[key])),Vector2(x+230,y),28,kit.INK,true)
  i+=1
 kit.text(modal,"逆足：%s     花式：%s" % [str(p.weakFoot) if p.weakFoot!=null else "来源未填写",str(p.skillMoves) if p.skillMoves!=null else "来源未填写"],Vector2(440,1120),24,kit.MUTED)
 var style:=preload("res://player_style.gd").derive(p)
 kit.text(modal,style.name+" · "+preload("res://player_style.gd").description(style),Vector2(1030,1090),21,kit.GOLD,false,1070)
 var turning:=Ratings.for_player(p)
 kit.text(modal,"原地转身：180° %.3f 秒 · 90° %.3f 秒 · 高速变向需先减速" % [turning.turn_time,turning.turn_time/2],Vector2(1030,1130),22,kit.CYAN)
 var physique:Dictionary=Ratings.Body.from_record(p).physique
 kit.text(modal,"体型修正：启动 %+.0f%% · 刹车 %+.0f%% · 伸脚 %+.0f%%" % [(physique.acceleration_scale-1)*100,(physique.braking_scale-1)*100,(physique.tackle_reach_scale-1)*100],Vector2(420,332),21,kit.MUTED)
 for slot in Team.SIZE:
  var b=kit.button(modal,("✓ " if Squad.ids[slot]==p.id else "")+Squad.SLOTS[slot],Rect2(330+slot*270,1180,250,60),func():
   if Squad.assign_player(p.id,slot):
    show_squad()
    toast_requested.emit(p.name+"已加入首发")
   else: toast_requested.emit("阵容保存失败，请重试"))
  b.disabled=(p.role=="GK")!=(slot==0) or (picking>=0 and picking!=slot)
 kit.button(modal,"返回",Rect2(1980,1180,300,60),close_requested.emit)
