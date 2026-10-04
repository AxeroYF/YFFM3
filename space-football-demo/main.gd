extends Node3D
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
const Assistance=preload("res://play_assistance.gd")
var assistance_return:="menu"
var pass_arrow:MeshInstance3D
var rules_view=preload("res://rules_presentation.gd").new()
var impact_feedback=preload("res://impact_feedback.gd").new()
var quick_fixture:Dictionary={}
var quick_arcade:=false
var quick_ice_mode:=false
var quick_verify:=false
const DesktopInput=preload("res://desktop_input.gd")
const InputGlyph=preload("res://input_glyph.gd")
var desktop_input:Node
var binding_icons:Array[Control]=[]
var binding_labels:Array[Label]=[]
var input_verify:=false
const INK = Color("edf6ff")
const MUTED = Color("8da9bf")
const CYAN = Color("6af4dc")
const GOLD = Color("f3ca82")
var campaign = Campaign.new()
var sim
var screen := "menu"
var previous_screen := "hub"
var ui: Control
var modal: Control
var font: SystemFont
var bold: SystemFont
var camera: Camera3D
var arena: Node3D
var planet: MeshInstance3D
var planet_material: ShaderMaterial
var orbit: Node3D
var actors: Array[Node3D] = []
var indicator: MeshInstance3D
var football: Node3D
var ball_shadow: MeshInstance3D
var trail: Array[MeshInstance3D] = []
var trail_points: Array[Vector3] = []
var portraits: Array[Texture2D] = []
var records: Array = []
var score_label: Label
var time_label: Label
var energy_label: Label
var event_label: Label
var player_label: Label
var charge_bar: ColorRect
var energy_bar: ColorRect
var rule_label: Label
var selected_labels: Array[Label3D] = []
var event_age := 0.0
var last_event := -1
var time := 0.0
var ui_age := 0.0
var pending_result := false
var result_data := {}
var has_save := false
var tactic := 1
var sounds := true
var sound_player: AudioStreamPlayer
var sound_playback: AudioStreamGeneratorPlayback
var sound_left := 0.0
var sound_phase := 0.0
var sound_freq := 400.0
var sound_impact:=false
var sound_age:=0.0
var sound_power:=0.5
var verify := false
var verify_step := 0
var verify_ticks := 0
var screen_ticks := 0
var capture_busy := false
var toast_label: Label
var sound_button: Button
var aim_marker: MeshInstance3D
var travel_left := 0.0
var travel_text: Label
var controls=FootballInput.new()
var network:Node
var goal_nets:Array=[]
var online:=false
var server_only:=false
var bot_mode:=false
var network_test:=false
var arcade_rules:=false
var practice:=false
var lobby_status:Label
var address_field:LineEdit
var port_field:LineEdit
var network_label:Label
var settings_panel:Control
var rigs:Array[Node3D]=[]
var camera_motion:=true
var last_online_event:=-1
var net_result_shown:=false
var action_hint:Label
var bot_ready_sent:=false
var graphical_test:=false
var network_capture_done:=false
var arena_walls:Array[MeshInstance3D]=[]
var body_showroom:Node3D
var model_verify:=false
var library_screen=LibraryScreen.new()
var library_verify:=false
var booting:=true
var loader:CanvasLayer
var load_epoch:=0
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
  add_child(loader);loader.build(self);loader.begin("正在启动")
  await loader.present(0,"读取球员资料")
  if "--verify-loading" in OS.get_cmdline_user_args(): await capture("loading-startup")
 library_screen.game=self
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
 if input_verify: desktop_input.preferences_path="user://input-test-preferences.cfg"
 desktop_input.game=self
 desktop_input.changed.connect(refresh_binding_hints)
 desktop_input.active_pad_lost.connect(on_controller_disconnected)
 add_child(desktop_input)
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

func verify_ai()->void:
 await preload("res://ai_verification.gd").new().run(self)

func verify_motion_visuals()->void:
 await preload("res://motion_verification.gd").new().run(self)

func verify_locomotion_visuals()->void:
 await preload("res://locomotion_verification.gd").new().run(self)

func verify_loading_ui()->void:
 await preload("res://loading_verification.gd").new().run(self)

func verify_keeper_visuals()->void:
 practice=true
 await start_match()
 screen="keeper_verification"
 camera_motion=false
 ui.visible=false
 desktop_input.overlay.visible=false
 sim.freeze=0
 var p:Dictionary=sim.players[0]
 p.dir=Vector2(0,1)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=7
 camera.position=Vector3(p.pos.x,3.8,p.pos.y+9)
 camera.look_at(Vector3(p.pos.x,1.4,p.pos.y))
 for state_name in ["idle","dive","catch","throw"]:
  p.action=state_name;p.action_time=0.5;p.keeper_side=1;p.keeper_height=1.4
  sim.owner=0 if state_name=="catch" else -1
  p.keeper_holding=sim.owner==0
  sim.ball=p.pos+Vector2(0,0.8);sim.ball_height=p.body.height*0.65 if sim.owner==0 else Match.BallPhysics.FLOOR
  for i in 20: render_match(1.0/60)
  await capture("keeper-"+state_name)
 print("KEEPER_VISUAL_PASS")
 get_tree().quit()

func verify_release_ui()->void:
 Squad.ids=Squad.DEFAULT.duplicate()
 show_menu()
 await get_tree().create_timer(1.0).timeout
 await capture("main-menu")
 library_screen.show_squad()
 await get_tree().create_timer(0.4).timeout
 await capture("my-squad")
 library_screen.picking=1
 library_screen.query="姆巴佩"
 library_screen.show_library()
 await get_tree().create_timer(0.4).timeout
 await capture("squad-search")
 library_screen.details(PlayerLibrary.find("legend-mbappe"))
 await get_tree().create_timer(0.4).timeout
 await capture("player-abilities")
 var assigned:=false
 for child in modal.get_children():
  if child is Button and child.text=="前锋":
   child.pressed.emit()
   assigned=true
   break
 assert(assigned and Squad.ids[1]=="legend-mbappe")
 Squad.load_squad()
 assert(Squad.ids[1]=="legend-mbappe")
 await get_tree().create_timer(0.4).timeout
 await capture("my-squad-updated")
 practice=false
 await start_match()
 assert(sim.players[1].name=="姆巴佩" and rigs[1].body.height_cm==PlayerLibrary.find("legend-mbappe").heightCm)
 await get_tree().create_timer(2.0).timeout
 await capture("squad-match")
 print("RELEASE_UI_PASS roster_selection=button save=reload model=height abilities=server_catalog")
 get_tree().quit()

