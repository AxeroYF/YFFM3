extends Node3D
# Composition root. Compatibility accessors keep existing verification entry points stable.
var verification_driver=preload("res://verification_driver.gd").new()
var match_renderer=preload("res://match_renderer.gd").new()
var stadium=preload("res://stadium_view.gd").new()
var ui_kit=preload("res://ui_kit.gd").new()
var match_hud=preload("res://match_hud.gd").new()
var session=preload("res://match_session.gd").new()
var tools_screen=preload("res://match_tools_screen.gd").new()
var match_loading=preload("res://match_loading.gd").new()
const Team=preload("res://team_config.gd")
const Pitch=preload("res://pitch_geometry.gd")

const Campaign = preload("res://campaign.gd")
const Match = preload("res://match_sim.gd")
const FootballInput=preload("res://football_input.gd")
var match_tools=preload("res://match_tools.gd").new()
const MatchNetwork=preload("res://match_network.gd")
const FootballActor=preload("res://skinned_player.gd")
const Body=preload("res://player_body.gd")
const BodyShowroom=preload("res://body_showroom.gd")
const PlayerLibrary=preload("res://player_library.gd")
const LibraryScreen=preload("res://library_screen.gd")
const Squad=preload("res://squad.gd")
const QuickMatch=preload("res://quick_match.gd")
const Conditions=preload("res://match_environment.gd")
var quick_environment:
 get: return session.quick_environment
 set(value): session.quick_environment=value
var environment_visual:
 get: return stadium.environment_visual
 set(value): stadium.environment_visual=value
var sky_material:
 get: return stadium.sky_material
 set(value): stadium.sky_material=value
var pitch_material:
 get: return stadium.pitch_material
 set(value): stadium.pitch_material=value
const Assistance=preload("res://play_assistance.gd")
var assistance_return:="menu"
var pass_arrow:
 get: return stadium.pass_arrow
 set(value): stadium.pass_arrow=value
var rules_view=preload("res://rules_presentation.gd").new()
var impact_feedback=preload("res://impact_feedback.gd").new()
var quick_fixture:
 get: return session.quick_fixture
 set(value): session.quick_fixture=value
var quick_arcade:
 get: return session.quick_arcade
 set(value): session.quick_arcade=value
var quick_ice_mode:
 get: return session.quick_ice_mode
 set(value): session.quick_ice_mode=value
var quick_verify:=false
const DesktopInput=preload("res://desktop_input.gd")
const InputGlyph=preload("res://input_glyph.gd")
var desktop_input:Node
var binding_icons:
 get: return ui_kit.binding_icons
 set(value): ui_kit.binding_icons=value
var binding_labels:
 get: return ui_kit.binding_labels
 set(value): ui_kit.binding_labels=value
var input_verify:=false
const INK = Color("edf6ff")
const MUTED = Color("8da9bf")
const CYAN = Color("6af4dc")
const GOLD = Color("f3ca82")
var campaign = Campaign.new()
var sim:
 get: return session.sim
 set(value): session.sim=value
var screen:
 get: return session.screen
 set(value): session.screen=value
var previous_screen := "hub"
var ui: Control
var modal: Control
var font:
 get: return ui_kit.font
 set(value): ui_kit.font=value
var bold:
 get: return ui_kit.bold
 set(value): ui_kit.bold=value
var camera:
 get: return stadium.camera
 set(value): stadium.camera=value
var arena:
 get: return stadium.arena
 set(value): stadium.arena=value
var planet:
 get: return stadium.planet
 set(value): stadium.planet=value
var planet_material:
 get: return stadium.planet_material
 set(value): stadium.planet_material=value
var orbit:
 get: return stadium.orbit
 set(value): stadium.orbit=value
var actors:
 get: return stadium.actors
 set(value): stadium.actors=value
var indicator:
 get: return stadium.indicator
 set(value): stadium.indicator=value
var football:
 get: return stadium.football
 set(value): stadium.football=value
var ball_shadow:
 get: return stadium.ball_shadow
 set(value): stadium.ball_shadow=value
var trail:
 get: return stadium.trail
 set(value): stadium.trail=value
var trail_points:
 get: return stadium.trail_points
 set(value): stadium.trail_points=value
var portraits: Array[Texture2D] = []
var records: Array = []
var score_label:
 get: return match_hud.score_label
 set(value): match_hud.score_label=value
var time_label:
 get: return match_hud.time_label
 set(value): match_hud.time_label=value
var energy_label:
 get: return match_hud.energy_label
 set(value): match_hud.energy_label=value
var event_label:
 get: return match_hud.event_label
 set(value): match_hud.event_label=value
var player_label:
 get: return match_hud.player_label
 set(value): match_hud.player_label=value
var charge_bar:
 get: return match_hud.charge_bar
 set(value): match_hud.charge_bar=value
var energy_bar:
 get: return match_hud.energy_bar
 set(value): match_hud.energy_bar=value
var rule_label:
 get: return match_hud.rule_label
 set(value): match_hud.rule_label=value
var environment_label:
 get: return match_hud.environment_label
 set(value): match_hud.environment_label=value
var selected_labels:
 get: return stadium.selected_labels
 set(value): stadium.selected_labels=value
var event_age:
 get: return match_hud.event_age
 set(value): match_hud.event_age=value
var last_event:
 get: return match_hud.last_event
 set(value): match_hud.last_event=value
var time := 0.0
var ui_age := 0.0
var pending_result := false
var result_data := {}
var has_save := false
var tactic := 1
var sounds := true
var audio:AudioStreamPlayer
var verify := false
var verify_step := 0
var verify_ticks := 0
var screen_ticks := 0
var capture_busy := false
var toast_label: Label
var sound_button: Button
var aim_marker:
 get: return stadium.aim_marker
 set(value): stadium.aim_marker=value
var travel_left := 0.0
var travel_text: Label
var controls=FootballInput.new()
var network:Node
var goal_nets:
 get: return stadium.goal_nets
 set(value): stadium.goal_nets=value
var online:
 get: return session.online
 set(value): session.online=value
var server_only:=false
var bot_mode:=false
var network_test:=false
var arcade_rules:=false
var practice:
 get: return session.practice
 set(value): session.practice=value
var lobby_status:Label
var address_field:LineEdit
var port_field:LineEdit
var network_label:
 get: return match_hud.network_label
 set(value): match_hud.network_label=value
var settings_panel:Control
var rigs:
 get: return stadium.rigs
 set(value): stadium.rigs=value
var camera_motion:=true
var last_online_event:=-1
var net_result_shown:=false
var action_hint:
 get: return match_hud.action_hint
 set(value): match_hud.action_hint=value
var bot_ready_sent:=false
var graphical_test:=false
var network_capture_done:=false
var arena_walls:
 get: return stadium.arena_walls
 set(value): stadium.arena_walls=value
var body_showroom:Node3D
var model_verify:=false
var library_screen=LibraryScreen.new()
var library_verify:=false
var booting:=true
var loader:CanvasLayer
var load_epoch:
 get: return session.load_epoch
 set(value): session.load_epoch=value
signal match_loaded

