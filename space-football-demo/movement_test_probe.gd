extends RefCounted
const Team=preload("res://team_config.gd")
static func advance(network,command:Dictionary,dt:float)->void:
 var sim=network.sim
 # Isolated legacy movement probe for comparison tests; never loaded by runtime.
 if sim.phase!="play": return
 if network.prediction_index<0: return
 var p:Dictionary=sim.players[network.prediction_index]
 var speed:float=p.speed*(1-float(p.get("fatigue",0))*0.14)
 if not p.get("active",true): return
 if p.get("jump_z",0)>0: speed*=0.7
 if p.get("landing",0)>0 or p.get("balance",0)>0: speed*=0.65
 if p.get("release_wait",0)>0: speed*=0.55
 if p.action in sim.Motion.DEFENSIVE_ACTIONS and p.action_time>0:
  network.prediction_vel=network.prediction_vel.move_toward(sim.Motion.defensive_velocity(p.action,p.action_time,network.prediction_dir,speed,p.get("slide_speed",0)),dt*32)
  network.prediction_pos=(network.prediction_pos+network.prediction_vel*dt).clamp(-sim.player_limit(network.prediction_index),sim.player_limit(network.prediction_index))
  return
 if command.sprint and p.stamina>2: speed*=1.42
 if command.jockey: speed*=0.58
 if sim.owner==network.prediction_index: speed*=p.ratings.dribble_speed
 if p.action_time>0 and p.action=="tackle": speed*=0.32
 if p.action_time>0 and p.action=="receive": speed*=0.7
 if p.action in sim.Motion.DIVES and p.action_time>0: speed*=1.25 if p.action_time>0.28 else 0.25
 var move:Vector2=command.move
 var receiving_assist:int=int(command.get("receive_assist",sim.teams[network.prediction_index/Team.SIZE].receive_assist))
 if receiving_assist<0: receiving_assist=int(command.get("assist",sim.teams[network.prediction_index/Team.SIZE].assist))
 if p.action_time>0 and p.action=="slide":
  move=p.dir if p.action_time>0.3 else Vector2.ZERO
  speed=p.speed*1.15
 if bool(command.get("assist_active",true)):
  move=sim.assisted_movement(network.prediction_index,move,network.prediction_pos,receiving_assist,network.prediction_vel,int(command.sprint))
 if (network.prediction_index%Team.SIZE!=0 or sim.owner==network.prediction_index) and not command.jockey and p.action!="slide":
  speed*=sim.Motion.turn_scale(network.prediction_dir,move,p.ratings)
 network.prediction_vel=sim.Movement.velocity(network.prediction_vel,move,speed,p.ratings,sim.owner==network.prediction_index,dt,sim.surface_grip())
 network.prediction_pos=(network.prediction_pos+network.prediction_vel*dt).clamp(-sim.player_limit(network.prediction_index),sim.player_limit(network.prediction_index))
 var facing:Vector2=(sim.ball-network.prediction_pos).normalized() if (command.jockey or network.prediction_index%Team.SIZE==0) and sim.owner!=network.prediction_index else move.normalized()
 if bool(command.get("assist_active",true)):
  var reception:Vector2=sim.receiving_facing(network.prediction_index,command.move,network.prediction_pos,receiving_assist)
  if reception.length()>0.1: facing=reception
 if command.jockey and sim.owner==network.prediction_index and move.length()<0.15: facing=sim.shield_facing(network.prediction_index,network.prediction_pos)
 if p.action in sim.Motion.DIVES and p.action_time>0: facing=network.prediction_dir
 if facing.length()>0.1:
  var turn:float=sim.Movement.turn_rate(p.ratings,network.prediction_vel,command.jockey or network.prediction_index%Team.SIZE==0)
  network.prediction_dir=network.prediction_dir.rotated(clampf(network.prediction_dir.angle_to(facing),-dt*turn,dt*turn)).normalized()