func verify_input_ui()->void:
 var runner=preload("res://input_verification.gd").new()
 await runner.run(self)

func verify_quick_ui()->void:
 var runner=preload("res://quick_match_verification.gd").new()
 await runner.run(self)

func material(color: Color, glow: float=0.0, metal: float=0.0) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new()
 m.albedo_color=color
 m.metallic=metal
 m.roughness=0.4
 if glow>0:
  m.emission_enabled=true
  m.emission=color
  m.emission_energy_multiplier=glow
 return m

func box(parent: Node3D, pos: Vector3, size_value: Vector3, mat: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 var mesh:=BoxMesh.new()
 mesh.size=size_value
 node.mesh=mesh
 node.material_override=mat
 node.position=pos
 parent.add_child(node)
 return node

func sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 var mesh:=SphereMesh.new()
 mesh.radius=radius
 mesh.height=radius*2
 mesh.radial_segments=48
 mesh.rings=24
 node.mesh=mesh
 node.material_override=mat
 node.position=pos
 parent.add_child(node)
 return node

func beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 var mesh:=CylinderMesh.new()
 mesh.top_radius=radius
 mesh.bottom_radius=radius
 mesh.height=a.distance_to(b)
 mesh.radial_segments=8
 node.mesh=mesh
 node.material_override=mat
 node.position=(a+b)*0.5
 node.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
 parent.add_child(node)
 return node

func ring(parent: Node3D, pos: Vector3, radius: float, width: float, mat: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 var mesh:=TorusMesh.new()
 mesh.inner_radius=radius-width
 mesh.outer_radius=radius+width
 mesh.rings=80
 mesh.ring_segments=8
 node.mesh=mesh
 node.material_override=mat
 node.position=pos
 parent.add_child(node)
 return node

func build_world() -> void:
 var environment:=WorldEnvironment.new()
 var env:=Environment.new()
 env.background_mode=Environment.BG_SKY
 var sky:=Sky.new()
 var sky_material:=ShaderMaterial.new()
 sky_material.shader=load("res://shaders/space.gdshader")
 sky.sky_material=sky_material
 env.sky=sky
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color("96b9df")
 env.ambient_light_energy=0.8
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 env.glow_enabled=true
 env.glow_intensity=0.6
 environment.environment=env
 add_child(environment)
 var light:=DirectionalLight3D.new()
 light.light_cull_mask=1
 light.rotation_degrees=Vector3(-52,-30,0)
 light.light_energy=1.9
 light.shadow_enabled=true
 add_child(light)
 var fill:=DirectionalLight3D.new()
 fill.light_cull_mask=1
 fill.rotation_degrees=Vector3(-10,150,0)
 fill.light_color=Color("5bc5fa")
 fill.light_energy=0.8
 add_child(fill)
 camera=Camera3D.new()
 camera.far=1000
 camera.near=0.1
 add_child(camera)
 planet_material=ShaderMaterial.new()
 planet_material.shader=load("res://shaders/planet.gdshader")
 planet_material.set_shader_parameter("base_color",Color("094b8a"))
 planet_material.set_shader_parameter("secondary_color",Color("39b1a4"))
 planet_material.set_shader_parameter("kind",1)
 planet=sphere(self,Vector3(28,6,-93),36,planet_material)
 var atmosphere:=ShaderMaterial.new()
 atmosphere.shader=load("res://shaders/atmosphere.gdshader")
 atmosphere.set_shader_parameter("tint",Color("49bdec"))
 sphere(planet,Vector3.ZERO,36.6,atmosphere)
 orbit=Node3D.new()
 orbit.position=planet.position
 orbit.rotation_degrees=Vector3(15,0,-20)
 add_child(orbit)
 ring(orbit,Vector3.ZERO,49,0.07,material(Color("728cbd"),0.4))
 ring(orbit,Vector3.ZERO,52,0.22,material(Color("cbb48e"),0.3,0.7))
 var rng:=RandomNumberGenerator.new()
 rng.seed=44
 var stars:=MultiMeshInstance3D.new()
 var multimesh:=MultiMesh.new()
 multimesh.transform_format=MultiMesh.TRANSFORM_3D
 var star_mesh:=SphereMesh.new()
 star_mesh.radius=0.13
 star_mesh.height=0.26
 star_mesh.radial_segments=6
 star_mesh.rings=4
 star_mesh.material=material(Color("b0d4ff"),3)
 multimesh.mesh=star_mesh
 multimesh.instance_count=650
 for i in 650:
  var pos:=Vector3(rng.randf_range(-220,220),rng.randf_range(-60,160),rng.randf_range(-240,-100))
  multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(0.4,2)),pos))
 stars.multimesh=multimesh
 add_child(stars)
 arena=Node3D.new()
 add_child(arena)
 var steel:=material(Color("14263d"),0,0.8)
 var dark:=material(Color("0b1323"),0,0.8)
 var glow:=material(CYAN,1.9)
 var orange:=material(Color("ff8267"),1.4)
 box(arena,Vector3(0,-1.6,0),Vector3(Pitch.HALF_LENGTH*2+8,2.6,Pitch.HALF_WIDTH*2+7),steel)
 box(arena,Vector3(0,-3.1,0),Vector3(Pitch.HALF_LENGTH*2-2,1,Pitch.HALF_WIDTH*2-1),dark)
 box(arena,Vector3(0,-0.12,0),Vector3(Pitch.HALF_LENGTH*2,0.2,Pitch.HALF_WIDTH*2),load_pitch())
 for z in [-Pitch.HALF_WIDTH-3,Pitch.HALF_WIDTH+3]:
  box(arena,Vector3(0,-0.6,z),Vector3(Pitch.HALF_LENGTH*2+7,0.17,0.15),glow)
  for x in range(-32,33,8):
   box(arena,Vector3(x,0.25,z),Vector3(5.2,0.6,1.4),steel)
   box(arena,Vector3(x,0.62,z),Vector3(4.2,0.1,0.65),glow if x<0 else orange)
 for x in [-Pitch.HALF_LENGTH-3,Pitch.HALF_LENGTH+3]:
  box(arena,Vector3(x,-0.4,0),Vector3(0.16,0.2,Pitch.HALF_WIDTH*2+4),glow if x<0 else orange)
  for z in [-Pitch.HALF_WIDTH,Pitch.HALF_WIDTH]:
   box(arena,Vector3(x,-3.7,z),Vector3(3.4,4,3.4),steel)
   sphere(arena,Vector3(x,-5.9,z),1.1,material(Color("64d9ff"),3))
 var white:=material(Color("8cbac7"),0.45)
 for z in [-Pitch.HALF_WIDTH,Pitch.HALF_WIDTH]: beam(arena,Vector3(-Pitch.HALF_LENGTH,0.03,z),Vector3(Pitch.HALF_LENGTH,0.03,z),0.07,white)
 for x in [-Pitch.HALF_LENGTH,0,Pitch.HALF_LENGTH]: beam(arena,Vector3(x,0.03,-Pitch.HALF_WIDTH),Vector3(x,0.03,Pitch.HALF_WIDTH),0.07,white)
 ring(arena,Vector3(0,0.05,0),5,0.07,white)
 sphere(arena,Vector3(0,0.04,0),0.17,white)
 for side in [-1,1]:
  var goal_mat: Material=glow if side==-1 else orange
  box(arena,Vector3((Pitch.HALF_LENGTH+Pitch.GOAL_DEPTH*0.5)*side,-0.12,0),Vector3(Pitch.GOAL_DEPTH,0.2,Pitch.GOAL_HALF_WIDTH*2),material(Color("1c3547"),0.05))
  for z in [-Pitch.PENALTY_HALF_WIDTH,Pitch.PENALTY_HALF_WIDTH]: beam(arena,Vector3((Pitch.HALF_LENGTH-Pitch.PENALTY_DEPTH)*side,0.04,z),Vector3(Pitch.HALF_LENGTH*side,0.04,z),0.07,white)
  beam(arena,Vector3((Pitch.HALF_LENGTH-Pitch.PENALTY_DEPTH)*side,0.04,-Pitch.PENALTY_HALF_WIDTH),Vector3((Pitch.HALF_LENGTH-Pitch.PENALTY_DEPTH)*side,0.04,Pitch.PENALTY_HALF_WIDTH),0.07,white)
  for z in [-Pitch.GOAL_AREA_HALF_WIDTH,Pitch.GOAL_AREA_HALF_WIDTH]: beam(arena,Vector3((Pitch.HALF_LENGTH-Pitch.GOAL_AREA_DEPTH)*side,0.04,z),Vector3(Pitch.HALF_LENGTH*side,0.04,z),0.055,white)
  beam(arena,Vector3((Pitch.HALF_LENGTH-Pitch.GOAL_AREA_DEPTH)*side,0.04,-Pitch.GOAL_AREA_HALF_WIDTH),Vector3((Pitch.HALF_LENGTH-Pitch.GOAL_AREA_DEPTH)*side,0.04,Pitch.GOAL_AREA_HALF_WIDTH),0.055,white)
  for z in [-5,5]:
   beam(arena,Vector3(Pitch.HALF_LENGTH*side,0,z),Vector3(Pitch.HALF_LENGTH*side,3.6,z),0.12,goal_mat)
   beam(arena,Vector3(Pitch.HALF_LENGTH*side,3.6,z),Vector3((Pitch.HALF_LENGTH+3)*side,3.0,z),0.10,goal_mat)
  beam(arena,Vector3(Pitch.HALF_LENGTH*side,3.6,-5),Vector3(Pitch.HALF_LENGTH*side,3.6,5),0.12,goal_mat)
  var net:=preload("res://goal_net_visual.gd").new();arena.add_child(net);net.build(side);goal_nets.append(net)
  for z in [-Pitch.HALF_WIDTH,Pitch.HALF_WIDTH]:
   beam(arena,Vector3(Pitch.HALF_LENGTH*side,0,z),Vector3(Pitch.HALF_LENGTH*side,5.2,z),0.15,steel)
   sphere(arena,Vector3(Pitch.HALF_LENGTH*side,5.2,z),0.3,material(Color("e1edff"),4))
 var glass:=material(Color(0.15,0.55,0.7,0.09))
 glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 glass.cull_mode=BaseMaterial3D.CULL_DISABLED
 for z in [-Pitch.HALF_WIDTH-0.3,Pitch.HALF_WIDTH+0.3]: arena_walls.append(box(arena,Vector3(0,0.85,z),Vector3(Pitch.HALF_LENGTH*2,1.5,0.06),glass))
 for x in [-Pitch.HALF_LENGTH-0.3,Pitch.HALF_LENGTH+0.3]:
  for side in [-1,1]:
   arena_walls.append(box(arena,Vector3(x,0.85,side*(Pitch.HALF_WIDTH+5)*0.5),Vector3(0.06,1.5,Pitch.HALF_WIDTH-5),glass))
 # Match footballers are built when entering a fixture, not hidden behind the main menu.
 indicator=MeshInstance3D.new()
 var selection_mesh:=ImmediateMesh.new()
 for layer_index in 2:
  var selection_material:=material(Color("101c29") if layer_index==0 else GOLD)
  selection_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  selection_material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
  selection_material.no_depth_test=true
  selection_material.cull_mode=BaseMaterial3D.CULL_DISABLED
  selection_material.render_priority=10+layer_index
  selection_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,selection_material)
  var corners:Array=[Vector3(-0.65,0.45,0),Vector3(0.65,0.45,0),Vector3(0,-0.55,0)] if layer_index==0 else [Vector3(-0.50,0.36,0.01),Vector3(0.50,0.36,0.01),Vector3(0,-0.40,0.01)]
  for corner in corners: selection_mesh.surface_add_vertex(corner)
  selection_mesh.surface_end()
 indicator.mesh=selection_mesh
 indicator.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 arena.add_child(indicator)
 football=Node3D.new()
 arena.add_child(football)
 sphere(football,Vector3.ZERO,Match.BallPhysics.RADIUS,material(Color("f5faff"),0.1,0.15))
 var football_ring:=ring(football,Vector3.ZERO,Match.BallPhysics.RADIUS,0.018,material(Color("132138")))
 football_ring.rotation_degrees.x=90
 var football_ring2:=ring(football,Vector3.ZERO,Match.BallPhysics.RADIUS,0.018,material(Color("132138")))
 football_ring2.rotation_degrees.z=90
 ball_shadow=ring(arena,Vector3(0,0.06,0),0.34,0.025,material(Color("fbde91"),0.2))
 aim_marker=ring(arena,Vector3(Pitch.HALF_LENGTH,0.08,0),0.9,0.08,material(GOLD,2))
 aim_marker.visible=false
 pass_arrow=MeshInstance3D.new()
 var arrow_mesh:=ImmediateMesh.new()
 var arrow_material:=material(CYAN,0.3)
 arrow_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 arrow_material.cull_mode=BaseMaterial3D.CULL_DISABLED
 arrow_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,arrow_material)
 for vertex in [Vector3(0.65,0,0.10),Vector3(1.45,0,0.10),Vector3(0.65,0,-0.10),Vector3(0.65,0,-0.10),Vector3(1.45,0,0.10),Vector3(1.45,0,-0.10),Vector3(1.25,0,0.30),Vector3(1.95,0,0),Vector3(1.25,0,-0.30)]: arrow_mesh.surface_add_vertex(vertex)
 arrow_mesh.surface_end()
 pass_arrow.mesh=arrow_mesh
 pass_arrow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 arena.add_child(pass_arrow)
 pass_arrow.visible=false
 for i in 10:
  trail.append(sphere(arena,Vector3.ZERO,0.14*(1-float(i)/12),material(Color("f3cd8a"),1.4)))

