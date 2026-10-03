extends RefCounted
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
 checks+=1
 if not value: failures+=1;push_error(message)
func frame(game)->void:
 game.sim.step(1.0/60);game.render_match(1.0/60);game.impact_feedback.update(game,1.0/60)
func run(game)->void:
 game.practice=true;game.quick_fixture=preload("res://quick_match.gd").generate(721)
 await game.start_match()
 game.set_physics_process(false);game.set_process(false);game.screen="match"
 var s=game.sim
 for t in s.teams: t.human=true;t.move=Vector2.ZERO
 s.players[1].pos=Vector2(4,15);s.players[1].dir=Vector2.DOWN
 s.ball=Vector2(7,18.6);s.ball_height=s.BallPhysics.FLOOR;s.velocity=Vector2.ZERO
 s.Rules.restart(s,0,"kick_in",s.ball)
 var captured:Dictionary={}
 for tick in 2000:
  frame(game)
  var stage:String=s.restart_flow.stage
  if stage in ["fetch","lift","carry","place","ready"] and not captured.has(stage) and (s.restart_flow.time>0.22 or stage=="ready"):
   check(not game.rules_view.banner.visible and not game.rules_view.goal_overlay.visible,"no floating stoppage panel "+stage)
   check(game.event_label.modulate.a==0,"no central event message "+stage)
   await game.capture("restart-"+stage)
   captured[stage]=true
   if stage in ["lift","carry","place"]:
    var previous_transform:Transform3D=game.camera.transform
    game.camera_motion=false
    var p:Dictionary=s.players[s.restart_taker]
    var center:=Vector3(p.pos.x,0.85,p.pos.y)
    game.camera.position=center+Vector3(3,1.8,4)
    game.camera.look_at(center)
    game.ui.visible=false;game.desktop_input.overlay.visible=false
    await game.capture("restart-"+stage+"-detail")
    game.ui.visible=true;game.desktop_input.overlay.visible=true
    game.camera.transform=previous_transform;game.camera_motion=true
  if stage=="ready": break
 check(captured.size()==5,"all restart stages reached in rendered match")
 s.pass_ball(false,Vector2.LEFT,false,false,1,true)
 var state:PackedByteArray=var_to_bytes(s.snapshot())
 game.impact_feedback.update(game,0.035)
 check(absf(game.camera.h_offset)+absf(game.camera.v_offset)>0.01,"real driven pass shakes camera")
 check(var_to_bytes(s.snapshot())==state,"camera feedback cannot mutate match state")
 var offset:Vector2=Vector2(game.camera.h_offset,game.camera.v_offset)
 game.impact_feedback.update(game,0)
 check(Vector2(game.camera.h_offset,game.camera.v_offset)==offset,"same snapshot does not retrigger feedback")
 for tick in 20: game.impact_feedback.update(game,1.0/60)
 check(game.camera.h_offset==0 and game.camera.v_offset==0,"camera returns exactly to original projection")
 s.impact(1,1,Vector2.RIGHT);game.impact_feedback.update(game,0.03)
 game.screen="pause";game.impact_feedback.update(game,0.016)
 check(game.camera.h_offset==0 and game.camera.v_offset==0,"pause clears camera recoil")
 game.desktop_input.options.camera_impact=0;game.screen="match"
 s.impact(1,1,Vector2.RIGHT);game.impact_feedback.update(game,0.03)
 check(game.camera.h_offset==0 and game.camera.v_offset==0,"disabled feedback stays off")
 game.desktop_input.options.camera_impact=1;game.impact_feedback.update(game,0.03)
 check(game.camera.h_offset==0 and game.camera.v_offset==0,"enabling feedback never replays an old hit")
 game.match_tools.advanced_settings(game)
 await game.capture("restart-impact-settings")
 var file:=FileAccess.open("res://artifacts/restart-impact-verification.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"passed":failures==0,"stages":captured.keys(),"resolution":str(game.get_viewport().get_visible_rect().size)},"  "))
 print("RESTART_IMPACT_VISUAL_", "PASS" if failures==0 else "FAIL", " checks=",checks," failures=",failures)
 game.get_tree().quit(0 if failures==0 else 1)
