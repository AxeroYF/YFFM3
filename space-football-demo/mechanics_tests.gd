extends SceneTree
const Match=preload("res://match_sim.gd")
const InputSource=preload("res://football_input.gd")
var checks:=0
var failures:=0
func check(value:bool,label:String)->void:
 checks+=1
 if not value: failures+=1;push_error("MECHANICS_FAILED: "+label)
func fixture():
 var s=Match.new();s.setup(preload("res://campaign.gd").new(),984,Match.Squad.DEFAULT,Match.Squad.DEFAULT,true)
 s.freeze=0;s.phase="play";s.teams[0].human=true;s.teams[1].human=true
 for i in 10:
  s.players[i].cooldown=0;s.players[i].pos=Vector2(-25+(i%5)*10,14 if i<5 else -14)
 s.selected=1;s.owner=1;s.players[1].pos=Vector2.ZERO;s.players[1].dir=Vector2.RIGHT;s.ball=Vector2(1,0)
 s.players[2].pos=Vector2(10,3)
 return s
func command(action:int,extra:Dictionary={})->Dictionary:
 var c={"action":action,"move":Vector2.RIGHT,"aim":0.3,"sprint":false,"jockey":false,"power":0.5,"assist":1}
 c.merge(extra,true);return c
func settle(s,seconds:float=0.12)->void:
 for i in ceili(seconds*60): s.mechanics.tick(s,1.0/60)