func load_pitch() -> ShaderMaterial:
 var mat:=ShaderMaterial.new()
 mat.shader=load("res://shaders/pitch.gdshader")
 return mat

func create_actor(index: int) -> void:
 var actor:=Node3D.new()
 arena.add_child(actor)
 actors.append(actor)
 var color:=CYAN if index<Match.TEAM_SIZE else Color("ff866c")
 if index%Team.SIZE==0: color=GOLD if index<Team.SIZE else Color("b79bff")
 var rig:=FootballActor.new()
 actor.add_child(rig)
 var profile:Dictionary=sim.players[index].body if sim!=null else Body.profile(index%Team.SIZE)
 rig.build(color,Match.JERSEY_NUMBERS[index],index%Team.SIZE==0,profile)
 rig.set_meta("player_id",sim.players[index].player_id if sim!=null else "")
 rigs.append(rig)
 var label:=Label3D.new()
 label.font=bold
 label.font_size=44
 label.pixel_size=0.012
 label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 label.no_depth_test=true
 label.position.y=profile.height+0.35
 label.modulate=color
 label.outline_size=10
 label.text=Match.JERSEY_NUMBERS[index]
 actor.add_child(label)
 selected_labels.append(label)
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

func cycle_input_glyphs()->void:
 var options:=["auto","xbox","playstation","nintendo","generic"]
 desktop_input.glyph_override=options[(options.find(desktop_input.glyph_override)+1)%options.size()]
 desktop_input.update_prompts()
 if not desktop_input.save_preferences(): toast("按键图标偏好保存失败")
 for child in modal.get_children():
  if child is Button and child.text.begins_with("按键图标："):
   child.text="按键图标："+{"auto":"自动识别","xbox":"Xbox","playstation":"PlayStation","nintendo":"Nintendo","generic":"通用"}[desktop_input.glyph_override]

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
 b.pressed.connect(func(): beep(550,0.07); action.call())
 parent.add_child(b)
 return b

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

