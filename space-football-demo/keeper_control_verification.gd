extends RefCounted
const Team=preload("res://team_config.gd")

func run(game)->void:
 game.practice=true;await game.start_match()
 game.screen="keeper_control_verification";game.camera_motion=false
 var s=game.sim
 s.freeze=0;s.phase="play";s.owner=-1;s.pickup_lock=0
 s.teams[1].human=true
 for index in Team.COUNT:
  s.players[index].pos=Vector2(2+index*2,12)
  s.players[index].cooldown=100;s.players[index].speed=0;s.players[index].vel=Vector2.ZERO
 var p:Dictionary=s.players[0]
 p.pos=Vector2(-27,0);p.cooldown=0;p.dir=Vector2.RIGHT
 s.players[2].pos=Vector2(-19,-8);s.players[3].pos=Vector2(-18,8)
 s.ball=p.pos+Vector2(0.7,0);s.ball_height=s.BallPhysics.FLOOR
 s.velocity=Vector2(-4,0);s.last_touch=4;s.ball_is_shot=false
 s.resolve_player_contacts(s.ball)
 for frame in 90: s.step(1.0/60);game.render_match(1.0/60)
 var passed:bool=s.owner==0 and s.selected==0 and not p.keeper_holding and s.ball_height<0.36
 game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=16
 game.camera.position=Vector3(-19,10,12);game.camera.look_at(Vector3(-25,1,0))
 await game.capture("keeper-foot-control")
 p.speed=5
 s.apply_command(0,{"move":Vector2.DOWN})
 for frame in 24: s.step(1.0/60);game.render_match(1.0/60)
 passed=passed and p.dir.y>0.95 and s.ball_height<0.36
 await game.capture("keeper-foot-dribble")
 s.apply_command(0,{"move":Vector2(1,-1).normalized(),"action":4})
 passed=passed and s.pass_receiver==2 and p.action=="pass" and not p.keeper_holding and s.velocity.y<0
 for frame in 10: s.step(1.0/60);game.render_match(1.0/60)
 await game.capture("keeper-foot-pass")
 if passed: print("KEEPER_CONTROL_VISUAL_PASS default_feet=1 human_control=1 directional_pass=1")
 else: push_error("KEEPER_CONTROL_VISUAL_FAILED")
 game.get_tree().quit(0 if passed else 1)
