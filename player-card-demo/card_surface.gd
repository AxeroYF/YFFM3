extends Control

var theme_id := 0
var layer_kind := 0
var accent := Color("edc983")
var record: Dictionary
var font: Font
var bold: Font
var flag_texture: Texture2D
var badge_texture: Texture2D
const SERIES = ["S O L A R   L E G A C Y", "D E E P S P A C E   A L L O Y", "P R I S M   A S C E N D A N T"]
const ENGLISH_NAMES = ["LIONEL MESSI", "ERLING HAALAND", "JUDE BELLINGHAM"]

func label_at(text: String, point: Vector2, font_size: int, color: Color, heavy: bool=false, width: float=0, align: HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label:=Label.new()
	label.text=text
	label.position=point
	label.add_theme_font_override("font",bold if heavy else font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.55))
	label.add_theme_constant_override("shadow_offset_y",2)
	label.horizontal_alignment=align
	if width>0: label.size.x=width
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	if layer_kind==0: return
	flag_texture=load("res://assets/identities/"+["ar.svg","no.svg","gb-eng.svg"][theme_id])
	badge_texture=load("res://assets/identities/"+["barcelona.webp","manchester-city.webp","real-madrid.webp"][theme_id])
	label_at(SERIES[theme_id],Vector2(60,50),17,accent,false,600,HORIZONTAL_ALIGNMENT_CENTER)
	label_at(str(int(record.overall)),Vector2(56,127),102,accent,true)
	label_at(record.role,Vector2(65,248),30,accent,true)
	label_at("评级",Vector2(579,138),15,accent,false,74,HORIZONTAL_ALIGNMENT_CENTER)
	label_at(record.grade,Vector2(579,157),44,accent,true,74,HORIZONTAL_ALIGNMENT_CENTER)
	label_at(record.name,Vector2(40,752),45,Color("f3f4ee"),true,640,HORIZONTAL_ALIGNMENT_CENTER)
	label_at(ENGLISH_NAMES[theme_id],Vector2(40,813),23,accent,true,640,HORIZONTAL_ALIGNMENT_CENTER)
	var keys:=["pace","finishing","passing","dribbling","stamina","strength"]
	var labels:=["速度","射门","传球","盘带","体能","力量"]
	for i in 6:
		var col:=i%3
		var row:=i/3
		var x:=64+col*207
		var y:=888+row*63
		label_at(str(int(record.attributes[keys[i]])),Vector2(x,y-8),38,Color("e7edf2"),true)
		label_at(labels[i],Vector2(x+65,y+4),19,Color("9faab4"))
	label_at("Y F F M   /   O R I G I N   C O L L E C T I O N",Vector2(40,1031),12,accent,false,640,HORIZONTAL_ALIGNMENT_CENTER)

func outline(inset: float, cut: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(inset+cut,inset),Vector2(720-inset-cut,inset),Vector2(720-inset,inset+cut),Vector2(720-inset,1080-inset-cut),Vector2(720-inset-cut,1080-inset),Vector2(inset+cut,1080-inset),Vector2(inset,1080-inset-cut),Vector2(inset,inset+cut),Vector2(inset+cut,inset)])

func _draw() -> void:
	if layer_kind==0:
		for i in [3,8,18]:
			var c:=Color(accent,0.28 if i==8 else 0.65)
			draw_polyline(outline(i,29),c,1.5,true)
		draw_polyline(outline(23,22),Color(accent,0.38),1,true)
		draw_polyline(outline(28,20),Color(accent,0.10),1,true)
		for side in [0,1]:
			var x:=36.0 if side==0 else 684.0
			for j in 12:
				draw_line(Vector2(x,620+j*9),Vector2(x+(9 if side==0 else -9),620+j*9),Color(accent,0.3),1,true)
		for p in [Vector2(35,55),Vector2(685,55),Vector2(35,1025),Vector2(685,1025)]:
			draw_circle(p,2,accent)
		# Theme-specific mechanical corner geometry.
		if theme_id==1:
			for x in [36,645]:
				draw_colored_polygon(PackedVector2Array([Vector2(x,74),Vector2(x+39,74),Vector2(x+39,95),Vector2(x+12,122),Vector2(x,122)]),Color(accent,0.45))
		elif theme_id==2:
			for j in 4:
				draw_line(Vector2(72+j*10,95),Vector2(116+j*10,95),Color(0.7+0.08*j,0.8,1.0,0.35),1,true)
	else:
		for column in 130:
			var opacity:=0.45*(1.0-float(column)/130.0)
			draw_rect(Rect2(43+column,126,1,308),Color(0.01,0.02,0.03,opacity))
		draw_line(Vector2(67,293),Vector2(128,293),Color(accent,0.65),1.2,true)
		if flag_texture: draw_texture_rect(flag_texture,Rect2(65,321,50,37),false)
		if badge_texture: draw_texture_rect(badge_texture,Rect2(65,382,50,50),false)
		var badge:=PackedVector2Array([Vector2(579,126),Vector2(653,126),Vector2(653,204),Vector2(616,221),Vector2(579,204),Vector2(579,126)])
		draw_colored_polygon(badge,Color(0.01,0.025,0.035,0.40))
		draw_polyline(badge,Color(accent,0.55),1.3,true)
		draw_line(Vector2(58,865),Vector2(662,865),Color(accent,0.32),1,true)
		draw_line(Vector2(58,1008),Vector2(662,1008),Color(accent,0.25),1,true)
		for x in [253,460]: draw_line(Vector2(x,890),Vector2(x,986),Color(accent,0.16),1,true)
		var cy:=727.0
		draw_line(Vector2(231,cy),Vector2(326,cy),Color(accent,0.5),1,true)
		draw_line(Vector2(394,cy),Vector2(489,cy),Color(accent,0.5),1,true)
		var diamond:=PackedVector2Array([Vector2(360,cy-10),Vector2(370,cy),Vector2(360,cy+10),Vector2(350,cy)])
		draw_colored_polygon(diamond,accent)
		draw_circle(Vector2(360,cy),17,Color(accent,0.35),false,1,true)