func _ready() -> void:
 if "--audit-library" in OS.get_cmdline_user_args():
  set_process(false)
  set_physics_process(false)
  var definitions:=PlayerLibrary.all()
  var valid:=definitions.size()==386
  for p in definitions:
   valid=valid and p.attributes.size()==26 and ResourceLoader.exists(p.portrait)
  print("PACKED_LIBRARY_AUDIT_PASS records=386 portraits=386 attributes=10036" if valid else "PACKED_LIBRARY_AUDIT_FAILED")
  get_tree().quit(0 if valid else 2)
  return
 verify="--verify" in OS.get_cmdline_user_args()
 model_verify="--verify-models" in OS.get_cmdline_user_args()
 library_verify="--verify-library" in OS.get_cmdline_user_args()
 input_verify="--verify-input" in OS.get_cmdline_user_args()
 quick_verify="--verify-quick" in OS.get_cmdline_user_args()
 server_only="--server" in OS.get_cmdline_user_args()
 bot_mode="--bot" in OS.get_cmdline_user_args()
 if not server_only and not bot_mode:
  font=SystemFont.new()
  font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Segoe UI"])
  bold=SystemFont.new();bold.font_names=font.font_names;bold.font_weight=700
  loader=preload("res://loading_screen.gd").new()
  add_child(loader);loader.build(ui_kit);loader.begin("正在启动")
  await loader.present(0,"读取球员资料")
  if "--verify-loading" in OS.get_cmdline_user_args(): await capture("loading-startup")
 if "--verify-release-ui" in OS.get_cmdline_user_args():
  Squad.save_path="user://release-ui-squad-test.json"
  Squad.ids=Squad.DEFAULT.duplicate()
  has_save=false
 Squad.load_squad()
 server_only="--server" in OS.get_cmdline_user_args()
 bot_mode="--bot" in OS.get_cmdline_user_args()
 network_test="--network-test" in OS.get_cmdline_user_args()
 graphical_test="--client-test" in OS.get_cmdline_user_args()
 network=MatchNetwork.new()
 session.network=network
 network.local_roster=Squad.ids.duplicate()
 if "--test-alternate-roster" in OS.get_cmdline_user_args(): network.local_roster[1]="legend-mbappe"
 network.name="Network"
 add_child(network)
 network.status_changed.connect(on_network_status)
 network.match_started.connect(on_network_start)
 network.match_ended.connect(on_network_end)
 network.session_lost.connect(on_network_lost)
 if server_only or bot_mode:
  # No need to spin an unbounded render loop on a shared compute server.
  Engine.max_fps=60
  booting=false
  online=true
  if network_test: network.test_duration=5.0
  var port_value:=int(argument("--port=","28765"))
  if server_only:
   var listen_test:bool="--listen-host-test" in OS.get_cmdline_user_args()
   var host_error:Error=network.host(port_value,not listen_test)
   if host_error!=OK: get_tree().quit(2);return
   if listen_test: network.set_ready()
  else:
   network.delay_ms=int(argument("--delay=","0"))
   network.loss_every=int(argument("--loss-every=","0"))
   network.join(argument("--connect=","127.0.0.1"),port_value)
  return
 if verify or input_verify: campaign.save_path="user://verification-campaign.json"
 await loader.present(18,"球员资料已就绪 · 读取主菜单资源")
 for name in ["Messi","Haaland","Bellingham","VanDijk"]: portraits.append(load("res://assets/"+name+".webp"))
 for id in ["legend-messi","legend-haaland","s4-fc26-252371","s4-fc26-203376"]: records.append(PlayerLibrary.find(id))
 has_save=campaign.load_game()
 await loader.present(38,"主菜单资源已就绪 · 准备星空球场")
 build_world()
 await loader.present(72,"球场已就绪 · 准备界面与操作")
 var layer:=CanvasLayer.new()
 add_child(layer)
 ui=Control.new()
 ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layer.add_child(ui)
 ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
 modal=Control.new()
 modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layer.add_child(modal)
 modal.mouse_filter=Control.MOUSE_FILTER_IGNORE
 desktop_input=DesktopInput.new()
 ui_kit.desktop_input=desktop_input
 ui_kit.sound_requested.connect(beep)
 rules_view.sound_requested.connect(beep)
 match_hud.sound_requested.connect(beep)
 match_hud.kick_requested.connect(kick_sound)
 if input_verify: desktop_input.preferences_path="user://input-test-preferences.cfg"
 desktop_input.configure(controls,ui_kit,ui,modal,func():return session.screen)
 desktop_input.back_requested.connect(navigate_back)
 desktop_input.cancel_requested.connect(cancel_charge_input)
 desktop_input.changed.connect(refresh_binding_hints)
 desktop_input.active_pad_lost.connect(on_controller_disconnected)
 add_child(desktop_input)
 library_screen.configure(ui_kit,ui,modal)
 library_screen.page_requested.connect(begin_library_page)
 library_screen.modal_requested.connect(func():clear_modal();dim_modal())
 library_screen.close_requested.connect(clear_modal)
 library_screen.menu_requested.connect(show_menu)
 library_screen.toast_requested.connect(toast)
 setup_audio()
 show_menu()
 await loader.present(100,"准备完成")
 loader.finish();booting=false
 if model_verify or "--models" in OS.get_cmdline_user_args(): show_player_bodies()
 if "--verify-legends" in OS.get_cmdline_user_args(): call_deferred("verify_legends")
 if "--verify-physique" in OS.get_cmdline_user_args(): call_deferred("verify_physique")
 if library_verify: library_screen.show_library()
 if "--verify-release-ui" in OS.get_cmdline_user_args(): call_deferred("verify_release_ui")
 if input_verify: call_deferred("verify_input_ui")
 if "--verify-keeper" in OS.get_cmdline_user_args(): call_deferred("verify_keeper_visuals")
 if "--verify-keeper-control" in OS.get_cmdline_user_args(): call_deferred("verify_keeper_control")
 if "--verify-keeper-goal" in OS.get_cmdline_user_args(): call_deferred("verify_keeper_goal")
 if "--verify-restart-impact" in OS.get_cmdline_user_args(): call_deferred("verify_restart_impact")
 if "--verify-pitch-modes" in OS.get_cmdline_user_args(): call_deferred("verify_pitch_modes")
 if "--verify-action-net" in OS.get_cmdline_user_args(): call_deferred("verify_action_net")
 if "--verify-six" in OS.get_cmdline_user_args(): call_deferred("verify_six")
 if "--verify-environment" in OS.get_cmdline_user_args(): call_deferred("verify_environment")
 if "--verify-ai" in OS.get_cmdline_user_args(): call_deferred("verify_ai")
 if "--verify-mechanics" in OS.get_cmdline_user_args(): call_deferred("verify_mechanics")
 if "--verify-rules" in OS.get_cmdline_user_args(): call_deferred("verify_rules_visuals")
 if "--verify-motion" in OS.get_cmdline_user_args(): call_deferred("verify_motion_visuals")
 if "--verify-locomotion" in OS.get_cmdline_user_args(): call_deferred("verify_locomotion_visuals")
 if "--verify-loading" in OS.get_cmdline_user_args(): call_deferred("verify_loading_ui")
 if quick_verify: call_deferred("verify_quick_ui")
 if "--verify-receiving-defending" in OS.get_cmdline_user_args(): call_deferred("verify_receiving_defending")
 elif "--quick-match" in OS.get_cmdline_user_args():
  var fixture_seed:=int(argument("--quick-seed=","0"))
  if fixture_seed>0: quick_fixture=QuickMatch.generate(fixture_seed)
  show_quick_options(fixture_seed<=0)
 print("STARBORNE_READY 2560x1440 / 6v6 / CORE_V2 / network+controller")
 if graphical_test:
  show_lobby()
  network.delay_ms=int(argument("--delay=","0"))
  network.loss_every=int(argument("--loss-every=","0"))
  network.join(argument("--connect=","127.0.0.1"),int(argument("--port=","28765")))

func verify_legends()->void:
 await preload("res://legend_models_verification.gd").new().run(self)

func verify_physique()->void:
 await preload("res://physique_verification.gd").new().run(self)

func verify_six()->void:
 await preload("res://six_a_side_verification.gd").new().run(self)

func verify_rules_visuals()->void:
 await preload("res://rules_verification.gd").new().run(self)

func verify_keeper_control()->void:
 await preload("res://keeper_control_verification.gd").new().run(self)

func verify_keeper_goal()->void:
 await preload("res://keeper_goal_verification.gd").new().run(self)

func verify_action_net()->void:
 await preload("res://action_net_verification.gd").new().run(self)

func verify_restart_impact()->void:
 await preload("res://restart_impact_verification.gd").new().run(self)

func verify_environment()->void:
 await preload("res://environment_verification.gd").new().run(self)

func verify_ai()->void:
 await preload("res://ai_verification.gd").new().run(self)

func verify_motion_visuals()->void:
 await preload("res://motion_verification.gd").new().run(self)

func verify_locomotion_visuals()->void:
 await preload("res://locomotion_verification.gd").new().run(self)

func verify_loading_ui()->void:
 await preload("res://loading_verification.gd").new().run(self)

func verify_keeper_visuals()->void:
 await verification_driver.verify_keeper_visuals(self)

func verify_release_ui()->void:
 await verification_driver.verify_release_ui(self)

func verify_input_ui()->void:
 var runner=preload("res://input_verification.gd").new()
 await runner.run(self)

func verify_quick_ui()->void:
 var runner=preload("res://quick_match_verification.gd").new()
 await runner.run(self)

func material(color: Color, glow: float=0.0, metal: float=0.0) -> StandardMaterial3D:
 return stadium.material(color,glow,metal)

func box(parent: Node3D, pos: Vector3, size_value: Vector3, mat: Material) -> MeshInstance3D:
 return stadium.box(parent,pos,size_value,mat)

func sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
 return stadium.sphere(parent,pos,radius,mat)

func beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
 return stadium.beam(parent,a,b,radius,mat)

func ring(parent: Node3D, pos: Vector3, radius: float, width: float, mat: Material) -> MeshInstance3D:
 return stadium.ring(parent,pos,radius,width,mat)

func build_world()->void:
 add_child(stadium)
 stadium.build_world()

func load_pitch() -> ShaderMaterial:
 return stadium.load_pitch()

func apply_environment_visual(value:Dictionary)->void:
 stadium.apply_environment_visual(value)

func create_actor(index:int)->void:
 stadium.create_actor(index,sim.players[index],bold)

func style(bg: Color, border: Color=Color.TRANSPARENT, radius: int=12) -> StyleBoxFlat:
 return ui_kit.style(bg,border,radius)

func panel(parent: Control, rect: Rect2, bg: Color=Color(0.027,0.048,0.081,0.93), border: Color=Color(0.25,0.48,0.61,0.4),radius:int=12) -> Panel:
 return ui_kit.panel(parent,rect,bg,border,radius)

func text(parent: Control, value: String, pos: Vector2, size_value: int=26, color: Color=INK, heavy: bool=false, width: float=0) -> Label:
 return ui_kit.text(parent,value,pos,size_value,color,heavy,width)