func camera_hub() -> void:
 camera.environment=null
 camera.cull_mask=1
 planet.position=Vector3(28,6,-93)
 orbit.position=planet.position
 planet_material.set_shader_parameter("base_color",Color("094b8a"))
 planet_material.set_shader_parameter("secondary_color",Color("39b1a4"))
 planet_material.set_shader_parameter("kind",1)
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 camera.fov=48
 camera.position=Vector3(69,46,85)
 camera.look_at(Vector3(-13,0,0))
 for actor in actors: actor.visible=false
 football.visible=false
 indicator.visible=false
 ball_shadow.visible=false
 aim_marker.visible=false
 for t in trail: t.visible=false

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
 button(modal,"分别调整辅助 / 镜头反馈 / 比赛选项",Rect2(655,1010,1250,55),func(): match_tools.advanced_settings(self))
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

func start_match() -> void:
 if is_instance_valid(loader) and loader.active: return
 camera.cull_mask=1
 load_epoch+=1
 var epoch:=load_epoch
 controls.reset()
 controls.enabled=false
 loader.begin("正在进入比赛")
 screen="loading"
 await loader.present(0,"准备双方阵容")
 if epoch!=load_epoch: return
 clear_modal()
 clear_ui()
 if online:
  sim=network.sim
 else:
  sim=Match.new()
  if practice:
   if not QuickMatch.valid_fixture(quick_fixture): quick_fixture=QuickMatch.generate()
   sim.setup(Campaign.new(),quick_fixture.seed,quick_fixture.home,quick_fixture.away,true)
   sim.teams[0].human=true
   sim.teams[1].human=false
   print("QUICK_MATCH_STARTED seed=",quick_fixture.seed," home=",quick_fixture.home," away=",quick_fixture.away)
  else: sim.setup(campaign,731 if verify else 0,Squad.ids)
  sim.arcade=quick_arcade if practice else arcade_rules
  sim.ice_mode=practice and quick_ice_mode
  if sim.ice_mode: sim.arcade=false
  sim.tactic=tactic
  sim.regulation=100
  sim.Rules.restart(sim,0,"kickoff",Vector2.ZERO)
 if not online: sim.mechanics.strict_rules=bool(desktop_input.options.strict_rules)
 match_tools.reset()
 sim.teams[sim.view_team].assist=desktop_input.assistance
 pending_result=false
 for actor in actors:
  arena.remove_child(actor)
  actor.queue_free()
 actors.clear()
 rigs.clear()
 selected_labels.clear()
 await loader.present(10,"双方阵容已就绪 · 准备球员 0 / 12")
 if epoch!=load_epoch: return
 for i in Match.PLAYER_COUNT:
  create_actor(i)
  await loader.present(10+(i+1)*70.0/Team.COUNT,"球员已就绪 %d / 12" % (i+1))
  if epoch!=load_epoch: return
 last_event=-1
 event_age=0
 trail_points.clear()
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 camera.fov=44
 camera.position=Pitch.CAMERA
 camera.look_at(Vector3(0,0,-1))
 planet.position=Vector3(40,-18,-76)
 orbit.position=planet.position
 var stage: int=0 if online or practice else mini(campaign.stage,2)
 planet_material.set_shader_parameter("kind",[1,2,0][stage])
 planet_material.set_shader_parameter("base_color",[Color("094b8a"),Color("762e23"),Color("392466")][stage])
 planet_material.set_shader_parameter("secondary_color",[Color("39b1a4"),Color("e9863d"),Color("d7a98e")][stage])
 for actor in actors: actor.visible=true
 for wall in arena_walls: wall.visible=sim.arcade or sim.ice_mode
 football.visible=true
 indicator.visible=true
 ball_shadow.visible=true
 for t in trail: t.visible=true
 build_match_ui()
 render_match(0)
 await loader.present(92,"球员已就位 · 完成球场画面")
 if epoch!=load_epoch: return
 if online and network.active:
  await loader.present(96,"本机已就绪 · 等待对手加载")
  if epoch!=load_epoch: return
  network.scene_ready()
  while network.preparing and epoch==load_epoch:
   await get_tree().process_frame
  if epoch!=load_epoch or not network.active: return
 await loader.present(100,"准备开球")
 if epoch!=load_epoch: return
 loader.finish()
 desktop_input.reset_navigation()
 controls.reset();controls.enabled=true
 screen="match"
 match_loaded.emit()

