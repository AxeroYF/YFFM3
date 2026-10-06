extends SceneTree
const Library=preload("res://player_library.gd")
const Body=preload("res://player_body.gd")
const Ratings=preload("res://player_ratings.gd")
const Movement=preload("res://player_movement.gd")
const Match=preload("res://match_sim.gd")
const Network=preload("res://match_network.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures+=1;push_error("PHYSIQUE_FAILED "+label)

func fixture():
 var s=Match.new();s.setup(preload("res://campaign.gd").new(),719,Match.Squad.DEFAULT,Match.Squad.DEFAULT,true)
 s.freeze=0;s.phase="play";s.owner=-1;s.arcade=false;s.ball=Vector2(20,15);s.pickup_lock=10
 for team in 2:
  s.teams[team].human=true;s.teams[team].selected=team*6+1;s.teams[team].assist_active=false
 for p in s.players: p.active=false;p.vel=Vector2.ZERO;p.pos=Vector2.ZERO;p.dir=Vector2.RIGHT;p.action="idle";p.action_time=0
 s.players[1].active=true
 return s

func install(s,index:int,record:Dictionary)->void:
 var p:Dictionary=s.players[index]
 p.body=Body.from_record(record,index%6);p.ratings=Ratings.for_player(record,p.body);p.speed=p.ratings.speed
 p.player_id=record.get("id","");p.attributes=record.attributes.duplicate(true)

func sample(record:Dictionary,hz:int=120)->Dictionary:
 var r:=Ratings.for_player(record);var dt:=1.0/hz
 var v:=Vector2.ZERO;var start_time:=0.0
 while v.length()<r.speed*0.95 and start_time<2:
  v=Movement.velocity(v,Vector2.RIGHT,r.speed,r,false,dt);start_time+=dt
 v=Vector2.RIGHT*r.speed*1.42
 var stopping_distance:=0.0;var stop_time:=0.0
 while v.length()>0.001 and stop_time<2:
  var before:=v.length();v=Movement.velocity(v,Vector2.ZERO,r.speed,r,false,dt)
  stopping_distance+=(before+v.length())*0.5*dt;stop_time+=dt
 v=Vector2.RIGHT*r.speed*1.42
 var reverse_time:=0.0
 while v.x>=0 and reverse_time<2:
  v=Movement.velocity(v,Vector2.LEFT,r.speed,r,false,dt);reverse_time+=dt
 return {"id":record.get("id",""),"name":record.get("name","test"),"height_cm":record.heightCm,"start_95_ms":snappedf(start_time*1000,0.1),"sprint_stop_metres":snappedf(stopping_distance/Body.WORLD_UNITS_PER_METRE,0.001),"reverse_ms":snappedf(reverse_time*1000,0.1),"turn_180_ms":snappedf(r.turn_time*1000,0.1),"tackle_metres":snappedf(r.tackle_reach/Body.WORLD_UNITS_PER_METRE,0.001),"shield":snappedf(r.shield,0.001),"physique":Body.from_record(record).physique}

func _initialize()->void:
 await process_frame
 var original:=Library.all().duplicate(true)
 for record in Library.all():
  var b:=Body.from_record(record);var f:Dictionary=b.physique;var r:=Ratings.for_player(record,b)
  check(f.acceleration_scale>=0.92 and f.acceleration_scale<=1.08 and f.braking_scale>=0.90 and f.braking_scale<=1.10 and f.turn_scale>=0.90 and f.turn_scale<=1.10,"bounded movement "+record.id)
  check(r.turn_time>=Ratings.TURN_MIN and r.turn_time<=Ratings.TURN_MAX and f.tackle_reach_scale>=0.935 and f.tackle_reach_scale<=1.07,"bounded turning and tackling "+record.id)
  check(is_equal_approx(r.speed,(5.8+Ratings.unit(record.attributes,"pace")*2.9)*0.78),"top speed unaffected by shape "+record.id)
  var cosmetic:=b.duplicate(true)
  for key in ["skin","hair","hair_style","beard_style","name","nationality"]: cosmetic[key]="different"
  cosmetic.head_width=2;cosmetic.jaw_width=2;cosmetic.nose_size=2
  check(Body.Physique.derive(cosmetic)==f,"colour hair face identity cannot affect gameplay "+record.id)
  check(Ratings.for_player(record,Body.from_record(record,0))==r and Ratings.for_player(record,Body.from_record(record,5))==r,"slot independent physics "+record.id)
 var short:=Library.find("legend-messi").duplicate(true)
 var tall:=Library.find("legend-haaland").duplicate(true)
 for record in [short,tall]:
  for key in record.attributes: record.attributes[key]=80
 var sr:=Ratings.for_player(short);var tr:=Ratings.for_player(tall)
 var small:=sample(short);var large:=sample(tall)
 check(small.start_95_ms<large.start_95_ms and small.sprint_stop_metres<large.sprint_stop_metres,"equal abilities: compact body starts faster and stops sooner")
 check(sr.turn_time<tr.turn_time and sr.shield<tr.shield and sr.tackle_reach<tr.tackle_reach,"equal abilities: agility trades against shielding and long-leg reach")
 check(large.start_95_ms/small.start_95_ms<1.20 and large.sprint_stop_metres/small.sprint_stop_metres<1.25,"noticeable but restrained equal-stat differences")
 var skilled:=tall.duplicate(true);skilled.attributes.acceleration=99
 var unskilled:=short.duplicate(true);unskilled.attributes.acceleration=35
 check(Ratings.for_player(skilled).acceleration>Ratings.for_player(unskilled).acceleration,"ability advantage remains stronger than physique")
 for record in [short,tall]:
  var r:=Ratings.for_player(record)
  for hz in [30,60,120]:
   var dt:float=1.0/hz;var v:Vector2=Vector2.RIGHT*r.speed*1.42;var before:=v
   v=Movement.velocity(v,Vector2.LEFT,r.speed,r,false,dt)
   check(v.x>0 and v.length()<before.length(),"reversal first brakes old momentum: "+str(hz))
   v=Vector2.ZERO;var max_speed:=0.0
   for frame in hz*3:
    v=Movement.velocity(v,Vector2.from_angle(floori(frame/7.0)*PI/4),r.speed,r,false,dt)
    max_speed=maxf(max_speed,v.length())
   check(max_speed<=r.speed+0.00001,"eight-way cuts cannot accumulate extra speed: "+str(hz))
   for frame in hz: v=Movement.velocity(v,Vector2.ZERO,r.speed,r,false,dt)
   check(v==Vector2.ZERO,"no creeping after release")
   var measured:=sample(record,hz)
   check(absf(measured.sprint_stop_metres-sample(record).sprint_stop_metres)<0.02,"braking travel consistent across frame rates")
  var forward:=Movement.reachable_distance(r.speed,r.speed,r,0.5)
  var backward:=Movement.reachable_distance(-r.speed,r.speed,r,0.5)
  check(backward<forward*0.6,"receiver and AI intercept estimates respect wrong-way momentum")
  for initial in [-r.speed,0,r.speed*1.42]:
   var v:=Vector2(initial,0);var distance:=0.0
   for frame in 240:
    var next:=Movement.velocity(v,Vector2.RIGHT,r.speed,r,false,1.0/240)
    distance+=(v.x+next.x)*0.5/240;v=next
   check(absf(maxf(0,distance)-Movement.reachable_distance(initial,r.speed,r,1))<0.002,"interception travel agrees with shared actual motion")
 # The body reaches a real ball at the new boundary, with the original angle/height guards.
 var middle:float=(sr.tackle_reach+tr.tackle_reach)*0.5
 for record in [short,tall]:
  for blocked in ["none","behind","high"]:
   var s=fixture();install(s,1,record);s.ball=Vector2(middle,0);s.ball_height=2 if blocked=="high" else s.BallPhysics.FLOOR
   if blocked=="behind": s.players[1].dir=Vector2.LEFT
   s.resolve_tackle(1,false)
   check((s.tackles[0]==1)==(record==tall and blocked=="none"),"leg reach changes real tackle without bypassing height/facing: "+str([record.id,blocked]))
 # Same defender challenges two equal-stat carriers from the side.
 var knocked:Array=[]
 for record in [short,tall]:
  var s=fixture();install(s,1,record);s.owner=1;s.players[7].active=true;s.players[7].pos=Vector2(0,0.7)
  s.teams[1].jockey=true;s.players[7].ratings.shield=(sr.shield+tr.shield)*0.5+0.12
  s.mechanics.contact(s,1,7);knocked.append(s.players[1].balance>0)
 check(knocked==[true,false],"wider equal-stat carrier resists a borderline shoulder challenge")
 var s=fixture();install(s,1,short);install(s,7,tall);s.players[7].active=true
 var spacing:float=s.players[1].body.body_radius+s.players[7].body.body_radius
 s.players[7].pos=Vector2(spacing-0.025,0)
 var before:Vector2=s.players[7].pos;s.step(1.0/60)
 var short_push:float=s.players[1].pos.length();var tall_push:float=s.players[7].pos.distance_to(before)
 check(short_push>tall_push and short_push<=s.players[1].speed*0.20/60 and tall_push<=s.players[7].speed*0.20/60,"contact mass shares overlap correction within existing displacement budget")
 check(s.players[1].vel==Vector2.ZERO and s.players[7].vel==Vector2.ZERO,"body separation never injects running velocity")
 test_prediction()
 var report:Array=[]
 for id in ["legend-messi","legend-maradona","legend-modric","legend-zidane","legend-haaland","legend-courtois"]:
  var row:=sample(Library.find(id));report.append(row);print("PHYSIQUE_SAMPLE ",JSON.stringify(row))
 var file:=FileAccess.open("res://artifacts/physique-report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"equal_abilities":[small,large],"players":report,"note":"Game coefficients, not real-world measurements; straight run 0 to 95%, sprint to stop; 120 Hz."},"  "))
 check(original==Library.all(),"original catalog and all 26 abilities unchanged")
 print("PHYSIQUE_","PASS" if failures==0 else "FAILED"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)

func test_prediction()->void:
 var net:=Network.new()
 for id in ["legend-messi","legend-haaland","legend-courtois"]:
  for mode in ["free","carry","jockey","shield","receive","dive"]:
   var s=fixture();var record:=Library.find(id);var index:=0 if record.role=="GK" else 1
   s.players[1].active=false;s.players[index].active=true;s.teams[0].selected=index;install(s,index,record)
   var p:Dictionary=s.players[index]
   if mode in ["carry","shield"]: s.owner=index
   if mode=="receive": p.action="receive";p.action_time=0.25
   if mode=="dive": p.action="dive_low";p.action_time=0.35
   net.sim=s;net.prediction_index=index;net.prediction_pos=p.pos;net.prediction_vel=p.vel;net.prediction_dir=p.dir
   var same:=true
   for frame in 150:
    var direction:=Vector2.from_angle(floori(frame/17.0)*PI/4)*(0.4 if frame%11<3 else 1.0) if frame<120 else Vector2.ZERO
    var sprinting:bool=frame<65;var jockeying:bool=mode in ["jockey","shield"]
    s.teams[0].move=direction;s.teams[0].jockey=jockeying
    # Predict from the same pre-step stamina used by the authoritative tick.
    preload("res://movement_test_probe.gd").advance(net,{"move":direction,"sprint":sprinting,"jockey":jockeying,"assist_active":false},1.0/60)
    s.move_player(index,1.0/60,direction,sprinting,jockeying)
    same=same and p.pos.distance_to(net.prediction_pos)<0.0001 and p.vel.distance_to(net.prediction_vel)<0.0001 and p.dir.distance_to(net.prediction_dir)<0.0001
   check(same,"authority/client shared physique motion "+id+" / "+mode)
 # Wire identities must rebuild the physical coefficients, including substitutions.
 var server=fixture();server.mechanics.benches[0]=[{"id":"legend-haaland","fatigue":0.0,"yellow":0}]
 server.mechanics.requests[0]={"out":1,"reserve":0};server.mechanics.substitute(server,0)
 net.sim=server;var wire:=net.pack_state(server.snapshot())
 var client=fixture();net.sim=client;var snapshot:=net.unpack_state(wire)
 check(snapshot.players[1].body.physique==server.players[1].body.physique and snapshot.players[1].ratings==server.players[1].ratings,"substitution restores same physique and ratings over network")
 net.free()
