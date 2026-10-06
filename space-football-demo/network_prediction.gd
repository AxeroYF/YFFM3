extends RefCounted
## Disposable presentation simulation. Its scores, possession changes and rule
## events are never copied back to authority or used to submit match results.
const Match=preload("res://match_sim.gd")
const Command=preload("res://network_command.gd")
const PREVIEW_ACTIONS=preload("res://match_actions.gd").PREVIEW
var sim
var team:=0
var ball_visible:=false
var preview_kicker:=-1
var horizon:=0.0

func reset(state:Dictionary,side:int)->void:
 if sim==null: sim=Match.new()
 sim.restore(state);sim.view_team=side;team=side
 preview_kicker=int(state.last_touch)
 ball_visible=false
 horizon=0

func step(c:Dictionary,dt:float)->void:
 if sim==null or sim.phase!="play" or sim.freeze>0 or sim.finished: ball_visible=false;return
 var command:=c.duplicate(true)
 if not Command.matches(sim,team,c): command=Command.neutral()
 command.action=int(command.get("action",0))&PREVIEW_ACTIONS
 var old_owner:int=sim.owner
 sim.apply_command(team,command)
 # Run existing release/charge/airborne timers against the private clone.
 # Never resolve player contacts or award goals in this preview.
 sim.mechanics.tick(sim,dt,true)
 horizon+=dt
 sim.frame+=1;sim.elapsed+=dt
 if old_owner>=0 and old_owner/6==team and sim.owner<0:
  preview_kicker=old_owner
 var t:Dictionary=sim.teams[team]
 if t.charging:
  t.charge=minf(1,t.charge+dt*0.9)
  sim.players[t.selected].action="windup";sim.players[t.selected].action_strength=t.charge;sim.players[t.selected].action_time=0.15
 for p in sim.players:
  p.cooldown=maxf(0,p.cooldown-dt);p.action_time=maxf(0,p.action_time-dt)
  p.tackle_cd=maxf(0,p.tackle_cd-dt);p.keeper_cd=maxf(0,p.keeper_cd-dt)
 var index:int=t.selected;var p:Dictionary=sim.players[index]
 p.touch+=dt*p.vel.length()
 var movement:Vector2=sim.assisted_movement(index,t.move,p.pos)
 sim.move_player(index,dt,movement,t.sprint,t.jockey)
 ball_visible=false
 if sim.owner>=0 and sim.owner/6==team:
  sim.advance_owned_ball(dt)
  ball_visible=true
 elif sim.owner<0 and preview_kicker>=0 and preview_kicker/6==team and horizon<=0.25:
  var flight:Dictionary=sim.advance_ball(sim.ball,sim.velocity,sim.ball_height,sim.vertical_speed,sim.ball_spin,sim.ball_is_shot,dt)
  sim.ball=flight.pos;sim.velocity=flight.velocity;sim.ball_height=flight.height;sim.vertical_speed=flight.vertical;sim.ball_spin=flight.spin
  ball_visible=true
 # Handover before contested touches, walls, posts or the scoring plane.
 if ball_visible:
  if absf(sim.ball.x)>sim.Pitch.HALF_LENGTH-1 or absf(sim.ball.y)>sim.Pitch.HALF_WIDTH-0.7: ball_visible=false
  for rival in range((1-team)*6,(1-team)*6+6):
   if sim.players[rival].active and sim.players[rival].pos.distance_to(sim.ball)<sim.players[rival].body.foot_reach+0.45: ball_visible=false

func index()->int:
 return int(sim.teams[team].selected) if sim!=null else -1

func ball()->Vector3:
 return Vector3(sim.ball.x,sim.ball_height,sim.ball.y)
