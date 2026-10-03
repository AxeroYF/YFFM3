extends RefCounted
## Input collection has no simulation authority. Actions are consumed once per command.
var pending:=0
var tactic:=1
var last_aim:=0.0
var gamepad:=-1
var shot_held:=false
var has_ball:=false
var controlled_player:=-1
var enabled:=true
var assistance:=1
var aerial_available:=false
var receiving:=false
var team_attacking:=false
var restart:=false
var restart_preparing:=false
var skip_held:=false
var skip_block_release:=false
var receive_assist:=-1
var shot_assist:=-1
var auto_switch:=1
var pre_shot:=false
var pass_held:=0
var pass_started:=0
var power:=0.35
var direction:=Vector2.ZERO
var right_stick:=Vector2.ZERO
var stick_latched:=false
var modifier_used:={"left":false,"right":false}
var modifier_down:={"left":false,"right":false}
var modifier_since:={"left":0,"right":0}
var shot_started:=0
var release_finesse:=false
var release_chip:=false
var key_bindings:={"switch_up":KEY_KP_8,"switch_down":KEY_KP_2,"switch_left":KEY_KP_4,"switch_right":KEY_KP_6}
const Extra=preload("res://match_mechanics.gd")
const Provider=preload("res://input_provider.gd")
var external_provider:Provider

func movement()->Vector2:
 var move:=Vector2.ZERO
 if not enabled: return move
 if Input.is_physical_key_pressed(KEY_LEFT): move.x-=1
 if Input.is_physical_key_pressed(KEY_RIGHT): move.x+=1
 if Input.is_physical_key_pressed(KEY_UP): move.y-=1
 if Input.is_physical_key_pressed(KEY_DOWN): move.y+=1
 if gamepad>=0:
  var stick:=Vector2(Input.get_joy_axis(gamepad,JOY_AXIS_LEFT_X),Input.get_joy_axis(gamepad,JOY_AXIS_LEFT_Y))
  if stick.length()>0.18: move=stick.normalized()*clampf((stick.length()-0.18)/0.82,0,1)
 return move.limit_length()

func command()->Dictionary:
 if external_provider!=null:
  if enabled:
   var sample:Dictionary=external_provider.sample()
   sample["assist"]=assistance
   sample["assist_active"]=true
   sample["receive_assist"]=receive_assist
   sample["shot_assist"]=shot_assist
   sample["auto_switch"]=auto_switch
   return sample
  external_provider.reset()
  return {"move":Vector2.ZERO,"sprint":false,"jockey":false,"action":0,"aim":0.0,"tactic":tactic,"assist":assistance,"assist_active":false}
 var move:=movement()
 if absf(move.y)>0.1: last_aim=move.y
 var sprint:=enabled and Input.is_physical_key_pressed(KEY_E)
 var jockey:=enabled and Input.is_physical_key_pressed(KEY_C)
 var finesse:=enabled and Input.is_physical_key_pressed(KEY_Z)
 var chip:=enabled and Input.is_physical_key_pressed(KEY_Q)
 var keeper_rush:=enabled and not has_ball and Input.is_physical_key_pressed(KEY_W)
 if gamepad>=0 and enabled:
  sprint=sprint or Input.get_joy_axis(gamepad,JOY_AXIS_TRIGGER_RIGHT)>0.25
  jockey=jockey or Input.get_joy_axis(gamepad,JOY_AXIS_TRIGGER_LEFT)>0.25
  finesse=finesse or Input.is_joy_button_pressed(gamepad,JOY_BUTTON_RIGHT_SHOULDER)
  chip=chip or Input.is_joy_button_pressed(gamepad,JOY_BUTTON_LEFT_SHOULDER)
  keeper_rush=keeper_rush or (not has_ball and Input.is_joy_button_pressed(gamepad,JOY_BUTTON_Y))
 finesse=finesse or modifier_down.right or release_finesse
 chip=chip or modifier_down.left or release_chip
 var contain:bool=enabled and not team_attacking and finesse
 var result:={"move":move,"sprint":sprint,"jockey":jockey,"action":pending if enabled else 0,"aim":last_aim,"tactic":tactic,"assist":assistance,"assist_active":enabled,"finesse":finesse,"chip":chip,"keeper_rush":keeper_rush,"power":power,"direction":direction,"driven":finesse,"contain":contain,"receive_assist":receive_assist,"shot_assist":shot_assist,"auto_switch":auto_switch}
 pending=0;release_finesse=false;release_chip=false
 result.skip_restart=enabled and restart_preparing and skip_held
 return result

