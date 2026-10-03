extends RefCounted
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
 checks+=1
 if not value: failures+=1;push_error("KEEPER_VISUAL_FAILED "+message)
func frame(game,dt:float=1.0/60)->void:
 game.sim.step(dt);game.render_match(dt);game.match_tools.update(game,dt)
func run(game)->void:
 game.practice=true;game.quick_fixture=preload("res://quick_match.gd").generate(716)
 await game.start_match()
 game.screen="rules_verification";game.camera_motion=true
 var s=game.sim;s.freeze=0;s.phase="play";s.owner=1;s.selected=1
 for team in 2: s.teams[team].human=true;s.teams[team].assist_active=false
 for i in 10:
  s.players[i].pos=Vector2(-22+(i%5)*7,12 if i<5 else -12)
  s.players[i].vel=Vector2.ZERO;s.players[i].cooldown=0
 s.players[1].pos=Vector2(10,-3);s.players[1].dir=Vector2.RIGHT;s.teams[0].move=Vector2.RIGHT
 s.players[5].pos=Vector2(29,4.5)
 for tick in 120: frame(game)
 s.players[5].pos=Vector2(29,4.5);s.players[5].vel=Vector2.ZERO
 s.ball=s.players[1].pos+Vector2(1,0);s.ball_height=0.7;s.velocity=Vector2(30,0);s.vertical_speed=3
 s.ball_is_shot=true;s.last_touch=1;s.owner=-1;s.kick_age=0.3;s.pickup_lock=0;s.teams[0].move=Vector2.ZERO
 for tick in 90:
  frame(game)
  if s.phase=="goal": break
 check(s.phase=="goal","live shot must cross the line")
 check(not game.match_tools.replay.is_empty(),"goal records pre-goal footage")
 var goal_history:Array=game.match_tools.history.duplicate(true)
 frame(game,0.22)
 check(game.rules_view.goal_overlay.visible and game.rules_view.goal_title.text=="GOAL","Goal intro is visible")
 check(not game.indicator.visible and not game.pass_arrow.visible and not game.ball_shadow.visible,"goal has no player or foot-ring markers")
 check(game.camera.position.y>40,"goal keeps broadcast camera rather than zooming at scorer")
 await game.capture("goal-overlay")
 frame(game,s.Rules.GOAL_INTRO-0.22+0.05)
 check(game.match_tools.showing_replay(game) and not game.rules_view.goal_overlay.visible,"intro transitions to replay")
 check(game.football.position.x<s.ball.x-2,"replay shows run-up rather than only result")
 var before:PackedByteArray=var_to_bytes(s.snapshot())
 var replayed_ball:Vector3=game.football.position
 game.match_tools.update(game,0.05)
 check(before==var_to_bytes(s.snapshot()),"replay never mutates authority")
 check(game.football.position==replayed_ball,"paused authority clock also pauses replay")
 await game.capture("goal-replay-build-up")
 frame(game,s.phase_time-0.2)
 check(game.football.position.x>32,"replay includes actual goal-line crossing")
 await game.capture("goal-replay-crossing")
 game.set_process(false);game.set_physics_process(false);game.screen="match"
 var key:=InputEventKey.new();key.physical_keycode=KEY_S;key.pressed=true
 game._input(key)
 check(game.match_tools.replay.is_empty() and s.phase=="goal","skip consumes key without changing match phase")
 frame(game,0.3)
 check(s.phase=="restart" and s.restart_team==1,"replay interval returns to conceding team's kickoff")
 game.screen="rules_verification"
 s.phase="play";s.freeze=0;s.overtime=true;s.last_touch=1;game.match_tools.last_phase="play"
 game.match_tools.history=goal_history
 s.Rules.goal(s,0);frame(game,0.22)
 check(game.rules_view.goal_overlay.visible and game.rules_view.goal_title.text=="GOAL","golden goal uses the same Goal animation")
 await game.capture("golden-goal-overlay")
 frame(game,s.Rules.GOAL_INTRO-0.22+0.05)
 check(game.match_tools.showing_replay(game),"golden goal also plays recorded buildup")
 game.screen="match"
 var button:=InputEventJoypadButton.new();button.device=maxi(0,game.controls.gamepad);button.button_index=JOY_BUTTON_A;button.pressed=true
 game._input(button)
 check(game.match_tools.replay.is_empty() and s.phase=="goal","Xbox A skips without resuming or passing")
 game.screen="rules_verification"
 frame(game,s.Rules.GOAL_DURATION)
 check(s.finished,"golden goal ends after presentation")
 s.finished=false;s.phase="play";game.match_tools.last_phase="play";game.desktop_input.options.replay=false
 s.Rules.goal(s,0);frame(game,0.22)
 check(game.rules_view.goal_overlay.visible and game.match_tools.replay.is_empty(),"replay option off still shows Goal")
 game.desktop_input.options.replay=true
 # Close-up verifies wider awareness actually produces a keeper action.
 s.finished=false;s.overtime=false;s.phase="play";s.freeze=0;s.owner=-1;s.pickup_lock=0
 for i in 10: s.players[i].active=i==0;s.players[i].cooldown=0
 var p:Dictionary=s.players[0];p.pos=Vector2(-29,0);p.dir=Vector2.RIGHT;p.vel=Vector2.ZERO;p.action="idle";p.action_time=0;p.keeper_cd=0
 s.teams[0].selected=1;s.ball=Vector2(-20,2);s.velocity=Vector2(-30,0);s.ball_height=0.6;s.vertical_speed=1.0;s.ball_is_shot=true;s.last_touch=6;s.kick_age=0.4
 game.camera_motion=false;game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=13
 game.camera.position=Vector3(-19,9,10);game.camera.look_at(Vector3(-28,1,1))
 for tick in 10: frame(game)
 check(p.action in s.Motion.DIVES or s.saves[0]>0,"keeper actively reacts to shot")
 await game.capture("keeper-active-coverage")
 print("KEEPER_GOAL_VISUAL_","PASS" if failures==0 else "FAILED"," checks=",checks," failures=",failures)
 game.get_tree().quit(0 if failures==0 else 1)
