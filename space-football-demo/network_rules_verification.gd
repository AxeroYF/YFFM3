extends RefCounted
const Pitch=preload("res://pitch_geometry.gd")
## Explicit --rules-test only: stage repeatable stoppages over real ENet peers.
var seen:Dictionary={}
func near_restart(s,team:int,kind:String,spot:Vector2)->void:
 # Test fixture starts near the restart so every real preparation stage fits in
 # the ENet integration window. Production Flow still owns all subsequent motion.
 s.ball=spot;s.ball_height=s.BallPhysics.FLOOR;s.velocity=Vector2.ZERO
 s.Rules.restart(s,team,kind,spot)
 s.ball=s.restart_spot
 for i in 10: s.players[i].pos=s.restart_flow.targets[i];s.players[i].vel=Vector2.ZERO
 s.players[s.restart_taker].pos=s.ball-s.Rules.Flow.facing(s)*0.60
 s.players[s.restart_taker].dir=s.Rules.Flow.facing(s)
func step(network)->void:
 var s=network.sim
 match s.frame:
  30: near_restart(s,0,"kick_in",Vector2(5,18))
  180: near_restart(s,1,"corner",Vector2(-32,18))
  330:
   network.mechanics_test.stage(s,1);s.restart_touch=-1;s.restart_origin=""
   s.players[1].pos=Vector2(-2,0);s.players[2].pos=Vector2(8,-5)
   s.players[1].dir=Vector2.RIGHT;s.ball=Vector2(-1,0);s.players[1].cooldown=0
  375:
   s.phase="play";s.restart_touch=-1;s.owner=1;s.teams[0].selected=1
   var old:int=s.view_team;s.view_team=0;s.charge=0.9;s.shoot();s.view_team=old
  390:
   s.phase="play";s.players[1].pos=Vector2(12,1)
   s.Rules.foul(s,6,1,true)
  490: near_restart(s,1,"penalty",Vector2(-24,0))
  660:
   s.phase="play";s.last_touch=1;s.owner=-1;s.ball=Vector2(Pitch.HALF_LENGTH-0.5,1)
   s.velocity=Vector2(32,0);s.ball_height=1.3;s.vertical_speed=1;s.pickup_lock=1;s.restart_touch=-1
  1000:
   s.phase="play";s.freeze=0;s.owner=-1;s.ball=Vector2(Pitch.HALF_LENGTH-1,5)
   s.velocity=Vector2(60,0);s.ball_height=0.5;s.vertical_speed=0;s.pickup_lock=1
  1040:
   s.ball=Vector2(Pitch.HALF_LENGTH,Pitch.HALF_WIDTH+1)
   s.Rules.restart(s,0,"kick_in",s.ball)
  1180: s.duration=s.elapsed+0.5;s.overtime=false

func observe(s)->void:
 if s.ice_mode: seen.ice_mode=true
 if s.phase=="restart" and s.restart_flow.get("skipped",false): seen.hold_skip=true
 if s.event_kind=="post": seen.post=true
 for team in s.teams:
  if team.keeper_rush: seen.keeper_rush=true
  if team.run_player>=0 and team.run_time>0: seen.one_two=true
 if s.phase=="restart": seen[s.restart_kind]=true
 if s.phase=="restart" and not s.restart_flow.is_empty(): seen["flow_"+s.restart_flow.stage]=true
 if s.impact_id>0: seen.impact=true
 if s.phase=="goal" and s.goal_net.serial>0: seen.net_impact=true
 if s.phase in ["foul","goal"]: seen[s.phase]=true
 if s.phase=="goal" and s.players.all(func(p):return p.action=="idle") and s.phase_time>3.0: seen.goal_presentation=true
 for p in s.players:
  if p.action_time>0 and p.action in ["cross","chip","fall"]: seen[p.action]=true

func verify()->void:
 for key in ["kick_in","corner","free_kick","penalty","foul","goal","kickoff","cross","chip","fall","goal_presentation","net_impact","keeper_rush","one_two","post","flow_fetch","flow_lift","flow_carry","flow_place","impact","hold_skip"]:
  if not seen.has(key): push_error("NETWORK_RULES_MISSING "+key)
 if "--ice-mode" in OS.get_cmdline_user_args() and not seen.has("ice_mode"): push_error("NETWORK_RULES_MISSING ice_mode")
 print("NETWORK_RULES_OBSERVED ",seen.keys())