func binding_hint(parent:Control,action:String,caption:String,pos:Vector2)->void:
 ui_kit.binding_hint(parent,action,caption,pos)

func button_binding(parent:Button,action:String)->void:
 ui_kit.button_binding(parent,action)

func binding_text(parent:Control,template:String,actions:Array,pos:Vector2,size_value:int=24,color:Color=INK)->Label:
 return ui_kit.binding_text(parent,template,actions,pos,size_value,color)

func refresh_binding_hints()->void:
 ui_kit.refresh_binding_hints()

func cycle_input_glyphs()->void:
 var options:=["auto","xbox","playstation","nintendo","generic"]
 desktop_input.glyph_override=options[(options.find(desktop_input.glyph_override)+1)%options.size()]
 desktop_input.update_prompts()
 if not desktop_input.save_preferences(): toast("按键图标偏好保存失败")
 for child in modal.get_children():
  if child is Button and child.text.begins_with("按键图标："):
   child.text="按键图标："+{"auto":"自动识别","xbox":"Xbox","playstation":"PlayStation","nintendo":"Nintendo","generic":"通用"}[desktop_input.glyph_override]

func button(parent: Control, value: String, rect: Rect2, action: Callable, primary: bool=false) -> Button:
 return ui_kit.button(parent,value,rect,action,primary)

func clear_ui() -> void:
 controls.reset()
 if is_instance_valid(body_showroom): body_showroom.visible=false
 for child in ui.get_children():
  ui.remove_child(child)
  child.queue_free()
 toast_label=null
 screen_ticks=0

func clear_modal() -> void:
 for child in modal.get_children():
  modal.remove_child(child)
  child.queue_free()

func chrome(section: String) -> void:
 text(ui,"Y F F M  3    /    S T A R B O R N E",Vector2(72,42),23,CYAN,true)
 text(ui,section,Vector2(72,84),21,MUTED)
 panel(ui,Rect2(72,127,2416,2),Color("244052"),Color.TRANSPARENT)
 sound_button=button(ui,"音效 开" if sounds else "音效 关",Rect2(2245,1360,140,48),toggle_sound)
 sound_button.set_meta("utility_focus",true)
 button(ui,"全屏",Rect2(2397,1360,90,48),toggle_fullscreen).set_meta("utility_focus",true)

func camera_hub()->void:
 stadium.camera_hub()

func show_menu() -> void:
 if online:
  network.close()
  online=false
 practice=false
 clear_modal()
 clear_ui()
 screen="menu"
 camera_hub()
 panel(ui,Rect2(0,0,970,1440),Color(0.016,0.03,0.058,0.93),Color.TRANSPARENT,0)
 text(ui,"YFFM 3",Vector2(108,72),36,INK,true)
 text(ui,"S T A R B O R N E",Vector2(316,82),23,CYAN)
 text(ui,"主场",Vector2(1040,85),27,INK,true)
 panel(ui,Rect2(1040,132,57,3),CYAN)
 button(ui,"我的球队",Rect2(1140,69,208,62),library_screen.show_squad)
 button(ui,"球员库",Rect2(1370,69,208,62),library_screen.open_catalog)
 text(ui,"群星联队",Vector2(2180,76),28,INK,true)
 text(ui,"6-A-SIDE FOOTBALL",Vector2(110,284),24,CYAN)
 text(ui,"群星绿茵",Vector2(101,333),112,INK,true)
 text(ui,"你的球队。你的主场。",Vector2(111,499),33,MUTED)
 button(ui,"联机对战",Rect2(110,657,680,105),show_lobby,true)
 button(ui,"快速比赛",Rect2(110,784,680,90),func(): quick_ice_mode=false;show_quick_options())
 button(ui,"冰球模式",Rect2(110,896,680,90),func(): quick_ice_mode=true;quick_arcade=false;show_quick_options())
 text(ui,"澜星  /  轨道竞技场",Vector2(1060,222),25,CYAN)
 var featured:=PlayerLibrary.find(Squad.ids[1])
 panel(ui,Rect2(1800,292,610,652),Color(0.02,0.04,0.075,0.72),Color("355567"),28)
 text(ui,"09",Vector2(1875,322),220,Color(0.20,0.49,0.53,0.23),true)
 var hero:=TextureRect.new()
 hero.position=Vector2(1700,258)
 hero.size=Vector2(740,620)
 hero.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 hero.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 hero.texture=load(featured.portrait)
 hero.mouse_filter=Control.MOUSE_FILTER_IGNORE
 ui.add_child(hero)
 text(ui,featured.name,Vector2(1840,841),37,INK,true,540)
 text(ui,"%s  /  %d cm" % [featured.role,featured.heightCm],Vector2(1845,900),22,CYAN)
 var titles:=["星际杯","我的球队","球员库"]
 var descriptions:=["继续航程" if has_save else "开启新航程","管理你的六人阵容","%d 名球员" % PlayerLibrary.all().size()]
 var actions:Array[Callable]=[show_hub if has_save else request_new_game,library_screen.show_squad,library_screen.open_catalog]
 for i in 3:
  var x:=110+i*792
  panel(ui,Rect2(x,1060,752,213),Color(0.026,0.048,0.079,0.96),Color("2c4659"),18)
  text(ui,"0%d" % (i+1),Vector2(x+32,1084),21,CYAN)
  text(ui,titles[i],Vector2(x+32,1124),39,INK,true)
  text(ui,descriptions[i],Vector2(x+32,1194),23,MUTED)
  button(ui,"进入  →",Rect2(x+524,1142,190,79),actions[i])
 button(ui,"设置",Rect2(110,1338,150,58),show_settings)
 button(ui,"操作指南",Rect2(280,1338,200,58),func(): show_help("menu"))
 button(ui,"退出",Rect2(2280,1338,150,58),func(): get_tree().quit())

func show_settings()->void:
 clear_modal()
 dim_modal()
 panel(modal,Rect2(790,275,980,910))
 text(modal,"设置",Vector2(850,397),46,INK,true)
 button(modal,"音效："+("开" if sounds else "关"),Rect2(850,510,860,76),func(): toggle_sound();show_settings())
 button(modal,"切换全屏",Rect2(850,612,860,76),toggle_fullscreen)
 button(modal,"球员模型展示",Rect2(850,714,860,76),func(): clear_modal();show_player_bodies())
 button(modal,"按键图标："+{"auto":"自动识别","xbox":"Xbox","playstation":"PlayStation","nintendo":"Nintendo","generic":"通用"}[desktop_input.glyph_override],Rect2(850,816,860,76),cycle_input_glyphs)
 button(modal,"操作辅助与传球指示",Rect2(850,918,860,76),show_assistance_settings)
 button(modal,"返回",Rect2(850,1030,860,76),clear_modal)

func show_assistance_settings()->void:
 if screen!="assist_settings": assistance_return=screen
 screen="assist_settings"
 clear_modal()
 dim_modal()
 panel(modal,Rect2(590,270,1380,930))
 text(modal,"操作辅助",Vector2(655,320),46,INK,true)
 text(modal,"主动移动始终优先；辅助不会提高球员能力值。",Vector2(658,403),26,MUTED)
 for level in 3:
  var y:=478+level*140
  button(modal,Assistance.NAMES[level]+("  ✓" if desktop_input.assistance==level else ""),Rect2(655,y,320,78),func(): set_assistance(level),desktop_input.assistance==level)
  text(modal,Assistance.DESCRIPTIONS[level],Vector2(1000,y+15),24,INK,false,875)
 button(modal,"传球方向指示："+("开" if desktop_input.pass_indicator else "关"),Rect2(655,925,1250,78),toggle_pass_indicator)
 button(modal,"分别调整辅助 / 镜头反馈 / 比赛选项",Rect2(655,1010,1250,55),func(): show_advanced_settings())
 button(modal,"返回",Rect2(655,1080,1250,70),close_assistance_settings)

func set_assistance(level:int)->void:
 desktop_input.assistance=Assistance.level(level)
 desktop_input.options.receive_assist=level
 desktop_input.options.shot_assist=level
 desktop_input.options.auto_switch=0 if level==0 else level
 desktop_input.update_prompts()
 if not desktop_input.save_preferences(): toast("辅助设置保存失败")
 show_assistance_settings()

func toggle_pass_indicator()->void:
 desktop_input.pass_indicator=not desktop_input.pass_indicator
 if not desktop_input.save_preferences(): toast("指示器设置保存失败")
 show_assistance_settings()

func close_assistance_settings()->void:
 var origin:=assistance_return
 if origin=="pause": screen="match";pause_match()
 elif origin=="online_menu": screen="match";show_online_menu()
 else: screen=origin;show_settings()

