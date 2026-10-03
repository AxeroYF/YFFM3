extends RefCounted
const Pitch=preload("res://pitch_geometry.gd")
const Motion=preload("res://football_motion.gd")
const Ratings=preload("res://player_ratings.gd")
func run(test)->void:
 var Frame=preload("res://goal_frame.gd")
 for side in [-1.0,1.0]:
  for z in [-5.0,5.0]:
   var hit:=Frame.collide(Vector3((Pitch.HALF_LENGTH-2)*side,0.5,z),Vector3((Pitch.HALF_LENGTH+2)*side,0.5,z),Vector3(60*side,0,0))
   test.check(not hit.is_empty() and hit.velocity.x*side<0 and hit.velocity.length()<60,"fast shot sweeps against either post on either goal")
  var bar:=Frame.collide(Vector3((Pitch.HALF_LENGTH-2)*side,3.6,0),Vector3((Pitch.HALF_LENGTH+2)*side,3.6,0),Vector3(60*side,0,0))
  test.check(not bar.is_empty() and bar.kind=="bar" and bar.velocity.x*side<0,"crossbar rebounds a high shot")
  test.check(Frame.collide(Vector3((Pitch.HALF_LENGTH-2)*side,1,0),Vector3((Pitch.HALF_LENGTH+2)*side,1,0),Vector3(60*side,0,0)).is_empty(),"clear shot through goal mouth is not blocked")
 var frame_sim=test.fixture();frame_sim.owner=-1;frame_sim.ball=Vector2(Pitch.HALF_LENGTH-1,5);frame_sim.velocity=Vector2(60,0);frame_sim.ball_height=0.5;frame_sim.pickup_lock=1
 frame_sim.step(1.0/30)
 test.check(frame_sim.score==[0,0] and frame_sim.event_kind=="post" and frame_sim.velocity.x<0,"live match frame hit rebounds without scoring or awarding goal kick")
 for kind in ["normal","finesse","chip"]:
  var speeds:Array=[];var peaks:Array=[];var durations:Array=[]
  for q in [0.1,0.5,1.0]:
   var s=test.fixture()
   s.charge=q;s.shoot(0.4,kind=="finesse",kind=="chip")
   speeds.append(s.velocity.length());durations.append(s.players[1].action_time)
   var flight:Dictionary={"pos":s.ball,"velocity":s.velocity,"height":s.ball_height,"vertical":s.vertical_speed,"spin":s.ball_spin}
   var peak:float=flight.height
   for i in 120:
    flight=s.BallPhysics.advance(flight.pos,flight.velocity,flight.height,flight.vertical,flight.spin,true,1.0/120)
    peak=maxf(peak,flight.height)
   peaks.append(peak)
  test.check(speeds[0]<speeds[1] and speeds[1]<speeds[2],kind+" charge raises actual ball speed")
  test.check(peaks[0]<peaks[1] and peaks[1]<peaks[2],kind+" charge raises simulated trajectory apex")
  test.check(durations[0]<durations[2],kind+" charge changes follow-through animation duration")
 var s=test.fixture();s.start_charge();s.step(0.25)
 test.check(s.players[1].action=="windup" and s.players[1].action_strength>0.2,"holding shoot drives charge windup pose")
 var records:Array=preload("res://player_library.gd").all()
 var bounded:=true
 for record in records:
  var profile:=Ratings.derive(record.attributes,float(record.heightCm))
  bounded=bounded and profile.turn_time>=Ratings.TURN_MIN and profile.turn_time<=Ratings.TURN_MAX
 test.check(bounded and records.size()==386,"all 386 catalog players have bounded short turn times")
 var weak:=Ratings.derive({"agility":30,"acceleration":40,"dribbling":30,"strength":95},198)
 var agile:=Ratings.derive({"agility":95,"acceleration":90,"dribbling":95,"strength":60},170)
 test.check(agile.turn_time<weak.turn_time and weak.turn_time-agile.turn_time<0.13,"agility and modest body modifiers differentiate turns without sluggish outliers")
 test.check(Ratings.derive({"crossing":95}).cross_error<Ratings.derive({"crossing":30}).cross_error and Ratings.derive({"setPieces":95}).set_piece_error<Ratings.derive({"setPieces":30}).set_piece_error,"crossing and set-piece skill reduce kick error")
 # Same normalized eight directions on keyboard; pad remains analog and supports them all.
 var controls=preload("res://football_input.gd").new()
 var keys:Array=[[KEY_RIGHT],[KEY_RIGHT,KEY_DOWN],[KEY_DOWN],[KEY_LEFT,KEY_DOWN],[KEY_LEFT],[KEY_LEFT,KEY_UP],[KEY_UP],[KEY_RIGHT,KEY_UP]]
 for i in 8:
  for code in keys[i]:
   var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true
   Input.parse_input_event(event)
  Input.flush_buffered_events()
  var direction:=Vector2.from_angle(i*PI/4)
  test.check(controls.movement().distance_to(direction)<0.001,"keyboard eight-way input normalized: "+str(i))
  for code in keys[i]:
   var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=false
   Input.parse_input_event(event)
  Input.flush_buffered_events()
  s=test.fixture();var p:Dictionary=s.players[1];p.pos=Vector2.ZERO;p.dir=Vector2.RIGHT
  var angle:float=absf(p.dir.angle_to(direction))
  var frames:=maxi(1,ceili(angle/p.ratings.turn_rate*60))
  for frame in frames: s.move_player(1,1.0/60,direction,false,false)
  test.check(p.dir.dot(direction)>0.999 and frames<=22,"angle-proportional turn reaches eight-way target within bounded frames: "+str(i))
 s=test.fixture();s.players[1].dir=Vector2.from_angle(deg_to_rad(179))
 s.move_player(1,1.0/60,Vector2.from_angle(deg_to_rad(-179)),false,false)
 test.check(s.players[1].dir.dot(Vector2.from_angle(deg_to_rad(-179)))>0.999,"turn across angle boundary takes shortest path")
 s=test.fixture();s.players[1].pos=Vector2.ZERO;s.players[1].dir=Vector2.RIGHT;s.players[1].vel=Vector2.RIGHT*8
 var turn_frames:=42
 for i in turn_frames: s.move_player(1,1.0/60,Vector2.LEFT,false,false)
 test.check(s.players[1].vel.normalized().dot(Vector2.LEFT)>0.99 and s.players[1].vel.length()<=s.players[1].speed,"running reversal brakes and accelerates into new direction within 0.7 seconds")
 var body:Dictionary=s.players[0].body
 for item in [[0.31,20,0,"scoop"],[0.31,40,0,"foot_save"],[body.height*0.65,20,0,"catch"],[body.height*0.65,40,0,"parry"],[body.height*0.93,20,0,"catch_high"],[body.height*1.08,40,0,"tip"],[0.31,30,2,"dive_low"],[body.height*0.65,30,2,"dive"],[body.height*0.95,30,2,"dive_high"]]:
  test.check(Motion.keeper_action(item[0],item[1],item[2],body,30)==item[3],"keeper selects height/speed/lateral-specific action: "+item[3])
 for direction in [-1.0,1.0]:
  s=test.fixture();s.owner=-1;s.ball=Vector2(-20,2*direction);s.velocity=Vector2(-30,0);s.ball_is_shot=true;s.kick_age=0.4;s.ball_height=0.4
  s.last_touch=6
  s.players[0].cooldown=0
  s.keeper_target(0)
  test.check(s.players[0].action=="dive_low" and s.players[0].keeper_side==-direction,"low dive mirrors on both sides")
 var transport=preload("res://match_network.gd").new();transport.sim=s
 for action in ["windup","power_shot","finesse","dive_high","foot_save","tip","scoop"]:
  s.players[0].action=action;s.players[0].action_strength=0.85
  var wire:Dictionary=transport.pack_state(s.snapshot())
  var state:Dictionary=transport.unpack_state(wire)
  test.check(state.players[0].action==action and absf(state.players[0].action_strength-0.85)<0.001,"network preserves new animation and charge intensity: "+action)
 transport.free()
