extends RefCounted
const Team=preload("res://team_config.gd")
var seen:Dictionary={}
var sent:Dictionary={}
func stage(s,owner:int)->void:
 s.mechanics.reset(s);s.phase="play";s.freeze=0;s.owner=owner;s.teams[owner/Team.SIZE].selected=owner
 for i in Team.COUNT:
  s.players[i].pos=Vector2(-25+(i%Team.SIZE)*10,13 if i<Team.SIZE else -13);s.players[i].vel=Vector2.ZERO;s.players[i].cooldown=0
  s.players[i].tackle_cd=0;s.players[i].tackle_resolved=false;s.players[i].action="idle";s.players[i].action_time=0
 s.players[owner].pos=Vector2.ZERO;s.ball=Vector2(0.8,0);s.velocity=Vector2.ZERO;s.pickup_lock=0
 s.ball_height=s.BallPhysics.FLOOR;s.vertical_speed=0;s.ball_is_shot=false;s.pass_receiver=-1
func duel(s,moving:bool=false)->void:
 stage(s,6);s.teams[0].selected=1
 s.players[7].pos=Vector2(1.8,0);s.players[7].dir=Vector2.LEFT
 s.players[1].pos=Vector2(-1,0) if moving else Vector2.ZERO;s.players[1].dir=Vector2.RIGHT
 s.players[1].vel=Vector2(8,0) if moving else Vector2.ZERO;s.ball=Vector2(0.9,0)
func step(network)->void:
 var s=network.sim
 match s.frame:
  15: stage(s,1)
  70: stage(s,6)
  110:
   stage(s,1);s.owner=-1;s.ball=Vector2(0.3,0);s.ball_height=s.players[1].body.head_height+0.8;s.vertical_speed=3.8;s.last_touch=2;s.pass_receiver=1
  170: s.Rules.restart(s,0,"kick_in",Vector2(0,18));s.freeze=0
  230: s.mechanics.strict_rules=true
  260:
   stage(s,1);s.mechanics.discipline(s,7,true);s.mechanics.discipline(s,7,true)
  290:
   s.players[7].sinbin=0;s.Rules.restart(s,0,"kick_in",Vector2(0,18))
  340: duel(s)
  390: duel(s,true)
  440: duel(s)
  490:
   stage(s,1);s.owner=-1;s.players[1].pos=Vector2(0,3);s.players[1].dir=Vector2.RIGHT
   s.ball=Vector2(-8,0);s.velocity=Vector2(14,0);s.last_touch=2;s.pass_receiver=1;s.kick_age=0.1
   s.teams[0].assist_active=true;s.teams[0].receive_assist=2
  620:
   stage(s,1);s.score=[1,0];s.duration=s.elapsed+0.4
func bot(s,team:int)->Dictionary:
 var c:Dictionary={"move":Vector2.ZERO,"sprint":false,"jockey":false,"action":0,"aim":0.2,"tactic":1,"assist":1,"assist_active":false}
 if team!=0: return c
 if s.frame>=18 and s.frame<60 and not sent.has("run"):
  sent.run=true;c.action=s.Mechanics.RUN;c.move=Vector2.RIGHT
 elif s.frame>=73 and s.frame<105: c.contain=true
 elif s.frame>=112 and s.frame<155 and not sent.has("jump"):
  sent.jump=true;c.action=1024
 elif s.frame>=172 and s.frame<220 and not sent.has("sub"):
  sent.sub=true;c.action=s.Mechanics.SUBSTITUTE;c.reserve=1;c.out=1
 elif s.frame>=343 and s.frame<380 and not sent.has("tackle"):
  sent.tackle=true;c.action=32
 elif s.frame>=393 and s.frame<425 and not sent.has("slide"):
  sent.slide=true;c.action=512
 elif s.frame>=443 and s.frame<480 and not sent.has("slide_still"):
  sent.slide_still=true;c.action=512
 elif s.frame>=490 and s.frame<590:
  c.move=Vector2.RIGHT;c.assist=0;c.receive_assist=2;c.assist_active=true
 return c
func observe(s)->void:
 if s.teams[0].request_player>=0: seen.run=true
 if s.teams[0].contain_player>=0: seen.contain=true
 if s.players[1].jump_z>0.1: seen.jump=true
 if s.players[1].sub_revision>0: seen.substitution=true
 if s.mechanics.strict_rules: seen.keeper_rules=true
 if not s.players[7].active: seen.red=true
 if s.players[7].sub_revision>0: seen.replacement=true
 if s.players[1].action=="tackle" and s.frame>=340: seen.standing_tackle=true
 if s.players[1].action=="slide" and s.players[1].slide_speed>1.2 and s.frame>=390: seen.moving_slide=true
 if s.players[1].action=="slide_still" and s.frame>=440: seen.stationary_slide=true
 if s.owner==1 and s.frame>490 and s.frame<590: seen.moving_receive=true
func verify()->void:
 for key in ["run","contain","jump","substitution","keeper_rules","red","replacement","standing_tackle","moving_slide","stationary_slide","moving_receive"]:
  if not seen.has(key): push_error("NETWORK_MECHANICS_MISSING "+key)
 print("NETWORK_MECHANICS_OBSERVED ",seen.keys())
