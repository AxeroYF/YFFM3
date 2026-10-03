extends RefCounted
const Pitch=preload("res://pitch_geometry.gd")
var test

func fixture():
 var s=test.fixture()
 s.arcade=false
 s.teams[0].human=true;s.teams[1].human=true
 return s

func run(runner)->void:
 test=runner
 var s=fixture()
 for team in 2:
  for kind in s.Rules.TITLES:
   s=fixture()
   s.Rules.restart(s,team,kind,Vector2(14*s.side(team),4))
   var origin:Vector2=s.ball
   var p:Vector2=s.players[s.restart_taker].pos
   var event:int=s.event_serial
   s.apply_command(1-team,{"action":4095,"move":Vector2.RIGHT})
   s.apply_command(team,{"action":4,"move":Vector2.RIGHT})
   s.step(0.2)
   test.check(s.phase=="restart" and s.ball==origin and s.players[s.restart_taker].pos.distance_to(p)<=s.players[s.restart_taker].speed*0.23 and s.event_serial==event,"restart moves players continuously and rejects premature/wrong-team commands: "+kind)
   test.check(s.elapsed==0,"stoppage pauses clock: "+kind)
   test.check(preload("res://restart_impact_tests.gd").prepare(s),"restart preparation completes")
   s.apply_command(team,{"action":4})
   s.mechanics.tick(s,0.09)
   test.check(s.phase=="play" and s.owner==-1 and s.restart_touch==s.restart_taker and s.velocity.length()>0,"legal restart releases play: "+kind)
   if kind=="goal_kick": test.check(s.players[team*5].action=="set_kick" and s.ball_height==s.BallPhysics.FLOOR,"goal clearance defaults to directional foot distribution")
 s=fixture()
 s.Rules.restart(s,0,"free_kick",Vector2(15,2))
 preload("res://restart_impact_tests.gd").prepare(s)
 test.check(s.players[7].action=="wall" and s.players[8].action=="wall" and s.players[7].pos.distance_to(s.ball)>=5,"free kick arranges a defensive wall")
 var corner_case=fixture()
 for p in corner_case.players: p.pos=Vector2(29,16)
 corner_case.Rules.restart(corner_case,0,"kick_in",Vector2(30,18))
 preload("res://restart_impact_tests.gd").prepare(corner_case)
 var clearance:=true
 for i in range(6,10): clearance=clearance and corner_case.players[i].pos.distance_to(corner_case.ball)>=5.2
 test.check(clearance,"boundary-clamped opponents still respect restart clearance")
 test.check(preload("res://restart_impact_tests.gd").prepare(s),"restart preparation completes");s.charge=0.5;s.apply_command(0,{"action":2,"finesse":true,"aim":0.5})
 s.mechanics.tick(s,0.09)
 test.check(s.phase=="play" and s.ball_spin!=0 and s.shots[0]==1,"free kick accepts charged curling shot")
 for kind in ["kick_in","goal_kick","indirect"]:
  s=fixture();s.Rules.restart(s,0,kind,Vector2(5,18));test.check(preload("res://restart_impact_tests.gd").prepare(s),"restart preparation completes")
  s.apply_command(0,{"action":3})
  test.check(s.phase=="restart" and s.shots[0]==0,"indirect restart rejects direct shot input: "+kind)
  s.apply_command(0,{"action":4})
  s.mechanics.tick(s,0.09)
  s.ball=Vector2(Pitch.HALF_LENGTH+1,0);s.ball_height=0.31;s.resolve_boundary()
  test.check(s.score==[0,0] and s.restart_kind=="goal_kick","untouched indirect delivery cannot score: "+kind)
 s=fixture();s.Rules.restart(s,0,"kick_in",Vector2(0,18));test.check(preload("res://restart_impact_tests.gd").prepare(s),"restart preparation completes")
 s.pass_ball();var taker:int=s.restart_touch
 test.check(not s.kick(taker,Vector2.ZERO,20,false) and s.restart_kind=="indirect" and s.restart_team==1,"second touch by restart taker awards indirect free kick")
 s=fixture();s.Rules.restart(s,0,"corner",Vector2(32,18));test.check(preload("res://restart_impact_tests.gd").prepare(s),"restart preparation completes")
 s.pass_ball();s.kick(2 if s.restart_taker==1 else 1,Vector2(Pitch.HALF_LENGTH+1,0),25,true)
 s.ball=Vector2(Pitch.HALF_LENGTH+1,0);s.ball_height=0.31;s.resolve_boundary()
 test.check(s.score[0]==1,"another player touching the ball clears restart restrictions")
 for kind in ["kick_in","corner","free_kick"]:
  s=fixture();s.Rules.restart(s,0,kind,Vector2(8,18));test.check(preload("res://restart_impact_tests.gd").prepare(s),"restart preparation completes");s.step(4.01)
  test.check(s.phase=="restart" and s.restart_team==1 and s.message.contains("超时"),"four-second restart violation transfers possession: "+kind)
 for spot in [Vector2(9,1),Vector2(Pitch.HALF_LENGTH-7,1)]:
  s=fixture();s.owner=1;s.players[1].pos=spot;s.players[1].dir=Vector2.RIGHT
  s.players[6].pos=spot-Vector2(1.5,0);s.players[6].dir=Vector2.RIGHT
  s.ball=spot+Vector2(1,0);s.tackle(6,true)
  s.players[6].action_time=s.Motion.SLIDE_DURATION-0.10;s.resolve_tackle(6,true)
  test.check(s.phase=="foul" and s.fouls[1]==1 and s.players[1].action=="fall","late slide from behind triggers foul and fall")
  test.check(s.restart_kind==("penalty" if spot.x>Pitch.HALF_LENGTH-9 else "free_kick"),"foul location selects penalty or free kick")
  s.apply_command(0,{"action":3});s.step(1.3)
  test.check(s.phase=="restart" and s.restart_team==0 and s.owner==-1 and s.restart_flow.stage=="fetch" and s.elapsed==0,"foul animation transitions to playable restart without advancing clock")
 s=fixture();s.owner=6;s.players[6].pos=Vector2(1.5,0);s.players[6].dir=Vector2.LEFT
 s.players[1].pos=Vector2.ZERO;s.players[1].dir=Vector2.RIGHT;s.ball=Vector2(0.7,0)
 s.tackle(1,true)
 s.players[1].action_time=s.Motion.SLIDE_DURATION-0.10;s.resolve_tackle(1,true)
 test.check(s.phase=="play" and s.owner==-1 and s.tackles[0]==1 and s.fouls==[0,0],"front-on ball-first slide is legal")
 s=fixture();s.owner=1;s.players[1].pos=Vector2(5,0);s.players[1].dir=Vector2.RIGHT
 s.players[6].pos=Vector2(1,0);s.players[6].dir=Vector2.RIGHT;s.ball=Vector2(6,0)
 s.tackle(6,true)
 s.players[6].pos=Vector2(3.5,0);s.resolve_tackle(6,true)
 test.check(s.phase=="foul","moving slide checks later contact, not only button-press frame")
 s=fixture();s.apply_command(0,{"action":256,"move":Vector2.ZERO})
 s.mechanics.tick(s,0.09)
 test.check(s.vertical_speed>4 and s.players[1].action=="cross" and s.pass_receiver>=0,"cross produces elevated pass and receiver")
 s=fixture();s.apply_command(0,{"action":8,"chip":true})
 s.mechanics.tick(s,0.09)
 test.check(s.vertical_speed>4 and s.players[1].action=="cross","modifier-through input creates lobbed through ball")
 s=fixture();s.charge=0.6;s.apply_command(0,{"action":2,"chip":true})
 s.mechanics.tick(s,0.09)
 test.check(s.vertical_speed>8 and s.players[1].action=="chip" and s.shots[0]==1,"chip shot uses high arc")
 s=fixture();s.start_charge();s.apply_command(0,{"action":2176})
 test.check(s.owner==1 and not s.charging and s.players[1].action=="feint" and s.shots[0]==0,"fake shot retains possession without firing")
 for header in [true,false]:
  s=fixture();s.owner=-1;s.ball=s.players[1].pos;s.players[1].cooldown=0
  s.ball_height=s.players[1].body.head_height if header else 1.2
  var height:float=s.ball_height
  s.apply_command(0,{"action":1024,"aim":0.5})
  if header: s.mechanics.tick(s,1.0/60)
  test.check(s.players[1].action==("header" if header else "volley") and s.ball_height==height and s.shots[0]==1,"aerial strike preserves contact height and selects appropriate animation")
 s=fixture();s.owner=-1;s.ball=s.players[1].pos;s.ball_height=9;s.aerial(1,0)
 test.check(s.shots[0]==0,"unreachable aerial ball cannot be struck")
 s=fixture();s.last_touch=1;s.Rules.goal(s,0)
 var elapsed:float=s.elapsed
 s.apply_command(1,{"action":4095});s.step(1.5)
 test.check(s.phase=="goal" and s.score==[1,0] and s.elapsed==elapsed and s.players[1].action=="idle" and s.players[6].action=="idle","goal presentation locks gameplay without player celebration and pauses time")
 s.step(s.Rules.GOAL_DURATION-1.5+0.1)
 test.check(s.phase=="restart" and s.restart_kind=="kickoff" and s.restart_team==1,"goal returns to conceding side kickoff")
 var transport=load("res://match_network.gd").new()
 transport.sim=s
 for phase in ["foul","restart","goal"]:
  s.phase=phase;s.phase_time=1.3;s.restart_kind="penalty";s.fouls=[2,4]
  s.message="克里斯蒂亚诺·罗纳尔多 犯规 · 直接任意球"
  var wire:Dictionary=transport.pack_state(s.snapshot())
  var state:Dictionary=transport.unpack_state(wire)
  test.check(state.rules.phase==phase and state.rules.fouls==[2,4] and state.restart=="penalty" and absf(state.rules.phase_time-1.3)<0.001,"compact network snapshot preserves stoppage state: "+phase)
  test.check(var_to_bytes(wire).size()<1200,"stoppage snapshot including long player name stays below MTU")
 transport.free()
 var controls=load("res://football_input.gd").new()
 for keyboard in [true,false]:
  controls.reset();controls.gamepad=93;controls.sync_context(1,6,1)
  var event:InputEvent=InputEventKey.new() if keyboard else InputEventJoypadButton.new()
  if keyboard: event.physical_keycode=KEY_A
  else: event.device=93;event.button_index=JOY_BUTTON_X
  event.pressed=true;controls.handle(event)
  test.check(controls.command().action==512,"keyboard / pad cross key becomes slide while defending")
  controls.aerial_available=true
  if keyboard: event.physical_keycode=KEY_D
  else: event.button_index=JOY_BUTTON_B
  controls.handle(event)
  test.check(controls.command().action==1024,"keyboard / pad shoot key selects aerial action near high ball")
