extends RefCounted
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures+=1;push_error("SIX_VISUAL_FAILED "+label)
func capture(game,label:String)->void:
 game.desktop_input.window_active=true
 game.desktop_input.step(0)
 await game.capture(label)
func run(game)->void:
 game.set_process(false);game.set_physics_process(false)
 game.library_screen.show_squad();await capture(game,"six-squad")
 game.show_hub();await capture(game,"six-campaign")
 game.show_menu();game.show_quick_options();await capture(game,"six-lineups")
 game.practice=true
 await game.start_match()
 game.screen="match";game.camera_motion=false
 var s=game.sim
 for t in s.teams: t.human=true;t.move=Vector2.ZERO
 check(game.actors.size()==12 and game.rigs.size()==12,"twelve rendered actors and rigs")
 s.freeze=0;game.render_match(0.016)
 await capture(game,"six-match")
 game.match_tools.substitutions(game);await capture(game,"six-substitutions")
 game.clear_modal();game.screen="match"
 s.players[1].pos=Vector2(19,2);s.ball=Vector2(20,2)
 s.Rules.restart(s,0,"free_kick",s.ball)
 for tick in 1800:
  s.step(1.0/60)
  if s.Rules.Flow.ready(s): break
 game.render_match(0.016)
 check(s.Rules.Flow.ready(s) and s.restart_flow.wall.size()==2,"small-sided free kick staged for rendering")
 await capture(game,"six-free-kick")
 s.view_team=0;s.charge=0.9;s.shoot()
 game.render_match(0)
 var point:=Vector3(s.ball.x,s.ball_height,s.ball.y)
 game.camera.h_offset=0;game.camera.v_offset=0
 var before:Vector2=game.camera.unproject_position(point)
 game.desktop_input.options.camera_impact=1
 game.impact_feedback.update(game,0)
 var displacement:float=before.distance_to(game.camera.unproject_position(point))
 var expected:float=11*s.impact_strength*game.get_viewport().get_visible_rect().size.y/1440.0
 check(displacement>3 and absf(displacement-expected)<0.4,"camera contact impulse reaches calibrated screen pixels")
 await capture(game,"six-shot-contact")
 var state:PackedByteArray=var_to_bytes(s.snapshot())
 game.impact_feedback.update(game,0)
 check(absf(displacement-before.distance_to(game.camera.unproject_position(point)))<0.01,"same snapshot does not retrigger impulse")
 for tick in 30: game.impact_feedback.update(game,1.0/60)
 check(game.camera.h_offset==0 and game.camera.v_offset==0 and state==var_to_bytes(s.snapshot()),"shake settles with no simulation changes")
 s.frame+=30;s.impact(4,1,Vector2.RIGHT);s.frame+=20
 game.impact_feedback.update(game,0.016)
 check(game.camera.h_offset==0 and game.camera.v_offset==0,"stale snapshot impact is not displayed")
 s.impact(4,1,Vector2.RIGHT);game.screen="pause";game.impact_feedback.update(game,0.016)
 check(game.camera.h_offset==0 and game.camera.v_offset==0,"menus suppress contact feedback")
 game.screen="match";game.desktop_input.options.camera_impact=0;s.impact(4,1,Vector2.RIGHT);game.impact_feedback.update(game,0.016)
 check(game.camera.h_offset==0 and game.camera.v_offset==0,"off setting suppresses all recoil")
 var report:={"checks":checks,"passed":failures==0,"contact_pixels":displacement,"expected_pixels":expected,"resolution":str(game.get_viewport().get_visible_rect().size)}
 var file:=FileAccess.open("res://artifacts/six-visual.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
 print("SIX_VISUAL_", "PASS" if failures==0 else "FAIL", " ",report)
 game.get_tree().quit(0 if failures==0 else 1)
