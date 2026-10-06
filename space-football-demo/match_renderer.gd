extends RefCounted
## Draws a match from session state. No menus, save data or lifecycle access.
const Team=preload("res://team_config.gd")
const Match=preload("res://match_sim.gd")
const Pitch=preload("res://pitch_geometry.gd")
func render(stadium,session,controls,router,replay,dt:float)->void:
 var sim=session.sim
 var network=session.network
 var online:bool=session.online
 var predicted:bool=online and not stadium.multiplayer.is_server() and network.prediction_ready
 var view=network.input_state() if online else sim
 var selected:int=view.selected
 stadium.indicator.visible=sim.players[selected].active and sim.phase!="goal"
 for i in Match.PLAYER_COUNT:
  var p: Dictionary=network.render_player(i) if predicted else sim.players[i]
  stadium.selected_labels[i].visible=sim.phase!="goal"
  if replay.showing_replay(sim): continue
  stadium.actors[i].visible=p.get("active",true)
  if not stadium.actors[i].visible: continue
  stadium.sync_actor(sim.players[i],i)
  var target:Vector2=p.pos
  var target3:=Vector3(target.x,p.get("jump_z",0),target.y)
  var previous_position:Vector3=stadium.actors[i].position
  var teleported:bool=previous_position.distance_to(target3)>=7
  stadium.actors[i].position=previous_position.lerp(target3,1.0-exp(-dt*22)) if dt>0 and not teleported and not predicted else target3
  var facing:Vector2=p.dir
  if p.action_time>0 and p.action in Match.Motion.KICKS:
   var weight:float=smoothstep(0,0.20,float(p.action_time)/Match.Motion.action_duration(p))
   facing=facing.slerp(p.action_dir,weight)
  stadium.actors[i].rotation.y=lerp_angle(stadium.actors[i].rotation.y,atan2(facing.x,facing.y),1-exp(-dt*28)) if dt>0 and not teleported else atan2(facing.x,facing.y)
  # Follow visible ground travel, including prediction/interpolation, not stale snapshot velocity.
  var visible_velocity:Vector3=(stadium.actors[i].position-previous_position)/dt if dt>0 and not teleported else Vector3.ZERO
  var animation_state:Dictionary=p
  if p.action in ["retrieve_ball","carry_ball","place_ball"]:
   animation_state=p.duplicate()
   var rendered_ball:Vector3=stadium.football.position.lerp(Vector3(sim.ball.x,sim.ball_height,sim.ball.y),minf(1,dt*25))
   animation_state.hand_ball=stadium.actors[i].transform.affine_inverse()*rendered_ball
  stadium.rigs[i].animate_player(animation_state,dt if sim.freeze<=0 else 0,sim.owner==i,stadium.actors[i].basis.inverse()*visible_velocity)
  var next:int=sim.mechanics.candidate(sim,sim.view_team) if i/Team.SIZE==sim.view_team and sim.owner!=selected else -1
  stadium.selected_labels[i].text=(p.name if i==selected else ("▽ " if i==next else "")+Match.JERSEY_NUMBERS[i])+(" [黄]" if p.get("yellow",0)>0 else "")
  if i==sim.teams[sim.view_team].contain_player: stadium.selected_labels[i].text+=" 协防"
  if i==sim.teams[sim.view_team].request_player: stadium.selected_labels[i].text+=" 跑位"
  stadium.selected_labels[i].position.y=p.body.height+(2.4 if i==selected else 0.35)
 var bp: Vector2=sim.ball
 var ball_target:=Vector3(bp.x,sim.ball_height,bp.y)
 if predicted: ball_target=network.render_ball()
 if not replay.showing_replay(sim):
  # Short visual blend also softens the bounded ball-preview handover.
  stadium.football.position=stadium.football.position.lerp(ball_target,minf(1,dt*(35 if predicted else 25))) if sim.phase!="goal" and dt>0 and stadium.football.position.distance_to(ball_target)<6 else ball_target
  stadium.football.rotate_z(dt*(sim.velocity.length() if sim.owner<0 else 7))
 for net in stadium.goal_nets: net.show_state(sim.goal_net)
 stadium.ball_shadow.position=Vector3(stadium.football.position.x,0.09,stadium.football.position.z)
 stadium.ball_shadow.visible=sim.owner<0 and sim.ball_height>1.0 and sim.phase=="play"
 stadium.indicator.position=stadium.actors[selected].position+Vector3(0,sim.players[selected].body.height+1.15,0)
 update_pass_arrow(stadium,session,controls,router)
 stadium.indicator.scale=Vector3.ONE*clampf(stadium.camera.global_position.distance_to(stadium.indicator.global_position)/65.0,0.8,1.25)
 stadium.aim_marker.visible=view.charging and sim.owner==selected
 if stadium.aim_marker.visible:
  stadium.aim_marker.position.x=Pitch.HALF_LENGTH*sim.side(sim.view_team)
  stadium.aim_marker.position.z=controls.last_aim*4.35
  stadium.aim_marker.scale=Vector3.ONE*(0.7+view.charge*0.4)
 stadium.trail_points.push_front(stadium.football.position)
 if stadium.trail_points.size()>30: stadium.trail_points.pop_back()
 for i in stadium.trail.size():
  stadium.trail[i].visible=sim.phase!="goal" and sim.owner<0 and stadium.trail_points.size()>i*2 and sim.velocity.length()>6
  if stadium.trail[i].visible: stadium.trail[i].position=stadium.trail_points[i*2]
func update_pass_arrow(stadium,session,controls,router)->void:
 var sim=session.sim
 var network=session.network
 var online:bool=session.online
 var screen:String=session.screen
 stadium.pass_arrow.visible=false
 if screen!="match" or not router.pass_indicator or sim==null or sim.finished: return
 if sim.phase in ["goal","foul"]: return
 if sim.phase=="restart" and not sim.Rules.Flow.ready(sim): return
 var view=network.input_state() if online else sim
 var index:int=view.selected
 var direction:=Vector2.ZERO
 if view.owner==index and not view.charging:
  direction=view.pass_plan(index,controls.movement(),false,router.assistance).direction
 elif view.owner<0 and not view.ball_is_shot and view.last_touch/Team.SIZE==view.view_team and view.kick_age<0.3:
  index=view.last_touch
  direction=view.velocity.normalized()
 if direction.length()<0.1: return
 stadium.pass_arrow.position=stadium.actors[index].position*Vector3(1,0,1)+Vector3(0,0.14,0)
 stadium.pass_arrow.rotation.y=-atan2(direction.y,direction.x)
 stadium.pass_arrow.visible=true
