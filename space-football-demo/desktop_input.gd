extends Node
## Device detection and scoped UI navigation. Match simulation only receives commands.
signal changed
signal active_pad_lost
const Glyph=preload("res://input_glyph.gd")
var game:Node
var kind:="keyboard"
var active_pad:=-1
var devices:Dictionary={}
var glyph_override:="auto"
var assistance:=1
var pass_indicator:=true
var options:={"receive_assist":1,"shot_assist":1,"auto_switch":1,"vibration":1,"replay":1,"strict_rules":0,"alternate_directions":0,"camera_impact":1}
var scope:Control
var scope_key:=""
var focus_memory:Dictionary={}
var stick:=Vector2.ZERO
var dpad:=Vector2.ZERO
var held_direction:=Vector2.ZERO
var next_repeat_ms:=0
var neutral_required:=false
var status:Label
var status_icon:Control
var legend:Control
var legend_label:Label
var confirm_icon:Control
var back_icon:Control
var focus_badge:Control
var overlay:Control
var window_active:=true
var preferences_path:="user://input-preferences.cfg"

func _ready()->void:
 var config:=ConfigFile.new()
 if config.load(preferences_path)==OK:
  var stored:String=config.get_value("controller","glyphs","auto")
  if stored in ["auto","xbox","playstation","nintendo","generic"]: glyph_override=stored
  assistance=clampi(int(config.get_value("gameplay","assistance",1)),0,2)
  pass_indicator=bool(config.get_value("gameplay","pass_indicator",true))
  for key in options: options[key]=clampi(int(config.get_value("advanced",key,options[key])),0,2 if key in ["receive_assist","shot_assist","auto_switch","camera_impact"] else 1)
 Input.joy_connection_changed.connect(connection_changed)
 for id in Input.get_connected_joypads(): devices[id]=Input.get_joy_name(id)
 if not devices.is_empty():
  active_pad=devices.keys()[0];kind="gamepad"
  for id in devices:
   if classify(devices[id])=="xbox": active_pad=id;break
 var layer:=CanvasLayer.new()
 layer.layer=8
 add_child(layer)
 overlay=Control.new()
 overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(overlay)
 status_icon=make_glyph(overlay,Vector2(1760,36),"PAD")
 status=game.text(overlay,"",Vector2(1814,40),20,game.CYAN,false,650)
 status.max_lines_visible=1
 status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 legend=Control.new()
 legend.position=Vector2(680,1352)
 legend.mouse_filter=Control.MOUSE_FILTER_IGNORE
 overlay.add_child(legend)
 legend_label=game.text(legend,"",Vector2(0,8),21,game.MUTED)
 confirm_icon=make_glyph(legend,Vector2(670,0),"A")
 game.text(legend,"确认",Vector2(722,8),21,game.INK)
 back_icon=make_glyph(legend,Vector2(810,0),"B")
 game.text(legend,"返回",Vector2(862,8),21,game.INK)
 focus_badge=make_glyph(overlay,Vector2.ZERO,"A")
 update_prompts()

func make_glyph(parent:Node,where:Vector2,symbol:String)->Control:
 var icon:=Glyph.new()
 icon.position=where
 icon.size=Vector2(42,42)
 icon.face=game.font
 icon.token=symbol
 parent.add_child(icon)
 return icon

static func classify(name_value:String)->String:
 var value:=name_value.to_lower()
 if "xbox" in value or "xinput" in value or "x-box" in value: return "xbox"
 if "dualsense" in value or "dualshock" in value or "playstation" in value or "ps4" in value or "ps5" in value: return "playstation"
 if "nintendo" in value or "switch" in value: return "nintendo"
 return "generic"

func family()->String:
 return glyph_override if glyph_override!="auto" else classify(str(devices.get(active_pad,"")))

