extends SceneTree
const Team=preload("res://team_config.gd")
const Match=preload("res://match_sim.gd")
const Campaign=preload("res://campaign.gd")
const Pitch=preload("res://pitch_geometry.gd")
const Flow=preload("res://restart_flow.gd")
var checks:=0
var failures:=0
func check(value:bool,label:String)->void:
 checks+=1
 if not value: failures+=1;push_error("PITCH_MODES_FAILED "+label)
func fixture():
 var s=Match.new();s.setup(Campaign.new(),722,Match.Squad.DEFAULT,Match.Squad.DEFAULT,true)
 s.freeze=0;s.duration=1000;s.pickup_lock=0;s.owner=-1;s.phase="play"
 for t in s.teams: t.human=true
 for p in s.players: p.cooldown=0;p.vel=Vector2.ZERO
 return s
func skip_tests()->void:
 for team in 2:
  var s=fixture();s.ball=Vector2(Pitch.HALF_LENGTH,Pitch.HALF_WIDTH+1)
  s.Rules.restart(s,team,"kick_in",s.ball)
  var clock:float=s.elapsed
  for i in 30: s.apply_command(team,{"skip_restart":true});s.step(1.0/60)
  check(s.restart_flow.hold[team]>0.45 and s.restart_flow.skip_time<0,"hold fills without premature cut")
  s.apply_command(team,{"skip_restart":false});s.step(1.0/60)
  check(s.restart_flow.hold[team]==0,"releasing early resets ring")
  for i in 80: s.apply_command(team,{"skip_restart":true});s.step(1.0/60)
  check(Flow.ready(s) and s.restart_flow.skipped and s.owner==s.restart_taker,"either human team can complete deliberate hold")
  check(s.elapsed==clock and s.phase_time<0.1,"skip preserves clock and begins restart timer only after fade")
  check(s.ball.distance_to(s.restart_spot)<0.001 and s.players[s.restart_taker].pos.distance_to(s.restart_flow.targets[s.restart_taker])<0.001,"skip produces legal player and ball positions")
  var net=preload("res://match_network.gd").new();net.sim=s
  var state:Dictionary=net.unpack_state(net.pack_state(s.snapshot()))
  check(state.rules.restart_flow.skipped and absf(state.rules.restart_flow.skip_time-s.restart_flow.skip_time)<0.001,"skip stage replicates in compact authority snapshot")
  net.free()
 var input=preload("res://football_input.gd").new();input.restart_preparing=true
 input.passing(4,true)
 check(input.command().skip_restart and int(input.command().action)==0,"held pass during preparation is skip command")
 input.restart_preparing=false;input.passing(4,false)
 check(int(input.command().action)==0,"release after skip cannot accidentally pass")
 input.passing(4,true);input.passing(4,false)
 check(int(input.command().action)&4,"next deliberate press passes normally")
 input.restart_preparing=true;input.passing(4,true);input.reset()
 check(not input.command().skip_restart,"focus/menu reset releases hold")
func boundary_tests()->void:
 check(absf(Pitch.HALF_LENGTH*Pitch.HALF_WIDTH/(32.0*18.0)-1.2)<0.00001,"playing area is exactly twenty percent larger")
 for end in [-1,1]:
  for axis in 2:
   var s=fixture();s.ice_mode=true
   s.ball=Vector2(end*(Pitch.HALF_LENGTH+0.3),10) if axis==0 else Vector2(3,end*(Pitch.HALF_WIDTH+0.3))
   s.velocity=Vector2(end*30,0) if axis==0 else Vector2(0,end*30)
   var before:float=s.velocity.length();s.resolve_boundary()
   check(s.phase=="play" and s.velocity[axis]*end<0 and s.velocity.length()<before,"each wall rebounds and dissipates energy")
   check(absf(s.ball.x)<=Pitch.HALF_LENGTH and absf(s.ball.y)<=Pitch.HALF_WIDTH,"rebound returns ball inside enlarged pitch")
   s=fixture();s.ice_mode=true;s.ball=Vector2(end*(Pitch.HALF_LENGTH+0.4),0);s.ball_height=2.4;s.resolve_boundary()
   check(s.phase=="goal" and s.score[0 if end==1 else 1]==1,"goal mouth remains open for elevated goals")
  var s=fixture();s.ice_mode=true;s.ball=Vector2(end*(Pitch.HALF_LENGTH+0.1),0);s.ball_height=5;s.velocity=Vector2(end*30,0);s.resolve_boundary()
  check(s.phase=="play" and s.velocity.x*end<0,"ball above crossbar rebounds from end boundary")
 var s=fixture();s.ice_mode=true;s.ball=Vector2(Pitch.HALF_LENGTH+1,Pitch.HALF_WIDTH+1);s.velocity=Vector2(30,20);s.resolve_boundary()
 check(s.velocity.x<0 and s.velocity.y<0 and s.phase=="play","corner reflects both components without an out-of-play event")
 s=fixture();s.ice_mode=true;s.owner=1;s.ball=Vector2(0,Pitch.HALF_WIDTH+0.2);s.velocity=Vector2(0,8);s.resolve_boundary()
 check(s.owner==-1 and s.pickup_lock>0 and s.velocity.y<0,"carried ball hitting wall releases possession")
 s=fixture();s.ball=Vector2(0,Pitch.HALF_WIDTH+0.1);s.last_touch=1;s.resolve_boundary()
 check(s.phase=="restart" and s.restart_kind=="kick_in" and s.restart_team==1,"classic rules retain touchline restarts")
 s=fixture();s.ice_mode=true;s.stage=1;s.elapsed=14
 check(not s.wind_active() and not s.arcade,"ice mode does not inherit campaign wind or power bonuses")
 var net=preload("res://match_network.gd").new();net.sim=s
 var restored=Match.new();restored.restore(net.unpack_state(net.pack_state(s.snapshot())))
 check(restored.ice_mode and not restored.arcade,"rebound rule survives full compact transport")
 net.free()
