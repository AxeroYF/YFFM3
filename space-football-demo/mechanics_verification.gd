extends RefCounted
func run(game)->void:
 game.practice=true;game.quick_fixture=preload("res://quick_match.gd").generate(981)
 await game.start_match()
 game.screen="mechanics_verification";game.camera_motion=false
 var s=game.sim;s.freeze=0;s.phase="play";s.owner=1;s.selected=1
 s.charging=true;s.charge=0.4
 game.save_scenario()
 var saved_ball:Vector2=s.ball;var saved_rng:int=s.rng.state
 s.ball=Vector2(11,4);s.rng.randf()
 game.retry_scenario()
 assert(s.ball==saved_ball and s.rng.state==saved_rng and not s.charging)
 s.players[1].pos=Vector2(0,0);s.players[1].dir=Vector2.RIGHT;s.ball=Vector2(0.8,0)
 s.players[2].pos=Vector2(9,-4);s.players[3].pos=Vector2(9,5)
 s.apply_command(0,{"action":s.Mechanics.RUN,"move":Vector2.RIGHT})
 for frame in 20: s.step(1.0/60);game.render_match(1.0/60)
 await game.capture("mechanics-runs")
 s.owner=-1;s.selected=1;s.players[1].cooldown=0;s.ball=s.players[1].pos;s.ball_height=s.players[1].body.head_height+0.45
 s.mechanics.jump(s,1,"shot",0,Vector2.RIGHT)
 for frame in 15: s.mechanics.tick(s,1.0/60);game.render_match(1.0/60)
 await game.capture("mechanics-aerial")
 game.show_substitutions()
 await game.capture("mechanics-substitutes")
 game.close_match_tools();game.screen="mechanics_verification"
 var old:String=s.players[1].player_id
 s.mechanics.requests[0]={"out":1,"reserve":1};s.mechanics.substitute(s,0)
 game.render_match(0)
 assert(s.players[1].player_id!=old and game.rigs[1].get_meta("player_id")==s.players[1].player_id)
 game.screen="assist_settings";game.show_advanced_settings()
 await game.capture("mechanics-options")
 game.previous_screen="match";game.screen="help";game.show_extra_help()
 await game.capture("mechanics-help-keyboard")
 game.desktop_input.kind="gamepad";game.desktop_input.glyph_override="xbox";game.show_extra_help()
 await game.capture("mechanics-help-xbox")
 game.clear_modal();game.screen="mechanics_verification"
 s.owner=1;s.phase="play";s.freeze=0
 for frame in 120:
  s.players[1].pos.x+=0.02;game.render_match(1.0/60);game.update_match_tools(1.0/60)
 s.Rules.goal(s,0);game.render_match(1.0/60);game.update_match_tools(1.0/60)
 assert(not game.match_tools.replay.is_empty())
 s.step(s.Rules.GOAL_INTRO+0.3);game.render_match(1.0/60);game.update_match_tools(1.0/60)
 await game.capture("mechanics-replay")
 print("MECHANICS_VISUAL_PASS frames=155 screens=7 substitution_rig=ok replay=ok checkpoint=ok")
 game.get_tree().quit()