func symbol(action:String)->String:
 if action=="move": return "方向键" if kind!="gamepad" else "左摇杆"
 if action=="chip": return symbol("switch")
 if action=="cross": return "A" if kind!="gamepad" else {"playstation":"□","nintendo":"Y","generic":"左","xbox":"X"}.get(family(),"X")
 if action=="finesse": return "Z" if kind!="gamepad" else {"playstation":"R1","nintendo":"R","generic":"RB","xbox":"RB"}.get(family(),"RB")
 if kind!="gamepad":
  return {"accept":"Enter","back":"Esc","pause":"Esc","pass":"S","shoot":"D","through":"W","tackle":"D","switch":"Q","sprint":"E","jockey":"C","help":"F1","tactics":"1 / 2 / 3"}.get(action,action)
 if action=="tactics": return "十字键 ← / →"
 var map:Dictionary
 match family():
  "playstation": map={"accept":"×","back":"○","pass":"×","shoot":"○","through":"△","tackle":"○","switch":"L1","sprint":"R2","jockey":"L2","pause":"≡","help":"View"}
  "nintendo": map={"accept":"B","back":"A","pass":"B","shoot":"A","through":"X","tackle":"A","switch":"L","sprint":"ZR","jockey":"ZL","pause":"+","help":"−"}
  "generic": map={"accept":"下","back":"右","pass":"下","shoot":"右","through":"上","tackle":"右","switch":"LB","sprint":"RT","jockey":"LT","pause":"Menu","help":"View"}
  _: map={"accept":"A","back":"B","pass":"A","shoot":"B","through":"Y","tackle":"B","switch":"LB","sprint":"RT","jockey":"LT","pause":"≡","help":"View"}
 return map.get(action,action)

func connection_changed(id:int,connected:bool)->void:
 if connected:
  devices[id]=Input.get_joy_name(id)
  if active_pad<0: active_pad=id;kind="gamepad"
 else:
  devices.erase(id)
  if active_pad==id:
   var was_using:bool=kind=="gamepad"
   active_pad=devices.keys()[0] if not devices.is_empty() else -1
   kind="gamepad" if was_using and active_pad>=0 else "keyboard"
   stick=Vector2.ZERO;dpad=Vector2.ZERO
   if was_using:
    game.controls.reset()
    active_pad_lost.emit()
 update_prompts()

func observe(event:InputEvent)->void:
 var before:=str([kind,active_pad])
 if event is InputEventJoypadButton and event.pressed and devices.has(event.device):
  if active_pad!=event.device: stick=Vector2.ZERO;dpad=Vector2.ZERO
  active_pad=event.device;kind="gamepad"
 elif event is InputEventJoypadMotion and devices.has(event.device):
  var meaningful:bool=absf(event.axis_value)>0.35 if event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y] else event.axis_value>0.4
  if meaningful:
   if active_pad!=event.device: stick=Vector2.ZERO;dpad=Vector2.ZERO
   active_pad=event.device;kind="gamepad"
 elif event is InputEventKey and event.pressed:
  kind="keyboard"
 elif event is InputEventMouseButton and event.pressed:
  kind="keyboard"
 elif event is InputEventMouseMotion and event.relative.length()>4:
  kind="keyboard"
 if before!=str([kind,active_pad]):
  if kind=="keyboard": stick=Vector2.ZERO;dpad=Vector2.ZERO
  game.cancel_charge_input()
  update_prompts()

func update_prompts()->void:
 game.controls.assistance=assistance
 game.controls.receive_assist=options.receive_assist
 game.controls.shot_assist=options.shot_assist
 game.controls.auto_switch=options.auto_switch
 game.controls.key_bindings={"switch_up":KEY_I,"switch_down":KEY_K,"switch_left":KEY_J,"switch_right":KEY_L} if options.alternate_directions else {"switch_up":KEY_KP_8,"switch_down":KEY_KP_2,"switch_left":KEY_KP_4,"switch_right":KEY_KP_6}
 game.controls.gamepad=active_pad if kind=="gamepad" else -1
 if not is_instance_valid(status): return
 var connected_name:=str(devices.get(active_pad,""))
 status.text=(connected_name+" · "+("使用中" if kind=="gamepad" else "已连接 / 键鼠操作")) if not connected_name.is_empty() else "键盘 / 鼠标"
 status_icon.set_symbol("PAD" if not devices.is_empty() else "KB",family())
 confirm_icon.set_symbol(symbol("accept"),family())
 back_icon.set_symbol(symbol("back"),family())
 focus_badge.set_symbol(symbol("accept"),family())
 legend_label.text="左摇杆 / 十字键 选择" if kind=="gamepad" else "方向键 / WASD 选择   ·   Tab 切换"
 changed.emit()

