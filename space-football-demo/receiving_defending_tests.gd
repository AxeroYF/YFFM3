extends SceneTree
const Team=preload("res://team_config.gd")
const Match=preload("res://match_sim.gd")
const Controls=preload("res://football_input.gd")
var checks:=0
var failures:=0
func check(value:bool,label:String)->void:
 checks+=1
 if not value: failures+=1;push_error("RECEIVING_DEFENDING_FAILED: "+label)
func fixture():
 var s=Match.new();s.setup(preload("res://campaign.gd").new(),719,Match.Squad.DEFAULT,Match.Squad.DEFAULT,true)
 s.freeze=0;s.phase="play";s.owner=-1;s.arcade=false;s.duration=1000
 for team in 2: s.teams[team].human=true
 for i in Team.COUNT:
  s.players[i].active=false;s.players[i].cooldown=0;s.players[i].vel=Vector2.ZERO
  s.players[i].pos=Vector2(-29+6*i,16);s.players[i].dir=Vector2.RIGHT
 s.players[1].active=true;s.players[1].pos=Vector2(0,3)
 s.selected=1;s.ball=Vector2(-8,0);s.velocity=Vector2(14,0);s.ball_height=s.BallPhysics.FLOOR
 s.last_touch=2;s.pass_receiver=1;s.pickup_lock=0;s.kick_age=0.1
 s.teams[0].receive_assist=2
 return s
func advance(s,seconds:float)->void:
 for i in ceili(seconds*60): s.step(1.0/60)
func duel():
 var s=fixture();s.owner=7;s.pass_receiver=-1;s.velocity=Vector2.ZERO
 s.players[1].pos=Vector2.ZERO;s.players[7].active=true;s.players[7].pos=Vector2(1.8,0);s.players[7].dir=Vector2.LEFT
 s.teams[1].selected=7;s.ball=Vector2(0.9,0)
 return s
