extends RefCounted
const Library=preload("res://player_library.gd")
const Squad=preload("res://squad.gd")
const Ratings=preload("res://player_ratings.gd")
const LABELS={"passing":"传球","firstTouch":"停球","dribbling":"盘带","crossing":"传中","finishing":"射门","longShots":"远射","heading":"头球","setPieces":"定位球","tackling":"抢断","marking":"盯人","positioning":"站位","vision":"视野","decisions":"决策","composure":"冷静","offBall":"无球","discipline":"纪律","pace":"速度","acceleration":"加速","strength":"力量","stamina":"耐力","agility":"灵活","jumping":"弹跳","workRate":"投入","aggression":"侵略性","goalkeeping":"守门","reflexes":"反应"}
var game:Node
var page:=0
var query:=""
var picking:=-1
var role_filter:="全部"

func open_catalog()->void:
 picking=-1
 page=0
 query=""
 role_filter="全部"
 show_library()

func show_squad()->void:
 game.clear_modal()
 game.clear_ui()
 game.camera_hub()
 game.screen="squad"
 game.chrome("我的球队")
 game.text(game.ui,"首发阵容",Vector2(76,175),52,game.INK,true)
 game.text(game.ui,"1 门将 · 4 名场上球员",Vector2(78,255),25,game.MUTED)
 game.button(game.ui,"返回主菜单",Rect2(2110,185,375,65),game.show_menu)
 for i in 5:
  var p:=Library.find(Squad.ids[i])
  var x:=76+i*486
  var card=game.panel(game.ui,Rect2(x,378,464,765))
  game.text(card,Squad.SLOTS[i],Vector2(26,25),25,game.CYAN)
  var picture:=TextureRect.new()
  picture.position=Vector2(26,84)
  picture.size=Vector2(410,395)
  picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  picture.texture=load(p.portrait)
  card.add_child(picture)
  game.text(card,p.name,Vector2(26,501),32,game.INK,true,414)
  game.text(card,"%s  /  %d cm" % [p.role,p.heightCm],Vector2(26,564),25,game.MUTED)
  game.button(card,"更换球员",Rect2(26,652,410,72),func(): picking=i;page=0;query="";role_filter="全部";show_library(),true)
 game.text(game.ui,"阵容自动保存 · 用于星际杯与联机对战",Vector2(78,1230),25,game.MUTED)

func show_library()->void:
 game.clear_modal()
 game.clear_ui()
 game.camera_hub()
 game.screen="library"
 game.chrome("球员库")
 game.text(game.ui,"选择"+Squad.SLOTS[picking] if picking>=0 else "球员库",Vector2(76,160),48,game.INK,true)
 var list:Array=Library.all().filter(func(p): return (picking<0 or (p.role=="GK")== (picking==0)) and (role_filter=="全部" or p.role==role_filter) and (query.is_empty() or (str(p.name)+str(p.get("sourceName",""))+str(p.club)+str(p.role)).to_lower().contains(query.to_lower())))
 var pages:=maxi(1,ceili(list.size()/12.0))
 page=clampi(page,0,pages-1)
 game.text(game.ui,"%d 名球员" % Library.all().size(),Vector2(78,234),25,game.MUTED)
 var filter:=OptionButton.new()
 filter.position=Vector2(650,172)
 filter.size=Vector2(310,65)
 filter.add_theme_font_override("font",game.font)
 filter.add_theme_font_size_override("font_size",25)
 var roles:=["全部","GK","CB","RB","LB","DM","AM","RM","LM","RW","LW","ST"]
 for role in roles: filter.add_item("位置："+role)
 filter.select(roles.find(role_filter))
 filter.item_selected.connect(func(index): role_filter=roles[index];page=0;show_library())
 game.ui.add_child(filter)
 var search:=LineEdit.new()
 search.position=Vector2(1000,172)
 search.size=Vector2(760,65)
 search.text=query
 search.placeholder_text="搜索姓名、俱乐部或位置"
 search.add_theme_font_override("font",game.font)
 search.add_theme_font_size_override("font_size",28)
 game.ui.add_child(search)
 search.text_submitted.connect(func(value): query=value.strip_edges();page=0;show_library())
 game.button(game.ui,"搜索",Rect2(1780,172,185,65),func(): query=search.text.strip_edges();page=0;show_library())
 game.button(game.ui,"返回球队" if picking>=0 else "返回主菜单",Rect2(2110,172,375,65),show_squad if picking>=0 else game.show_menu)
 for i in mini(12,list.size()-page*12):
  var p:Dictionary=list[page*12+i]
  var x:=76+(i%4)*610
  var y:=320+(i/4)*286
  var card=game.panel(game.ui,Rect2(x,y,572,258))
  var picture:=TextureRect.new()
  picture.position=Vector2(10,10)
  picture.size=Vector2(170,226)
  picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  picture.texture=load(p.portrait)
  card.add_child(picture)
  game.text(card,p.name,Vector2(194,22),29,game.INK,true)
  game.text(card,"%s · %s · %d OVR" % [p.role,p.grade,p.overall],Vector2(194,70),22,game.CYAN)
  game.text(card,"%s / %d cm" % [p.nationality,p.heightCm],Vector2(194,112),20,game.MUTED)
  game.text(card,p.club,Vector2(194,149),20,game.MUTED,false,346)
  game.button(card,"球员资料",Rect2(194,195,345,48),func(): details(p)).set_meta("preferred_focus",i==0)
 if list.is_empty(): game.text(game.ui,"没有符合条件的球员",Vector2(900,680),36,game.MUTED)
 game.button(game.ui,"上一页",Rect2(76,1225,260,65),func(): page=maxi(0,page-1);show_library())
 game.text(game.ui,"%d / %d 页   ·   %d 条结果" % [page+1,pages,list.size()],Vector2(390,1238),27,game.INK)
 game.button(game.ui,"下一页",Rect2(840,1225,260,65),func(): page=mini(pages-1,page+1);show_library())
 game.text(game.ui,"总评为档案评级 · 比赛表现由单项能力与操作决定",Vector2(1310,1242),23,game.MUTED)

