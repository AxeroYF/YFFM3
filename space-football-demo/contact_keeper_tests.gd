extends RefCounted
const Physics=preload("res://ball_physics.gd")
var test

func fixture():
 var s=test.fixture()
 s.teams[1].human=true
 s.owner=-1;s.pickup_lock=0;s.velocity=Vector2.ZERO
 for i in 10:
  s.players[i].pos=Vector2(-12+i*2,14)
  s.players[i].vel=Vector2.ZERO;s.players[i].speed=0;s.players[i].cooldown=100
 return s

func run(runner)->void:
 test=runner
 check_contacts()
 check_keeper()

func check_contacts()->void:
 var energy_ok:=true
 var rng:=RandomNumberGenerator.new();rng.seed=4312
 for i in 300:
  var speed:=rng.randf_range(0,55)
  var velocity:=Vector2.from_angle(rng.randf_range(-PI,PI))*speed
  var normal:=Vector2.from_angle(rng.randf_range(-PI,PI))
  var result:=Physics.deflect(velocity,normal,rng.randf_range(0.1,0.8))
  energy_ok=energy_ok and result.length()<=speed+0.00001
 test.check(energy_ok,"passive contact never adds speed across 300 approach angles and speeds")
 test.check(Physics.deflect(Vector2.ZERO,Vector2.RIGHT,0.4)==Vector2.ZERO,"stationary contact does not create a fixed impulse")
 test.check(Physics.deflect(Vector2.RIGHT*4,Vector2.RIGHT,0.4)==Vector2.RIGHT*4,"separating ball is not reflected or accelerated again")
 var hit:=Physics.player_contact(Vector2(-3,0),Vector2(3,0),Vector2.ZERO,1)
 test.check(not hit.is_empty() and hit.normal==Vector2.LEFT and hit.position.x<-1,"swept collision catches a fast ball at the near surface")
 test.check(Physics.player_contact(Vector2(-3,2),Vector2(3,2),Vector2.ZERO,1).is_empty(),"nearby flight outside contact radius is unchanged")
 var s=fixture()
 s.ball=Vector2(3,0);s.velocity=Vector2(45,0);s.ball_is_shot=true
 s.players[1].pos=Vector2(1.8,0);s.players[1].cooldown=0
 s.players[6].pos=Vector2(-0.8,0);s.players[6].cooldown=0
 s.resolve_player_contacts(Vector2(-3,0))
 test.check(s.last_touch==6 and s.velocity.x<0 and s.velocity.length()<45,"first physical contact wins regardless of player-array order")
 var last_speed:=4.0
 var contacts:={}
 var decays:=true
 s=fixture();s.velocity=Vector2(4,0);s.ball_height=s.players[1].body.chest_height
 s.players[6].body=s.players[1].body.duplicate()
 for bounce in 30:
  var index:int=1 if bounce%2==0 else 6
  var other:int=6 if index==1 else 1
  s.players[other].cooldown=100
  s.players[index].cooldown=0
  s.players[index].pos=s.ball+s.velocity.normalized()*0.5
  s.pickup_lock=0
  s.resolve_player_contacts(s.ball)
  contacts[s.last_touch]=true
  decays=decays and s.velocity.length()<=last_speed+0.00001
  last_speed=s.velocity.length()
 test.check(decays and last_speed<0.001 and contacts.size()==2,"thirty alternating player deflections dissipate speed instead of pumping the ball")
 s=fixture();s.ball=Vector2(0.4,0);s.velocity=Vector2(0.5,0);s.vertical_speed=-0.05
 s.ball_height=s.players[1].body.chest_height;s.players[1].pos=Vector2.ZERO;s.players[1].cooldown=0
 var before:=Vector3(s.velocity.x,s.vertical_speed,s.velocity.y).length()
 s.resolve_player_contacts(s.ball)
 test.check(Vector3(s.velocity.x,s.vertical_speed,s.velocity.y).length()<=before+0.00001,"low-speed overlap cannot create horizontal or vertical energy")
 s=fixture();s.teams[0].human=false;s.teams[1].human=false
 s.ball=Vector2(20,0);s.ball_height=1.6
 for index in [1,2,6,7]: s.players[index].pos=s.ball;s.players[index].cooldown=0
 s.step(1.0/60)
 test.check(s.shots[0]+s.shots[1]==1,"crowded AI aerial duel allows only one kick in a simulation frame")
 var kicked_velocity:Vector2=s.velocity
 s.aerial(7,0)
 test.check(s.velocity==kicked_velocity and s.shots[0]+s.shots[1]==1,"aerial touch respects shared post-kick pickup lock")
 s=fixture();s.owner=1;s.selected=1;s.charge=1;s.shoot()
 test.check(s.velocity.length()>30 and s.vertical_speed>8,"fix retains deliberately charged powerful shots")

func receive_keeper(team:int,shot:bool=false,outside:bool=false):
 var s=fixture()
 var index:=team*5
 var p:Dictionary=s.players[index]
 p.pos=Vector2((-15 if outside else -27)*s.side(team),0);p.cooldown=0
 s.ball=p.pos+Vector2(s.side(team)*0.7,0)
 s.ball_height=p.body.chest_height if shot else Physics.FLOOR
 s.last_touch=(1-team)*5+1 if shot else team*5+4
 s.velocity=Vector2(-4*s.side(team),0);s.ball_is_shot=shot
 s.resolve_player_contacts(s.ball)
 return s

