extends RefCounted
const Team=preload("res://team_config.gd")
const Library=preload("res://player_library.gd")
const Style=preload("res://player_style.gd")
const Ratings=preload("res://player_ratings.gd")
var test

func fixture():
 var s=test.fixture()
 s.teams[0].human=true;s.teams[1].human=true
 var positions:=[Vector2(-29,0),Vector2.ZERO,Vector2(-5,-9),Vector2(-4,9),Vector2(-11,0),Vector2(-9,5),Vector2(29,0),Vector2(13,0),Vector2(14,-8),Vector2(16,8),Vector2(20,0),Vector2(19,5)]
 for i in Team.COUNT:
  s.players[i].pos=positions[i];s.players[i].vel=Vector2.ZERO;s.players[i].cooldown=0
  s.players[i].speed=s.players[i].ratings.speed
 s.ball=Vector2(0.9,0);s.owner=1;s.selected=1
 return s

func run(runner)->void:
 test=runner
 var s=fixture();s.brain.prepare(s)
 test.check(s.brain.jobs[4]=="anchor" and s.brain.targets[4].x<s.ball.x-4,"attack retains a covering defender behind the ball")
 var support:int=s.brain.supports[0]
 test.check(support in [2,3,Team.MIDFIELD_SLOT] and s.brain.targets[support].distance_to(s.ball)>4 and s.brain.targets[support].distance_to(s.ball)<15,"short support forms a reachable diagonal instead of joining carrier")
 var runner_index:int=3 if support==2 else 2
 test.check(s.brain.jobs[runner_index]=="run" and s.brain.targets[runner_index].x>4 and absf(s.brain.targets[runner_index].y)>4,"other attacker provides depth and width")
 s.owner=4;s.ball=s.players[4].pos;s.selected=4;s.brain.reset();s.brain.prepare(s)
 test.check(s.brain.anchors[0]!=4 and s.brain.targets[s.brain.anchors[0]].x<s.ball.x,"another player covers when the defender carries forward")
 s=fixture();s.owner=7;s.ball=Vector2(0.9,0);s.players[7].pos=Vector2.ZERO;s.players[1].pos=Vector2(-1.7,0)
 s.brain.prepare(s)
 test.check(s.brain.pressers[0]==1 and s.brain.jobs.slice(1,Team.SIZE).count("press")==1,"manual defender counts as primary pressure; AI does not add a second chaser")
 var marked:Array=[]
 for i in range(1,Team.SIZE):
  if s.brain.marks[i]>=0: marked.append(s.brain.marks[i])
 test.check(marked.size()==3 and marked[0]!=marked[1] and marked[0]!=marked[2] and marked[1]!=marked[2],"three markers cover distinct opponents rather than duplicate one target")
 test.check(s.brain.jobs[s.brain.anchors[0]]=="cover" and s.brain.targets[s.brain.anchors[0]].x<0,"remaining defender protects the route to own goal")
 var primary:int=s.brain.pressers[0]
 for i in Team.COUNT: s.players[i].pos.y+=0.04
 s.elapsed+=0.13;s.frame+=1;s.brain.prepare(s)
 test.check(s.brain.pressers[0]==primary,"small positional changes do not alternate pressing responsibility")
 for i in range(1,Team.SIZE):
  if i!=primary: test.check(not s.brain.may_tackle(s,i),"non-primary defender does not spam an extra tackle")
 s=fixture();s.owner=-1;s.pass_receiver=-1;s.ball=Vector2(2,0);s.velocity=Vector2(10,3);s.ball_height=0.31
 s.brain.prepare(s)
 # A new loose ball is perceived first; inspect the settled team plan afterwards.
 s.elapsed+=0.5;s.frame+=30;s.brain.prepare(s)
 for team in 2:
  var count:=0
  for i in range(team*Team.SIZE+1,team*Team.SIZE+Team.SIZE):
   if s.brain.jobs[i] in ["intercept","receive"]: count+=1
  test.check(count==1,"one free-ball pursuer per team while others retain shape")
  var chaser:int=s.brain.pressers[team]
  test.check(s.brain.targets[chaser].x>s.ball.x,"free-ball pursuer predicts the rolling ball path")
 s=fixture();s.owner=-1;s.last_touch=1;s.pass_receiver=2;s.pass_destination=Vector2(2,-8);s.kick_age=0.2
 s.ball=Vector2(0,-4);s.velocity=Vector2(4,-10);s.brain.prepare(s)
 test.check(s.brain.modes[0]=="attack" and s.brain.jobs[4]=="anchor","a friendly pass in flight does not collapse attack into a defensive crowd")
 var safe:float=s.brain.lane_safety(s,0,Vector2.ZERO,Vector2(10,-8))
 s.players[7].pos=Vector2(5,-4)
 var blocked:float=s.brain.lane_safety(s,0,Vector2.ZERO,Vector2(10,-8))
 test.check(safe>blocked+0.3,"pass evaluation detects an opponent in the actual passing lane")
 s=fixture();s.players[2].pos=Vector2(10,0);s.players[7].pos=Vector2(5,0);s.players[3].pos=Vector2(5,10)
 var option:Dictionary=s.brain.pass_option(s,1)
 test.check(option.receiver!=2 and option.safety>0.3,"AI rejects the blocked forward teammate in favour of an available outlet")
 s=fixture();s.owner=2;s.selected=2;s.players[2].pos=Vector2.ZERO;s.ball=Vector2(0.9,0)
 s.players[1].pos=Vector2(18,0);s.players[3].pos=Vector2(-10,12);s.players[4].pos=Vector2(-18,-10)
 s.players[7].pos=Vector2(9,0)
 for i in range(Team.SIZE+2,Team.COUNT): s.players[i].pos=Vector2(-10,15)
 s.teams[0].tactic=2;s.brain.prepare(s)
 option=s.brain.pass_option(s,2)
 test.check(option.kind=="lob" and option.receiver==1,"creative passer can find a lofted route over the blocked ground corridor")
 s.elapsed=1;s.ai_direction(2)
 test.check(s.owner==-1 and s.players[2].action=="cross" and s.vertical_speed>4,"AI loft choice executes existing airborne pass physics and animation")
 s=fixture();s.brain.prepare(s)
 var old_targets:Array=s.brain.targets.duplicate()
 s.teams[0].tactic=2;s.frame+=1;s.brain.prepare(s)
 var new_runner:int=3 if s.brain.supports[0]==2 else 2
 test.check(s.brain.targets[new_runner].x>old_targets[new_runner].x,"attacking tactic increases forward-run depth without increasing player speed")
 s=fixture();s.players[1].pos=Vector2(21,0);s.ball=Vector2(21.9,0)
 for i in range(Team.SIZE+1,Team.COUNT): s.players[i].pos=Vector2(-10,i)
 s.brain.prepare(s);s.ai_direction(1)
 test.check(s.teams[0].charging,"AI starts a shot when a genuine scoring lane opens")
 s.teams[0].charge=0.7;s.elapsed+=0.3;s.ai_direction(1)
 test.check(s.shots[0]==1 and s.owner==-1,"AI finishes its charged shot without indefinite windup")
 s=fixture();s.teams[1].human=false
 for i in range(Team.SIZE,Team.COUNT): s.players[i].pos=Vector2(28,i+8);s.players[i].speed=0;s.players[i].cooldown=100
 var initial:Vector2=s.players[1].pos
 for frame in 45: s.apply_command(0,{"move":Vector2.UP});s.step(1.0/60)
 test.check(s.owner==1 and s.selected==1 and s.shots[0]==0 and s.passes[0]==0 and s.players[1].pos.y<initial.y-1,"player tendencies never override manual movement or trigger an unsolicited pass or shot")
 s=fixture();s.brain.prepare(s)
 var snapshot:Dictionary=s.snapshot();var clone=preload("res://match_sim.gd").new();clone.restore(snapshot)
 test.check(clone.snapshot()==snapshot,"full snapshots preserve role commitments and AI decision timers")
 var net=preload("res://match_network.gd").new();net.sim=s
 var packet:Dictionary=net.pack_state(snapshot)
 test.check(var_to_bytes(packet).size()<1200,"AI planning memory adds no per-tick network packet cost")
 net.free()
 check_styles()

