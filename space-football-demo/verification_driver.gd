extends RefCounted
## Legacy visual verification orchestration; game is deliberately a test fixture.
func verify_keeper_visuals(game)->void:
 game.practice=true
 await game.start_match()
 game.screen="keeper_verification"
 game.camera_motion=false
 game.ui.visible=false
 game.desktop_input.overlay.visible=false
 game.sim.freeze=0
 var p:Dictionary=game.sim.players[0]
 p.dir=Vector2(0,1)
 game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 game.camera.size=7
 game.camera.position=Vector3(p.pos.x,3.8,p.pos.y+9)
 game.camera.look_at(Vector3(p.pos.x,1.4,p.pos.y))
 for state_name in ["idle","dive","catch","throw"]:
  p.action=state_name;p.action_time=0.5;p.keeper_side=1;p.keeper_height=1.4
  game.sim.owner=0 if state_name=="catch" else -1
  p.keeper_holding=game.sim.owner==0
  game.sim.ball=p.pos+Vector2(0,0.8);game.sim.ball_height=p.body.height*0.65 if game.sim.owner==0 else game.Match.BallPhysics.FLOOR
  for i in 20: game.render_match(1.0/60)
  await game.capture("keeper-"+state_name)
 print("KEEPER_VISUAL_PASS")
 game.get_tree().quit()

func verify_release_ui(game)->void:
 game.Squad.ids=game.Squad.DEFAULT.duplicate()
 game.show_menu()
 await game.get_tree().create_timer(1.0).timeout
 await game.capture("main-menu")
 game.library_screen.show_squad()
 await game.get_tree().create_timer(0.4).timeout
 await game.capture("my-squad")
 game.library_screen.picking=1
 game.library_screen.query="姆巴佩"
 game.library_screen.show_library()
 await game.get_tree().create_timer(0.4).timeout
 await game.capture("squad-search")
 game.library_screen.details(game.PlayerLibrary.find("legend-mbappe"))
 await game.get_tree().create_timer(0.4).timeout
 await game.capture("player-abilities")
 var assigned:=false
 for child in game.modal.get_children():
  if child is Button and child.text=="前锋":
   child.pressed.emit()
   assigned=true
   break
 assert(assigned and game.Squad.ids[1]=="legend-mbappe")
 game.Squad.load_squad()
 assert(game.Squad.ids[1]=="legend-mbappe")
 await game.get_tree().create_timer(0.4).timeout
 await game.capture("my-squad-updated")
 game.practice=false
 await game.start_match()
 assert(game.sim.players[1].name=="姆巴佩" and game.rigs[1].body.height_cm==game.PlayerLibrary.find("legend-mbappe").heightCm)
 await game.get_tree().create_timer(2.0).timeout
 await game.capture("squad-match")
 print("RELEASE_UI_PASS roster_selection=button save=reload model=height abilities=server_catalog")
 game.get_tree().quit()

func verification_tick(game)->void:
 game.verify_ticks+=1
 if game.capture_busy: return
 if game.verify_step==0 and game.screen_ticks>45:
  game.capture_busy=true
  await game.capture("title")
  game.campaign=game.Campaign.new()
  game.campaign.save_path="user://verification-campaign.json"
  game.has_save=true
  game.show_hub()
  game.verify_step=1
  game.capture_busy=false
 elif game.verify_step==1 and game.screen_ticks>30:
  game.capture_busy=true
  await game.capture("bridge")
  assert(game.campaign.train(0))
  assert(game.campaign.credits==180)
  game.persist()
  var reloaded=game.Campaign.new()
  reloaded.save_path=game.campaign.save_path
  assert(reloaded.load_game() and reloaded.training[0]==1)
  game.show_briefing()
  game.verify_step=2
  game.capture_busy=false
 elif game.verify_step==2 and game.screen_ticks>25:
  game.capture_busy=true
  await game.capture("briefing")
  game.begin_travel()
  game.verify_step=3
  game.capture_busy=false
 elif game.verify_step==3 and game.screen=="match" and game.sim.elapsed>3.0:
  game.capture_busy=true
  assert(game.actors.size()==game.Team.COUNT and game.sim.players.size()==game.Team.COUNT)
  assert(game.selected_labels[4].text=="04" or game.selected_labels[4].text=="范戴克")
  await game.capture("match")
  var before: float=game.sim.elapsed
  game.pause_match()
  assert(game.screen=="pause")
  assert(game.sim.elapsed==before)
  game.resume_match()
  game.sim.freeze=0
  game.sim.owner=game.sim.selected
  var key:=InputEventKey.new()
  key.physical_keycode=KEY_D
  key.pressed=true
  game.get_viewport().push_input(key)
  game.sim.apply_command(0,game.controls.command())
  assert(game.sim.charging)
  game.sim.charge=1
  key.pressed=false
  game.get_viewport().push_input(key)
  game.sim.apply_command(0,game.controls.command())
  assert(game.sim.owner==-1 and game.sim.shots[0]>0)
  var original_selection: int=game.sim.selected
  key.physical_keycode=KEY_Q
  key.pressed=true
  game.get_viewport().push_input(key)
  game.sim.apply_command(0,game.controls.command())
  assert(game.sim.selected!=original_selection)
  key.pressed=false
  game.get_viewport().push_input(key)
  # Check scoring through the live simulation, then finish every fixture.
  game.sim.ball=Vector2(31.9,3)
  game.sim.velocity=Vector2(30,0)
  game.sim.tick(0.05,Vector2.ZERO)
  assert(game.sim.score[0]==1)
  assert(game.sim.phase=="goal")
  game.sim.step(3.1)
  assert(game.sim.phase=="restart" and game.sim.restart_team==1)
  game.sim.freeze=0;game.sim.view_team=1;game.sim.pass_ball();game.sim.view_team=0
  game.sim.freeze=0
  game.sim.elapsed=game.sim.duration
  game.sim.tick(0.02,Vector2.ZERO)
  assert(game.sim.finished)
  game.show_result()
  assert(game.campaign.stage==1)
  game.verify_step=4
  game.capture_busy=false
 elif game.verify_step==4 and game.screen_ticks>30:
  game.capture_busy=true
  await game.capture("result")
  for stage in [1,2]:
   await game.start_match()
   game.sim.score=[2,1]
   game.sim.freeze=0
   game.sim.pass_ball()
   game.sim.elapsed=game.sim.duration
   game.sim.tick(0.02,Vector2.ZERO)
   assert(game.sim.finished)
   game.show_result()
  assert(game.campaign.stage==3 and game.campaign.wins==3)
  assert(game.campaign.recruit())
  game.persist()
  game.verify_step=5
  game.capture_busy=false
 elif game.verify_step==5 and game.screen_ticks>30:
  game.capture_busy=true
  await game.capture("champion")
  print("STARBORNE_VERIFY_PASS: native-window captures / input / goal / pause / training / save / three-stage campaign / keeper recruitment")
  game.get_tree().quit()