func details(p:Dictionary)->void:
 game.clear_modal()
 game.dim_modal()
 game.panel(game.modal,Rect2(360,190,1840,1090))
 game.text(game.modal,p.name+"  /  "+str(p.get("sourceName","")),Vector2(420,220),38,game.INK,true)
 game.text(game.modal,"%s · %s · %d cm · %s" % [p.club,p.role,p.heightCm,"左脚" if p.preferredFoot=="left" else ("双脚" if p.preferredFoot=="both" else "右脚")],Vector2(420,284),25,game.CYAN)
 var picture:=TextureRect.new()
 picture.position=Vector2(410,380)
 picture.size=Vector2(530,710)
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.texture=load(p.portrait)
 game.modal.add_child(picture)
 var i:=0
 for key in LABELS:
  var x:=1030+(i/13)*530
  var y:=360+(i%13)*55
  game.text(game.modal,LABELS[key],Vector2(x,y),27,game.MUTED if key in Ratings.ACTIVE else game.GOLD)
  game.text(game.modal,str(int(p.attributes[key])),Vector2(x+230,y),28,game.INK,true)
  i+=1
 game.text(game.modal,"逆足：%s     花式：%s" % [str(p.weakFoot) if p.weakFoot!=null else "来源未填写",str(p.skillMoves) if p.skillMoves!=null else "来源未填写"],Vector2(440,1120),24,game.MUTED)
 var style:=preload("res://player_style.gd").derive(p)
 game.text(game.modal,style.name+" · "+preload("res://player_style.gd").description(style),Vector2(1030,1090),21,game.GOLD,false,1070)
 var turning:=Ratings.derive(p.attributes,float(p.heightCm))
 game.text(game.modal,"180° 转身 %.3f 秒  ·  90° %.3f 秒  /  弹跳已接入起跳争顶" % [turning.turn_time,turning.turn_time/2],Vector2(1030,1130),22,game.CYAN)
 for slot in 5:
  var b=game.button(game.modal,("✓ " if Squad.ids[slot]==p.id else "")+Squad.SLOTS[slot],Rect2(430+slot*252,1180,230,60),func():
   if Squad.assign_player(p.id,slot):
    show_squad()
    game.toast(p.name+"已加入首发")
   else: game.toast("阵容保存失败，请重试"))
  b.disabled=(p.role=="GK")!=(slot==0) or (picking>=0 and picking!=slot)
 game.button(game.modal,"返回",Rect2(1730,1180,380,60),game.clear_modal)
