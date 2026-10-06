extends RefCounted
const Palette=preload("res://ui_palette.gd")
## UI construction and binding glyphs; actions are supplied by the screen owner.
const INK=Palette.INK
const CYAN=Palette.CYAN
const MUTED=Palette.MUTED
const GOLD=Palette.GOLD
const InputGlyph=preload("res://input_glyph.gd")
signal sound_requested(frequency:float,duration:float)
var desktop_input:Node
var font: SystemFont
var bold: SystemFont
var binding_icons:Array[Control]=[]
var binding_labels:Array[Label]=[]
func style(bg: Color, border: Color=Color.TRANSPARENT, radius: int=12) -> StyleBoxFlat:
 var s:=StyleBoxFlat.new()
 s.bg_color=bg
 s.border_color=border
 s.set_border_width_all(1)
 s.set_corner_radius_all(radius)
 s.content_margin_left=24
 s.content_margin_right=24
 return s

func panel(parent: Control, rect: Rect2, bg: Color=Color(0.027,0.048,0.081,0.93), border: Color=Color(0.25,0.48,0.61,0.4),radius:int=12) -> Panel:
 var p:=Panel.new()
 p.position=rect.position
 p.size=rect.size
 p.add_theme_stylebox_override("panel",style(bg,border,radius))
 p.mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(p)
 return p

func text(parent: Control, value: String, pos: Vector2, size_value: int=26, color: Color=INK, heavy: bool=false, width: float=0) -> Label:
 var label:=Label.new()
 label.text=value
 label.position=pos
 label.add_theme_font_override("font",bold if heavy else font)
 label.add_theme_font_size_override("font_size",size_value)
 label.add_theme_color_override("font_color",color)
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if width>0:
  label.size.x=width
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 parent.add_child(label)
 return label

func binding_hint(parent:Control,action:String,caption:String,pos:Vector2)->void:
 var icon:=InputGlyph.new()
 icon.size=Vector2(42,42)
 icon.position=pos
 icon.face=font
 icon.set_meta("binding_action",action)
 parent.add_child(icon)
 binding_icons.append(icon)
 text(parent,caption,pos+Vector2(52,7),22,INK)
 refresh_binding_hints()

func button_binding(parent:Button,action:String)->void:
 var icon:=InputGlyph.new()
 var side:float=parent.get_meta("input_icon_size",32.0)
 icon.size=Vector2(side,side)
 icon.position=Vector2(10,(parent.size.y-side)/2)
 icon.face=font
 icon.set_meta("binding_action",action)
 for state in ["normal","hover","pressed","disabled"]:
  var box:StyleBoxFlat=parent.get_theme_stylebox(state).duplicate()
  box.content_margin_left=side+22
  box.content_margin_right=12
  parent.add_theme_stylebox_override(state,box)
 parent.add_child(icon)
 binding_icons.append(icon)
 refresh_binding_hints()

func binding_text(parent:Control,template:String,actions:Array,pos:Vector2,size_value:int=24,color:Color=INK)->Label:
 var label:=text(parent,"",pos,size_value,color)
 label.set_meta("binding_template",template)
 label.set_meta("binding_actions",actions)
 binding_labels.append(label)
 refresh_binding_hints()
 return label

func refresh_binding_hints()->void:
 if not is_instance_valid(desktop_input): return
 binding_icons=binding_icons.filter(func(icon): return is_instance_valid(icon))
 binding_labels=binding_labels.filter(func(label): return is_instance_valid(label))
 for icon in binding_icons: icon.set_symbol(desktop_input.symbol(icon.get_meta("binding_action")),desktop_input.family())
 for label in binding_labels:
  var tokens:Array=[]
  for action in label.get_meta("binding_actions"):
   tokens.append(("左摇杆" if desktop_input.kind=="gamepad" else "方向键") if action=="move" else desktop_input.symbol(action))
  label.text=label.get_meta("binding_template") % tokens

func button(parent: Control, value: String, rect: Rect2, action: Callable, primary: bool=false) -> Button:
 var b:=Button.new()
 b.text=value
 b.position=rect.position
 b.size=rect.size
 b.focus_mode=Control.FOCUS_ALL
 b.set_meta("preferred_focus",primary)
 var outline:=style(Color(0.13,0.45,0.48,0.14),Color("b1fff0"))
 outline.set_border_width_all(4)
 outline.expand_margin_left=4
 outline.expand_margin_right=4
 outline.expand_margin_top=4
 outline.expand_margin_bottom=4
 b.add_theme_stylebox_override("focus",outline)
 b.add_theme_font_override("font",bold)
 b.add_theme_font_size_override("font_size",26)
 b.add_theme_color_override("font_color",Color("10282a") if primary else INK)
 b.add_theme_color_override("font_hover_color",Color("10282a") if primary else Color.WHITE)
 b.add_theme_color_override("font_focus_color",Color("10282a") if primary else Color.WHITE)
 b.add_theme_color_override("font_disabled_color",Color("586e80"))
 b.add_theme_stylebox_override("normal",style(CYAN if primary else Color("172a40"),CYAN if primary else Color("38546d")))
 b.add_theme_stylebox_override("hover",style(Color("a6ffef") if primary else Color("29405b"),CYAN))
 b.add_theme_stylebox_override("pressed",style(Color("52bba9") if primary else Color("101d30"),CYAN))
 b.add_theme_stylebox_override("disabled",style(Color("111d2d"),Color("233447")))
 # Reserve space on both sides: shortcut at left, focused confirm beside caption at right.
 var icon_side:=clampf(rect.size.y-22,22,32 if rect.size.x<240 else 56 if rect.size.y>=90 else 44)
 var inset:=icon_side+22
 var left_inset:=12.0 if rect.size.x<240 else inset
 b.set_meta("input_icon_size",icon_side)
 for state in ["normal","hover","pressed","disabled"]:
  var box:StyleBoxFlat=b.get_theme_stylebox(state).duplicate()
  box.content_margin_left=left_inset
  box.content_margin_right=inset
  b.add_theme_stylebox_override(state,box)
 var caption_width:=bold.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x
 var fit:=mini(26,maxi(12,floori(26.0*maxf(1,rect.size.x-left_inset-inset)/maxf(1,caption_width))))
 b.add_theme_font_size_override("font_size",fit)
 b.pressed.connect(func(): sound_requested.emit(550,0.07); action.call())
 parent.add_child(b)
 return b