func collect(root:Node)->Array[Control]:
 var result:Array[Control]=[]
 for child in root.get_children():
  if child is Control and child.is_visible_in_tree():
   if child is BaseButton and not child.disabled and child.focus_mode!=Control.FOCUS_NONE: result.append(child)
   elif child is LineEdit and child.editable: result.append(child)
   if child is LineEdit or child is OptionButton:
    if not child.has_meta("input_focus_style"):
     var outline:=StyleBoxFlat.new()
     outline.bg_color=Color(0.05,0.12,0.16,0.15)
     outline.border_color=Color("b1fff0")
     outline.set_border_width_all(3)
     outline.set_corner_radius_all(8)
     child.add_theme_stylebox_override("focus",outline)
     child.set_meta("input_focus_style",true)
   result.append_array(collect(child))
 return result

func sync_scope()->void:
 var next:Control=game.modal if game.modal.get_child_count()>0 else (null if game.screen=="match" or game.screen=="travel" else game.ui)
 var key:String=game.screen+("/modal" if next==game.modal else "/page")
 if scope!=next or scope_key!=key:
  var old_focus:=get_viewport().gui_get_focus_owner()
  if is_instance_valid(old_focus) and is_instance_valid(scope) and scope.is_ancestor_of(old_focus): focus_memory[scope_key]=weakref(old_focus)
  scope=next;scope_key=key
  neutral_required=stick.length()>0.45 or dpad.length()>0
  held_direction=Vector2.ZERO
  if is_instance_valid(old_focus): old_focus.release_focus()
  if scope!=null:
   var remembered=focus_memory.get(key)
   var remembered_node=remembered.get_ref() if remembered!=null else null
   if is_instance_valid(remembered_node) and remembered_node in collect(scope): remembered_node.grab_focus()
 if scope==null: return
 var items:=collect(scope)
 var focus:=get_viewport().gui_get_focus_owner()
 if focus not in items and not items.is_empty():
  var initial:Control=items[0]
  for item in items:
   if not item.get_meta("utility_focus",false): initial=item;break
  for item in items:
   if item.get_meta("preferred_focus",false): initial=item;break
  initial.grab_focus()

func step(dt:float)->void:
 if not window_active: return
 sync_scope()
 if not is_instance_valid(status): return
 status.position=Vector2(1814,225 if game.screen=="match" else 40)
 status_icon.position=Vector2(1760,status.position.y-4)
 legend.visible=scope!=null
 var focus:=get_viewport().gui_get_focus_owner()
 focus_badge.visible=scope!=null and kind=="gamepad" and is_instance_valid(focus) and focus is Button and not focus is OptionButton
 if focus_badge.visible:
  var rect:=focus.get_global_rect()
  var side:float=focus.get_meta("input_icon_size",32.0)
  focus_badge.size=Vector2(side,side)
  var caption_font:Font=focus.get_theme_font("font")
  var caption_width:float=caption_font.get_string_size(focus.text,HORIZONTAL_ALIGNMENT_LEFT,-1,focus.get_theme_font_size("font_size")).x
  var box:StyleBox=focus.get_theme_stylebox("normal")
  var caption_center:float=rect.get_center().x+(box.get_content_margin(SIDE_LEFT)-box.get_content_margin(SIDE_RIGHT))/2
  focus_badge.position=Vector2(minf(rect.end.x-side-10,caption_center+caption_width/2+12),rect.get_center().y-side/2)
  focus_badge.queue_redraw()
 var direction:=dpad if dpad.length()>0 else stick
 if direction.length()<0.35:
  neutral_required=false;held_direction=Vector2.ZERO
 if scope==null or kind!="gamepad" or neutral_required: return
 if direction.length()<0.55: return
 direction=Vector2(signf(direction.x),0) if absf(direction.x)>absf(direction.y) else Vector2(0,signf(direction.y))
 var now:=Time.get_ticks_msec()
 if direction!=held_direction:
  navigate(direction);held_direction=direction;next_repeat_ms=now+340
 elif now>=next_repeat_ms:
  navigate(direction);next_repeat_ms=now+130

