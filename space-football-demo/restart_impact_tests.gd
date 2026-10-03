extends SceneTree
const Pitch=preload("res://pitch_geometry.gd")
const Match=preload("res://match_sim.gd")
const Feedback=preload("res://impact_feedback.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
 checks+=1
 if not value: failures+=1;push_error("RESTART_IMPACT_FAILED "+message)
func fixture():
 var s=Match.new();s.setup(preload("res://campaign.gd").new(),721,Match.Squad.DEFAULT,Match.Squad.DEFAULT,true)
 s.phase="play";s.freeze=0;s.arcade=false;s.duration=1000
 for t in s.teams: t.human=true;t.move=Vector2.ZERO
 for p in s.players: p.vel=Vector2.ZERO
 return s
static func prepare(s)->bool:
 for tick in 2400:
  if s.Rules.Flow.ready(s): return true
  s.step(1.0/60)
 return false
func _initialize()->void:
 await process_frame
 for team in 2:
  for kind in Match.Rules.TITLES:
   var s=fixture();s.ball=Vector2(17*s.side(team),18.2);s.velocity=Vector2(5,3)
   var positions:Array=[]
   for p in s.players: positions.append(p.pos)
   var ball:Vector2=s.ball
   s.Rules.restart(s,team,kind,ball)
   var untouched:bool=s.ball==ball
   for i in 10: untouched=untouched and positions[i]==s.players[i].pos
   check(untouched,"restart preserves current ball/player positions "+kind+str(team))
   check(s.owner==-1 and not s.kick(s.restart_taker,Vector2.ZERO,30,false),"preparation cannot be skipped by kick "+kind)
   var stages:Array=[];var smooth:=true;var paused:=true
   for tick in 2400:
    if s.Rules.Flow.ready(s): break
    if s.restart_flow.stage not in stages: stages.append(s.restart_flow.stage)
    positions.clear()
    for p in s.players: positions.append(p.pos)
    s.step(1.0/60)
    for i in 10: smooth=smooth and s.players[i].pos.distance_to(positions[i])<=s.players[i].speed*1.13*s.Rules.Flow.TRAVEL_SCALE/60+0.001
    paused=paused and s.elapsed==0 and s.phase_time<0.02
   check(s.Rules.Flow.ready(s),"restart finishes preparation "+kind+str(team)+" stage="+str(s.restart_flow.get("stage")))
   check(smooth and paused,"continuous travel and paused countdown "+kind)
   check(stages.size()>=5,"fetch/lift/carry/place/organize all occur "+kind)
   check(s.ball.distance_to(s.restart_spot)<0.001 and absf(s.ball_height-s.BallPhysics.FLOOR)<0.00001,"ball placed at legal restart location "+kind)
   s.apply_command(team,{"action":s.Mechanics.SWITCH,"direction":Vector2.RIGHT})
   check(s.teams[team].selected==s.restart_taker,"directional switch cannot abandon the restart taker "+kind)
   var transport=load("res://match_network.gd").new();transport.sim=s
   var wire:Dictionary=transport.pack_state(s.snapshot());var decoded:Dictionary=transport.unpack_state(wire)
   check(decoded.rules.restart_flow.stage=="ready" and decoded.players[s.restart_taker].action==s.players[s.restart_taker].action,"network preserves restart stage and animation "+kind)
   check(var_to_bytes(wire).size()<1200,"restart snapshot stays under MTU "+kind)
   transport.free()
   s.view_team=team;s.pass_ball(false,Vector2(s.side(team),0))
   check(s.phase=="play" and s.owner==-1,"prepared restart is playable "+kind)
 var s=fixture();s.ball=Vector2(30,19);s.Rules.restart(s,0,"corner",s.ball)
 check(prepare(s),"corner ready before change taker")
 var previous:int=s.restart_taker;var new_taker:int=1 if previous!=1 else 2
 var old_pos:Vector2=s.players[previous].pos;var new_pos:Vector2=s.players[new_taker].pos
 s.Rules.Flow.change_taker(s,new_taker)
 check(s.owner==-1 and old_pos==s.players[previous].pos and new_pos==s.players[new_taker].pos,"changing taker never swaps actual player positions")
 check(prepare(s) and s.owner==new_taker,"replacement taker retrieves and places ball")
 s=fixture();s.ball=Vector2(33,1);s.Rules.restart(s,1,"kickoff",Vector2.ZERO)
 for tick in 2400:
  s.step(1.0/60)
  if s.restart_flow.stage=="carry": break
 var copy=fixture();copy.restore(s.snapshot())
 for tick in 100: s.step(1.0/60);copy.step(1.0/60)
 check(s.snapshot()==copy.snapshot(),"mid-carry snapshot resumes identical authoritative motion")
 s=fixture();s.players[1].jump_z=0.6;s.players[1].jump_v=1
 s.Rules.restart(s,0,"kick_in",Vector2(2,18))
 check(s.players[1].jump_z==0.6,"restart does not teleport airborne player down")
 for tick in 30: s.step(1.0/60)
 check(s.players[1].jump_z==0,"airborne player lands during stoppage")
 s=fixture();s.mechanics.discipline(s,6,true);s.mechanics.discipline(s,6,true);s.players[6].sinbin=0
 s.Rules.restart(s,0,"kick_in",Vector2(3,18));s.mechanics.tick(s,1.0/60)
 check(s.players[6].active and s.players[6].pos.y>18,"red-card replacement enters at touchline, never appears in central formation")
 check(prepare(s) and absf(s.players[6].pos.y)<17,"replacement runs into formation before ready")
 for powerful in [false,true]:
  s=fixture();s.charge=0.85 if powerful else 0.2;s.shoot()
  check((s.impact_id>0)==powerful,"only powerful real shots emit impact")
  s=fixture();s.pass_ball(false,Vector2.RIGHT,false,false,0.9 if powerful else 0.3,powerful)
  check((s.impact_id>0)==powerful,"only driven/strong real passes emit impact")
 s=fixture();s.notify("shot","test notification")
 check(s.impact_id==0,"UI events cannot fabricate impacts")
 s=fixture();s.owner=6;s.players[6].pos=Vector2(1.5,0);s.players[6].dir=Vector2.LEFT
 s.players[1].pos=Vector2.ZERO;s.players[1].dir=Vector2.RIGHT;s.ball=Vector2(0.7,0)
 s.tackle(1,true);s.resolve_tackle(1,true)
 check(s.impact_id==1 and s.impact_kind==3 and s.fouls==[0,0],"clean slide contact emits impact")
 s.resolve_tackle(1,true);check(s.impact_id==1,"same slide cannot emit repeated impacts")
 s=fixture();s.owner=1;s.players[1].pos=Vector2(5,0);s.players[1].dir=Vector2.RIGHT
 s.players[6].pos=Vector2(3.5,0);s.players[6].dir=Vector2.RIGHT;s.ball=Vector2(6,0)
 s.tackle(6,true);s.resolve_tackle(6,true)
 check(s.phase=="foul" and s.impact_id==0,"foul does not receive clean tackle feedback")
 var maximum:=0.0
 for tick in 60:
  var value:=Feedback.offset(tick/120.0,1,Vector2.RIGHT,1,1)
  maximum=maxf(maximum,value.length())
 check(maximum>0.025 and maximum<0.17,"default feedback has a small visible bounded amplitude")
 check(Feedback.offset(0.04,1,Vector2.RIGHT,0,1)==Vector2.ZERO and Feedback.offset(0.3,1,Vector2.RIGHT,2,1)==Vector2.ZERO,"feedback can be disabled and always returns exactly to zero")
 print("RESTART_IMPACT_TESTS_", "PASS" if failures==0 else "FAIL", " checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
