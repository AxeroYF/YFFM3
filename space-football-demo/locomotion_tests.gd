extends RefCounted
const Locomotion=preload("res://locomotion.gd")
const Rig=preload("res://skinned_player.gd")
func run(test)->void:
 var sim=test.fixture()
 var p:Dictionary=sim.players[1]
 sim.owner=-1
 p.pos=Vector2.ZERO;p.dir=Vector2.RIGHT
 for i in 60: sim.move_player(1,1.0/60,Vector2.RIGHT,false,false)
 var jog:float=p.vel.length()
 var old_speed:float=5.8+sim.Ratings.unit(p.attributes,"pace")*2.9
 test.check(is_equal_approx(jog,old_speed*0.78),"actual running top speed reduced by 22 percent")
 p.pos=Vector2.ZERO
 for i in 60: sim.move_player(1,1.0/60,Vector2.RIGHT,true,false)
 test.check(is_equal_approx(p.vel.length(),jog*1.42),"sprint remains distinct at the same reduced global pace")
 var network=preload("res://match_network.gd").new();network.sim=sim;network.prediction_index=1
 p.pos=Vector2.ZERO;p.vel=Vector2.ZERO;p.dir=Vector2.RIGHT
 network.prediction_pos=p.pos;network.prediction_vel=p.vel;network.prediction_dir=p.dir
 for i in 60:
  sim.move_player(1,1.0/60,Vector2.RIGHT,true,false)
  preload("res://movement_test_probe.gd").advance(network,{"move":Vector2.RIGHT,"sprint":true,"jockey":false,"assist_active":false},1.0/60)
 test.check(p.pos.distance_to(network.prediction_pos)<0.001,"client prediction matches authority at reduced pace")
 network.free()
 var rig:=Rig.new()
 test.root.add_child(rig)
 # Exercise the same real skeleton, without creating GPU mesh/material resources headlessly.
 rig.build_skeleton(p.body)
 var last_cadence:=0.0
 for speed in [1.5,4.0,6.5,9.5]:
  var profile:=Locomotion.profile(speed,p.body.leg_length)
  test.check(speed/profile.stride>last_cadence,"cadence increases from walking through sprinting: "+str(speed))
  last_cadence=speed/profile.stride
  var max_slip:=0.0;var max_height_error:=0.0
  for direction in [Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT]:
   for i in 60: rig.animate_player(p,1.0/60,false,direction*speed)
   for contact in [0.08,0.18,0.28,0.38]:
    rig.phase=contact*TAU
    rig.animate_player(p,0,false,direction*speed)
    rig.skeleton.force_update_all_bone_transforms()
    var foot_id:int=rig.bone_ids["foot.L"]
    var before:Vector3=rig.skeleton.get_bone_global_pose(foot_id).origin+rig.position
    var dt:=0.001
    rig.animate_player(p,dt,false,direction*speed)
    rig.skeleton.force_update_all_bone_transforms()
    var after:Vector3=rig.skeleton.get_bone_global_pose(foot_id).origin+rig.position+direction*speed*dt
    max_slip=maxf(max_slip,before.distance_to(after))
    max_height_error=maxf(max_height_error,absf(before.y-rig.leg_rest[".L"][2].y))
  test.check(max_slip<0.004 and max_height_error<0.06,"grounded sole follows actual displacement in forward/back/side movement: "+str([speed,max_slip,max_height_error]))
 # Animation uses the displayed displacement even if an old snapshot still says running.
 p.vel=Vector2(9,0)
 var before_phase:float=rig.phase
 for i in 60: rig.animate_player(p,1.0/60,false,Vector3.ZERO)
 test.check(is_equal_approx(rig.phase,before_phase) and rig.gait<0.001,"stopped visible player does not run on stale simulation velocity")
 check_arms(test,rig,p)
 rig.free()