func show_player_bodies(page:int=-1,focus:int=-1)->void:
 clear_modal()
 clear_ui()
 screen="bodies"
 camera_hub()
 if not is_instance_valid(body_showroom):
  body_showroom=BodyShowroom.new()
  add_child(body_showroom)
  body_showroom.build()
 if page>=0 and body_showroom.page!=page: body_showroom.set_page(page)
 body_showroom.focus(focus)
 body_showroom.visible=true
 camera.cull_mask=2
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=7.0
 camera.environment=get_world_3d().environment.duplicate()
 camera.environment.ambient_light_energy=0.3
 camera.environment.glow_enabled=false
 camera.position=Vector3(0,77,15)
 camera.look_at(Vector3(0,76.65,0))
 if focus>=0:
  var focused_height:float=body_showroom.models[focus].body.height
  var aim_height:float=75+focused_height-0.38
  camera.size=2.6
  camera.position=Vector3(0,aim_height,15)
  camera.look_at(Vector3(0,aim_height,0))
 chrome("传奇球员  /  模型展厅")
 text(ui,"传奇，各有身姿",Vector2(75,166),48,INK,true)
 text(ui,"%d 名传奇 · 按卡画塑造外观 · 身高取自球员库" % body_showroom.records.size(),Vector2(78,240),25,MUTED)
 button(ui,"正面",Rect2(78,310,180,62),func(): body_showroom.angle=0; body_showroom.turning=false)
 button(ui,"侧面",Rect2(274,310,180,62),func(): body_showroom.angle=PI/2; body_showroom.turning=false)
 button(ui,"背面",Rect2(470,310,180,62),func(): body_showroom.angle=PI; body_showroom.turning=false)
 button(ui,"自动旋转",Rect2(666,310,220,62),func(): body_showroom.turning=not body_showroom.turning)
 button(ui,"跑动 / 站立",Rect2(902,310,250,62),func(): body_showroom.running=not body_showroom.running)
 button(ui,"上一页",Rect2(1260,310,180,62),func(): show_player_bodies(posmod(body_showroom.page-1,body_showroom.page_count())))
 text(ui,"%02d / %02d" % [body_showroom.page+1,body_showroom.page_count()],Vector2(1473,324),27,CYAN)
 button(ui,"下一页",Rect2(1635,310,180,62),func(): show_player_bodies(posmod(body_showroom.page+1,body_showroom.page_count())))
 if focus>=0: button(ui,"全身对比",Rect2(1840,310,250,62),func():show_player_bodies())
 button(ui,"返回主菜单",Rect2(2170,310,315,62),show_menu)
 for i in body_showroom.page_records.size():
  var x:int=100+i*610
  var model_record:Dictionary=body_showroom.page_records[i]
  var body:=Body.from_record(model_record)
  panel(ui,Rect2(x,1100,530,212))
  var portrait:=TextureRect.new();portrait.texture=load(model_record.portrait)
  portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  portrait.position=Vector2(x+14,1114);portrait.size=Vector2(108,175)
  portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(portrait)
  text(ui,"%s  ·  %d cm" % [model_record.name,body.height_cm],Vector2(x+134,1118),27,INK,true)
  text(ui,body.build_name,Vector2(x+134,1160),23,CYAN)
  text(ui,FootballActor.Groom.LABELS.get(body.hair_style,body.hair_style),Vector2(x+134,1196),21,MUTED)
  button(ui,"近看外观",Rect2(x+134,1245,360,48),func():show_player_bodies(-1,i))
 text(ui,"体型影响启动、刹车、变向与身体对抗 · 球员资料可查看修正 · 肤色与发型仅影响外观",Vector2(100,1334),23,MUTED)

func request_new_game() -> void:
 if not has_save: new_game(); return
 clear_modal()
 dim_modal()
 panel(modal,Rect2(790,475,980,450))
 text(modal,"开启新航程？",Vector2(850,520),42,INK,true)
 text(modal,"这会替换当前的航线进度、训练和星币。",Vector2(850,613),29,MUTED)
 button(modal,"保留当前航程",Rect2(850,774,395,76),clear_modal)
 button(modal,"重新出发",Rect2(1280,774,420,76),new_game,true)

func new_game() -> void:
 var save_path: String=campaign.save_path
 campaign=Campaign.new()
 campaign.save_path=save_path
 has_save=true
 persist()
 show_hub()
 show_help("hub")

func persist() -> void:
 if not campaign.save_game(): toast(campaign.save_error)

func show_hub() -> void:
 records.clear()
 portraits.clear()
 for slot in [2,1,3,4,5]:
  var record:=PlayerLibrary.find(Squad.ids[slot])
  records.append(record)
  portraits.append(load(record.portrait))
 practice=false
 controls.reset()
 clear_modal()
 clear_ui()
 screen="hub"
 camera_hub()
 chrome("舰桥  /  群星联队")
 var stage: int=mini(campaign.stage,2)
 var mission: Dictionary=Campaign.MISSIONS[stage]
 text(ui,"群星杯航线",Vector2(72,160),55,INK,true)
 text(ui,"STAR CUP EXPEDITION  /  赛前准备",Vector2(76,242),21,GOLD)
 button(ui,"星际规则" if arcade_rules else "经典规则",Rect2(1630,176,242,70),func(): arcade_rules=not arcade_rules; show_hub())
 panel(ui,Rect2(1908,158,580,106))
 text(ui,"星币",Vector2(1938,186),23,MUTED)
 text(ui,str(campaign.credits),Vector2(2020,173),43,GOLD,true)
 text(ui,"胜场  %d / 3" % campaign.stage,Vector2(2260,189),24,CYAN)
 panel(ui,Rect2(72,299,872,421))
 text(ui,"冠军航程已完成" if campaign.stage==3 else mission.tag,Vector2(110,325),22,CYAN)
 text(ui,"你是群星杯冠军" if campaign.stage==3 else mission.title,Vector2(108,369),50,INK,true)
 text(ui,"继续训练并重开航程，挑战更高难度。" if campaign.stage==3 else mission.info,Vector2(111,455),26,MUTED,false,779)
 text(ui,"航程记录   %d 场比赛   /   %d 粒进球" % [campaign.played,campaign.goals] if campaign.stage==3 else "本场奖励   + %d 星币" % mission.reward,Vector2(112,578),24,GOLD)
 button(ui,"开启下一次航程" if campaign.stage==3 else "出航  /  前往"+mission.name,Rect2(110,629,560,65),request_new_game if campaign.stage==3 else show_briefing,true)
 button(ui,"操作说明",Rect2(694,629,211,65),func(): show_help("hub"))
 for i in 3:
  var x:=1030+i*475
  var active: bool=i==campaign.stage
  panel(ui,Rect2(x,553,434,167),Color(0.035,0.064,0.10,0.94),CYAN if active else Color("345065"))
  text(ui,"✓  已征服" if i<campaign.stage else ("→  下一站" if active else "锁定  /  赢下前站解锁"),Vector2(x+25,573),21,CYAN if i<=campaign.stage else MUTED)
  text(ui,Campaign.MISSIONS[i].name,Vector2(x+25,612),34,INK,true)
  text(ui,Campaign.MISSIONS[i].tag,Vector2(x+25,669),17,GOLD)
 text(ui,"首发阵容",Vector2(72,756),33,INK,true)
 text(ui,"位置训练  /  每个位置最多 5 次",Vector2(255,766),21,MUTED)
 button(ui,"调整阵容",Rect2(1500,747,270,64),library_screen.show_squad)
 for i in Team.FIELD_PLAYERS: roster_card(i,Vector2(72+i*352,824))
 panel(ui,Rect2(1850,824,638,475))
 text(ui,"星舰补给站",Vector2(1885,850),30,INK,true)
 text(ui,PlayerLibrary.find(Squad.ids[0]).name+"  /  首发门将",Vector2(1885,915),27,GOLD,true)
 text(ui,"门将专项训练，提升移动速度。",Vector2(1885,964),23,MUTED,false,546)
 var recruit_button:=button(ui,"专项训练完成" if campaign.keeper else "门将专项训练   /   500 星币",Rect2(1885,1060,566,66),recruit_keeper)
 recruit_button.disabled=campaign.keeper>0 or campaign.credits<500
 button(ui,"难度："+("标准" if campaign.difficulty else "轻松")+"  ↔",Rect2(1885,1150,275,65),toggle_difficulty)
 button(ui,"返回主菜单",Rect2(2178,1150,273,65),show_menu)
 text(ui,"比赛结束、训练和签约后自动存档",Vector2(1885,1246),19,MUTED)
 if campaign.save_error!="": toast(campaign.save_error)

