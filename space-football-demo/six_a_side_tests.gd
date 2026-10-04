extends SceneTree
const Team=preload("res://team_config.gd")
const Match=preload("res://match_sim.gd")
const Campaign=preload("res://campaign.gd")
const Feedback=preload("res://impact_feedback.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures+=1;push_error("SIX_A_SIDE_FAILED "+label)
func fixture():
 var s=Match.new();s.setup(Campaign.new(),740,Match.Squad.DEFAULT,Match.Squad.DEFAULT,true)
 s.freeze=0;s.duration=1000
 for t in s.teams: t.human=true
 return s
func ready(s)->bool:
 return preload("res://restart_impact_tests.gd").prepare(s)
func _initialize()->void:
 await process_frame
 for team in 2:
  var s=fixture();var index:=team*Team.SIZE+Team.MIDFIELD_SLOT
  s.teams[team].selected=index;s.owner=index;s.ball=s.players[index].pos;s.view_team=team
  var position:Vector2=s.players[index].pos
  for tick in 20: s.apply_command(team,{"move":Vector2(0,1)});s.step(1.0/60)
  check(s.players[index].pos.y>position.y+0.1 and s.is_controlled(index),"sixth player has manual movement on team "+str(team))
  s.pass_ball(false,Vector2(s.side(team),0))
  check(s.passes[team]==1 and s.last_touch==index and s.pass_receiver/Team.SIZE==team,"midfielder pass stays within correct team "+str(team))
  s=fixture();s.brain.prepare(s)
  check(s.brain.targets.size()==Team.COUNT and s.brain.jobs[index]!="keeper","midfielder participates in team planning")
  s=fixture();var q:float=s.side(team);var spot:=Vector2(20*q,2)
  s.players[team*Team.SIZE+1].pos=spot-Vector2(q,0)
  s.players[index].pos=spot+Vector2(-3*q,2)
  s.ball=spot;s.Rules.restart(s,team,"free_kick",spot)
  check(s.restart_flow.wall.size()==2 and s.restart_flow.wall.all(func(i):return i/Team.SIZE!=team),"only defending team forms shooting-range wall")
  check(s.restart_flow.targets[index].distance_to(spot)<5,"attacking midfielder can offer a short outlet")
  check(ready(s),"six-player free kick reaches legal ready state")
  var legal:=true
  for i in range((1-team)*Team.SIZE,(2-team)*Team.SIZE):
   var p:Vector2=s.players[i].pos
   legal=legal and (p.distance_to(spot)>=s.Rules.FREE_DISTANCE-0.09 or (absf(p.x-Match.HALF_LENGTH*q)<0.09 and absf(p.y)<Match.GOAL_WIDTH))
  check(legal,"all defenders respect five metres or goal-line exemption")
  var transport=load("res://match_network.gd").new();transport.sim=s
  s.impact(1,0.7,Vector2(q,0))
  var decoded:Dictionary=transport.unpack_state(transport.pack_state(s.snapshot()))
  check(decoded.players.size()==Team.COUNT and decoded.rules.restart_flow.targets.size()==Team.COUNT and decoded.impact_frame==s.frame,"twelve actors, wall and contact timestamp roundtrip")
  transport.free()
  s.step(4.1)
  check(s.phase=="restart" and s.restart_team==team,"ordinary free kick does not lose possession at four seconds")
  s.step(4.0)
  check(s.phase=="play" and s.last_touch/Team.SIZE==team,"eight-second game pacing fallback releases a friendly pass")
  s=fixture();s.ball=Vector2(-18*q,1);s.Rules.restart(s,team,"free_kick",s.ball)
  check(s.restart_flow.wall.is_empty(),"deep free kicks do not build a ceremonial wall")
  s=fixture();s.Rules.restart(s,team,"indirect",Vector2((Match.HALF_LENGTH-2)*q,1))
  check(is_equal_approx(s.restart_spot.x*q,Match.HALF_LENGTH-Match.Pitch.GOAL_AREA_DEPTH),"indirect inside goal area moves to nearest parallel line")
  s=fixture();s.ball=Vector2((-Match.HALF_LENGTH+3)*q,0);s.Rules.restart(s,team,"free_kick",s.ball)
  legal=true
  for i in range((1-team)*Team.SIZE,(2-team)*Team.SIZE): legal=legal and not s.Rules.in_box(s.restart_flow.targets[i],q)
  check(legal,"defensive free-kick opponents stand outside the penalty area")
  s=fixture();s.restart_touch=team*Team.SIZE+1;s.restart_origin="free_kick";s.owner=-1
  s.ball=Vector2(-(Match.HALF_LENGTH+1)*q,0);s.ball_height=s.BallPhysics.FLOOR;s.resolve_boundary()
  check(s.score==[0,0] and s.restart_kind=="corner" and s.restart_team==1-team,"untouched direct free kick into own net awards corner")
 for indoor in [false,true]:
  var s=fixture();s.mechanics.strict_rules=indoor;s.fouls[1]=5
  s.Rules.foul(s,Team.SIZE+1,1,false)
  check(s.restart_kind==("accumulated" if indoor else "free_kick"),"accumulated foul conversion is opt-in")
  s=fixture();s.mechanics.strict_rules=indoor;s.Rules.restart(s,0,"free_kick",Vector2(10,2));check(ready(s),"free kick ready for deadline test")
  s.step(4.1)
  check(s.restart_team==(1 if indoor else 0),"four-second free kick sanction belongs to indoor option")
 var saved_ids:Array=Match.Squad.ids.duplicate();var saved_path:String=Match.Squad.save_path
 Match.Squad.save_path="user://six-lineup-migration-test.json"
 var old:Array=Match.Squad.DEFAULT.slice(0,5);old[1]="legend-mbappe"
 var file:=FileAccess.open(Match.Squad.save_path,FileAccess.WRITE);file.store_string(JSON.stringify(old));file.close()
 Match.Squad.load_squad()
 check(Match.Squad.valid(Match.Squad.ids) and Match.Squad.ids.slice(0,5)==old,"legacy lineup preserves all custom choices")
 check(Match.Squad.assign_player(Match.Squad.ids[5],5),"new midfield slot can save atomically")
 Match.Squad.ids=saved_ids;Match.Squad.save_path=saved_path
 for version in [1,2,3]:
  var c=Campaign.new();c.save_path="user://six-campaign-migration-test.json"
  var data:Dictionary=c.data();data.version=version;data.training=[1,2,3,4,5].slice(0,version+2);data.credits=970
  file=FileAccess.open(c.save_path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
  check(c.load_game() and c.training.size()==5 and c.training.slice(0,version+2)==data.training and c.credits==970,"campaign version "+str(version)+" retains progress")
 check(Feedback.fresh(100,100) and Feedback.fresh(100,105) and not Feedback.fresh(100,112) and not Feedback.fresh(102,100),"fresh impacts accepted; stale/future contacts rejected")
 check(Feedback.offset(0,1,Vector2.RIGHT,1,1).length()>10 and Feedback.offset(0.24,1,Vector2.RIGHT,2,1)==Vector2.ZERO,"contact starts with visible impulse and returns to zero")
 var s=fixture();s.charge=0.9;s.apply_command(0,{"action":2})
 check(s.impact_id==0 and s.owner==1,"shot button/release windup does not shake before contact")
 for tick in 5: s.step(1.0/60)
 check(s.impact_id>0 and s.owner==-1 and Feedback.fresh(s.impact_frame,s.frame),"actual released shot stamps its contact frame")
 print("SIX_A_SIDE_TESTS_", "PASS" if failures==0 else "FAIL", " checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