func build_match_ui() -> void:
 var mission: Dictionary=Campaign.MISSIONS[mini(campaign.stage,2)]
 panel(ui,Rect2(72,38,630,129))
 text(ui,"ONLINE  /  1v1  /  6v6" if online else ("QUICK MATCH  /  开发测试" if practice else mission.tag),Vector2(101,57),18,CYAN)
 text(ui,"冰球模式 · 反弹边界" if sim.ice_mode else "经典六人制 · 轨道球场" if not sim.arcade else mission.name+" / 星际规则",Vector2(99,97),29,INK,true)
 panel(ui,Rect2(790,35,980,155),Color(0.016,0.03,0.055,0.96))
 text(ui,"主队"+(" · 你" if sim.view_team==0 else ""),Vector2(833,74),31,CYAN,true)
 text(ui,("客队" if online else "AI 测试队" if practice else mission.club)+(" · 你" if sim.view_team==1 else ""),Vector2(1440,80),27,Color("ffa78c"),true)
 score_label=text(ui,"0  :  0",Vector2(1168,57),52,INK,true)
 time_label=text(ui,"00 : 00",Vector2(1192,127),22,GOLD)
 var pause_control:=button(ui,"菜单" if online else "暂停",Rect2(2255,43,233,65),pause_match)
 button_binding(pause_control,"pause")
 var help_control:=button(ui,"操作说明",Rect2(2255,121,233,56),func(): show_help("match"))
 button_binding(help_control,"help")
 rule_label=text(ui,"进攻方向  →     右侧球门",Vector2(929,215),24,MUTED)
 panel(ui,Rect2(72,1184,620,190))
 text(ui,"CONTROLLED PLAYER",Vector2(102,1203),17,GOLD)
 player_label=text(ui,"哈兰德  /  持球",Vector2(100,1237),32,INK,true)
 text(ui,"射门蓄力",Vector2(102,1307),20,MUTED)
 panel(ui,Rect2(230,1318,420,9),Color("203649"),Color.TRANSPARENT)
 charge_bar=ColorRect.new()
 charge_bar.position=Vector2(230,1318)
 charge_bar.size=Vector2(0,9)
 charge_bar.color=GOLD
 ui.add_child(charge_bar)
 panel(ui,Rect2(1880,1184,608,190))
 text(ui,"球员体力",Vector2(1910,1207),23,CYAN,true)
 energy_label=text(ui,"100%",Vector2(2360,1207),25,CYAN,true)
 panel(ui,Rect2(1910,1266,538,11),Color("203649"),Color.TRANSPARENT)
 energy_bar=ColorRect.new()
 energy_bar.position=Vector2(1910,1266)
 energy_bar.size=Vector2(538,11)
 energy_bar.color=CYAN
 ui.add_child(energy_bar)
 binding_hint(ui,"sprint","冲刺",Vector2(1910,1300))
 binding_hint(ui,"jockey","横移",Vector2(2080,1300))
 binding_hint(ui,"tackle","抢断",Vector2(2250,1300))
 panel(ui,Rect2(725,1227,1118,146))
 binding_hint(ui,"shoot","蓄力射门",Vector2(757,1242))
 binding_hint(ui,"pass","短传",Vector2(1010,1242))
 binding_hint(ui,"through","直塞",Vector2(1190,1242))
 binding_hint(ui,"switch","换人",Vector2(1370,1242))
 binding_hint(ui,"cross","挑传 / 滑铲",Vector2(1540,1242))
 binding_text(ui,"%s 移动 / 瞄准",["move"],Vector2(757,1310),22,MUTED)
 binding_text(ui,"%s + %s 弧线射门",["finesse","shoot"],Vector2(1230,1310),22,MUTED)
 event_label=text(ui,"准备开球",Vector2(740,1090),34,GOLD,true,1080)
 event_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 network_label=text(ui,"",Vector2(78,187),20,CYAN)
 action_hint=text(ui,"",Vector2(1910,1150),20,GOLD)
 rules_view.build(self)

func update_pass_arrow()->void:
 pass_arrow.visible=false
 if screen!="match" or not desktop_input.pass_indicator or sim==null or sim.finished: return
 if sim.phase in ["goal","foul"]: return
 if sim.phase=="restart" and not sim.Rules.Flow.ready(sim): return
 var view=network.input_state() if online else sim
 var index:int=view.selected
 var direction:=Vector2.ZERO
 if view.owner==index and not view.charging:
  direction=view.pass_plan(index,controls.movement(),false,desktop_input.assistance).direction
 elif view.owner<0 and not view.ball_is_shot and view.last_touch/Team.SIZE==view.view_team and view.kick_age<0.3:
  index=view.last_touch
  direction=view.velocity.normalized()
 if direction.length()<0.1: return
 pass_arrow.position=actors[index].position*Vector3(1,0,1)+Vector3(0,0.14,0)
 pass_arrow.rotation.y=-atan2(direction.y,direction.x)
 pass_arrow.visible=true