func roster_card(index: int, pos: Vector2) -> void:
 var colors: Array[Color]=[GOLD,CYAN,Color("c4b6ff"),Color("ffa68a"),Color("8ecbff")]
 var p:=panel(ui,Rect2(pos,Vector2(337,475)),Color(0.026,0.045,0.078,0.96),colors[index]*Color(1,1,1,0.6))
 var portrait_clip:=Control.new()
 portrait_clip.position=Vector2(8,6)
 portrait_clip.size=Vector2(135,363)
 portrait_clip.clip_contents=true
 portrait_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
 p.add_child(portrait_clip)
 var sprite:=TextureRect.new()
 sprite.texture=portraits[index]
 sprite.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 sprite.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 sprite.size=Vector2(135,310)
 sprite.position=Vector2(0,48)
 portrait_clip.add_child(sprite)
 text(p,["右翼","前锋","左翼","后卫","中场"][index],Vector2(22,20),18,colors[index])
 text(p,records[index].name,Vector2(148,70),25,INK,true,178)
 text(p,"%s  ·  %d OVR" % [records[index].role,records[index].overall],Vector2(148,124),20,colors[index])
 text(p,"身高 %d cm" % records[index].heightCm,Vector2(148,155),18,MUTED)
 var attr: Dictionary=records[index].attributes
 text(p,("抢断  %d\n盯人  %d\n力量  %d" % [attr.tackling,attr.marking,attr.strength]) if index==3 else ("射门  %d\n传球  %d\n盘带  %d" % [attr.finishing,attr.passing,attr.dribbling]),Vector2(148,181),23,MUTED)
 text(p,"训练 %d / 5" % campaign.training[index],Vector2(148,311),23,colors[index],true)
 var train_button:=button(p,"训练完成" if campaign.training[index]>=5 else "训练  /  %d 星币" % campaign.cost(index),Rect2(22,387,293,64),func(): train_player(index))
 train_button.disabled=campaign.training[index]>=5 or campaign.credits<campaign.cost(index)

func train_player(index: int) -> void:
 if campaign.train(index):
  persist()
  show_hub()
  toast("位置训练完成 · 速度提升")

func recruit_keeper() -> void:
 if campaign.recruit():
  persist()
  show_hub()
  toast("门将专项训练完成")

func toggle_difficulty() -> void:
 campaign.difficulty=1-campaign.difficulty
 persist()
 show_hub()

func show_briefing() -> void:
 clear_ui()
 screen="briefing"
 chrome("比赛简报  /  航行准备")
 var m: Dictionary=Campaign.MISSIONS[mini(campaign.stage,2)]
 panel(ui,Rect2(72,174,1100,1140))
 text(ui,m.tag,Vector2(115,215),24,CYAN)
 text(ui,m.name+"轨道球场",Vector2(110,278),60,INK,true)
 text(ui,"群星联队  VS  "+m.club,Vector2(115,387),30,GOLD,true)
 text(ui,m.info,Vector2(115,465),28,MUTED,false,1000)
 text(ui,"本场环境",Vector2(115,606),24,INK,true)
 text(ui,m.rule if arcade_rules else "出界重开 · 角球 / 界外球 / 球门球 · 无越位",Vector2(115,655),25,CYAN,false,1000)
 text(ui,"6 人制 · 每队 1 门将 + 5 场上球员\n100 秒比赛  /  同分进入 30 秒金球加时",Vector2(115,737),25,MUTED)
 text(ui,"选择出场战术",Vector2(115,853),28,INK,true)
 for i in 3:
  button(ui,["稳固防守","均衡推进","全线压上"][i]+("  ✓" if tactic==i else ""),Rect2(115+i*335,914,313,76),func(): tactic=i; show_briefing(),tactic==i)
 text(ui,["无球队友站位更深，保护后场。","队友保持接应距离，攻守均衡。","持球时队友更积极向前插上。"][tactic],Vector2(116,1026),24,MUTED)
 button(ui,"进入球场   →",Rect2(115,1144,680,98),begin_travel,true)
 button(ui,"返回舰桥",Rect2(820,1144,302,98),show_hub)
 panel(ui,Rect2(1560,950,820,298))
 text(ui,"舰长提示",Vector2(1600,981),27,GOLD,true)
 binding_text(ui,"%s 短传 / %s 直塞：朝队友选择方向。\n%s 持球蓄力射门，上下方向调整角度。\n%s 防守横移，%s 无球时抢断。",["pass","through","shoot","jockey","tackle"],Vector2(1600,1045),25,INK)

func begin_travel() -> void:
 clear_ui()
 screen="travel"
 travel_left=2.0
 panel(ui,Rect2(770,970,1020,240),Color(0.02,0.04,0.07,0.95),CYAN)
 text(ui,"ORBITAL APPROACH  /  轨道接驳",Vector2(830,1009),25,CYAN)
 travel_text=text(ui,"前往"+Campaign.MISSIONS[mini(campaign.stage,2)].name+"轨道球场",Vector2(827,1065),43,INK,true)
 beep(140,0.7)

func start_match()->void:
 await match_loading.run(session,loader,stadium,controls,desktop_input,bold,prepare_match_session,prepare_match_view,render_match,func():match_loaded.emit())

func prepare_match_session()->void:
 clear_modal()
 clear_ui()
 session.prepare(campaign,tactic,arcade_rules,verify,bool(desktop_input.options.strict_rules))
 match_tools.reset()
 sim.teams[sim.view_team].assist=desktop_input.assistance
 pending_result=false

func prepare_match_view()->void:
 last_event=-1
 event_age=0
 stadium.prepare_match(sim,0 if online or practice else mini(campaign.stage,2))
 build_match_ui()

func build_match_ui()->void:
 match_hud.build(ui,ui_kit,sim,Campaign.MISSIONS[mini(campaign.stage,2)],online,practice,{"pause":pause_match,"help":func():show_help("match")})
 rules_view.build(ui,ui_kit,desktop_input)

func update_pass_arrow()->void:
 match_renderer.update_pass_arrow(stadium,session,controls,desktop_input)

func render_match(dt:float)->void:
 match_renderer.render(stadium,session,controls,desktop_input,match_tools,dt)
 var view=network.input_state() if online else sim
 match_hud.update(sim,view,controls,desktop_input,network.diagnostics() if online else ("测试编号 %d · 玩家 vs AI" % quick_fixture.seed if practice else ""),dt)
 var replaying:bool=match_tools.showing_replay(sim)
 rules_view.update(sim,match_hud,desktop_input,replaying,screen=="match")
 stadium.follow_ball(sim,replaying,camera_motion,dt)

func verify_mechanics()->void:
 await preload("res://mechanics_verification.gd").new().run(self)

func verify_receiving_defending()->void:
 await preload("res://receiving_defending_verification.gd").new().run(self)

func pause_match() -> void:
 if screen!="match": return
 if online:
  show_online_menu()
  return
 controls.reset()
 screen="pause"
 sim.apply_command(sim.view_team,{"action":Match.Mechanics.CANCEL})
 sim.charging=false
 sim.charge=0
 clear_modal()
 dim_modal()
 panel(modal,Rect2(850,300,860,960 if practice else 850))
 text(modal,"比赛暂停",Vector2(915,454),51,INK,true)
 text(modal,"比分与剩余时间已冻结",Vector2(918,538),26,MUTED)
 button(modal,"替补席",Rect2(1400,535,240,58),func():show_substitutions())
 button(modal,"继续比赛",Rect2(915,625,730,84),resume_match,true)
 button(modal,"同阵容重赛" if practice else "重新开始本场",Rect2(915,738,730,78),start_match)
 if practice: button(modal,"重新随机并开赛",Rect2(915,846,730,78),reroll_quick_match)
 button(modal,"操作辅助与传球指示",Rect2(915,954 if practice else 850,730,78),show_assistance_settings)
 button(modal,"返回主菜单" if practice else "放弃本场 · 返回舰桥",Rect2(915,1060 if practice else 956,730,78),show_menu if practice else show_hub)
 text(modal,"测试编号 %d · 重赛保留阵容与随机种子" % quick_fixture.seed if practice else "放弃本场不会发放奖励，也不会改变航程。",Vector2(918,1180 if practice else 1070),21,MUTED)

func resume_match() -> void:
 clear_modal()
 screen="match"

func show_result() -> void:
 if online:
  show_online_result()
  return
 if practice:
  show_practice_result()
  return
 if pending_result: return
 pending_result=true
 result_data=campaign.finish(sim.score)
 persist()
 screen="result"
 clear_ui()
 chrome("赛后报告  /  "+("群星杯冠军" if result_data.champion else "航程结算"))
 panel(ui,Rect2(655,195,1250,1120),Color(0.025,0.047,0.08,0.97),GOLD if result_data.won else Color("3b5f7e"))
 text(ui,"★  STAR CUP CHAMPION  ★" if result_data.champion else ("VICTORY  /  航线已解锁" if result_data.won else "再整旗鼓  /  航线等待挑战"),Vector2(728,244),27,GOLD)
 text(ui,"群星之巅，为你加冕" if result_data.champion else ("向下一颗星球出发" if result_data.won else "平局 · 再来一场" if sim.score[0]==sim.score[1] else "星海不会止步于此"),Vector2(725,308),49,INK,true)
 text(ui,"群星联队",Vector2(756,474),31,CYAN,true)
 text(ui,"%d   :   %d" % [sim.score[0],sim.score[1]],Vector2(1110,434),79,INK,true)
 text(ui,Campaign.MISSIONS[sim.stage].club,Vector2(1478,474),30,Color("ffa48b"),true)
 var possession_total: float=maxf(0.01,sim.possession[0]+sim.possession[1])
 var stats: Array=[ ["射门",str(sim.shots[0]),str(sim.shots[1])], ["传球",str(sim.passes[0]),str(sim.passes[1])], ["控球",str(roundi(sim.possession[0]/possession_total*100))+"%",str(roundi(sim.possession[1]/possession_total*100))+"%"] ]
 for i in 3:
  var y:=603+i*70
  panel(ui,Rect2(730,y,1100,60),Color("14273a"),Color.TRANSPARENT)
  text(ui,stats[i][0],Vector2(1207,y+9),24,MUTED)
  text(ui,stats[i][1],Vector2(927,y+6),29,CYAN,true)
  text(ui,stats[i][2],Vector2(1517,y+6),29,INK,true)
 text(ui,"+ %d 星币" % result_data.reward,Vector2(735,867),43,GOLD,true)
 text(ui,"冠军已记录 · 可返回舰桥开启新的航程" if result_data.champion else ("下一站："+Campaign.MISSIONS[mini(campaign.stage,2)].name if result_data.won else "保留成长，训练补强后再次挑战。"),Vector2(735,957),27,MUTED)
 button(ui,"返回舰桥   /   领取奖励",Rect2(730,1105,1100,105),show_hub,true)
 text(ui,"奖励已到账 · 航程已自动保存" if campaign.save_error=="" else campaign.save_error,Vector2(735,1254),22,MUTED)
 beep(660 if result_data.won else 220,0.5)