func navigate(direction:Vector2,tabbing:bool=false)->void:
 if scope==null: return
 var items:=collect(scope)
 if items.is_empty(): return
 var focus:=get_viewport().gui_get_focus_owner()
 if focus not in items: items[0].grab_focus();return
 if tabbing:
  items[posmod(items.find(focus)+(1 if direction.x>=0 else -1),items.size())].grab_focus()
  return
 if focus is OptionButton and direction.x!=0:
  var next:=clampi(focus.selected+int(direction.x),0,focus.item_count-1)
  if next!=focus.selected: focus.select(next);focus.item_selected.emit(next)
  return
 var origin:=focus.get_global_rect().get_center()
 var best:Control=null
 var best_cost:=INF
 for item in items:
  if item==focus: continue
  var delta:=item.get_global_rect().get_center()-origin
  var forward:=delta.dot(direction)
  if forward<8: continue
  var across:=absf(delta.cross(direction))
  var cost:=forward+across*2.5+across*across/maxf(1,forward)
  if cost<best_cost: best=item;best_cost=cost
 if best!=null: best.grab_focus()

func route(event:InputEvent)->bool:
 if not window_active: return event is InputEventJoypadButton or event is InputEventJoypadMotion
 observe(event)
 sync_scope()
 if event is InputEventJoypadMotion and event.device==active_pad:
  if event.axis==JOY_AXIS_LEFT_X: stick.x=event.axis_value
  if event.axis==JOY_AXIS_LEFT_Y: stick.y=event.axis_value
  return scope!=null
 if event is InputEventJoypadButton and event.device!=active_pad: return true
 if scope==null: return false
 var focus:=get_viewport().gui_get_focus_owner()
 if event is InputEventJoypadButton:
  if event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]:
   var direction:Vector2={JOY_BUTTON_DPAD_LEFT:Vector2.LEFT,JOY_BUTTON_DPAD_RIGHT:Vector2.RIGHT,JOY_BUTTON_DPAD_UP:Vector2.UP,JOY_BUTTON_DPAD_DOWN:Vector2.DOWN}[event.button_index]
   if direction.x!=0: dpad.x=direction.x if event.pressed else 0
   else: dpad.y=direction.y if event.pressed else 0
   # Digital taps must work even when press and release arrive in the same frame.
   if event.pressed and not neutral_required:
    navigate(direction)
    held_direction=direction
    next_repeat_ms=Time.get_ticks_msec()+340
   elif not event.pressed and dpad==Vector2.ZERO:
    held_direction=Vector2.ZERO
    if stick.length()<0.35: neutral_required=false
   return true
  if event.pressed:
   if event.button_index==JOY_BUTTON_A: activate(focus)
   elif event.button_index in [JOY_BUTTON_B,JOY_BUTTON_START]: game.navigate_back()
  return true
 if event is InputEventKey:
  var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
  if code==KEY_ESCAPE:
   if event.pressed and not event.echo: game.navigate_back()
   return true
  if code==KEY_TAB:
   if event.pressed: navigate(Vector2.LEFT if event.shift_pressed else Vector2.RIGHT,true)
   return true
  if focus is LineEdit:
   if code in [KEY_UP,KEY_DOWN] and event.pressed: navigate(Vector2.UP if code==KEY_UP else Vector2.DOWN);return true
   return false
  var directions:={KEY_UP:Vector2.UP,KEY_W:Vector2.UP,KEY_DOWN:Vector2.DOWN,KEY_S:Vector2.DOWN,KEY_LEFT:Vector2.LEFT,KEY_A:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT,KEY_D:Vector2.RIGHT}
  if directions.has(code):
   if event.pressed: navigate(directions[code])
   return true
  if code in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
   if event.pressed and not event.echo: activate(focus)
   return true
 return false

func activate(focus:Control)->void:
 if not is_instance_valid(focus): return
 if focus is OptionButton:
  var next:int=(focus.selected+1)%focus.item_count
  focus.select(next);focus.item_selected.emit(next)
 elif focus is Button and not focus.disabled: focus.pressed.emit()
 elif focus is LineEdit: focus.text_submitted.emit(focus.text)

func suspend()->void:
 window_active=false
 reset_navigation()
 game.controls.reset()

func reset_navigation()->void:
 stick=Vector2.ZERO;dpad=Vector2.ZERO;held_direction=Vector2.ZERO
 neutral_required=false;next_repeat_ms=0

func save_preferences()->bool:
 var config:=ConfigFile.new()
 config.set_value("controller","glyphs",glyph_override)
 config.set_value("gameplay","assistance",assistance)
 config.set_value("gameplay","pass_indicator",pass_indicator)
 for key in options: config.set_value("advanced",key,options[key])
 return config.save(preferences_path)==OK