func render_match(dt: float) -> void:
 var predicted:bool=online and not multiplayer.is_server() and network.prediction_ready
 var view=network.input_state() if online else sim
 var selected:int=view.selected
 indicator.visible=sim.players[selected].active and sim.phase!="goal"
 for i in Match.PLAYER_COUNT:
  var p: Dictionary=network.render_player(i) if predicted else sim.players[i]
  selected_labels[i].visible=sim.phase!="goal"
  if match_tools.showing_replay(self): continue
  actors[i].visible=p.get("active",true)
  if not actors[i].visible: continue
  match_tools.rig_sync(self,i)
  var target:Vector2=p.pos
  var target3:=Vector3(target.x,p.get("jump_z",0),target.y)
  var previous_position:Vector3=actors[i].position
  var teleported:bool=previous_position.distance_to(target3)>=7
  actors[i].position=previous_position.lerp(target3,1.0-exp(-dt*22)) if dt>0 and not teleported and not predicted else target3
  var facing:Vector2=p.dir
  if p.action_time>0 and p.action in Match.Motion.KICKS:
   var weight:float=smoothstep(0,0.20,float(p.action_time)/Match.Motion.action_duration(p))
   facing=facing.slerp(p.action_dir,weight)
  actors[i].rotation.y=lerp_angle(actors[i].rotation.y,atan2(facing.x,facing.y),1-exp(-dt*28)) if dt>0 and not teleported else atan2(facing.x,facing.y)
  # Follow visible ground travel, including prediction/interpolation, not stale snapshot velocity.
  var visible_velocity:Vector3=(actors[i].position-previous_position)/dt if dt>0 and not teleported else Vector3.ZERO
  var animation_state:Dictionary=p
  if p.action in ["retrieve_ball","carry_ball","place_ball"]:
   animation_state=p.duplicate()
   var rendered_ball:Vector3=football.position.lerp(Vector3(sim.ball.x,sim.ball_height,sim.ball.y),minf(1,dt*25))
   animation_state.hand_ball=actors[i].transform.affine_inverse()*rendered_ball
  rigs[i].animate_player(animation_state,dt if sim.freeze<=0 else 0,sim.owner==i,actors[i].basis.inverse()*visible_velocity)
  var next:int=sim.mechanics.candidate(sim,sim.view_team) if i/Team.SIZE==sim.view_team and sim.owner!=selected else -1
  selected_labels[i].text=(p.name if i==selected else ("▽ " if i==next else "")+Match.JERSEY_NUMBERS[i])+(" [黄]" if p.get("yellow",0)>0 else "")
  if i==sim.teams[sim.view_team].contain_player: selected_labels[i].text+=" 协防"
  if i==sim.teams[sim.view_team].request_player: selected_labels[i].text+=" 跑位"
  selected_labels[i].position.y=p.body.height+(2.4 if i==selected else 0.35)
 var bp: Vector2=sim.ball
 var ball_target:=Vector3(bp.x,sim.ball_height,bp.y)
 if predicted: ball_target=network.render_ball()
 if not match_tools.showing_replay(self):
  # Short visual blend also softens the bounded ball-preview handover.
  football.position=football.position.lerp(ball_target,minf(1,dt*(35 if predicted else 25))) if sim.phase!="goal" and dt>0 and football.position.distance_to(ball_target)<6 else ball_target
  football.rotate_z(dt*(sim.velocity.length() if sim.owner<0 else 7))
 for net in goal_nets: net.show_state(sim.goal_net)
 ball_shadow.position=Vector3(football.position.x,0.09,football.position.z)
 ball_shadow.visible=sim.owner<0 and sim.ball_height>1.0 and sim.phase=="play"
 indicator.position=actors[selected].position+Vector3(0,sim.players[selected].body.height+1.15,0)
 update_pass_arrow()
 indicator.scale=Vector3.ONE*clampf(camera.global_position.distance_to(indicator.global_position)/65.0,0.8,1.25)
 aim_marker.visible=view.charging and sim.owner==selected
 if aim_marker.visible:
  aim_marker.position.x=Pitch.HALF_LENGTH*sim.side(sim.view_team)
  aim_marker.position.z=controls.last_aim*4.35
  aim_marker.scale=Vector3.ONE*(0.7+view.charge*0.4)
 trail_points.push_front(football.position)
 if trail_points.size()>30: trail_points.pop_back()
 for i in trail.size():
  trail[i].visible=sim.phase!="goal" and sim.owner<0 and trail_points.size()>i*2 and sim.velocity.length()>6
  if trail[i].visible: trail[i].position=trail_points[i*2]
 score_label.text="%d  :  %d" % [sim.score[0],sim.score[1]]
 var remaining: int=maxi(0,int(ceil(sim.duration-sim.elapsed)))
 time_label.text=("金球 " if sim.overtime else "")+"%02d : %02d" % [remaining/60,remaining%60]
 player_label.text=sim.players[selected].name+(" / 持球" if sim.owner==selected else " / 接应" if sim.owner>=0 and sim.owner/Team.SIZE==sim.view_team else " / 回防")
 if sim.phase=="restart": player_label.text=sim.players[selected].name+(" / 主罚" if sim.Rules.Flow.ready(sim) else " / 取球") if selected==sim.restart_taker else sim.players[selected].name+" / 就位"
 energy_label.text="%d%% / 疲劳 %d%%" % [int(sim.energy),int(sim.players[selected].get("fatigue",0)*100)]
 energy_bar.size.x=538*sim.energy/100
 var pass_charge:float=clampf(0.28+float(Time.get_ticks_msec()-controls.pass_started)/800,0,1) if controls.pass_held else 0
 charge_bar.size.x=420*(pass_charge if controls.pass_held else view.charge)
 charge_bar.color=Color("ff967e") if view.charge>0.85 else GOLD
 rule_label.text="太阳风活跃 ↓" if sim.wind_active() else ("你的进攻方向  →  右侧球门" if sim.view_team==0 else "你的进攻方向  ←  左侧球门")+"  /  "+["稳固防守","均衡推进","全线压上"][sim.tactic]
 network_label.text=network.diagnostics() if online else ("测试编号 %d · 玩家 vs AI" % quick_fixture.seed if practice else "")
 var defender:Dictionary=sim.players[selected]
 action_hint.text="抢断恢复 %.1f 秒" % defender.tackle_cd if defender.tackle_cd>0 else desktop_input.symbol("tackle")+" 抢断 / "+desktop_input.symbol("cross")+" 铲球"
 if defender.action_time>0 and defender.action in Match.Motion.DEFENSIVE_ACTIONS:
  action_hint.text={"tackle":"伸脚抢断 · 收腿后恢复移动","slide_still":"原地铲球 · 收腿起身","slide":"跑动滑铲 · 减速后起身"}[defender.action]
 if sim.owner==selected:
  action_hint.text="蓄力 %d%% · " % int(view.charge*100)+("高射 · 注意横梁" if view.charge>0.85 else "有力射门" if view.charge>0.4 else "低平射门") if view.charging else desktop_input.symbol("jockey")+" 护球 / "+desktop_input.symbol("shoot")+" 蓄力射门"
  if selected%Team.SIZE==0 and not view.charging:
   action_hint.text=("手持球" if sim.players[selected].keeper_holding else "脚下控球")+" · 方向 + "+desktop_input.symbol("pass")+" 传球 / "+desktop_input.symbol("cross")+" 长传"
 elif sim.teams[sim.view_team].keeper_rush: action_hint.text="门将出击 · 松开 "+desktop_input.symbol("through")+" 回位"
 if controls.pass_held: action_hint.text="传球蓄力 %d%% · 松开出球" % int(pass_charge*100)
 if sim.teams[sim.view_team].contain_player>=0: action_hint.text="队友协防 · 松开 "+desktop_input.symbol("finesse")+" 结束"
 if not sim.mechanics.buffered[sim.view_team].is_empty(): action_hint.text="已预输入 · 等待触球"
 if sim.phase in ["foul","goal"]: action_hint.text=""
 rules_view.update(self,dt)
 rule_label.modulate=Color("ffbf8c") if sim.wind_active() else Color.WHITE
 if sim.event_serial!=last_event:
  last_event=sim.event_serial
  event_age=0
  event_label.text=sim.message
  if sim.event_kind=="goal": beep(780,0.5)
  elif sim.event_kind=="shot": kick_sound(float(sim.players[maxi(0,sim.last_touch)].action_strength))
  elif sim.event_kind=="save": beep(270,0.1)
  elif sim.event_kind=="post": beep(940,0.18)
 event_age+=dt
 event_label.modulate.a=clampf(3.5-event_age,0,1)
 if sim.freeze>0:
  event_label.modulate.a=1
  if sim.event_serial==0: event_label.text="准备开球  /  %d" % maxi(1,int(ceil(sim.freeze)))
 if sim.phase!="play" or sim.event_kind in ["restart","foul"]: event_label.modulate.a=0

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
 button(modal,"替补席",Rect2(1400,535,240,58),func():match_tools.substitutions(self))
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
 button(modal,"进阶操作",Rect2(543,1150,400,78),func():match_tools.extra_help(self))
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
 if not sounds: sound_left=0
 if is_instance_valid(sound_button): sound_button.text="音效 开" if sounds else "音效 关"