func _initialize()->void:
 await process_frame
 var s=fixture()
 s.apply_command(0,command(4));check(s.owner==1 and not s.mechanics.releases[0].is_empty(),"pass has bounded contact preparation")
 settle(s);check(s.owner==-1 and s.passes[0]==1,"one release sends exactly one pass")
 settle(s);check(s.passes[0]==1,"queued release cannot repeat")
 s=fixture();s.apply_command(0,command(4));s.apply_command(0,command(128));settle(s)
 check(s.owner==1 and s.passes[0]==0,"cancellation removes scheduled release")
 s=fixture();s.apply_command(0,command(4));s.owner=6;settle(s)
 check(s.passes[0]==0,"losing possession cancels release")
 s=fixture();s.charge=0.55;s.charging=true;s.apply_command(0,command(2));settle(s)
 check(not s.charging and is_equal_approx(s.players[1].action_strength,0.55),"shot strength latches on release rather than growing during windup")
 s=fixture();s.apply_command(0,command(s.Mechanics.CANCEL|4));settle(s)
 check(s.owner==1 and s.passes[0]==0,"explicit cancel wins over simultaneous queued pass")
 s=fixture();s.owner=-1;s.pass_receiver=1;s.last_touch=2;s.ball=Vector2(-3,0);s.velocity=Vector2(15,0)
 s.apply_command(0,command(4));check(not s.mechanics.buffered[0].is_empty(),"incoming teammate ball accepts pass buffer")
 s.owner=1;settle(s);check(s.passes[0]==1,"buffer passes after ownership arrives")
 s=fixture();s.owner=-1;s.pass_receiver=1;s.last_touch=2;s.ball=Vector2(-2,0);s.velocity=Vector2(12,0)
 s.apply_command(0,command(s.Mechanics.SHOT_BUFFER));s.owner=1;settle(s)
 check(s.shots[0]==1 and s.players[1].tackle_cd==0,"pre-shot becomes shot, never defensive tackle")
 s=fixture();s.owner=-1;s.pass_receiver=1;s.last_touch=2;s.ball=Vector2(-2,0);s.velocity=Vector2(12,0)
 s.apply_command(0,command(4));settle(s,0.5);s.owner=1;settle(s)
 check(s.passes[0]==0,"expired buffer cannot fire later")
 s=fixture();s.owner=-1;s.pass_receiver=6;s.last_touch=7;s.ball=Vector2(-2,0)
 s.apply_command(0,command(s.Mechanics.SHOT_BUFFER));check(s.mechanics.buffered[0].is_empty(),"no attacking preinput on opponent ball")
 s=fixture();s.players[2].pos=Vector2(0,-8);s.players[3].pos=Vector2(0,8)
 s.apply_command(0,command(s.Mechanics.SWITCH,{"direction":Vector2.DOWN}));check(s.selected==3,"direction switch obeys direction over distance to ball")
 s.players[2].active=false;s.selected=1
 check(s.mechanics.candidate(s,0,Vector2.UP)!=2,"switch excludes dismissed player")
 s=fixture();s.apply_command(0,command(s.Mechanics.RUN));s.brain.prepare(s);s.mechanics.plan(s)
 var runner:int=s.teams[0].request_player
 check(runner>=0 and s.brain.jobs[runner]=="run","run request overrides team plan for one teammate")
 s.apply_command(0,command(s.Mechanics.SUPPORT));s.mechanics.plan(s)
 check(s.brain.jobs[s.teams[0].request_player]=="support","support request seeks short outlet")
 s=fixture();s.owner=6;s.ball=s.players[6].pos;s.apply_command(0,command(0,{"contain":true}));s.brain.prepare(s);s.mechanics.plan(s)
 var helper:int=s.teams[0].contain_player
 check(helper>0 and helper!=s.selected and s.brain.pressers[0]==helper,"one helper presses without taking manual player")
 s.apply_command(0,command(0,{"contain":false}));s.mechanics.plan(s);check(s.teams[0].contain_player==-1,"releasing contain ends helper request")
 var speeds:Array=[]
 for power in [0.28,1.0]:
  s=fixture();s.apply_command(0,command(4,{"power":power}));settle(s);speeds.append(s.velocity.length())
 check(speeds[1]>speeds[0]*1.3,"pass power changes ground ball velocity")
 s=fixture();s.apply_command(0,command(256,{"driven":true}));settle(s)
 check(s.vertical_speed<0.5,"driven cross stays low")
 s=fixture();s.apply_command(0,command(256));settle(s)
 check(s.vertical_speed>3,"ordinary cross stays airborne")
 s=fixture();s.apply_command(0,command(s.Mechanics.SKILL,{"direction":Vector2.RIGHT,"sprint":true}))
 check(s.owner==-1 and s.pass_receiver==1 and s.velocity.x>8,"knock-on creates contestable free ball")
 s=fixture();s.apply_command(0,command(s.Mechanics.SKILL,{"direction":Vector2.DOWN}))
 check(s.owner==1 and s.players[1].dir.y>0.7,"drag changes body and ball direction")
 s=fixture();s.owner=-1;s.ball=Vector2(0.3,0);s.ball_height=s.players[1].body.head_height+0.45
 s.mechanics.jump(s,1,"shot",0,Vector2.RIGHT)
 check(s.players[1].jump_v>3 and s.players[1].jump_z>0,"aerial action starts physical jump")
 settle(s,0.25);check(s.shots[0]==1 and s.ball_height>2,"jump makes contact at actual elevated head position")
 settle(s,0.7);check(s.players[1].jump_z==0,"jumper returns to ground")
 s=fixture();s.owner=-1;s.ball=s.players[1].pos;s.ball_height=1.4
 s.mechanics.jump(s,1,"pass",0,Vector2.RIGHT);check(s.passes[0]==1 and s.shots[0]==0,"aerial pass is not counted as shot")
 s=fixture();s.players[1].attributes.firstTouch=20
 s.mechanics.after_receive(s,1,28,Vector2.RIGHT)
 check(s.owner==-1 and s.pass_receiver==1,"poor touch at speed creates recoverable loose ball")
 s=fixture();s.players[1].attributes.firstTouch=99
 s.mechanics.after_receive(s,1,10,Vector2.LEFT);check(s.owner==1,"good first touch retains control")
 s=fixture();s.players[1].fatigue=0.5;var before:float=s.players[1].fatigue
 s.players[1].vel=Vector2(9,0);settle(s,1);check(s.players[1].fatigue>before,"sustained running builds match fatigue")
 var old_id:String=s.players[1].player_id
 s.apply_command(0,command(s.Mechanics.SUBSTITUTE,{"reserve":1,"out":1}));check(s.players[1].player_id==old_id,"substitution waits for stoppage")
 s.Rules.restart(s,0,"kick_in",Vector2(0,18));settle(s)
 check(s.players[1].player_id!=old_id and s.players[1].sub_revision==1,"stoppage substitutes full player definition")
 check(s.players[1].fatigue==0 and s.players[1].role=="ST","substitute gets own abilities and fatigue")
 check(s.players[1].tackle_cd==0 and s.players[1].keeper_cd==0,"substitute does not inherit outgoing action cooldowns")
 s=fixture();s.Rules.restart(s,0,"corner",Vector2(32,18));check(preload("res://restart_impact_tests.gd").prepare(s),"corner ready")
 var taker:int=s.restart_taker;s.apply_command(0,command(s.Mechanics.SET_PIECE,{"direction":Vector2.LEFT}))
 check(s.restart_taker!=taker and s.owner==-1 and s.restart_flow.stage=="fetch","set piece taker can be changed")
 s.apply_command(0,command(s.Mechanics.SET_PIECE,{"direction":Vector2.RIGHT}))
 var previous:Vector2=s.players[4].pos;s.Rules.update(s,0.1)
 check(s.teams[0].corner_plan==1 and s.players[4].pos!=previous,"corner plan moves off-ball teammates")
 s=fixture();s.players[1].vel=Vector2(3,0);s.Rules.foul(s,6,1,false)
 check(s.phase=="play" and not s.mechanics.advantage.is_empty(),"advantage keeps promising attack alive")
 s.owner=6;settle(s);check(s.phase=="foul" and s.fouls[1]==1,"lost advantage recalled without double counting")
 s=fixture();s.Rules.foul(s,6,1,true);check(s.players[6].yellow==1,"dangerous slide foul cautioned")
 s.phase="play";s.owner=1;s.Rules.foul(s,6,1,true)
 check(not s.players[6].active and s.players[6].sinbin==120,"second caution dismisses player with reduction timer")
 s.phase="play";s.brain.reset();s.brain.prepare(s);s.mechanics.plan(s)
 check(s.brain.pressers[1]!=6 and s.brain.anchors[1]!=6,"reduced team reassigns active players")
 s.mechanics.requests[1]={"out":6,"reserve":1};s.mechanics.substitute(s,1)
 check(not s.players[6].active,"manual substitution cannot bypass red-card reduction")
 s.players[6].sinbin=0;s.phase="restart";settle(s)
 check(s.players[6].active and s.players[6].player_id not in s.mechanics.sent_off,"eligible replacement restores reduced slot")
 s=fixture();s.mechanics.discipline(s,0,true);s.mechanics.discipline(s,0,true)
 var count:=0
 for i in 5:
  if s.players[i].active: count+=1
 check(count==4 and s.players[0].active and s.players[0].player_id!="legend-courtois","GK dismissal brings reserve keeper for an outfielder")
 check(s.players[s.selected].active,"GK replacement also redirects control away from sacrificed outfielder")
 s.Rules.restart(s,1,"kickoff",Vector2.ZERO)
 check(s.players[s.teams[0].selected].active and s.players[1].pos.x< -32,"kickoff keeps red-card slot off pitch and selects active defender")
 s=fixture();s.mechanics.strict_rules=true;s.owner=-1;s.last_touch=2;s.mechanics.last_keeper_pass[0]=true
 s.players[0].pos=Vector2(-28,0);s.ball=Vector2(-27.7,0);s.ball_height=s.BallPhysics.FLOOR;s.velocity=Vector2(-8,0)
 s.resolve_player_contacts(Vector2(-26,0))
 check(s.restart_kind=="indirect" and s.restart_team==1,"keeper repeat backpass is enforced in enabled preset")
 s=fixture();s.teams[0].auto_switch=2;s.owner=-1;s.pass_receiver=-1;s.ball=s.players[2].pos;s.teams[0].move=Vector2.ZERO
 settle(s);check(s.selected==2,"high autoswitch can select nearby free-ball challenger")
 s=fixture();s.teams[0].auto_switch=0;s.owner=-1;s.pass_receiver=-1;s.ball=s.players[2].pos
 settle(s);check(s.selected==1,"manual autoswitch mode preserves selection")
 s=fixture();s.fouls[1]=5;s.Rules.foul(s,6,1,false)
 check(s.restart_kind=="accumulated","sixth foul creates no-wall accumulated kick")
 s=fixture();s.mechanics.strict_rules=true;s.owner=0;s.players[0].pos=Vector2(-28,0);s.ball=s.players[0].pos
 settle(s,4.1);check(s.phase=="restart" and s.restart_kind=="indirect" and s.restart_team==1,"keeper own-half four-second rule")
 var net=preload("res://match_network.gd").new();net.sim=s
 var extras:Dictionary=net.extra_command({"sprint":true,"direction":Vector2(3,4),"power":2.0})
 check(net.extra_command(extras).skill_sprint and extras.direction.length()<=1.0001 and extras.power==1.0,"reliable skill action carries sprint modifier and bounded direction/power")
 var wire:Dictionary=net.pack_state(s.snapshot());var decoded:Dictionary=net.unpack_state(wire)
 check(decoded.mechanics.strict_rules and decoded.players[0].active,"extra rules and player state roundtrip")
 check(var_to_bytes(wire).size()<1200,"new state stays within snapshot datagram budget")
 s=fixture();net.sim=s;s.players[2].jump_z=0.53;s.players[2].jump_v=2.1;s.players[2].yellow=1;s.teams[0].contain_player=4
 wire=net.pack_state(s.snapshot());decoded=net.unpack_state(wire)
 check(is_equal_approx(decoded.players[2].jump_z,0.53) and decoded.players[2].yellow==1 and decoded.teams[0].contain_player==4,"jump, cards and contain replicate")
 s.mechanics.requests[0]={"out":1,"reserve":1};s.mechanics.substitute(s,0)
 decoded=net.unpack_state(net.pack_state(s.snapshot()))
 check(decoded.players[1].player_id==s.players[1].player_id and decoded.players[1].attributes==s.players[1].attributes,"substitution identity and ratings replicate")
 net.free()
 input_checks()
 print("MECHANICS_TESTS_", "PASS" if failures==0 else "FAILED", " checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)

func input_checks()->void:
 for keyboard in [true,false]:
  var c=InputSource.new();c.gamepad=93;c.sync_context(1,1,1);c.team_attacking=true
  var e:InputEvent=InputEventKey.new() if keyboard else InputEventJoypadButton.new()
  if keyboard: e.physical_keycode=KEY_S
  else: e.device=93;e.button_index=JOY_BUTTON_A
  e.pressed=true;c.handle(e);check(c.command().action==0 and c.pass_held==4,"pass press starts charge")
  c.pass_started-=400;e.pressed=false;c.handle(e)
  var cmd:Dictionary=c.command();check(cmd.action==4 and cmd.power>0.7,"pass release carries charged power")
  c.reset();c.receiving=true;c.sync_context(1,-1,1)
  if keyboard: e.physical_keycode=KEY_D
  else: e.button_index=JOY_BUTTON_B
  e.pressed=true;c.handle(e);check(c.command().action==0 and c.pre_shot,"pre-shot press does not tackle")
  e.pressed=false;c.handle(e);check(c.command().action==Match.Mechanics.SHOT_BUFFER,"pre-shot release sends buffered intention")
  c.reset();c.receiving=true;c.sync_context(1,-1,1)
  e.pressed=true;c.handle(e);c.command();c.sync_context(1,1,1)
  check(c.command().action==1 and not c.pre_shot,"arrival while shot held converts receiving hold into normal shot charge")
  e.pressed=false;c.handle(e);check(c.command().action==2,"converted receiving hold releases one shot")
  c.reset();c.sync_context(1,1,1);c.team_attacking=true
  if keyboard: e.physical_keycode=KEY_Q
  else: e.button_index=JOY_BUTTON_LEFT_SHOULDER
  e.pressed=true;c.handle(e);e.pressed=false;c.handle(e)
  check(c.command().action==Match.Mechanics.RUN,"tap modifier requests run")
  c.reset();c.sync_context(1,1,1);c.team_attacking=true
  e.pressed=true;c.handle(e)
  if keyboard: e.physical_keycode=KEY_S
  else: e.button_index=JOY_BUTTON_A
  c.handle(e);e.pressed=false;c.handle(e)
  if keyboard: e.physical_keycode=KEY_Q
  else: e.button_index=JOY_BUTTON_LEFT_SHOULDER
  c.handle(e);var pass_cmd:Dictionary=c.command()
  check(pass_cmd.chip and pass_cmd.action==4 and c.command().action==0,"one-two survives both buttons released within one frame without requesting another run")
  c.reset();c.sync_context(1,1,1);c.team_attacking=true
  if keyboard: e.physical_keycode=KEY_Z
  else: e.button_index=JOY_BUTTON_RIGHT_SHOULDER
  e.pressed=true;c.handle(e)
  if keyboard: e.physical_keycode=KEY_S
  else: e.button_index=JOY_BUTTON_A
  c.handle(e);e.pressed=false;c.handle(e)
  if keyboard: e.physical_keycode=KEY_Z
  else: e.button_index=JOY_BUTTON_RIGHT_SHOULDER
  c.handle(e);pass_cmd=c.command()
  check(pass_cmd.driven and pass_cmd.action==4 and not c.command().driven,"driven pass modifier latches for exactly one release")
  c.reset();c.receiving=true;c.sync_context(1,-1,1);c.aerial_available=true
  if keyboard: e.physical_keycode=KEY_A
  else: e.button_index=JOY_BUTTON_X
  e.pressed=true;c.handle(e);e.pressed=false;c.handle(e)
  check(c.command().action==256,"high-ball cross button requests clearance, not sliding tackle")