func sync_context(selected:int,owner:int,current_tactic:int)->void:
 # Latch the action at press time. Losing possession or switching players cancels
 # the shot, so its release cannot shoot after a tackle, regain or menu transition.
 if (shot_held or (pending&3)!=0) and ((owner!=selected and not (pre_shot and receiving)) or controlled_player!=selected): cancel_shot()
 if pass_held!=0 and (controlled_player!=selected or (owner!=selected and not receiving)): pass_held=0
 controlled_player=selected
 has_ball=owner==selected
 if has_ball and pre_shot and shot_held: pre_shot=false;pending|=1
 if (pending&64)==0: tactic=current_tactic

func cancel_shot()->void:
 pending=(pending&~3)|128
 shot_held=false
 pre_shot=false

func primary_action(pressed:bool)->void:
 if pressed:
  if shot_held: return
  if not has_ball and aerial_available:
   pending|=1024;return
  if has_ball or receiving:
   pre_shot=not has_ball
   if not pre_shot: pending|=1
   shot_held=true
   shot_started=Time.get_ticks_msec()
   modifier_used.left=modifier_down.left;modifier_used.right=modifier_down.right
  else: pending|=1024 if aerial_available else 32
 elif shot_held:
  release_finesse=modifier_down.right;release_chip=modifier_down.left
  modifier_used.left=modifier_down.left;modifier_used.right=modifier_down.right
  if pre_shot:
   pending|=Extra.SHOT_BUFFER;power=clampf(float(Time.get_ticks_msec()-shot_started)/850,0.18,0.8)
  else: pending|=2
  shot_held=false
  pre_shot=false

func passing(action:int,pressed:bool)->void:
 if action==4 and (restart_preparing or skip_block_release):
  skip_held=pressed;skip_block_release=pressed
  pass_held=0;pending&=~4
  return
 if pressed:
  if shot_held and action==4: cancel_shot();pending|=2048;return
  if shot_held: cancel_shot()
  if has_ball or receiving:
   pass_held=action;pass_started=Time.get_ticks_msec()
   modifier_used.left=modifier_down.left;modifier_used.right=modifier_down.right
  else: pending|=action
 elif pass_held==action:
  release_finesse=modifier_down.right;release_chip=modifier_down.left
  modifier_used.left=modifier_down.left;modifier_used.right=modifier_down.right
  power=clampf(0.28+float(Time.get_ticks_msec()-pass_started)/800,0.28,1)
  pending|=action;pass_held=0

func modifier(side:String,pressed:bool)->void:
 modifier_down[side]=pressed
 if pressed:
  modifier_used[side]=false;modifier_since[side]=Time.get_ticks_msec()
  if side=="left" and not team_attacking and not has_ball and not receiving: pending|=16
 elif team_attacking and not modifier_used[side] and Time.get_ticks_msec()-modifier_since[side]<260:
  pending|=Extra.RUN if side=="left" else Extra.SUPPORT

func directional(value:Vector2)->void:
 direction=value.normalized()
 pending|=Extra.SKILL if has_ball else Extra.SWITCH

