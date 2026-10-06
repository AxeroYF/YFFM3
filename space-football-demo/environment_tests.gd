extends SceneTree
const Match=preload("res://match_sim.gd")
const Conditions=preload("res://match_environment.gd")
const Network=preload("res://match_network.gd")
const Prediction=preload("res://network_prediction.gd")
const Command=preload("res://network_command.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures+=1;push_error("ENVIRONMENT_FAILED "+label)
func fixture(config:Dictionary={}):
 var s=Match.new();s.setup(preload("res://campaign.gd").new(),813,Match.Squad.DEFAULT,Match.Squad.DEFAULT,true)
 s.environment=Conditions.normalize(config);s.freeze=0;s.phase="play";s.owner=-1;s.pickup_lock=100
 s.ball=Vector2.ZERO;s.ball_height=4;s.velocity=Vector2(6,0);s.vertical_speed=3
 for t in s.teams: t.human=true;t.assist_active=false
 for p in s.players: p.active=false;p.cooldown=0;p.vel=Vector2.ZERO
 return s
func flight(config:Dictionary,air:bool)->Dictionary:
 var s=fixture(config)
 if not air: s.ball_height=s.BallPhysics.FLOOR;s.vertical_speed=0
 for i in 60:
  s.elapsed+=1.0/60
  var f:Dictionary=s.advance_ball(s.ball,s.velocity,s.ball_height,s.vertical_speed,0,false,1.0/60)
  s.ball=f.pos;s.velocity=f.velocity;s.ball_height=f.height;s.vertical_speed=f.vertical
 return {"pos":s.ball,"height":s.ball_height,"vertical":s.vertical_speed}
func _initialize()->void:
 check_named_conditions()
 check(Conditions.normalize({"weather":NAN,"gravity":-3,"stadium":"bad"})==Conditions.normalize({}),"invalid config returns bounded defaults")
 var plain:=flight({},true);var windy:=flight({"weather":1},true)
 check(windy.pos.y>0.3 and plain.pos.y==0,"crosswind visibly bends airborne trajectory")
 check(flight({"weather":1},false)==flight({},false),"wind cannot move a resting or rolling ground ball")
 check(flight({"weather":2},false).pos.x<flight({},false).pos.x,"rain shortens ground-pass runout")
 check(flight({"gravity":1},true).height>plain.height+1,"low gravity prolongs ball flight")
 check(flight({"stadium":1},true)==plain,"background is cosmetic only")
 var normal=fixture();var low=fixture({"gravity":1})
 for s in [normal,low]:
  s.players[1].active=true;s.players[1].jump_z=0.01;s.players[1].jump_v=4.7
  for i in 45: s.mechanics.tick(s,1.0/60,true)
 check(normal.players[1].jump_z==0 and low.players[1].jump_z>1,"player jumping shares lower gravity and stays airborne")
 var p:Dictionary=normal.players[1];var dry:=Vector2(p.speed,0);var wet:=dry
 for i in 15:
  dry=normal.Movement.velocity(dry,Vector2.ZERO,p.speed,p.ratings,false,1.0/60)
  wet=normal.Movement.velocity(wet,Vector2.ZERO,p.speed,p.ratings,false,1.0/60,0.80)
 check(wet.length()>dry.length(),"wet pitch increases stopping distance")
 for stadium in 2:
  for weather in 4:
   for gravity in 2:
    var s=fixture({"stadium":stadium,"weather":weather,"gravity":gravity})
    var saved:Dictionary=s.snapshot();var copy=Match.new();copy.restore(saved)
    check(copy.environment==s.environment,"snapshot retains environment")
    saved.environment.weather=0
    check(s.environment.weather==weather,"snapshot does not alias config")
    var network=Network.new();network.sim=s
    var wire:Dictionary=network.unpack_state(network.pack_state(s.snapshot()))
    copy.restore(wire)
    check(copy.environment==s.environment,"compressed network state retains all environment choices")
    network.free()
    # Authority and private client prediction execute the same weather/traction.
    s.players[1].active=true;s.players[1].pos=Vector2.ZERO;s.players[1].vel=Vector2.ZERO
    s.teams[0].selected=1;s.last_touch=1
    var preview=Prediction.new();preview.reset(s.snapshot(),0)
    for frame in 10:
     var command:=Command.bind(s,0,{"move":Vector2.RIGHT,"action":0,"assist_active":false},frame+1,0)
     s.apply_command(0,command);s.step(1.0/60);preview.step(command,1.0/60)
    check(s.ball.distance_to(preview.sim.ball)<0.0001 and absf(s.ball_height-preview.sim.ball_height)<0.0001,"weather ball preview matches authority")
    check(s.players[1].pos.distance_to(preview.sim.players[1].pos)<0.0001,"wet movement preview matches authority")
 for ice in [false,true]:
  var s=Match.new();s.setup(preload("res://campaign.gd").new(),719)
  s.environment=Conditions.normalize({"stadium":1,"weather":3,"gravity":1});s.ice_mode=ice
  s.regulation=12;s.duration=12;s.overtime_duration=4;s.freeze=0
  for t in s.teams: t.human=false
  var finite:=true
  for i in 9000:
   s.step(1.0/60)
   finite=finite and s.ball.is_finite() and is_finite(s.ball_height)
   if s.finished: break
  check(s.finished and finite,"storm + low gravity AI match ends naturally, ice="+str(ice))
 print("ENVIRONMENT_TESTS_", "PASS" if failures==0 else "FAILED", " checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)

func check_named_conditions()->void:
 # Independent step settings must not mutate shared resources or another match.
 var s=fixture({"weather":3,"gravity":1})
 s.arcade=true;s.stage=1;s.elapsed=14
 var outdoor=s.flight_conditions()
 var indoor=s.flight_conditions(0,false)
 check(outdoor.solar_wind==3.7 and outdoor.crosswind>0 and indoor.solar_wind==0 and indoor.crosswind==0,"goal/restart wind suppression is local to that step")
 indoor.gravity_scale=9;indoor.rolling_drag=9;indoor.restitution=9
 var next=s.flight_conditions()
 check(next.gravity_scale==0.55 and next.rolling_drag==1.3 and next.restitution==0.23 and next.crosswind==outdoor.crosswind,"step settings cannot contaminate profiles or following predictions")
 # Named controls are independently useful: arbitrary new weather need not be a wet/dry flag.
 var settings=Conditions.Flight.new()
 settings.gravity_scale=0.25;settings.rolling_drag=2;settings.restitution=0.5
 var physics=Match.BallPhysics
 var roll:Dictionary=physics.step(Vector2.ZERO,Vector2(10,0),physics.FLOOR,0,0,false,0.1,settings)
 check(roll.velocity.is_equal_approx(Vector2(8.4,0)) and roll.pos.is_equal_approx(Vector2(0.84,0)),"custom rolling friction controls ground travel")
 var air:Dictionary=physics.step(Vector2.ZERO,Vector2.ZERO,3,2,0,false,0.1,settings)
 check(is_equal_approx(float(air.height),3.1825) and is_equal_approx(float(air.vertical),1.65),"custom gravity follows ballistic acceleration")
 var bounce:Dictionary=physics.step(Vector2.ZERO,Vector2.ZERO,physics.FLOOR+0.01,-4,0,false,0.01,settings)
 check(is_equal_approx(float(bounce.vertical),2.0175),"custom restitution controls bounce independently of friction")
 # Closed goal net still uses the same conditions when no net surface is touched.
 var net:Dictionary=s.GoalNet.advance_with_conditions(Vector2.ZERO,Vector2.ZERO,3,2,0,0,0.1,settings)
 check(net.pos.is_equal_approx(air.pos) and is_equal_approx(float(net.height),float(air.height)) and is_equal_approx(float(net.vertical),float(air.vertical)),"goal-net flight shares the named gravity settings within Vector3 precision")
