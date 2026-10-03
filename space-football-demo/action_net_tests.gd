extends SceneTree
const Match=preload("res://match_sim.gd")
const Pitch=preload("res://pitch_geometry.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures+=1;push_error("ACTION_NET_FAILED "+label)
func fixture():
 var s=Match.new();s.setup(preload("res://campaign.gd").new(),719,Match.Squad.DEFAULT,Match.Squad.DEFAULT,true)
 s.freeze=0;s.pickup_lock=0;s.owner=-1;s.duration=1000;s.kick_age=0.6
 for t in s.teams: t.human=false
 return s
func edge_tests()->void:
 var points:Array=[]
 for x in [-1.0,1.0]:
  for y in [-1.0,1.0]: points.append(Vector2(x*(Pitch.HALF_LENGTH-0.03),y*(Pitch.HALF_WIDTH-0.03)))
 for y in [-1.0,1.0]: points.append(Vector2(0,y*(Pitch.HALF_WIDTH-0.03)))
 for x in [-1.0,1.0]: points.append(Vector2(x*(Pitch.HALF_LENGTH-0.03),10))
 for point in points:
  var s=fixture();s.ice_mode=true;s.ball=point;s.velocity=Vector2.ZERO
  var received:=false
  for tick in 900:
   s.step(1.0/60)
   if s.owner>=0: received=true;break
  check(received,"AI actually reaches stationary wall/corner ball "+str(point))
 for team in 2:
  for wall in [-1.0,1.0]:
   var s=fixture();s.ice_mode=true;var carrier:int=team*5+2
   s.owner=carrier;s.teams[team].human=true;s.teams[team].selected=carrier
   s.players[carrier].pos=Vector2(0,wall*(Pitch.HALF_WIDTH-0.9));s.ball=s.players[carrier].pos
   var nearest:=INF
   for tick in 450:
    s.step(1.0/60)
    for i in range((1-team)*5+1,(1-team)*5+5): nearest=minf(nearest,s.players[i].pos.distance_to(s.players[carrier].pos))
    if s.owner!=carrier: break
   check(nearest<2.3 or s.owner!=carrier,"AI presses possession on both touchlines team "+str(team))
   s=fixture();s.ice_mode=true;s.owner=carrier;s.teams[team].human=true;s.teams[team].selected=carrier
   s.players[carrier].pos=Vector2(-12*s.side(team),wall*(Pitch.HALF_WIDTH-0.9));s.players[carrier].dir=Vector2(s.side(team),0)
   s.ball=s.players[carrier].pos+Vector2(s.side(team),0);s.teams[team].move=Vector2(s.side(team)*0.55,0)
   nearest=INF
   for tick in 400:
    s.step(1.0/60)
    for i in range((1-team)*5+1,(1-team)*5+5): nearest=minf(nearest,s.players[i].pos.distance_to(s.players[carrier].pos))
    if s.owner!=carrier: break
   check(nearest<2.3,"AI closes down moving touchline dribbler team "+str(team))
func net_tests()->void:
 for side in [-1.0,1.0]:
  for mode in [false,true]:
   var s=fixture();s.ice_mode=mode
   for p in s.players: p.active=false
   s.ball=Vector2(side*(Pitch.HALF_LENGTH+0.15),0);s.ball_height=1.3;s.velocity=Vector2(side*32,0)
   s.resolve_boundary();check(s.phase=="play" and s.score==[0,0],"partial ball crossing does not score")
   s.ball.x=side*(Pitch.HALF_LENGTH+0.35);s.resolve_boundary()
   check(s.phase=="goal" and s.velocity.length()>31,"whole ball scores with shooting momentum")
   var clock:float=s.elapsed
   s.step(0.04);check(s.ball.x*side>Pitch.HALF_LENGTH+1.0,"scored ball visibly travels into goal")
   s.step(0.10);check(s.goal_net.serial>0 and s.velocity.x*side<0,"back net catches and rebounds ball")
   check(s.goal_net.strength>0.4 and s.goal_net.point.x*side>Pitch.HALF_LENGTH+2.9,"net stores visible impact contact")
   var net=preload("res://match_network.gd").new();net.sim=s
   var state:Dictionary=net.unpack_state(net.pack_state(s.snapshot()))
   check(state.goal_net.serial==s.goal_net.serial and state.goal_net.point.distance_to(s.goal_net.point)<0.001,"network preserves net impact")
   net.free()
   s.step(0.8);check(s.elapsed==clock and s.score[0]+s.score[1]==1 and s.ball_height>=s.BallPhysics.FLOOR,"goal physics does not advance clock or rescore")
   s.step(1.0);check(s.velocity.length()<8 and s.ball_height<0.8,"ball loses energy and drops inside net")
 for side in [-1.0,1.0]:
  var side_hit:Dictionary=Match.GoalNet.advance(Vector2(side*(Pitch.HALF_LENGTH+1.0),4.7),Vector2(side*10,15),1.0,0,0,0 if side>0 else 1,0.02)
  check(side_hit.force>0 and side_hit.velocity.y<0,"side net reflects angled shots")
  var roof:Dictionary=Match.GoalNet.advance(Vector2(side*(Pitch.HALF_LENGTH+1.5),0),Vector2(side*5,0),3.25,5,0,0 if side>0 else 1,0.02)
  check(roof.force>0 and roof.vertical<0,"roof net catches rising shots")
func action_tests()->void:
 var s=fixture();s.owner=1;s.selected=1;s.players[1].pos=Vector2.ZERO;s.ball=Vector2(0.7,0.2);s.charge=0.5
 var start:Vector2=s.ball;s.shoot(0.5)
 check(s.ball.distance_to(start)<0.001,"shot starts at actual controlled ball")
 check(s.players[1].action_dir.dot(s.velocity.normalized())>0.99,"shot animation follows kick direction")
 check(s.impact_kind==1,"medium charged shot has restrained contact impact")
 s=fixture();s.owner=1;s.selected=1;s.pass_ball(false,Vector2.RIGHT,false,false,0.6,true)
 check(s.players[1].action=="driven_pass","driven pass triggers distinct animation in simulation")
 for zone in ["foot","chest","head"]:
  s=fixture()
  for p in s.players: p.active=false
  var p:Dictionary=s.players[1];p.active=true;p.cooldown=0;p.pos=Vector2.ZERO
  var h:float=0.4 if zone=="foot" else p.body.chest_height if zone=="chest" else p.body.head_height
  s.ball_height=h;s.ball=Vector2(0.4,0);s.velocity=Vector2(-28,0);s.ball_is_shot=true
  s.resolve_player_contacts(Vector2(2,0),h)
  check(p.action=={"foot":"block","chest":"block_chest","head":"block_head"}[zone],"physical contact dispatches "+zone+" reaction")
 var net=preload("res://match_network.gd").new();net.sim=s
 for name in ["driven_pass","block_chest","block_head","volley","receive"]:
  s.players[1].action=name;s.players[1].action_dir=Vector2(0.6,0.8);s.players[1].contact_height=1.4
  var state:Dictionary=net.unpack_state(net.pack_state(s.snapshot()))
  check(state.players[1].action==name and state.players[1].action_dir.distance_to(Vector2(0.6,0.8))<0.001 and absf(state.players[1].contact_height-1.4)<0.001,"wire keeps action, direction and touch height "+name)
 net.free()
 var rig=preload("res://skinned_player.gd").new();root.add_child(rig);rig.build_skeleton(s.players[1].body)
 var p:Dictionary=s.players[1];p.vel=Vector2.ZERO;p.dir=Vector2.DOWN;p.preferred_foot="right"
 var distinct:Array=[]
 for action in ["pass","driven_pass","receive","block","block_chest","block_head","shoot","volley"]:
  p.action=action;p.action_strength=0.6;p.action_time=Match.Motion.action_duration(p)*0.7
  rig.animate_player(p,0.016,false,Vector3.ZERO)
  var signature:Array=[]
  for bone in rig.ACTION_BONES:
   var rotation:Quaternion=rig.skeleton.get_bone_pose_rotation(rig.bone_ids[bone])
   check(rotation.is_finite() and rotation.is_normalized(),"valid continuous skeleton "+action+" "+bone)
   signature.append(rotation)
  check(signature not in distinct,"specific action has distinct full-body pose "+action);distinct.append(signature)
 p.action="pass";p.action_time=0.25
 rig.animate_player(p,0.016,false,Vector3.ZERO)
 var right:Quaternion=rig.skeleton.get_bone_pose_rotation(rig.bone_ids["upperleg01.R"])
 p.preferred_foot="left";rig.animate_player(p,0.016,false,Vector3.ZERO)
 var left:Quaternion=rig.skeleton.get_bone_pose_rotation(rig.bone_ids["upperleg01.L"])
 check(left.angle_to(Quaternion(right.x,-right.y,-right.z,right.w))<0.001,"preferred foot mirrors striking/support legs")
 rig.free()
func _initialize()->void:
 await process_frame
 edge_tests();net_tests();action_tests()
 print("ACTION_NET_TESTS_","PASS" if failures==0 else "FAILED"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