func dim_modal() -> void:
 var dim:=ColorRect.new()
 dim.size=Vector2(2560,1440)
 dim.color=Color(0.005,0.01,0.025,0.84)
 modal.add_child(dim)

func show_help(from: String) -> void:
 previous_screen=from
 controls.reset()
 if from=="match" and online:
  network.submit_local({"move":Vector2.ZERO,"sprint":false,"jockey":false,"action":128,"aim":0.0,"tactic":sim.tactic,"assist_active":false},1.0/60)
 if from=="match" and not online: sim.apply_command(sim.view_team,{"action":Match.Mechanics.CANCEL})
 screen="help"
 clear_modal()
 dim_modal()
 panel(modal,Rect2(470,188,1620,1080))
 text(modal,"第一次登场，也能掌控全场。",Vector2(538,237),47,INK,true)
 text(modal,"每队 6 人（含门将）；头顶金色倒三角标记操控球员，青色为主队，橙色为客队。",Vector2(540,327),27,MUTED)
 var entries:Array=["移动与瞄准；留意屏幕上的进攻方向","持球蓄力射门；上下方向选择球门角度","方向选队友，按住蓄力、松开出球；轻点快速传球","无球按下抢断；横移面向球，抢断落空有恢复时间","消耗体力冲刺 / 防守切人；不冲刺时恢复体力",""]
 for i in entries.size():
  var y:=418+i*92
  var bindings:Array=[["move"],["shoot"],["pass","through"],["tackle","jockey"],["sprint","switch"],["pause","help"]][i]
  binding_text(modal,["%s","%s 按住再松开","%s 短传  /  %s 直塞","%s 抢断  /  %s 横移","%s 冲刺  /  %s 换人","%s 菜单  /  %s 指南"][i],bindings,Vector2(543,y),26,CYAN)
  if i==5: binding_text(modal,"打开菜单与指南；%s 切换战术",["tactics"],Vector2(949,y),26,INK)
  else: text(modal,entries[i],Vector2(949,y),26,INK)
 binding_text(modal,"%s 挑传 / 无球铲球   ·   %s + %s 吊射   ·   %s + %s 挑直塞\n%s + %s 弧线射门   ·   蓄力中按 %s 假射   ·   高空球按射门键头球 / 凌空\n持球 %s 护球   ·   %s + %s 二过一   ·   防守时按住 %s 门将出击\n铲球：低速原地伸腿；跑得越快滑得越远，起身后恢复移动。\n满蓄力可能打飞；脚踢边线球，定位球限时开出，禁区犯规判点球。",["cross","chip","shoot","chip","through","finesse","shoot","pass","jockey","chip","pass","through"],Vector2(543,954),23,MUTED)
 button(modal,"进阶操作",Rect2(543,1150,400,78),func():show_extra_help())
 button(modal,"明白了  /  继续",Rect2(970,1150,1047,78),close_help,true)

func close_help() -> void:
 clear_modal()
 screen=previous_screen
 if not practice and not online:
  campaign.tutorial_seen=true
  if has_save: persist()

func toast(value: String) -> void:
 if is_instance_valid(toast_label): toast_label.queue_free()
 toast_label=text(ui,value,Vector2(740,1308),24,GOLD,true,1100)
 toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 ui_age=0

func toggle_fullscreen() -> void:
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func toggle_sound() -> void:
 sounds=not sounds
 if is_instance_valid(audio): audio.enabled=sounds
 if is_instance_valid(sound_button): sound_button.text="音效 开" if sounds else "音效 关"

func setup_audio() -> void:
 audio=preload("res://game_audio.gd").new()
 audio.enabled=sounds
 add_child(audio)
 audio.start()

func beep(frequency:float,duration:float)->void:
 if is_instance_valid(audio): audio.beep(frequency,duration)

func kick_sound(power:float)->void:
 if is_instance_valid(audio): audio.kick_sound(power)

func update_audio()->void:
 if is_instance_valid(audio): audio.fill_buffer()

func sync_control_context()->void:
 if sim==null: return
 var context=network.input_state() if online else sim
 var team:int=network.local_team if online else 0
 if team<0 or team>=context.teams.size(): return
 controls.receiving=context.mechanics.can_buffer(context,int(context.teams[team].selected))
 controls.team_attacking=context.owner>=0 and context.owner/Team.SIZE==team or (context.owner<0 and context.last_touch/Team.SIZE==team and not context.ball_is_shot)
 controls.restart=context.phase=="restart"
 controls.restart_preparing=context.phase=="restart" and not context.Rules.Flow.ready(context)
 controls.sync_context(int(context.teams[team].selected),context.owner,int(context.teams[team].tactic))
 var p:Dictionary=context.players[int(context.teams[team].selected)]
 controls.aerial_available=context.phase=="play" and context.owner<0 and context.ball_height>=0.8 and context.ball_height<=p.body.head_height+1.5 and p.pos.distance_to(context.ball)<=4.5

func _physics_process(dt:float)->void:
 if booting: return
 if online:
  if network.active and network.running and network.local_team>=0:
   var command:Dictionary
   if bot_mode or graphical_test or server_only: command=bot_command()
   else:
    controls.enabled=session.accepts_match_input()
    sync_control_context()
    command=controls.command()
   network.submit_local(command,dt)
  network.advance(dt)
 elif session.runs_local_simulation():
  controls.enabled=true
  sync_control_context()
  var command:Dictionary=controls.command()
  session.submit(command,dt)
  sim.step(dt)
  if sim.finished: show_result()

func _process(dt:float)->void:
 if booting or (is_instance_valid(loader) and loader.active): return
 if is_instance_valid(pass_arrow) and screen!="match": pass_arrow.visible=false
 if not session.shows_rules(): rules_view.hide()
 if server_only or bot_mode:
  if network_test and Time.get_ticks_msec()-network.start_time>55000:
   push_error("NETWORK_TEST_TIMEOUT")
   get_tree().quit(2)
  return
 time+=dt
 if is_instance_valid(environment_visual) and session.animates_environment():
  environment_visual.update(dt)
 desktop_input.step(dt)
 ui_age+=dt
 screen_ticks+=1
 if library_verify and screen_ticks==60:
  await capture("player-library")
  library_screen.details(PlayerLibrary.find("legend-messi"))
 elif library_verify and screen_ticks==100:
  await capture("player-library-details")
  print("PLAYER_LIBRARY_UI_VERIFY_PASS count=",PlayerLibrary.all().size())
  get_tree().quit()
 if screen=="bodies":
  body_showroom.update(dt)
  if model_verify and screen_ticks==60:
   await capture("player-bodies-front")
   body_showroom.angle=PI/2
  elif model_verify and screen_ticks==100:
   await capture("player-bodies-side")
   body_showroom.angle=PI
  elif model_verify and screen_ticks==140:
   await capture("player-bodies-back")
   body_showroom.running=true
   body_showroom.angle=0.4
  elif model_verify and screen_ticks==190:
   await capture("player-bodies-running")
   print("BODY_SHOWROOM_VERIFY_PASS")
   get_tree().quit()
 planet.rotate_y(dt*0.018)
 if is_instance_valid(toast_label) and ui_age>4: toast_label.modulate.a=maxf(0,5-ui_age)
 if session.renders_match(previous_screen): render_match(dt)
 elif screen=="travel":
  travel_left-=dt
  camera.position=camera.position.lerp(Pitch.CAMERA,dt*1.4)
  camera.look_at(Vector3(0,0,-1))
  if travel_left<=0: start_match()
 if session.updates_replay(): update_match_tools(dt)
 update_impact_feedback(dt)
 update_audio()
 if verify: verification_tick()
 if graphical_test and screen=="match" and sim.elapsed>1.0 and not network_capture_done:
  network_capture_done=true
  await capture("network-match")

