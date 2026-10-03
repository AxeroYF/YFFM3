extends Control
## Code-drawn glyphs stay crisp at the viewport's physical resolution.
var token:="A"
var family:="xbox"
var face:Font

func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 custom_minimum_size=Vector2(20,20)

func _draw()->void:
 var rect:=Rect2(Vector2(2,2),size-Vector2(4,4))
 var color:=Color("e5f6fa")
 if family=="xbox": color={"A":Color("7ee09b"),"B":Color("ff8484"),"X":Color("8fc4ff"),"Y":Color("ffdc85")}.get(token,color)
 if token=="PAD":
  var outline:=PackedVector2Array([Vector2(7,12),Vector2(16,9),Vector2(29,9),Vector2(37,13),Vector2(41,31),Vector2(35,34),Vector2(28,26),Vector2(16,26),Vector2(9,34),Vector2(3,30),Vector2(7,12)])
  draw_polyline(outline,color,2,true)
  draw_line(Vector2(10,18),Vector2(20,18),color,2)
  draw_line(Vector2(15,13),Vector2(15,23),color,2)
  draw_circle(Vector2(29,17),2,color)
  draw_circle(Vector2(34,22),2,color)
  return
 if token.length()<=1:
  draw_circle(size/2,rect.size.x/2,Color("122a3a"))
  draw_arc(size/2,rect.size.x/2,0,TAU,48,color,2,true)
 else:
  var box:=StyleBoxFlat.new()
  box.bg_color=Color("122a3a")
  box.border_color=color
  box.set_border_width_all(2)
  box.set_corner_radius_all(7)
  draw_style_box(box,rect)
 var draw_font:Font=face if face!=null else ThemeDB.fallback_font
 var text_size:=roundi(size.y*0.52) if token.length()<4 else roundi(size.y*0.31)
 var extent:=draw_font.get_string_size(token,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size)
 draw_string(draw_font,Vector2((size.x-extent.x)/2,(size.y+draw_font.get_ascent(text_size)-draw_font.get_descent(text_size))/2),token,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size,color)

func set_symbol(value:String,kind:String)->void:
 if token==value and family==kind: return
 token=value
 family=kind
 queue_redraw()