func height_tests()->void:
 var s=fixture();var p:Dictionary=s.players[1];p.pos=Vector2.ZERO
 var Collider=preload("res://player_collision.gd")
 var h:float=p.body.head_height
 check(Collider.sweep(p,Vector3(-2,h,0.8),Vector3(2,h,0.8)).is_empty(),"ball beside head is not blocked by a torso-sized horizontal radius")
 check(not Collider.sweep(p,Vector3(-2,h,0),Vector3(2,h,0)).is_empty(),"real head contact remains solid")
 check(Collider.sweep(p,Vector3(-2,p.body.height+0.5,0),Vector3(2,p.body.height+0.5,0)).is_empty(),"ball clears player's head including football radius")
 var crossing:=Collider.sweep(p,Vector3(-2,0.4,0),Vector3(2,4,0))
 check(not crossing.is_empty(),"swept collision tests height at contact rather than only end height")
 var energy_ok:=true
 for normal in [Vector3.LEFT,Vector3(1,1,0).normalized(),Vector3(0,-1,1).normalized()]:
  var v:=Vector3(36,9,2);energy_ok=energy_ok and Collider.deflect(v,normal,0.4).length()<=v.length()+0.001
 check(energy_ok,"three-dimensional passive contacts never add speed")
 var peaks:Array=[];var goal_heights:Array=[]
 for charge in [0.10,0.60,0.85]:
  var shot:Dictionary=s.Motion.shot(charge,"normal",p.ratings)
  var flight:Dictionary={"pos":Vector2(Pitch.HALF_LENGTH-18,0),"velocity":Vector2(shot.speed,0),"height":s.BallPhysics.FLOOR,"vertical":shot.vertical,"spin":0.0}
  var peak:float=flight.height
  for tick in 120:
   flight=s.BallPhysics.advance(flight.pos,flight.velocity,flight.height,flight.vertical,0,true,1.0/120)
   peak=maxf(peak,flight.height)
   if flight.pos.x>Pitch.HALF_LENGTH: break
  peaks.append(peak);goal_heights.append(flight.height)
 check(peaks[0]<peaks[1] and peaks[1]<peaks[2],"charge raises actual flight trajectory")
 check(goal_heights[1]>1.4 and goal_heights[1]<3.2,"medium charge reaches goal above ground and below bar")
 print("SHOT_GOAL_HEIGHTS ",goal_heights," PEAKS ",peaks)
func pace_tests()->void:
 var s=fixture();var p:Dictionary=s.players[1];p.pos=Vector2.ZERO;p.vel=Vector2(8,0);p.dir=Vector2.RIGHT
 var bounded:=true
 for i in 50:
  var before:Vector2=p.vel
  s.move_player(1,1.0/60,Vector2.LEFT,false,false)
  bounded=bounded and p.vel.distance_to(before)<=maxf(p.ratings.acceleration,p.ratings.braking)/60+0.001
 check(bounded and p.vel.x<0,"reversal obeys acceleration cap through whole turn")
 var home=fixture();var c=Campaign.new();c.stage=2;c.difficulty=1
 var hard=Match.new();hard.setup(c,722)
 check(is_equal_approx(home.players[7].speed,hard.players[7].speed),"campaign difficulty cannot multiply opponent running speed")
 s=fixture();s.owner=1;s.players[1].pos=Vector2.ZERO;s.ball=Vector2(1,0);s.brain.prepare(s)
 var jobs:Array=s.brain.jobs.duplicate();var targets:Array=s.brain.targets.duplicate()
 s.owner=-1;s.last_touch=1;s.pass_receiver=2;s.velocity=Vector2(20,-5);s.brain.prepare(s)
 check(s.brain.reaction_until[6]>s.elapsed and s.brain.targets[6]==targets[6] and s.brain.jobs[6]==jobs[6],"defenders perceive release before replanning interception")
 s=fixture();s.last_touch=1;s.velocity=Vector2(20,0);s.brain.prepare(s)
 check(s.brain.reaction_until[7]>s.elapsed and s.brain.targets[7]==s.players[7].pos,"first pass after a restart also requires perception without a run to world origin")
 s=fixture();s.owner=1;s.players[1].pos=Vector2.ZERO;s.ball=Vector2(1,0);s.brain.prepare(s)
 var support:int=s.brain.supports[0]
 check(absf(s.brain.targets[support].y)>6,"default support opens a wide passing angle")
 check(absf(s.players[2].pos.y-s.players[3].pos.y)>=24,"starting wings spread to separate lanes")
func _initialize()->void:
 await process_frame
 skip_tests();boundary_tests();height_tests();pace_tests()
 print("PITCH_MODES_TESTS_", "PASS" if failures==0 else "FAILED", " checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
