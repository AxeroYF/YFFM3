extends RefCounted
var game:Node
var checks:=0
var failures:=0
const DEVICE:=93

func check(condition:bool,description:String)->void:
 checks+=1
 if not condition:
  failures+=1
  push_error("INPUT_CHECK_FAILED: "+description)

func settle()->void:
 await game.get_tree().process_frame
 await game.get_tree().process_frame
 var frames:=0
 while game.loader.active and frames<1800:
  await game.get_tree().process_frame
  frames+=1
 if game.loader.active:
  check(false,"loading did not complete before input timeout")
  game.get_tree().quit(2)

func pad(button:int,pressed:bool=true)->void:
 var event:=InputEventJoypadButton.new()
 event.device=DEVICE
 event.button_index=button
 event.pressed=pressed
 game.get_viewport().push_input(event)
 await settle()

func tap(button:int)->void:
 if button in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]:
  var event:=InputEventJoypadButton.new()
  event.device=DEVICE
  event.button_index=button
  event.pressed=true
  game.get_viewport().push_input(event)
  event.pressed=false
  game.get_viewport().push_input(event)
  await settle()
  return
 await pad(button)
 await pad(button,false)

func key(code:int)->void:
 var event:=InputEventKey.new()
 event.physical_keycode=code
 event.keycode=code
 if code>=KEY_A and code<=KEY_Z: event.unicode=code+32
 event.pressed=true
 game.get_viewport().push_input(event)
 await settle()
 event.pressed=false
 game.get_viewport().push_input(event)
 await settle()

func focused()->Control:
 return game.get_viewport().gui_get_focus_owner()

func focus_button(prefix:String)->void:
 var scope:Control=game.desktop_input.scope
 for item in game.desktop_input.collect(scope):
  if item is Button and item.text.begins_with(prefix): item.grab_focus();return
 check(false,"button exists: "+prefix)

