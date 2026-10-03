extends SceneTree
const Pitch=preload("res://pitch_geometry.gd")
const Match=preload("res://match_sim.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
 checks+=1
 if not value: failures+=1;push_error("KEEPER_GOAL_FAILED "+message)
func fixture(team:int=0):
 var s=Match.new();s.setup(preload("res://campaign.gd").new(),716,Match.Squad.DEFAULT,Match.Squad.DEFAULT,true)
 s.freeze=0;s.phase="play";s.owner=-1;s.pickup_lock=0;s.duration=1000;s.kick_age=0.4;s.arcade=false
 for t in 2: s.teams[t].human=true;s.teams[t].selected=t*5+1
 for p in s.players: p.active=false;p.vel=Vector2.ZERO;p.cooldown=0
 var keeper:Dictionary=s.players[team*5];keeper.active=true;keeper.pos=Vector2((-Pitch.HALF_LENGTH+3)*s.side(team),0)
 keeper.dir=Vector2(s.side(team),0);s.last_touch=(1-team)*5+1;s.ball_is_shot=false
 s.ball_height=s.BallPhysics.FLOOR;s.vertical_speed=0;s.velocity=Vector2.ZERO
 return s
func advance(s,time:float)->void:
 for frame in ceili(time*60):
  s.step(1.0/60)
  if s.owner>=0 or s.phase!="play": break
func _initialize()->void:
 await process_frame
 for team in 2:
  var i:int=team*5
  var s=fixture(team);var q:float=s.side(team);var p:Dictionary=s.players[i]
  s.ball=Vector2((-Pitch.HALF_LENGTH+12)*q,2);s.velocity=Vector2((-Pitch.HALF_LENGTH+2)*q,0);s.ball_is_shot=true
  var aim:Vector2=s.keeper_target(i)
  check(p.action=="dive_low" and p.keeper_side==-q and aim.y>1,"shot anticipation and dive direction mirror correctly team "+str(team))
  s=fixture(team);p=s.players[i];p.cooldown=0.3;s.ball=Vector2((-Pitch.HALF_LENGTH+12)*q,2);s.velocity=Vector2((-Pitch.HALF_LENGTH+2)*q,0);s.ball_is_shot=true
  s.keeper_target(i)
  check(p.action not in s.Motion.DIVES,"recovering keeper cannot chain an immediate second dive team "+str(team))
  s=fixture(team);p=s.players[i]
  s.ball=p.pos+Vector2(q*1.50,0);s.velocity=Vector2(-q*8,0);s.ball_is_shot=true
  s.resolve_player_contacts(s.ball)
  check(s.owner==i and p.keeper_holding,"larger natural hand reach team "+str(team))
  s=fixture(team);p=s.players[i];s.last_touch=team*5+1;s.ball=p.pos+Vector2(q*1.15,0);s.velocity=Vector2(-q*4,0)
  s.resolve_player_contacts(s.ball)
  check(s.owner==i and not p.keeper_holding,"expanded foot control preserves backpass feet team "+str(team))
  s=fixture(team);p=s.players[i];p.pos=Vector2((-Pitch.HALF_LENGTH+4)*q,2);s.ball=Vector2((-Pitch.HALF_LENGTH+2)*q,2);s.velocity=Vector2(-2*q,0);s.last_touch=team*5+1
  var target:Vector2=s.keeper_target(i)
  check(target.x*q<p.pos.x*q,"keeper recovers ball behind current position team "+str(team))
  advance(s,1.5)
  check(s.owner==i and s.score==[0,0],"keeper actually collects ball after recovering behind team "+str(team))
  s=fixture(team);s.ball=Vector2((-Pitch.HALF_LENGTH+8)*q,3)
  advance(s,2.0)
  check(s.owner==i and not s.players[i].keeper_holding,"proactively sweeps loose ball with feet team "+str(team))
  s=fixture(team);p=s.players[i];p.pos=Vector2((-Pitch.HALF_LENGTH+1)*q,0);p.speed=0
  s.ball=Vector2((-Pitch.HALF_LENGTH+2.8)*q,0);s.velocity=Vector2(-50*q,0);s.ball_is_shot=true
  s.step(0.08)
  check(s.saves[team]==1 and s.score==[0,0] and s.velocity.x*q>0,"swept save precedes later same-tick goal crossing team "+str(team))
  s=fixture(team);p=s.players[i];p.pos=Vector2((-Pitch.HALF_LENGTH-2)*q,0);p.speed=0;p.ratings.acceleration=0.01
  s.ball=Vector2((-Pitch.HALF_LENGTH-1.5)*q,0);s.velocity=Vector2(-10*q,0);s.ball_is_shot=true
  s.resolve_player_contacts(Vector2((-Pitch.HALF_LENGTH+1)*q,0));s.resolve_boundary()
  check(s.score[1-team]==1 and s.saves[team]==0,"contact beyond goal line cannot rescue a goal team "+str(team))
  s=fixture(team);p=s.players[i];s.ball=p.pos+Vector2(q,0);s.ball_height=p.body.hand_reach+1;s.ball_is_shot=true
  s.resolve_player_contacts(s.ball)
  check(s.owner<0 and s.saves[team]==0,"greater reach cannot collect unreachable high ball team "+str(team))
  s=fixture(team);p=s.players[i];p.pos=Vector2((-Pitch.HALF_LENGTH+12)*q,0);s.ball=p.pos+Vector2(q,0);s.ball_is_shot=true
  check(not s.keeper_can_save(i),"no hands outside penalty area team "+str(team))
  s=fixture(team);p=s.players[i];p.pos=Vector2((-Pitch.HALF_LENGTH+3)*q,5);s.ball=Vector2((-Pitch.HALF_LENGTH+2)*q,-4);s.velocity=Vector2((-Pitch.HALF_LENGTH+12)*q,0);s.ball_is_shot=true
  advance(s,0.3)
  check(s.score[1-team]==1,"unreachable far-corner shot remains a goal team "+str(team))
  s=fixture(team);s.ball=Vector2((-Pitch.HALF_LENGTH+8)*q,3);s.players[(1-team)*5+1].active=true;s.players[(1-team)*5+1].pos=s.ball
  check(s.keeper_target(i).x*q< -Pitch.HALF_LENGTH+5,"keeper avoids losing race to loose ball team "+str(team))
 var s=fixture();s.last_touch=1;var elapsed:float=s.elapsed
 s.Rules.goal(s,0)
 check(s.phase_time==s.Rules.GOAL_DURATION and s.players.all(func(p):return p.action=="idle"),"goal uses presentation interval without staged player celebration")
 s.step(s.Rules.GOAL_INTRO+0.1)
 check(s.phase=="goal" and s.elapsed==elapsed,"intro and replay pause match clock")
 s.step(s.Rules.GOAL_DURATION)
 check(s.phase=="restart" and s.restart_team==1,"goal returns to opponent kickoff after replay interval")
 s=fixture();s.overtime=true;s.last_touch=1;s.Rules.goal(s,0)
 s.step(s.Rules.GOAL_DURATION-0.1);check(not s.finished,"golden goal leaves time for replay")
 s.step(0.2);check(s.finished,"golden goal finishes after replay")
 print("KEEPER_GOAL_TESTS_","PASS" if failures==0 else "FAILED"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