func check_keeper()->void:
 for team in 2:
  var index:=team*5
  var s=receive_keeper(team)
  var p:Dictionary=s.players[index]
  test.check(s.owner==index and s.teams[team].selected==index and not p.keeper_holding and p.action=="receive" and s.saves[team]==0,"ordinary keeper backpass selects foot possession on team "+str(team))
  for frame in 100: s.step(1.0/60)
  test.check(s.owner==index and s.ball_height<Physics.FLOOR+0.05 and s.passes[team]==0,"human keeper keeps ball at feet without automatic throw on team "+str(team))
  p.speed=5
  var origin:Vector2=p.pos
  s.apply_command(team,{"move":Vector2.DOWN})
  for frame in 20: s.step(1.0/60)
  test.check(p.pos.y>origin.y and p.dir.dot(Vector2.DOWN)>0.95 and s.ball_height<0.36,"keeper turns and dribbles in commanded direction on team "+str(team))
  for assist in 3:
   for lane in [-1,1]:
    s=receive_keeper(team);s.view_team=team;s.teams[team].assist=assist
    var target:=team*5+(2 if lane<0 else 3)
    s.players[target].pos=s.players[index].pos+Vector2(8*s.side(team),8*lane)
    var input=preload("res://football_input.gd").new()
    input.gamepad=93;input.assistance=assist;input.sync_context(index,index,1)
    var key:=InputEventKey.new();key.physical_keycode=KEY_S;key.pressed=true
    var button:=InputEventJoypadButton.new();button.device=93;button.button_index=JOY_BUTTON_A;button.pressed=true
    input.handle(key if lane<0 else button)
    key.pressed=false;button.pressed=false
    input.handle(key if lane<0 else button)
    var command:Dictionary=input.command()
    command.move=Vector2(s.side(team),lane).normalized()
    s.apply_command(team,command)
    s.mechanics.tick(s,0.09)
    test.check(s.owner==-1 and s.pass_receiver==target and s.teams[team].selected==target and s.velocity.dot(command.move)>s.velocity.length()*0.97 and s.players[index].action=="pass" and s.ball_height==Physics.FLOOR,"keeper keyboard S / Xbox A directional foot pass: team %d assist %d lane %d" % [team,assist,lane])
  s=receive_keeper(team,true)
  test.check(s.owner==index and s.players[index].keeper_holding and s.saves[team]==1 and s.ball_height>1,"keeper still catches an actual opponent shot inside own area on team "+str(team))
  s.step(1.2)
  test.check(s.owner==index,"human keeper waits for direction after a genuine catch")
  s.apply_command(team,{"action":4,"move":Vector2(s.side(team),-1).normalized()})
  s.mechanics.tick(s,0.09)
  test.check(s.owner==-1 and not s.players[index].keeper_holding and s.players[index].action=="throw" and s.velocity.y<0,"genuine hand catch distributes only on player's directional pass command")
  s=receive_keeper(team,true,true)
  test.check(not s.players[index].keeper_holding and s.owner==-1 and s.saves[team]==0,"keeper outside own area cannot use hands")
  s=receive_keeper(team)
  s.teams[team].human=false;s.players[index].cooldown=0
  s.ai_direction(index)
  test.check(s.owner==-1 and s.players[index].action=="pass" and s.ball_height==Physics.FLOOR,"AI keeper also distributes ordinary possession with feet")
  s=receive_keeper(team)
  s.owner=team*5+4;s.players[s.owner].pos=s.players[index].pos+Vector2(8*s.side(team),0)
  var plan:Dictionary=s.pass_plan(s.owner,Vector2(-s.side(team),0),false,1)
  test.check(plan.receiver==index,"directional passing can intentionally target own goalkeeper")
  var net=preload("res://match_network.gd").new()
  s=receive_keeper(team,true);net.sim=s
  var wire:Dictionary=net.pack_state(s.snapshot())
  var decoded:Dictionary=net.unpack_state(wire)
  test.check(decoded.players[index].keeper_holding and decoded.teams[team].selected==index and var_to_bytes(wire).size()<1200,"keeper hand mode and selection replicate within packet budget")
  s.players[index].keeper_holding=false
  decoded=net.unpack_state(net.pack_state(s.snapshot()))
  test.check(not decoded.players[index].keeper_holding,"keeper foot mode replaces previous hand mode in compact snapshot")
  net.prediction_index=index;net.prediction_pos=s.players[index].pos;net.prediction_vel=s.players[index].vel;net.prediction_dir=s.players[index].dir
  var command:={"move":Vector2.DOWN,"sprint":false,"jockey":false,"assist_active":false}
  net._predict(command,1.0/60)
  s.move_player(index,1.0/60,Vector2.DOWN,false,false)
  test.check(net.prediction_pos.is_equal_approx(s.players[index].pos) and net.prediction_dir.is_equal_approx(s.players[index].dir),"goalkeeper foot movement prediction matches authority")
  net.free()
