extends RefCounted

func run(game)->void:
 game.practice=true
 await game.start_match()
 game.screen="rules_verification"
 game.desktop_input.overlay.visible=false
 var s=game.sim
 s.freeze=0
 s.teams[0].human=true;s.teams[1].human=true
 for kind in ["kick_in","corner","goal_kick","free_kick","penalty"]:
  s.Rules.restart(s,0,kind,Vector2(12,17.8) if kind=="kick_in" else Vector2(16,2))
  s.freeze=0;s.phase_time=1.1
  for i in 30: game.render_match(1.0/60)
  await game.capture("rules-"+kind)
 s.phase="play"
 s.players[1].pos=Vector2(10,0);s.players[6].pos=Vector2(8.5,0)
 s.players[1].dir=Vector2.RIGHT;s.players[6].dir=Vector2.RIGHT
 s.owner=1;s.ball=Vector2(11,0)
 s.tackle(6,true)
 s.phase_time=0.65;s.players[1].action_time=0.65;s.players[6].action_time=0.4
 for i in 30: game.render_match(1.0/60)
 await game.capture("rules-foul")
 s.phase="play";s.last_touch=1
 s.Rules.goal(s,0);s.phase_time=2.4
 for i in 60: game.render_match(1.0/60)
 await game.capture("rules-goal")
 game.rules_view.hide()
 game.ui.visible=false
 game.camera_motion=false
 game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 game.camera.size=6.5
 var p:Dictionary=s.players[1]
 p.dir=Vector2(0,1);p.pos=Vector2.ZERO
 s.phase="play";s.owner=-1
 for i in range(2,10): s.players[i].pos=Vector2(-28,-15)
 game.camera.position=Vector3(5,3.5,9)
 game.camera.look_at(Vector3(0,1.2,0))
 for action in ["slide","fall","header","volley","cross","wall","celebrate"]:
  p.action=action
  p.action_time={"slide":0.4,"fall":0.6,"header":0.28,"volley":0.28,"cross":0.3,"wall":1.0,"celebrate":2.25}[action]
  for i in 25: game.render_match(1.0/60)
  await game.capture("action-"+action)
 print("MATCH_RULES_VISUAL_PASS")
 game.get_tree().quit()