func _initialize()->void:
 await process_frame
 var s=fixture();var p:Dictionary=s.players[1]
 var high:Vector2=s.assisted_movement(1,Vector2.RIGHT,p.pos,2)
 var standard:Vector2=s.assisted_movement(1,Vector2.RIGHT,p.pos,1)
 check(high.y<standard.y and standard.y< -0.1,"moving receiver gets correction at standard/high strength")
 check(s.assisted_movement(1,Vector2.RIGHT,p.pos,0)==Vector2.RIGHT,"low receive setting preserves manual movement")
 check(s.assisted_movement(1,Vector2.DOWN,p.pos,2)==Vector2.DOWN,"deliberately moving away can break from receiving route")
 check(s.assisted_movement(1,Vector2.ZERO,p.pos,2).y<0 and not s.teams[0].receive_cancelled,"release direction resumes help on the same pass")
 s.pass_receiver=-1;s.ball=Vector2(-2,3)
 check(s.assisted_movement(1,Vector2.RIGHT,p.pos,2)==Vector2.RIGHT,"loose-ball help does not hijack active manual movement")
 s=fixture();s.apply_command(0,{"action":s.Mechanics.CANCEL})
 check(s.assisted_movement(1,Vector2.ZERO,s.players[1].pos,2)==Vector2.ZERO,"explicit cancel can abandon current receiving run")
 s=fixture();s.ball_height=20;s.vertical_speed=5
 check(s.assisted_movement(1,Vector2.RIGHT,s.players[1].pos,2)==Vector2.RIGHT,"unreachable high ball does not create a ground reception")
 var receipt:Array=[]
 for team in 2:
  for level in 3:
   s=fixture();var index:int=team*Team.SIZE+1
   s.players[1].active=false;s.players[index].active=true;s.players[index].pos=Vector2(0,3)
   s.teams[team].selected=index;s.pass_receiver=index;s.last_touch=team*Team.SIZE+2
   s.teams[team].receive_assist=level;s.teams[team].move=Vector2.RIGHT
   var caught:=false;var top_speed:=0.0
   for frame in 120:
    s.step(1.0/60);top_speed=maxf(top_speed,s.players[index].vel.length())
    if s.owner==index: caught=true;break
   receipt.append(caught)
   check(caught if level>0 else not caught,"moving receiver collects pass according to assist: team %d level %d" % [team,level])
   check(top_speed<=s.players[index].speed+0.01,"receiving never grants extra running speed")
 s=fixture();s.ball=Vector2(-2,1);s.players[1].pos=Vector2.ZERO;s.teams[0].move=Vector2.UP
 var before_dir:Vector2=s.players[1].dir
 s.move_player(1,1.0/60,Vector2.UP,false,false)
 check(absf(before_dir.angle_to(s.players[1].dir))<=s.players[1].ratings.turn_rate/60+0.0001 and s.players[1].dir.x<1,"active reception turns toward ball within normal body turn rate")
 s.owner=1;before_dir=s.players[1].dir;s.mechanics.after_receive(s,1,10,Vector2.RIGHT)
 check(s.players[1].dir==before_dir,"first touch does not instantly snap body toward stick direction")
 var net=preload("res://match_network.gd").new()
 for level in [0,2]:
  s=fixture();s.teams[0].assist=2-level;s.teams[0].receive_assist=level;s.teams[0].move=Vector2.RIGHT
  net.sim=s;net.prediction_index=1;net.prediction_pos=s.players[1].pos;net.prediction_dir=s.players[1].dir;net.prediction_vel=Vector2.ZERO
  var movement:Vector2=s.assisted_movement(1,Vector2.RIGHT,s.players[1].pos)
  s.move_player(1,1.0/60,movement,false,false)
  net._predict({"move":Vector2.RIGHT,"sprint":false,"jockey":false,"assist":2-level,"receive_assist":level},1.0/60)
  check(s.players[1].pos.distance_to(net.prediction_pos)<0.0001 and s.players[1].dir.distance_to(net.prediction_dir)<0.0001,"client uses independent receiving level and shared facing: "+str(level))
 net.free()
 var bounded:=true;var slowed:=true
 for record in s.Library.all():
  var rating:Dictionary=s.Ratings.for_player(record)
  bounded=bounded and rating.turn_time>=0.224 and rating.turn_time<=0.3520001
  slowed=slowed and rating.turn_rate<PI/0.22
 check(bounded and slowed,"all 386 players use slower bounded turns while preserving attribute differences")
 for sliding in [false,true]:
  s=duel();var original_pos:Vector2=s.ball
  s.tackle(1,sliding)
  check(s.owner==7 and s.ball==original_pos,"defensive button starts an animation before contact")
  advance(s,0.16)
  check(s.tackles[0]==1 and s.owner==-1,"timed contact pokes opposing carrier ball: "+str(sliding))
  check(s.players[1].action==("slide_still" if sliding else "tackle"),"standing tackle and stationary ground tackle have distinct actions")
  var locked_dir:Vector2=s.players[1].dir;s.teams[0].move=Vector2.LEFT
  advance(s,0.14)
  check(s.players[1].dir==locked_dir and s.tackles[0]==1,"committed challenge cannot swivel or hit repeatedly")
  check(s.players[1].cooldown>0,"challenger cannot automatically possess while leg is extended or sliding")
  var cooldown:float=s.players[1].tackle_cd;s.tackle(1,sliding)
  check(s.players[1].tackle_cd==cooldown,"mashing tackle cannot reset recovery")
 s=duel();s.players[1].dir=Vector2.UP;s.tackle();advance(s,0.25)
 check(s.tackles[0]==0 and s.owner==7,"tackle facing away misses instead of magnetically stealing ball")
 s=duel();s.ball_height=2.0;s.tackle(-1,true);s.resolve_tackle(1,true)
 check(s.tackles[0]==0,"slide cannot collect an elevated ball")
 s=duel();s.players[1].pos=Vector2.ZERO;s.players[7].pos=Vector2(1.5,0);s.players[7].dir=Vector2.RIGHT;s.ball=Vector2(2.5,0)
 s.tackle(-1,true);advance(s,0.15)
 check(s.fouls[0]==1 and s.players[1].yellow==1,"body-first rear slide produces foul and caution")
 s=duel();s.owner=-1;s.ball=Vector2(1.3,0);s.tackle();advance(s,0.13)
 check(s.tackles[0]==1 and s.last_touch==1,"standing tackle can poke a reachable free ball")
 var distances:Array=[]
 net=preload("res://match_network.gd").new()
 for entry in [0.0,0.8,4.0,8.0]:
  s=fixture();s.pass_receiver=-1;s.ball=Vector2(20,15);s.players[1].pos=Vector2.ZERO;s.players[1].vel=Vector2.RIGHT*entry
  s.tackle(1,true)
  var action:String=s.players[1].action
  check(action==("slide_still" if entry<1.2 else "slide"),"slide variant follows actual entry speed "+str(entry))
  net.sim=s;net.prediction_index=1;net.prediction_pos=s.players[1].pos;net.prediction_vel=s.players[1].vel;net.prediction_dir=s.players[1].dir
  var duration:float=s.players[1].action_time
  for frame in ceili(duration*60):
   s.players[1].action_time=maxf(0.00001,s.players[1].action_time-1.0/60)
   s.move_player(1,1.0/60,Vector2.LEFT,true,false)
   net._predict({"move":Vector2.LEFT,"sprint":true,"jockey":false,"assist_active":false},1.0/60)
  distances.append(s.players[1].pos.x)
  check(s.players[1].pos.distance_to(net.prediction_pos)<0.0001,"client predicts speed-dependent slide distance "+str(entry))
  var decoded:Dictionary=net.unpack_state(net.pack_state(s.snapshot()))
  check(decoded.players[1].action==action and is_equal_approx(decoded.players[1].slide_speed,entry),"slide variant and entry speed replicate "+str(entry))
 check(distances[0]<0.01 and distances[1]<0.03 and distances[2]>1.0 and distances[3]>distances[2]*1.8,"stationary tackle has no boost; fast slide travels proportionally farther")
 print("SLIDE_DISTANCES entry=[0,0.8,4,8] distance=",distances)
 net.free()
 for keyboard in [true,false]:
  for sliding in [false,true]:
   var input=Controls.new();input.gamepad=93;input.sync_context(1,6,1)
   var event:InputEvent=InputEventKey.new() if keyboard else InputEventJoypadButton.new()
   if keyboard: event.physical_keycode=KEY_A if sliding else KEY_D
   else: event.device=93;event.button_index=JOY_BUTTON_X if sliding else JOY_BUTTON_B
   event.pressed=true;input.handle(event);var command:Dictionary=input.command()
   event.pressed=false;input.handle(event)
   check(command.action==(512 if sliding else 32) and input.command().action==0,"FIFA tackle input mapping and release safety keyboard=%s slide=%s" % [keyboard,sliding])
 print("RECEIVING_DEFENDING_TESTS_", "PASS" if failures==0 else "FAILED", " checks=",checks," failures=",failures," receptions=",receipt)
 quit(0 if failures==0 else 1)