func handle(event:InputEvent)->bool:
 if not enabled: return false
 if event is InputEventJoypadMotion and event.device==gamepad and event.axis in [JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:
  if event.axis==JOY_AXIS_RIGHT_X: right_stick.x=event.axis_value
  else: right_stick.y=event.axis_value
  if right_stick.length()<0.25: stick_latched=false
  elif right_stick.length()>0.65 and not stick_latched:
   directional(right_stick);stick_latched=true
  return true
 if event is InputEventKey:
  if event.echo: return false
  var code:int=event.physical_keycode
  if code in [KEY_Q,KEY_Z]: modifier("left" if code==KEY_Q else "right",event.pressed);return true
  if code in [KEY_S,KEY_W]: passing(4 if code==KEY_S else 8,event.pressed);return true
  if code==KEY_A and (has_ball or receiving or aerial_available or pass_held==256): passing(256,event.pressed);return true
  if event.pressed and code in key_bindings.values():
   var key:String=key_bindings.find_key(code)
   directional({"switch_up":Vector2.UP,"switch_down":Vector2.DOWN,"switch_left":Vector2.LEFT,"switch_right":Vector2.RIGHT}[key]);return true
  if event.pressed and code in [KEY_4,KEY_5]: pending|=Extra.SET_PIECE;direction=Vector2.LEFT if code==KEY_4 else Vector2.RIGHT;return true
  if event.pressed and code==KEY_BACKSPACE: pending|=Extra.CANCEL|128;pass_held=0;cancel_shot();return true
  if code==KEY_D:
   primary_action(event.pressed)
   return true
  if not event.pressed: return false
  if code==KEY_S:
   if shot_held: cancel_shot();pending|=2048
   else: pending|=4
  elif code==KEY_A:
   if shot_held: cancel_shot()
   pending|=256 if has_ball else 512
  elif code==KEY_W:
   if shot_held: cancel_shot()
   pending|=8
  elif code==KEY_Q:
   if not has_ball: pending|=16
  elif code in [KEY_1,KEY_2,KEY_3]: pending|=64; tactic=code-KEY_1
  else: return false
  return true
 if event is InputEventJoypadButton:
  if event.device!=gamepad: return false
  if event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]: modifier("left" if event.button_index==JOY_BUTTON_LEFT_SHOULDER else "right",event.pressed);return true
  if event.button_index in [JOY_BUTTON_A,JOY_BUTTON_Y]: passing(4 if event.button_index==JOY_BUTTON_A else 8,event.pressed);return true
  if event.button_index==JOY_BUTTON_X and (has_ball or receiving or aerial_available or pass_held==256): passing(256,event.pressed);return true
  if event.pressed and event.button_index in [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN] and restart:
   pending|=Extra.SET_PIECE;direction=Vector2.LEFT if event.button_index==JOY_BUTTON_DPAD_UP else Vector2.RIGHT;return true
  if event.pressed and event.button_index==JOY_BUTTON_RIGHT_STICK:
   pending|=Extra.CANCEL|128;pass_held=0;cancel_shot();return true
  if event.button_index==JOY_BUTTON_B:
   primary_action(event.pressed)
   return true
  if not event.pressed: return false
  if event.button_index==JOY_BUTTON_A:
   if shot_held: cancel_shot();pending|=2048
   else: pending|=4
  elif event.button_index==JOY_BUTTON_X:
   if shot_held: cancel_shot()
   pending|=256 if has_ball else 512
  elif event.button_index==JOY_BUTTON_Y:
   if shot_held: cancel_shot()
   pending|=8
  elif event.button_index==JOY_BUTTON_LEFT_SHOULDER:
   if not has_ball: pending|=16
  elif event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:
   pending|=64
   tactic=clampi(tactic+(-1 if event.button_index==JOY_BUTTON_DPAD_LEFT else 1),0,2)
  else: return false
  return true
 return false

func reset()->void:
 skip_held=false;skip_block_release=false;restart_preparing=false
 pending=0
 release_finesse=false;release_chip=false
 shot_held=false
 has_ball=false
 controlled_player=-1
 aerial_available=false
 receiving=false;team_attacking=false;pass_held=0;pre_shot=false
 modifier_down={"left":false,"right":false};modifier_used={"left":false,"right":false}
 direction=Vector2.ZERO;right_stick=Vector2.ZERO;stick_latched=false
 last_aim=0
 if external_provider!=null: external_provider.reset()