func setup_audio() -> void:
 sound_player=AudioStreamPlayer.new()
 var generator:=AudioStreamGenerator.new()
 generator.mix_rate=22050
 generator.buffer_length=0.15
 sound_player.stream=generator
 sound_player.volume_db=-16
 add_child(sound_player)
 sound_player.play()
 sound_playback=sound_player.get_stream_playback()

func beep(frequency: float, duration: float) -> void:
 if sounds:
  sound_impact=false
  sound_freq=frequency
  sound_left=duration

func kick_sound(power:float)->void:
 if not sounds: return
 sound_impact=true;sound_age=0;sound_phase=0;sound_power=clampf(power,0,1);sound_left=0.12

func update_audio() -> void:
 if sound_playback==null: return
 var count:=mini(sound_playback.get_frames_available(),3300)
 for i in count:
  var value:=0.0
  if sound_left>0:
   if sound_impact:
    value=(sin(sound_phase)*exp(-sound_age*30)*0.60+sin(sound_phase*13.7)*exp(-sound_age*100)*0.14)*(0.55+sound_power*0.45)
    sound_phase+=TAU*(55+75*exp(-sound_age*45))/22050.0;sound_age+=1.0/22050.0
   else:
    value=sin(sound_phase)*minf(1,sound_left*15)*0.35
    sound_phase+=TAU*sound_freq/22050.0
   sound_left-=1.0/22050.0
  sound_playback.push_frame(Vector2(value,value))

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
    controls.enabled=screen=="match"
    sync_control_context()
    command=controls.command()
   network.submit_local(command,dt)
  network.advance(dt)
 elif screen=="match" and sim!=null:
  controls.enabled=true
  sync_control_context()
  var command:Dictionary=controls.command()
  sim.apply_command(0,command)
  sim.step(dt)
  if sim.finished: show_result()

