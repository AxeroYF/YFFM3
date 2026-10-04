extends RefCounted
const Team=preload("res://team_config.gd")
const Pitch=preload("res://pitch_geometry.gd")
func run(test)->void:
 var s=test.fixture()
 s.apply_command(0,{"action":4,"chip":true})
 s.mechanics.tick(s,0.09)
 test.check(s.owner==-1 and s.teams[0].run_player==1 and s.teams[0].run_time==2 and s.selected!=1,"one-two pass selects receiver and orders original passer forward")
 test.check(s.ai_direction(1).x>0,"one-two passer AI actually runs toward attacking goal")
 s.owner=7;s.step(1.0/60)
 test.check(s.teams[0].run_player==-1,"one-two forward run cancels immediately after losing possession")
 for team in 2:
  s=test.fixture()
  s.owner=(1-team)*Team.SIZE+1;s.ball=Vector2(-20*s.side(team),4)
  s.apply_command(team,{"keeper_rush":true})
  var target:Vector2=s.keeper_target(team*Team.SIZE)
  test.check(target.x*s.side(team)>-Pitch.HALF_LENGTH+7 and target.x*s.side(team)<=-Pitch.HALF_LENGTH+8.501 and absf(target.y)<=7,"keeper rush advances inside own area on either end")
  s.apply_command(team,{"keeper_rush":false})
  test.check(s.keeper_target(team*Team.SIZE).x*s.side(team)<-Pitch.HALF_LENGTH+4,"releasing keeper rush returns to goal position")
 for shield in [false,true]:
  s=test.fixture();s.players[1].pos=Vector2.ZERO;s.players[1].dir=Vector2.RIGHT
  s.players[7].pos=Vector2(-1.6,0);s.players[7].dir=Vector2.RIGHT
  s.players[7].ratings.tackle_reach=2.5
  s.ball=Vector2(0.6,0);s.owner=1;s.teams[0].jockey=shield
  s.resolve_tackle(7,false)
  test.check(s.owner==(1 if shield else -1),"holding shield makes rear ball access harder without making tackles impossible")
 s=test.fixture();s.players[1].action_time=0;s.teams[0].jockey=true
 s.move_player(1,1.0/60,Vector2.ZERO,false,true)
 test.check(s.players[1].action=="shield" and s.players[1].stamina<100,"shield has posture and stamina cost")
 var controls=preload("res://football_input.gd").new()
 for keyboard in [true,false]:
  controls.gamepad=93;controls.sync_context(1,6,1)
  var event:InputEvent=InputEventKey.new() if keyboard else InputEventJoypadButton.new()
  if keyboard: event.keycode=KEY_W;event.physical_keycode=KEY_W
  else: event.device=93;event.button_index=JOY_BUTTON_Y
  event.pressed=true;Input.parse_input_event(event);Input.flush_buffered_events()
  test.check(controls.command().keeper_rush,"holding keyboard W / pad Y while defending requests keeper rush")
  event.pressed=false;Input.parse_input_event(event.duplicate());Input.flush_buffered_events()
  test.check(not controls.command().keeper_rush,"releasing keeper-rush key clears command")
 var net=preload("res://match_network.gd").new();net.sim=s
 s.teams[0].keeper_rush=true;s.teams[1].run_player=6;s.teams[1].run_time=1.4
 var roundtrip:Dictionary=net.unpack_state(net.pack_state(s.snapshot()))
 test.check(roundtrip.teams[0].keeper_rush and roundtrip.teams[1].run_player==6 and absf(roundtrip.teams[1].run_time-1.4)<0.001,"keeper rush and one-two run replicate in compact snapshot")
 net.free()