func run(target:Node)->void:
 game=target
 var router=game.desktop_input
 print("PHYSICAL_CONTROLLERS ",router.devices)
 # Virtual event source only; this does not install drivers or emulate hardware.
 router.devices[DEVICE]="Xbox Wireless Controller"
 router.glyph_override="auto"
 router.active_pad=DEVICE
 router.kind="gamepad"
 router.window_active=true
 router.update_prompts()
 game.show_menu()
 await settle()
 check(focused() is Button and focused().text.begins_with("联机"),"menu starts focused without mouse")
 check(focused().get_global_rect().encloses(router.focus_badge.get_global_rect()),"controller confirm glyph stays inside focused button")
 await game.capture("controller-main-menu")
 await tap(JOY_BUTTON_DPAD_DOWN)
 check(focused().text=="快速比赛","dpad chooses next main action")
 await tap(JOY_BUTTON_A)
 check(game.modal.get_child_count()>0 and game.modal.is_ancestor_of(focused()),"A opens modal with isolated focus")
 check(focused().text=="开始比赛","modal focuses primary action")
 await tap(JOY_BUTTON_B)
 check(game.modal.get_child_count()==0 and focused().text=="快速比赛","B closes and restores underlying focus")
 await key(KEY_UP)
 check(router.kind=="keyboard" and focused().text.begins_with("联机"),"keyboard navigation switches hints")
 await tap(JOY_BUTTON_DPAD_DOWN)
 check(router.kind=="gamepad" and router.symbol("accept")=="A","controller input restores Xbox hints")
 await tap(JOY_BUTTON_A)
 await tap(JOY_BUTTON_A)
 check(game.screen=="match" and game.sim.passes[0]==0,"confirming match does not also pass")
 check(focused()==null,"HUD does not retain GUI focus while playing")
 for icon in game.binding_icons:
  if is_instance_valid(icon) and icon.get_parent() is Button:
   check(icon.get_parent().get_global_rect().encloses(icon.get_global_rect()),"HUD shortcut glyph stays inside button")
 var axis:=InputEventJoypadMotion.new()
 axis.device=DEVICE
 axis.axis=JOY_AXIS_LEFT_X
 axis.axis_value=0.85
 Input.parse_input_event(axis)
 await settle()
 check(game.controls.movement().x>0.5,"selected controller left stick supplies match movement")
 axis.axis_value=0.12
 Input.parse_input_event(axis)
 await settle()
 check(game.controls.movement()==Vector2.ZERO,"stick deadzone rejects drift")
 axis.axis_value=0
 Input.parse_input_event(axis)
 check(preload("res://restart_impact_tests.gd").prepare(game.sim),"kickoff preparation finishes")
 game.sim.freeze=0
 game.sim.owner=game.sim.selected
 await pad(JOY_BUTTON_B)
 await game.get_tree().physics_frame
 await settle()
 check(game.sim.charging,"Xbox B begins charging")
 await tap(JOY_BUTTON_START)
 check(game.screen=="pause" and not game.sim.charging,"Menu pauses and cancels charging")
 check(focused().text=="继续比赛","pause has default continue focus")
 var before:float=game.sim.elapsed
 await game.get_tree().create_timer(0.12).timeout
 check(game.sim.elapsed==before,"local match time stays frozen")
 await game.capture("controller-pause")
 await tap(JOY_BUTTON_DPAD_DOWN)
 check(focused().text=="同阵容重赛","pause options navigable with dpad; actual="+focused().text)
 for i in 8:
  await tap(JOY_BUTTON_DPAD_RIGHT)
  check(game.modal.is_ancestor_of(focused()),"pause focus cannot escape to HUD")
 await pad(JOY_BUTTON_B,false)
 var shots:int=game.sim.shots[0]
 await tap(JOY_BUTTON_B)
 check(game.screen=="match" and game.sim.shots[0]==shots,"B resumes without shooting or tackling")
 await pad(JOY_BUTTON_B,false)
 check(game.controls.pending==0,"orphan shot release ignored")
 check(preload("res://restart_impact_tests.gd").prepare(game.sim),"kickoff preparation finishes")
 game.sim.freeze=0
 game.sim.owner=game.sim.selected
 await pad(JOY_BUTTON_B)
 await game.get_tree().physics_frame
 await settle()
 await key(KEY_W)
 check(not game.controls.shot_held and not game.sim.charging,"switching to keyboard cancels controller charge")
 await key(KEY_F1)
 check(game.screen=="help" and router.symbol("shoot")=="D" and router.symbol("pass")=="S","help shows classic keyboard bindings")
 await game.capture("classic-controls-keyboard")
 await tap(JOY_BUTTON_B)
 check(game.screen=="match" and game.controls.pending==0,"B closing help never leaks into tackle or shot")
 await tap(JOY_BUTTON_BACK)
 check(game.screen=="help" and router.symbol("shoot")=="B","help switches to classic Xbox bindings")
 await game.capture("classic-controls-xbox")
 await tap(JOY_BUTTON_B)
 await tap(JOY_BUTTON_START)
 router.connection_changed(DEVICE,false)
 await settle()
 check(game.controls.pending==0 and DEVICE not in router.devices,"disconnect clears input state")
 await key(KEY_ENTER)
 check(game.screen=="match","keyboard continues after disconnect")
 router.devices[DEVICE]="Sony DualSense Wireless Controller"
 await tap(JOY_BUTTON_START)
 check(router.family()=="playstation" and router.symbol("accept")=="×" and router.symbol("shoot")=="○","PlayStation uses classic circle shooting")
 await game.capture("controller-playstation-pause")
 router.devices[DEVICE]="Unknown USB Gamepad"
 router.update_prompts()
 check(router.symbol("accept")=="下","unknown pads have honest positional glyphs")
 router.glyph_override="xbox"
 router.update_prompts()
 check(router.symbol("accept")=="A","manual glyph override handles misidentified controllers")
 router.glyph_override="auto"
 router.devices[DEVICE]="Xbox Wireless Controller"
 router.update_prompts()
 game.show_menu()
 game.library_screen.open_catalog()
 await settle()
 focus_button("球员资料")
 var previous=focused()
 await tap(JOY_BUTTON_A)
 check(game.modal.is_ancestor_of(focused()) and not focused().disabled,"player detail skips disabled roster buttons")
 await tap(JOY_BUTTON_B)
 check(focused()==previous,"detail returns to selected card")
 var edit:LineEdit
 for item in router.collect(game.ui):
  if item is LineEdit: edit=item;break
 edit.grab_focus()
 await key(KEY_W)
 check(edit.text=="w" and focused()==edit,"typing WASD in search does not move focus")
 await key(KEY_TAB)
 check(focused()!=edit,"Tab leaves text input")
 await tap(JOY_BUTTON_B)
 check(game.screen=="menu","controller returns from library")
 game.show_settings()
 await settle()
 focus_button("按键图标")
 await tap(JOY_BUTTON_A)
 check(router.glyph_override=="xbox" and focused().text.begins_with("按键图标"),"glyph preference changes without losing settings focus")
 var stored:=ConfigFile.new()
 check(stored.load(router.preferences_path)==OK and stored.get_value("controller","glyphs")=="xbox","glyph override persists to input settings")
 router.glyph_override="auto"
 router.save_preferences()
 await tap(JOY_BUTTON_B)
 await settle()
 var motion:=InputEventJoypadMotion.new()
 motion.device=DEVICE
 motion.axis=JOY_AXIS_LEFT_Y
 motion.axis_value=0.8
 game.get_viewport().push_input(motion)
 await settle()
 check(focused().text=="快速比赛","left stick navigates menus")
 var first=focused()
 await game.get_tree().create_timer(0.08).timeout
 check(focused()==first,"stick does not repeat every frame")
 motion.axis_value=0
 game.get_viewport().push_input(motion)
 await settle()
 router.suspend()
 await tap(JOY_BUTTON_A)
 check(game.modal.get_child_count()==0,"unfocused window ignores gamepad confirmation")
 router.window_active=true
 # Input contract remains desktop-only. No Android adapter is instantiated or tested.
 var InputScript=preload("res://football_input.gd")
 var input_value=InputScript.new()
 input_value.pending=4;input_value.enabled=false
 check(input_value.command().action==0,"disabled input emits no queued match action")
 # The online menu uses the same scoped navigation, but the authority keeps ticking.
 game.practice=true
 await game.start_match()
 game.network.sim=game.sim
 game.network.running=false
 game.network.active=false
 game.online=true
 check(preload("res://restart_impact_tests.gd").prepare(game.sim),"kickoff preparation finishes")
 game.sim.freeze=0
 game.show_online_menu()
 await settle()
 check(focused().text=="继续比赛","online menu receives default focus")
 var clock_before:float=game.sim.elapsed
 game.sim.phase="play" # Exercise live play; a kickoff legitimately stops the clock.
 game.sim.step(1.0/60)
 check(game.sim.elapsed>clock_before,"online menu does not freeze authority")
 await tap(JOY_BUTTON_B)
 check(game.screen=="match" and game.controls.pending==0,"online menu returns cleanly")
 game.show_online_menu()
 game.show_assistance_settings()
 await settle()
 check(game.screen=="assist_settings" and game.assistance_return=="online_menu","online assistance keeps correct return context")
 game.close_assistance_settings()
 check(game.screen=="online_menu","assistance returns to online menu")
 game.online=false
 game.network.sim=null
 game.practice=true
 await game.start_match()
 check(preload("res://restart_impact_tests.gd").prepare(game.sim),"pass indicator waits for a prepared kickoff")
 game.sim.freeze=10
 game.sim.owner=game.sim.selected
 router.pass_indicator=true
 game.render_match(0)
 check(game.pass_arrow.visible,"small pass arrow visible at controlled ball carrier")
 check(game.indicator.position.y>game.sim.players[game.sim.selected].body.height and game.actors.all(func(actor): return actor.get_child_count()==2),"all players have rig and label only, without foot rings")
 var old_selected:int=game.sim.selected
 game.sim.selected=4
 game.render_match(0)
 check(game.indicator.position.x==game.actors[4].position.x and is_equal_approx(game.indicator.position.y,game.sim.players[4].body.height+1.15),"marker follows player switches and individual height")
 game.sim.selected=old_selected
 game.render_match(0)
 var plan:Dictionary=game.sim.pass_plan(game.sim.selected,game.controls.movement(),false,router.assistance)
 check(absf(wrapf(game.pass_arrow.rotation.y+atan2(plan.direction.y,plan.direction.x),-PI,PI))<0.001,"arrow points in same direction as authority pass plan")
 await game.capture("assistance-pass-arrow")
 await game.capture("current-player-triangle")
 game.pause_match()
 await settle()
 focus_button("操作辅助与传球指示")
 await tap(JOY_BUTTON_A)
 var paused_time:float=game.sim.elapsed
 focus_button("高辅助")
 await tap(JOY_BUTTON_A)
 check(router.assistance==2 and game.controls.assistance==2,"controller selects high assistance")
 await game.capture("assistance-settings")
 focus_button("传球方向指示")
 await tap(JOY_BUTTON_A)
 var saved:=ConfigFile.new()
 check(saved.load(router.preferences_path)==OK and saved.get_value("gameplay","assistance")==2 and saved.get_value("gameplay","pass_indicator")==false,"assistance and indicator preferences persist independently")
 check(game.sim.elapsed==paused_time,"assistance submenu preserves local pause")
 await tap(JOY_BUTTON_B)
 check(game.screen=="pause","B returns from assistance to pause instead of playing")
 await tap(JOY_BUTTON_B)
 game.render_match(0)
 check(not game.pass_arrow.visible,"indicator toggle hides arrow during match")
 router.pass_indicator=true
 game.sim.owner=game.sim.selected
 game.render_match(0)
 check(game.pass_arrow.visible,"indicator can be enabled again")
 game.sim.charging=true
 game.render_match(0)
 check(not game.pass_arrow.visible,"pass arrow hides during shot charge")
 game.sim.charging=false
 check(preload("res://restart_impact_tests.gd").prepare(game.sim),"kickoff preparation finishes")
 game.sim.freeze=0
 game.sim.teams[0].assist=2
 game.sim.pass_ball(false,Vector2.ZERO)
 game.render_match(0)
 check(game.pass_arrow.visible,"arrow briefly remains at passer after releasing ball")
 game.sim.kick_age=0.4
 game.render_match(0)
 check(not game.pass_arrow.visible,"released pass arrow fades out of receiving phase")
 game.sim.owner=game.sim.selected;game.sim.phase="play";game.sim.freeze=0
 game.sim.apply_command(0,{"action":4,"move":Vector2.RIGHT})
 game.pause_match()
 check(game.sim.mechanics.buffered[0].is_empty() and game.sim.mechanics.releases[0].is_empty(),"local pause clears pending contact and receiving inputs")
 await settle()
 focus_button("替补席")
 await tap(JOY_BUTTON_A)
 check(game.screen=="substitutions" and game.modal.is_ancestor_of(focused()),"controller opens substitution menu with scoped focus")
 var substitute_time:float=game.sim.elapsed
 await game.get_tree().create_timer(0.08).timeout
 check(game.sim.elapsed==substitute_time,"local substitution menu pauses match")
 await tap(JOY_BUTTON_B)
 check(game.screen=="match" and game.controls.pending==0,"leaving substitutes does not leak confirm input")
 game.sim.phase="play";game.sim.freeze=0;game.sim.owner=game.sim.selected
 game.sim.apply_command(0,{"action":4,"move":Vector2.RIGHT})
 game.show_help("match")
 check(game.sim.mechanics.releases[0].is_empty(),"local help clears pending contact input")
 game.close_help()
 game.pause_match()
 game.show_assistance_settings()
 await settle()
 focus_button("分别调整辅助")
 await tap(JOY_BUTTON_A)
 focus_button("接球跑位辅助")
 var old_receive:int=router.options.receive_assist
 await tap(JOY_BUTTON_A)
 check(router.options.receive_assist==(old_receive+1)%3 and game.controls.receive_assist==router.options.receive_assist,"advanced receiving assist changes independently")
 check(game.controls.shot_assist==router.options.shot_assist,"shot assist retains separate setting")
 router.options.receive_assist=1;router.options.shot_assist=1;router.options.auto_switch=1
 router.assistance=1
 router.update_prompts()
 router.save_preferences()
 game.show_menu()
 await settle()
 game.show_lobby()
 await settle()
 var invite:LineEdit
 for item in game.ui.get_children():
  if item is LineEdit and item.secret: invite=item
 check(invite!=null,"lobby has masked invitation input")
 if invite!=null:
  var previous_code:String=game.network.room_code
  check(invite.max_length==128 and invite.get_global_rect().end.y<game.lobby_status.position.y,"invitation fits above status without overlap")
  invite.grab_focus()
  check(focused()==invite,"invitation field accepts keyboard focus")
  invite.text="ui-test-invite";invite.text_changed.emit(invite.text)
  check(game.network.room_code==invite.text,"invitation is passed to network admission")
  game.network.room_code=previous_code;invite.text=previous_code
 await game.capture("online-invitation-lobby")
 game.show_menu()
 await settle()
 print("DESKTOP_INPUT_VERIFY_", "PASS" if failures==0 else "FAILED", " checks=",checks," failures=",failures)
 game.get_tree().quit(0 if failures==0 else 2)