func check_arms(test,rig,p:Dictionary)->void:
 var previous_span:=0.0
 for speed in [1.8,6.5,9.5]:
  for frame in 90: rig.animate_player(p,1.0/60,false,Vector3.BACK*speed)
  var contra:=true;var min_wrist:=INF;var max_wrist:=-INF
  var min_elbow:=INF;var max_elbow:=-INF;var clearance:=true
  for sample in 48:
   rig.phase=TAU*sample/48.0
   rig.animate_player(p,0,false,Vector3.BACK*speed)
   rig.skeleton.force_update_all_bone_transforms()
   var points:Dictionary={}
   for side in [".L",".R"]:
    for bone in ["foot","wrist","lowerarm01","upperarm01"]:
     points[bone+side]=rig.skeleton.get_bone_global_pose(rig.bone_ids[bone+side]).origin
   var feet:float=points["foot.L"].z-points["foot.R"].z
   var hands:float=points["wrist.L"].z-points["wrist.R"].z
   if absf(feet)>0.1: contra=contra and feet*hands<0
   min_wrist=minf(min_wrist,points["wrist.L"].z);max_wrist=maxf(max_wrist,points["wrist.L"].z)
   var elbow:float=(points["lowerarm01.L"]-points["upperarm01.L"]).angle_to(points["wrist.L"]-points["lowerarm01.L"])
   min_elbow=minf(min_elbow,elbow);max_elbow=maxf(max_elbow,elbow)
   clearance=clearance and points["wrist.L"].x>rig.body.shoulder*0.35 and points["wrist.R"].x<-rig.body.shoulder*0.35
  test.check(contra,"actual wrists swing opposite same-side feet across full cycle at speed "+str(speed))
  test.check(max_wrist-min_wrist>previous_span+0.03,"walking, running and sprinting have progressively larger actual arm travel")
  test.check(max_elbow-min_elbow>0.08 and clearance,"elbows flex dynamically and hands stay outside torso at speed "+str(speed))
  previous_span=max_wrist-min_wrist
 rig.is_keeper=true;p.action="rush";p.action_time=0.5
 rig.phase=0;rig.animate_player(p,0,false,Vector3.BACK*7)
 var left:Quaternion=rig.skeleton.get_bone_pose_rotation(rig.bone_ids["upperarm01.L"])
 rig.phase=PI;rig.animate_player(p,0,false,Vector3.BACK*7)
 test.check(left.angle_to(rig.skeleton.get_bone_pose_rotation(rig.bone_ids["upperarm01.L"]))>0.5,"rushing keeper retains coordinated running arms instead of fixed ready pose")
 p.action="idle";p.action_time=0;p.keeper_holding=false
 rig.phase=0;rig.animate_player(p,0,true,Vector3.BACK*7)
 left=rig.skeleton.get_bone_pose_rotation(rig.bone_ids["upperarm01.L"])
 rig.phase=PI;rig.animate_player(p,0,true,Vector3.BACK*7)
 test.check(left.angle_to(rig.skeleton.get_bone_pose_rotation(rig.bone_ids["upperarm01.L"]))>0.5,"keeper dribbling at feet retains coordinated arms instead of hugging a ball")
 p.action="catch";p.action_time=0.5;p.keeper_holding=true;rig.animate_player(p,0,true,Vector3.BACK*7)
 var held:Quaternion=rig.skeleton.get_bone_pose_rotation(rig.bone_ids["upperarm01.L"])
 rig.phase=0;rig.animate_player(p,0,true,Vector3.BACK*7)
 test.check(held.angle_to(rig.skeleton.get_bone_pose_rotation(rig.bone_ids["upperarm01.L"]))<0.01,"keeper holding the ball overrides free arm swing")
 rig.is_keeper=false;p.action="idle";p.action_time=0
 for frame in 90: rig.animate_player(p,1.0/60,false,Vector3.ZERO)
 rig.skeleton.force_update_all_bone_transforms()
 var wrist:Vector3=rig.skeleton.get_bone_global_pose(rig.bone_ids["wrist.L"]).origin
 test.check(wrist.y<rig.body.height*0.55,"arms settle beside hips after stopping")