func _input(event:InputEvent)->void:
 if booting or (is_instance_valid(loader) and loader.active):
  if is_instance_valid(desktop_input): desktop_input.observe(event)
  get_viewport().set_input_as_handled()
  return
 if not is_instance_valid(desktop_input): return
 if desktop_input.route(event):
  get_viewport().set_input_as_handled()
  return
 var pressed_key:bool=event is InputEventKey and event.pressed and not event.echo
 var pause_button:bool=(pressed_key and event.physical_keycode==KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START)
 if pressed_key and event.physical_keycode==KEY_F11: toggle_fullscreen(); return
 if pause_button:
  navigate_back()
  get_viewport().set_input_as_handled()
  return
 if screen!="match": return
 if not match_tools.replay.is_empty() and ((event is InputEventKey and event.pressed and event.physical_keycode in [KEY_S,KEY_D,KEY_A,KEY_W]) or (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_X,JOY_BUTTON_Y])):
  match_tools.skip_replay();get_viewport().set_input_as_handled();return
 if pressed_key and event.physical_keycode==KEY_F2: save_scenario();return
 if pressed_key and event.physical_keycode==KEY_F3: retry_scenario();return
 if (pressed_key and event.physical_keycode==KEY_F1) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_BACK):
  show_help("match")
  get_viewport().set_input_as_handled()
  return
 controls.enabled=true
 sync_control_context()
 if controls.handle(event): get_viewport().set_input_as_handled()

func navigate_back()->void:
 if screen=="match": pause_match()
 elif screen=="pause": resume_match()
 elif screen=="online_menu": clear_modal();screen="match";controls.enabled=true
 elif screen=="help": close_help()
 elif screen=="assist_settings": close_assistance_settings()
 elif screen=="substitutions": close_match_tools()
 elif screen=="briefing": show_hub()
 elif screen=="menu": clear_modal()
 elif screen=="library":
  if modal.get_child_count()>0: clear_modal()
  elif library_screen.picking>=0: library_screen.show_squad()
  else: show_menu()
 elif screen in ["squad","bodies","hub","lobby","practice_result","online_result","connection_lost"]: show_menu()
 elif screen=="result": show_hub()

func on_controller_disconnected()->void:
 if screen=="match": pause_match()
 toast("手柄已断开 · 可使用键盘继续")

func cancel_charge_input()->void:
 controls.reset()
 if screen=="match" and sim!=null:
  sim.charging=false
  sim.charge=0
  controls.pending|=128

func _notification(what:int)->void:
 if is_instance_valid(desktop_input):
  if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: desktop_input.suspend()
  elif what==NOTIFICATION_WM_WINDOW_FOCUS_IN: desktop_input.window_active=true
 if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and screen=="match" and not verify and not quick_verify and not bot_mode and not graphical_test:
  if online: show_online_menu()
  else: pause_match()
func verification_tick()->void:
 verification_driver.verification_tick(self)

func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 var img:=get_viewport().get_texture().get_image()
 # Canvas items render at the physical window size, keeping the 2K design coordinates.
 # The OS can clamp an oversized window's drawable surface to the display.
 assert(img.get_width()>0 and img.get_height()>0)
 print("CAPTURE ",name," render=",img.get_size()," window=",get_window().size)
 var err:=img.save_png("res://artifacts/"+name+".png")
 assert(err==OK)

func argument(prefix:String,fallback:String)->String:
 for value in OS.get_cmdline_user_args():
  if value.begins_with(prefix): return value.trim_prefix(prefix)
 return fallback

func show_quick_options(randomize_teams:bool=true)->void:
 if randomize_teams or not QuickMatch.valid_fixture(quick_fixture): new_quick_fixture()
 clear_modal()
 dim_modal()
 preload("res://quick_match_screen.gd").build(modal,ui_kit,quick_fixture,quick_environment,quick_ice_mode,camera_motion,{
  "rules":func():quick_ice_mode=not quick_ice_mode;quick_arcade=false;show_quick_options(false),
  "camera":func():camera_motion=not camera_motion;show_quick_options(false),
  "stadium":func():cycle_environment("stadium"),
  "weather":func():cycle_environment("weather"),
  "gravity":func():cycle_environment("gravity"),
  "start":begin_quick_match,"reroll":show_quick_options,"back":clear_modal})

func cycle_environment(key:String,_legacy_count:int=0)->void:
 quick_environment[key]=Conditions.next_option(key,int(quick_environment[key]))
 show_quick_options(false)
 # Keep keyboard/controller focus on the option being cycled.
 var prefix:String={"stadium":"球场：","weather":"天气：","gravity":"重力"}.get(key,"")
 for child in modal.get_children():
  if child is Button and ((key=="gravity" and "重力" in child.text) or (key!="gravity" and child.text.begins_with(prefix))):
   child.grab_focus();break

func new_quick_fixture()->void:
 var previous:Dictionary=quick_fixture.duplicate(true)
 quick_fixture=QuickMatch.generate()
 while not previous.is_empty() and (quick_fixture.seed==previous.seed or (quick_fixture.home==previous.home and quick_fixture.away==previous.away)):
  quick_fixture=QuickMatch.generate()

func begin_quick_match()->void:
 if network.active: network.close()
 online=false
 practice=true
 start_match()

func reroll_quick_match()->void:
 new_quick_fixture()
 begin_quick_match()

func show_lobby()->void:
 network.local_roster=Squad.ids.duplicate()
 if "--test-alternate-roster" in OS.get_cmdline_user_args(): network.local_roster[1]="legend-mbappe"
 clear_modal()
 clear_ui()
 screen="lobby"
 online=true
 camera_hub()
 chrome("ONLINE PLAY / 1 对 1 六人制")
 panel(ui,Rect2(72,190,1140,1115))
 text(ui,"与另一位玩家对战",Vector2(122,234),51,INK,true)
 text(ui,"每人控制一支六人球队，随时切换场上球员。",Vector2(125,334),26,MUTED)
 text(ui,"服务器地址",Vector2(125,427),24,CYAN)
 address_field=LineEdit.new()
 address_field.text="127.0.0.1"
 address_field.position=Vector2(125,479)
 address_field.size=Vector2(775,76)
 address_field.add_theme_font_size_override("font_size",29)
 ui.add_child(address_field)
 text(ui,"端口",Vector2(925,427),24,CYAN)
 port_field=LineEdit.new()
 port_field.text="28765"
 port_field.position=Vector2(925,479)
 port_field.size=Vector2(225,76)
 port_field.add_theme_font_size_override("font_size",29)
 ui.add_child(port_field)
 var mode_button:=button(ui,"房间模式："+("冰球反弹" if network.ice_mode else "经典六人制"),Rect2(125,370,1025,50),func():
  if not network.active: network.ice_mode=not network.ice_mode;show_lobby())
 mode_button.disabled=network.active
 button(ui,"创建房间",Rect2(125,595,495,83),func(): network.strict_rules=bool(desktop_input.options.strict_rules);network.host(clampi(int(port_field.text),1024,65535)))
 button(ui,"加入房间",Rect2(650,595,500,83),func(): network.join(address_field.text.strip_edges(),clampi(int(port_field.text),1024,65535)))
 lobby_status=text(ui,"创建房间，或输入对方 / 专用服务器地址后加入。",Vector2(127,744),26,GOLD,false,1010)
 button(ui,"准备开球",Rect2(125,879,1025,94),func(): network.set_ready(),true)
 button(ui,"返回主菜单",Rect2(125,1045,1025,76),show_menu)
 text(ui,"使用我的球队 · 不含星际杯训练加成\n3 分钟比赛 · 平局金球加时",Vector2(125,1160),23,MUTED)
 panel(ui,Rect2(1450,825,940,400))
 text(ui,"连接方式",Vector2(1500,864),31,CYAN,true)
 text(ui,"同一台电脑：地址使用 127.0.0.1。\n局域网：填写房主电脑的局域网 IP。\n互联网：使用可访问的专用服务器地址。\n自建房间需要网络允许对应 UDP 端口。",Vector2(1500,930),26,INK)

func on_network_status(value:String)->void:
 print("NETWORK_STATUS ",value)
 if is_instance_valid(lobby_status): lobby_status.text=value
 if screen=="lobby":
  for item in ui.get_children():
   if item is Button and item.text.begins_with("房间模式："):
    item.text="房间模式："+("冰球反弹" if network.ice_mode else "经典六人制")
    item.disabled=network.active
 if (bot_mode or graphical_test) and network.local_team>=0 and not network.running and not bot_ready_sent:
  bot_ready_sent=true
  network.set_ready()

func on_network_start()->void:
 online=true
 net_result_shown=false
 sim=network.sim
 controls.reset()
 if server_only or bot_mode:
  screen="match"
  var load_delay:=int(argument("--load-delay-ms=","0")) if network_test else 0
  if load_delay>0:
   await get_tree().create_timer(float(load_delay)/1000.0).timeout
   assert(network.preparing and sim.frame==0 and sim.elapsed==0)
   print("NETWORK_LOADING_WAIT_PASS frame=",sim.frame," elapsed=",sim.elapsed)
  network.scene_ready()
  return
 start_match()