func _process(dt:float)->void:
 if booting or (is_instance_valid(loader) and loader.active): return
 if is_instance_valid(pass_arrow) and screen!="match": pass_arrow.visible=false
 if screen not in ["match","online_menu","help","assist_settings","rules_verification"]: rules_view.hide()
 if server_only or bot_mode:
  if network_test and Time.get_ticks_msec()-network.start_time>55000:
   push_error("NETWORK_TEST_TIMEOUT")
   get_tree().quit(2)
  return
 time+=dt
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
 if screen=="match" or screen=="online_menu" or (screen in ["assist_settings","substitutions"] and online) or (screen=="help" and previous_screen=="match" and online): render_match(dt)
 elif screen=="travel":
  travel_left-=dt
  camera.position=camera.position.lerp(Pitch.CAMERA,dt*1.4)
  camera.look_at(Vector3(0,0,-1))
  if travel_left<=0: start_match()
 if sim!=null and (screen=="match" or (online and screen in ["online_menu","help","assist_settings","substitutions"])): match_tools.update(self,dt)
 impact_feedback.update(self,dt)
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
 if pressed_key and event.physical_keycode==KEY_F2: match_tools.save_scenario(self);return
 if pressed_key and event.physical_keycode==KEY_F3: match_tools.retry_scenario(self);return
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
 elif screen=="substitutions": match_tools.close(self)
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
func verification_tick() -> void:
 verify_ticks+=1
 if capture_busy: return
 if verify_step==0 and screen_ticks>45:
  capture_busy=true
  await capture("title")
  campaign=Campaign.new()
  campaign.save_path="user://verification-campaign.json"
  has_save=true
  show_hub()
  verify_step=1
  capture_busy=false
 elif verify_step==1 and screen_ticks>30:
  capture_busy=true
  await capture("bridge")
  assert(campaign.train(0))
  assert(campaign.credits==180)
  persist()
  var reloaded=Campaign.new()
  reloaded.save_path=campaign.save_path
  assert(reloaded.load_game() and reloaded.training[0]==1)
  show_briefing()
  verify_step=2
  capture_busy=false
 elif verify_step==2 and screen_ticks>25:
  capture_busy=true
  await capture("briefing")
  begin_travel()
  verify_step=3
  capture_busy=false
 elif verify_step==3 and screen=="match" and sim.elapsed>3.0:
  capture_busy=true
  assert(actors.size()==Team.COUNT and sim.players.size()==Team.COUNT)
  assert(selected_labels[4].text=="04" or selected_labels[4].text=="范戴克")
  await capture("match")
  var before: float=sim.elapsed
  pause_match()
  assert(screen=="pause")
  assert(sim.elapsed==before)
  resume_match()
  sim.freeze=0
  sim.owner=sim.selected
  var key:=InputEventKey.new()
  key.physical_keycode=KEY_D
  key.pressed=true
  get_viewport().push_input(key)
  sim.apply_command(0,controls.command())
  assert(sim.charging)
  sim.charge=1
  key.pressed=false
  get_viewport().push_input(key)
  sim.apply_command(0,controls.command())
  assert(sim.owner==-1 and sim.shots[0]>0)
  var original_selection: int=sim.selected
  key.physical_keycode=KEY_Q
  key.pressed=true
  get_viewport().push_input(key)
  sim.apply_command(0,controls.command())
  assert(sim.selected!=original_selection)
  key.pressed=false
  get_viewport().push_input(key)
  # Check scoring through the live simulation, then finish every fixture.
  sim.ball=Vector2(31.9,3)
  sim.velocity=Vector2(30,0)
  sim.tick(0.05,Vector2.ZERO)
  assert(sim.score[0]==1)
  assert(sim.phase=="goal")
  sim.step(3.1)
  assert(sim.phase=="restart" and sim.restart_team==1)
  sim.freeze=0;sim.view_team=1;sim.pass_ball();sim.view_team=0
  sim.freeze=0
  sim.elapsed=sim.duration
  sim.tick(0.02,Vector2.ZERO)
  assert(sim.finished)
  show_result()
  assert(campaign.stage==1)
  verify_step=4
  capture_busy=false
 elif verify_step==4 and screen_ticks>30:
  capture_busy=true
  await capture("result")
  for stage in [1,2]:
   await start_match()
   sim.score=[2,1]
   sim.freeze=0
   sim.pass_ball()
   sim.elapsed=sim.duration
   sim.tick(0.02,Vector2.ZERO)
   assert(sim.finished)
   show_result()
  assert(campaign.stage==3 and campaign.wins==3)
  assert(campaign.recruit())
  persist()
  verify_step=5
  capture_busy=false
 elif verify_step==5 and screen_ticks>30:
  capture_busy=true
  await capture("champion")
  print("STARBORNE_VERIFY_PASS: native-window captures / input / goal / pause / training / save / three-stage campaign / keeper recruitment")
  get_tree().quit()

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
 panel(modal,Rect2(390,190,1780,1080))
 text(modal,"冰球模式" if quick_ice_mode else "快速比赛",Vector2(450,235),50,INK,true)
 text(modal,"开发测试 · 玩家 vs AI · 双方随机阵容",Vector2(453,320),25,MUTED)
 text(modal,"测试编号  %d" % quick_fixture.seed,Vector2(1580,269),23,CYAN)
 for side_index in 2:
  var x:=460+side_index*840
  panel(modal,Rect2(x,395,780,450),Color("102131"))
  text(modal,"你的球队" if side_index==0 else "AI 测试队",Vector2(x+24,412),30,CYAN if side_index==0 else Color("ffa78c"),true)
  var ids:Array=quick_fixture.home if side_index==0 else quick_fixture.away
  for slot in Team.SIZE:
   var record:=PlayerLibrary.find(ids[slot])
   var y:=482+slot*55
   text(modal,QuickMatch.LABELS[slot]+" · "+record.role,Vector2(x+26,y),23,MUTED)
   var label:=text(modal,record.name,Vector2(x+235,y-2),28,INK,true,360)
   label.max_lines_visible=1
   label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
   text(modal,str(int(record.overall)),Vector2(x+677,y-2),28,GOLD,true)
 button(modal,"规则："+("冰球反弹" if quick_ice_mode else "经典六人制"),Rect2(460,880,780,70),func(): quick_ice_mode=not quick_ice_mode;quick_arcade=false; show_quick_options(false))
 button(modal,"镜头："+("跟随足球" if camera_motion else "固定"),Rect2(1300,880,780,70),func(): camera_motion=not camera_motion; show_quick_options(false))
 button(modal,"开始比赛",Rect2(460,1020,880,92),begin_quick_match,true)
 button(modal,"重新随机",Rect2(1370,1020,340,92),show_quick_options)
 button(modal,"返回",Rect2(1740,1020,340,92),clear_modal)
 text(modal,"1 门将 + 5 名场上球员 · 不修改球队与星际杯存档",Vector2(464,1162),23,MUTED)

func new_quick_fixture()->void:
 var previous:=quick_fixture.duplicate(true)
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
 button(modal,"替补席",Rect2(1450,575,270,65),func():match_tools.substitutions(self))
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