func check_styles()->void:
 var ids:=["legend-messi","legend-haaland","s4-fc26-252371","s4-fc26-203376","legend-courtois"]
 var expected:=["持球组织者","强力终结者","全能接应者","强力屏障","门线门将"]
 var profiles:Array=[];var report:Array=[]
 for i in ids.size():
  var record:=Library.find(ids[i]);var style:=Style.derive(record);var ratings:=Ratings.for_player(record)
  profiles.append(ratings)
  test.check(style.name==expected[i],"catalog produces meaningful tendency for "+record.name)
  report.append({"id":record.id,"name":record.name,"role":record.role,"foot":record.preferredFoot,"style":style.name,"description":Style.description(style),"turn_ms":ratings.turn_time*1000,"dribble_spacing":ratings.stride,"sprint_touch":ratings.sprint_touch,"control_seconds":ratings.control,"acceleration":ratings.acceleration,"shield":ratings.shield})
 test.check(profiles[0].stride<profiles[1].stride and profiles[0].sprint_touch<profiles[1].sprint_touch and profiles[0].turn_time<profiles[1].turn_time,"Messi has tighter touches and quicker turns than the taller striker")
 test.check(profiles[1].shield>profiles[0].shield and profiles[3].tackle_reach>profiles[0].tackle_reach,"power forward shields better; specialist defender has superior tackle reach")
 var power_sim=fixture();power_sim.players[7].pos=Vector2(-2,0)
 test.check(power_sim.brain.jockey(power_sim,1),"power forward chooses body shielding against pressure from behind")
 power_sim.owner=2;power_sim.players[2].pos=Vector2.ZERO
 test.check(not power_sim.brain.jockey(power_sim,2),"technical creator does not inherit the power-forward shield preference")
 var bounded:=true;var counts:={}
 for record in Library.all():
  var style:=Style.derive(record);var ratings:=Ratings.for_player(record)
  counts[style.name]=int(counts.get(style.name,0))+1
  bounded=bounded and not style.name.is_empty() and ratings.turn_time>=Ratings.TURN_MIN and ratings.turn_time<=Ratings.TURN_MAX and ratings.stride>=0.70 and ratings.stride<1.6 and ratings.carry_acceleration<=1.0
 test.check(bounded,"all 386 players receive bounded control profiles and an explicit AI tendency")
 var s=fixture();s.owner=2;s.selected=2;s.players[2].pos=Vector2.ZERO;s.players[2].vel=Vector2.ZERO
 var net=preload("res://match_network.gd").new();net.sim=s
 net.prediction_index=2;net.prediction_pos=s.players[2].pos;net.prediction_vel=s.players[2].vel;net.prediction_dir=s.players[2].dir
 for frame in 24:
  s.move_player(2,1.0/60,Vector2.DOWN,false,false)
  net._predict({"move":Vector2.DOWN,"sprint":false,"jockey":false,"assist_active":false},1.0/60)
 test.check(net.prediction_pos.distance_to(s.players[2].pos)<0.001,"new carrying acceleration is identical on authority and predicted client")
 net.free()
 var rig=preload("res://skinned_player.gd").new();test.root.add_child(rig);rig.build_skeleton(s.players[2].body)
 var p:Dictionary=s.players[2];p.action="shoot";p.action_time=0.20;p.action_strength=0.5;p.vel=Vector2.ZERO
 p.preferred_foot="right";rig.animate_player(p,0,false,Vector3.ZERO)
 var right:Quaternion=rig.skeleton.get_bone_pose_rotation(rig.bone_ids["upperleg01.R"])
 p.preferred_foot="left";rig.animate_player(p,0,false,Vector3.ZERO)
 var left:Quaternion=rig.skeleton.get_bone_pose_rotation(rig.bone_ids["upperleg01.L"])
 test.check(left.angle_to(Quaternion(right.x,-right.y,-right.z,right.w))<0.001,"preferred left foot mirrors the actual strike animation onto the left leg")
 rig.free()
 var file:=FileAccess.open("res://artifacts/player-style-audit.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"examples":report,"catalog_style_counts":counts},"  "))