func on_network_end()->void:
 if network_test:
  print("NETWORK_ASSISTANCE levels=",[network.sim.teams[0].assist,network.sim.teams[1].assist])
  if bot_mode and int(network.sim.teams[network.local_team].assist)!=clampi(int(argument("--assist-level=","1")),0,2):
   push_error("NETWORK_ASSISTANCE_MISMATCH")
   get_tree().quit(2)
   return
 if network_test and network.round_id<int(argument("--rounds=","1")):
  print("NETWORK_ROUND_PASS round=",network.round_id," team=",network.local_team)
  await get_tree().create_timer(0.5).timeout
  if network.local_team>=0: network.set_ready()
  return
 if graphical_test:
  show_online_result()
  await capture("network-result")
  print("NETWORK_TEST_PASS role=graphical-client team=",network.local_team," snapshots=",network.received_count," score=",network.sim.score," frame=",network.sim.frame)
  print("GRAPHICAL_NETWORK_PASS prediction=",network.prediction_ready)
  await get_tree().create_timer(1.5).timeout
  get_tree().quit()
  return
 if server_only or bot_mode:
  if network_test:
   print("NETWORK_TEST_PASS role=",("server" if server_only else "client")," team=",network.local_team," snapshots=",network.received_count," score=",network.sim.score," frame=",network.sim.frame)
   # Leave time for the reliable final snapshot to reach both peers.
   await get_tree().create_timer(0.75 if server_only else 1.5).timeout
   get_tree().quit()
  return
 show_online_result()

func on_network_lost(value:String)->void:
 if server_only or bot_mode:
  if network_test:
   push_error(value)
   get_tree().quit(3)
  return
 load_epoch+=1
 if is_instance_valid(loader): loader.finish()
 controls.reset()
 screen="connection_lost"
 clear_modal()
 dim_modal()
 panel(modal,Rect2(680,430,1200,550))
 text(modal,"连接已结束",Vector2(743,484),45,INK,true)
 text(modal,value,Vector2(745,596),28,MUTED,false,1060)
 button(modal,"返回主菜单",Rect2(745,817,1060,85),show_menu,true)

func show_online_menu()->void:
 if screen!="match": return
 controls.reset()
 network.submit_local({"move":Vector2.ZERO,"sprint":false,"jockey":false,"action":128,"aim":0.0,"tactic":sim.tactic,"assist_active":false},1.0/60)
 screen="online_menu"
 clear_modal()
 dim_modal()
 panel(modal,Rect2(775,470,1010,590))
 text(modal,"比赛仍在继续",Vector2(839,515),44,INK,true)
 text(modal,"在线对局不会暂停；返回后可继续操作。",Vector2(841,609),27,MUTED)
 button(modal,"继续比赛",Rect2(840,737,440,89),func(): clear_modal(); screen="match"; controls.enabled=true,true)
 button(modal,"退出对局",Rect2(1305,737,414,89),show_menu)
 button(modal,"替补席",Rect2(1450,575,270,65),func():show_substitutions())
 button(modal,"操作辅助与传球指示",Rect2(840,865,879,78),show_assistance_settings)

func show_online_result()->void:
 if net_result_shown: return
 net_result_shown=true
 clear_modal()
 clear_ui()
 screen="online_result"
 var home:int=sim.score[sim.view_team]
 var away:int=sim.score[1-sim.view_team]
 chrome("ONLINE / 比赛结束")
 panel(ui,Rect2(670,310,1220,810))
 text(ui,"比赛胜利" if home>away else ("平局" if home==away else "下场再战"),Vector2(744,355),56,GOLD,true)
 text(ui,"主队  %d  :  %d  客队" % [sim.score[0],sim.score[1]],Vector2(744,497),66,INK,true)
 text(ui,"你的球队："+("主队" if sim.view_team==0 else "客队"),Vector2(748,621),28,CYAN)
 text(ui,"射门 %d    传球 %d    抢断 %d    扑救 %d" % [sim.shots[sim.view_team],sim.passes[sim.view_team],sim.tackles[sim.view_team],sim.saves[sim.view_team]],Vector2(748,718),29,MUTED)
 button(ui,"留在房间 / 再战",Rect2(745,884,660,91),show_lobby,true)
 button(ui,"返回主菜单",Rect2(1430,884,384,91),show_menu)
 text(ui,"本场结果由服务器结算 · 联机不修改单人战役存档",Vector2(748,1026),23,MUTED)

func show_practice_result()->void:
 clear_modal()
 clear_ui()
 screen="practice_result"
 chrome("QUICK MATCH / 比赛结束")
 panel(ui,Rect2(720,340,1120,820))
 text(ui,"比赛结束",Vector2(790,440),54,INK,true)
 text(ui,"%d   :   %d" % [sim.score[0],sim.score[1]],Vector2(1060,559),84,GOLD,true)
 text(ui,"测试编号 %d · 不计入星际杯进度" % quick_fixture.seed,Vector2(790,715),26,MUTED)
 button(ui,"重新随机并开赛",Rect2(790,836,490,86),reroll_quick_match,true)
 button(ui,"同阵容重赛",Rect2(1310,836,450,86),start_match)
 button(ui,"返回主菜单",Rect2(790,974,970,80),show_menu)

func bot_command()->Dictionary:
 var s=network.sim
 var team:int=network.local_team
 if "--latency-test" in OS.get_cmdline_user_args(): return network.latency_test.bot(s,team)
 if "--rules-test" in OS.get_cmdline_user_args() and s.frame>=1040 and s.frame<1160:
  return {"move":Vector2.ZERO,"sprint":false,"jockey":false,"action":0,"aim":0.0,"tactic":1,"assist":1,"assist_active":true,"skip_restart":true}
 if "--mechanics-test" in OS.get_cmdline_user_args(): return network.mechanics_test.bot(s,team)
 if "--rules-test" in OS.get_cmdline_user_args() and s.frame>=325 and s.frame<375:
  # Do not let a generic bot's periodic switch race the staged one-two receiver.
  return {"move":Vector2.RIGHT if team==0 else Vector2.ZERO,"sprint":false,"jockey":false,"action":4 if s.frame>=335 and team==0 and s.owner==s.selected else 0,"aim":0.0,"tactic":1,"assist":1,"assist_active":true,"chip":true}
 if "--rules-test" not in OS.get_cmdline_user_args(): s=network.input_state()
 var p:Dictionary=s.players[s.selected]
 var move:=Vector2.ZERO
 var action:=0
 if s.phase=="restart":
  if s.restart_team==team and s.freeze<=0:
   action=2 if s.restart_kind=="penalty" else 4
   if "--rules-test" in OS.get_cmdline_user_args() and s.restart_kind=="corner": action=256
 elif s.owner==s.selected:
  move=Vector2(s.side(team),0)
  if "--rules-test" in OS.get_cmdline_user_args() and s.frame>=330 and s.frame<360: action=4
  if p.pos.x*s.side(team)>11:
   if not s.charging: action|=1
   elif s.charge>0.3: action|=2
 else:
  move=(s.ball-p.pos).normalized()
  if s.frame%55==0: action|=16
  if p.pos.distance_to(s.ball)<2.2: action|=32
 return {"move":move,"sprint":true,"jockey":false,"action":action,"aim":-1.0 if p.pos.y<0 else 1.0,"tactic":1,"assist":clampi(int(argument("--assist-level=","1")),0,2),"assist_active":true,"finesse":"--finesse-test" in OS.get_cmdline_user_args(),"chip":"--rules-test" in OS.get_cmdline_user_args() and (s.restart_kind=="penalty" or (s.frame>=330 and s.frame<360)),"keeper_rush":"--rules-test" in OS.get_cmdline_user_args() and s.frame>=100 and s.frame<125}

func verify_pitch_modes()->void:
 await preload("res://pitch_modes_verification.gd").new().run(self)

func show_advanced_settings()->void:
 clear_modal()
 dim_modal()
 tools_screen.advanced_settings(modal,ui_kit,desktop_input,show_advanced_settings,show_assistance_settings)

func show_substitutions()->void:
 controls.reset()
 screen="substitutions"
 clear_modal()
 dim_modal()
 tools_screen.substitutions(modal,ui_kit,sim,session.submit_action,show_substitutions,close_match_tools)

func close_match_tools()->void:
 clear_modal()
 screen="match"
 controls.reset()

func show_extra_help()->void:
 clear_modal()
 dim_modal()
 tools_screen.extra_help(modal,ui_kit,desktop_input,func():show_help(previous_screen))

func save_scenario()->void:
 match_tools.save_scenario(session,toast)

func retry_scenario()->void:
 match_tools.retry_scenario(session,controls,toast)

func update_match_tools(dt:float)->void:
 match_tools.update(sim,stadium,controls,desktop_input,match_hud,dt)

func update_impact_feedback(dt:float)->void:
 impact_feedback.update(camera,sim,screen=="match",int(desktop_input.options.get("camera_impact",1)),dt)

func begin_library_page(page_name:String,title:String)->void:
 clear_modal()
 clear_ui()
 camera_hub()
 screen=page_name
 chrome(title)
