extends SceneTree
const Team=preload("res://team_config.gd")
const Pitch=preload("res://pitch_geometry.gd")

const Campaign=preload("res://campaign.gd")
const Match=preload("res://match_sim.gd")
var checks:=0
var failures:=0

func check_classic_controls()->void:
 var ControlInput=load("res://football_input.gd")
 # Exercise the shared attack/defence key with real simulation outcomes on both teams.
 for team in [0,1]:
  for keyboard in [true,false]:
   var controls=ControlInput.new()
   controls.gamepad=93
   var event:InputEvent
   if keyboard:
    event=InputEventKey.new()
    event.physical_keycode=KEY_D
   else:
    event=InputEventJoypadButton.new()
    event.device=93
    event.button_index=JOY_BUTTON_B
   var sim=fixture()
   var selected:int=team*Team.SIZE+1
   sim.teams[team].selected=selected
   sim.owner=selected
   controls.sync_context(selected,selected,1)
   event.pressed=true
   controls.handle(event)
   sim.apply_command(team,controls.command())
   check(sim.teams[team].charging,"classic primary key charges for selected team")
   event.pressed=false
   controls.handle(event)
   sim.apply_command(team,controls.command())
   sim.mechanics.tick(sim,0.09)
   check(sim.shots[team]==1 and sim.owner==-1,"classic primary release shoots for selected team")
   sim.owner=(1-team)*Team.SIZE+1
   controls.sync_context(selected,sim.owner,1)
   event.pressed=true
   controls.handle(event)
   var command:Dictionary=controls.command()
   sim.apply_command(team,command)
   check(command.action==32 and sim.players[selected].tackle_cd>0 and not sim.teams[team].charging,"same primary key tackles immediately without possession")
   sim.owner=selected
   controls.sync_context(selected,sim.owner,1)
   event.pressed=false
   controls.handle(event)
   check(controls.command().action==0,"tackle release cannot shoot after gaining possession")
   event.pressed=true
   controls.handle(event)
   controls.command()
   controls.sync_context(selected,-1,1)
   check(controls.command().action==128 and not controls.shot_held,"losing possession cancels a held shot")
   controls.sync_context(selected,selected,1)
   event.pressed=false
   controls.handle(event)
   check(controls.command().action==0,"regaining possession does not revive cancelled shot")
   event.pressed=true
   controls.handle(event)
   controls.sync_context(selected+1,selected+1,1)
   check(controls.command().action==128,"selection change cancels queued shot before consumption")
 var controls=ControlInput.new()
 controls.gamepad=93
 var key:=InputEventKey.new()
 key.pressed=true
 for pair in [[KEY_S,4],[KEY_W,8],[KEY_Q,16]]:
  controls.sync_context(1,6,1)
  key.physical_keycode=pair[0]
  controls.handle(key)
  check(controls.command().action==pair[1],"classic keyboard pass, through and defensive switching")
 controls.sync_context(1,1,1)
 key.physical_keycode=KEY_Q
 controls.handle(key)
 check(controls.command().action==0,"Q does not switch away from the ball carrier")
 for old_key in [KEY_SPACE,KEY_TAB,KEY_J,KEY_R]:
  key.physical_keycode=old_key
  check(not controls.handle(key) and controls.command().action==0,"retired gameplay keys do not trigger legacy actions")
 key.physical_keycode=KEY_D
 key.echo=true
 controls.handle(key)
 check(controls.command().action==0,"keyboard repeat cannot retrigger shared action")
 key.echo=false
 controls.handle(key)
 controls.command()
 key.physical_keycode=KEY_S
 controls.handle(key)
 check(controls.command().action==2176 and not controls.shot_held,"shot then short-pass performs fake shot and cancels charge")
 var pad:=InputEventJoypadButton.new()
 pad.device=93
 pad.pressed=true
 pad.button_index=JOY_BUTTON_LEFT_SHOULDER
 controls.handle(pad)
 check(controls.command().action==0,"LB does not switch the ball carrier")
 pad.button_index=JOY_BUTTON_X
 controls.handle(pad);pad.pressed=false;controls.handle(pad);pad.pressed=true
 check(controls.command().action==256,"X release performs lofted pass while in possession")
 pad.button_index=JOY_BUTTON_DPAD_RIGHT
 controls.sync_context(1,6,0)
 controls.handle(pad)
 var command:Dictionary=controls.command()
 check(command.action==64 and command.tactic==1,"dpad right steps from defensive to balanced")
 controls.handle(pad)
 check(controls.command().tactic==2,"dpad right steps to attacking")
 controls.handle(pad)
 check(controls.command().tactic==2,"attacking tactic clamps at maximum")
 pad.button_index=JOY_BUTTON_DPAD_LEFT
 controls.handle(pad)
 check(controls.command().tactic==1,"dpad left steps back toward defensive")
 pad.device=94
 check(not controls.handle(pad) and controls.command().action==0,"inactive controller cannot change tactics")
 controls.gamepad=-1
 for code in [KEY_UP,KEY_RIGHT,KEY_W,KEY_A,KEY_S,KEY_D,KEY_E,KEY_C,KEY_SHIFT]:
  key.physical_keycode=code
  key.keycode=code
  key.pressed=true
  Input.parse_input_event(key.duplicate())
  Input.flush_buffered_events()
  var state:Dictionary=controls.command()
  if code==KEY_UP: check(state.move==Vector2.UP,"up arrow supplies movement")
  elif code==KEY_RIGHT: check(state.move==Vector2.RIGHT,"right arrow supplies movement")
  elif code==KEY_E: check(state.sprint and state.move==Vector2.ZERO,"E sprints without moving or passing")
  elif code==KEY_C: check(state.jockey and state.move==Vector2.ZERO,"C jockeys without moving")
  else: check(state.move==Vector2.ZERO and not state.sprint,"action and retired sprint keys do not move the player")
  key.pressed=false
  Input.parse_input_event(key.duplicate())
  Input.flush_buffered_events()

func check_quick_matches()->void:
 var Quick=preload("res://quick_match.gd")
 var Squad=preload("res://squad.gd")
 var Ratings=preload("res://player_ratings.gd")
 var squad_before:Array=Squad.ids.duplicate()
 var all_valid:=true
 var varied:Dictionary={}
 for seed_value in range(1,101):
  var fixture_value:Dictionary=Quick.generate(seed_value)
  all_valid=all_valid and Quick.valid_fixture(fixture_value)
  varied[JSON.stringify(fixture_value.home+fixture_value.away)]=true
 check(all_valid,"100 random fixtures have two valid position-aware lineups and twelve unique players")
 check(varied.size()>95,"new fixture seeds produce varied teams")
 check(Quick.generate(44321)==Quick.generate(44321),"same quick-match seed reproduces lineups")
 check(Squad.ids==squad_before,"random fixtures never change the saved squad")
 var fixture_value:Dictionary=Quick.generate(44321)
 var sim=Match.new()
 var campaign_value=Campaign.new()
 campaign_value.training=[5,5,5,5,5]
 campaign_value.keeper=1
 var before:Dictionary=campaign_value.data().duplicate(true)
 sim.setup(campaign_value,fixture_value.seed,fixture_value.home,fixture_value.away,true)
 check(sim.teams[0].human and not sim.teams[1].human,"quick match defaults to player versus AI")
 var correct_data:=true
 for i in Team.COUNT:
  var ids:Array=fixture_value.home if i<Team.SIZE else fixture_value.away
  correct_data=correct_data and sim.players[i].player_id==ids[i%Team.SIZE] and is_equal_approx(sim.players[i].speed,Ratings.derive(sim.players[i].attributes).speed)
 check(correct_data,"both randomized squads use catalog abilities without campaign or AI speed modifiers")
 var initial=sim.snapshot()
 var replay=Match.new()
 replay.setup(campaign_value,fixture_value.seed,fixture_value.home,fixture_value.away,true)
 check(initial==replay.snapshot(),"same-lineup restart restores the exact starting state")
 sim.freeze=0
 var away_start:Vector2=sim.players[7].pos
 for i in 60: sim.step(1.0/60)
 check(sim.players[7].pos.distance_to(away_start)>0.1,"AI opponent moves without player input")
 check(campaign_value.data()==before,"quick simulation does not alter campaign state")

func check_assistance()->void:
 var s=fixture()
 s.players[1].pos=Vector2.ZERO
 s.players[1].dir=Vector2.RIGHT
 s.players[2].pos=Vector2(10,5)
 s.players[3].pos=Vector2(-12,-10)
 s.players[4].pos=Vector2(-15,10)
 var original_rng:int=s.rng.state
 var low:Dictionary=s.pass_plan(1,Vector2.RIGHT,false,0)
 var normal:Dictionary=s.pass_plan(1,Vector2.RIGHT,false,1)
 var high:Dictionary=s.pass_plan(1,Vector2.RIGHT,false,2)
 check(low.receiver==-1 and low.direction==Vector2.RIGHT,"low assistance respects aim outside its narrow cone")
 check(normal.receiver==2 and high.receiver==2,"standard and high identify nearby aimed teammate")
 var exact:Vector2=s.players[2].pos.normalized()
 check(absf(high.direction.angle_to(exact))<0.001 and absf(normal.direction.angle_to(exact))>0.01,"high snaps fully while standard leaves directional control")
 check(s.rng.state==original_rng and s.passes[0]==0,"drawing pass preview never consumes randomness or performs a pass")
 s.players[1].ratings.pass_error=0.0
 s.teams[0].assist=2
 s.pass_ball(false,Vector2.RIGHT)
 check(s.velocity.normalized().distance_to(high.direction)<0.001 and s.pass_receiver==high.receiver,"actual pass follows the shared preview plan")
 s=fixture()
 s.owner=-1;s.last_touch=2;s.pass_receiver=1;s.kick_age=0.1
 s.ball=Vector2(-6,0);s.velocity=Vector2(10,0)
 s.players[1].pos=Vector2(0,4)
 var p:Vector2=s.players[1].pos
 check(s.assisted_movement(1,Vector2.ZERO,p,0)==Vector2.ZERO,"low assistance never moves selected receiver")
 check(s.assisted_movement(1,Vector2.ZERO,p,1).y<0,"standard moves receiver toward incoming pass")
 check(s.assisted_movement(1,Vector2.RIGHT,p,2).y< -0.2,"manual adjustment keeps high receiving assistance active")
 s.teams[0].assist_active=false
 check(s.assisted_movement(1,Vector2.ZERO,p,2)==Vector2.ZERO,"online menu disabled input cannot auto-run")
 s.teams[0].assist_active=true
 s.switch_player()
 check(s.assisted_movement(1,Vector2.ZERO,p,2)==Vector2.ZERO,"manual switching cancels automatic reception of current pass")
 s.teams[0].receive_cancelled=false
 s.pass_receiver=-1;s.ball=Vector2(1,4)
 check(s.assisted_movement(1,Vector2.ZERO,p,1)==Vector2.ZERO and s.assisted_movement(1,Vector2.ZERO,p,2).length()>0,"only high assistance helps with nearby loose balls")
 s.ball=Vector2(15,4)
 check(s.assisted_movement(1,Vector2.ZERO,p,2)==Vector2.ZERO,"high assistance does not chase distant unrelated balls")
 s.owner=1
 check(s.assisted_movement(1,Vector2.ZERO,p,2)==Vector2.ZERO,"assistance never dribbles automatically after possession")
 s.apply_command(0,{"assist":999})
 s.apply_command(1,{"assist":-999})
 check(s.teams[0].assist==2 and s.teams[1].assist==0,"authority clamps each team's assistance independently")
 var transport=load("res://match_network.gd").new()
 transport.sim=s
 s.pass_receiver=2;s.pass_destination=Vector2(8,3);s.last_touch=1;s.kick_age=0.7
 var state:Dictionary=transport.unpack_state(transport.pack_state(s.snapshot()))
 check(state.teams[0].assist==2 and state.teams[1].assist==0 and state.pass_receiver==2 and state.pass_destination==Vector2(8,3),"network snapshot preserves assistance and pass prediction data")
 transport.free()
 # Compare a real incoming pass with and without automatic reception.
 var received:=[false,false,false]
 for level in 3:
  s=fixture()
  for i in Team.COUNT:
   s.players[i].pos=Vector2(-28 if i<Team.SIZE else 28,-16+i*3)
   s.players[i].cooldown=0
  s.owner=-1;s.last_touch=2;s.pass_receiver=1;s.kick_age=0.1
  s.ball=Vector2(-6,0);s.velocity=Vector2(10,0);s.ball_height=0.48
  s.players[1].pos=Vector2(0,4);s.teams[0].assist=level
  for frame_value in 100:
   s.step(1.0/60)
   if s.owner==1: received[level]=true;break
 check(not received[0] and received[1] and received[2],"standard and high receivers actually collect a pass while low requires movement")

func check_ball_and_keeper()->void:
 var Physics=load("res://ball_physics.gd")
 var input_value=load("res://football_input.gd").new()
 for keyboard in [true,false]:
  var event:InputEvent
  if keyboard:
   event=InputEventKey.new();event.physical_keycode=KEY_Z;event.keycode=KEY_Z
  else:
   event=InputEventJoypadButton.new();event.device=93;event.button_index=JOY_BUTTON_RIGHT_SHOULDER
   input_value.gamepad=93
  event.pressed=true
  Input.parse_input_event(event.duplicate());Input.flush_buffered_events()
  check(input_value.command().finesse,"keyboard Z and Xbox RB request finesse modifier")
  event.pressed=false
  Input.parse_input_event(event.duplicate());Input.flush_buffered_events()
 var paths:Array=[]
 for spin in [-3.0,0.0,3.0]:
  var flight:Dictionary={"pos":Vector2.ZERO,"velocity":Vector2(25,0),"height":Physics.FLOOR,"vertical":6.0,"spin":spin}
  var peak:float=flight.height
  for i in 90:
   flight=Physics.advance(flight.pos,flight.velocity,flight.height,flight.vertical,flight.spin,true,1.0/60)
   peak=maxf(peak,flight.height)
   check(flight.height>=Physics.FLOOR,"ball never penetrates ground") if i==89 else null
  check(peak>1.4 and flight.height<peak,"gravity creates an arc and brings ball down")
  check(flight.velocity.length()<25 and absf(flight.spin)<=absf(spin),"drag, bounce and spin decay lose energy")
  paths.append(flight.pos)
 check(paths[0].y < -1 and absf(paths[1].y)<0.001 and paths[2].y>1,"opposite spins produce mirrored curves; zero spin stays straight")
 check(paths[0].distance_to(Vector2(paths[2].x,-paths[2].y))<0.001,"spin simulation is symmetric")
 var s=fixture()
 s.charge=0.6;s.shoot(0.5,true)
 check(absf(s.ball_spin)>2 and s.vertical_speed>4,"finesse shot creates airborne spin")
 var transport=load("res://match_network.gd").new()
 transport.sim=s
 s.players[0].action="dive";s.players[0].keeper_side=-1;s.players[0].keeper_height=1.5
 var wire:Dictionary=transport.pack_state(s.snapshot())
 var decoded:Dictionary=transport.unpack_state(wire)
 check(absf(decoded.spin-s.ball_spin)<0.001 and decoded.players[0].action=="dive" and decoded.players[0].keeper_side==-1,"network preserves curve and keeper animation state")
 check(var_to_bytes(wire).size()<1200,"expanded physics snapshot remains below MTU budget")
 transport.free()
 for team in 2:
  s=fixture()
  var index:int=team*Team.SIZE
  var sign_value:float=s.side(team)
  s.owner=-1;s.ball=Vector2(-19*sign_value,2);s.velocity=Vector2(-30*sign_value,0)
  s.last_touch=(1-team)*Team.SIZE+1
  s.players[index].cooldown=0
  s.ball_height=1;s.ball_is_shot=true;s.kick_age=0.3
  var target:Vector2=s.keeper_target(index)
  check(s.players[index].action in s.Motion.DIVES and target.y>1 and s.players[index].keeper_cd>0,"both goalkeepers anticipate and commit to off-centre shots")
  s.players[index].action_time=0
  s.players[index].dir=Vector2(sign_value,0)
  s.move_player(index,0.1,Vector2.DOWN,false,false)
  check(s.players[index].dir.dot((s.ball-s.players[index].pos).normalized())>0.95,"keeper shuffles while facing ball on both ends")
 s=fixture()
 s.owner=0;s.players[0].cooldown=0.5
 s.ai_direction(0)
 check(s.owner==0,"AI keeper settles the ball before distribution")
 s.players[0].cooldown=0
 s.ai_direction(0)
 check(s.owner==-1 and s.players[0].action=="pass" and s.ball_height==Physics.FLOOR,"AI keeper distributes ordinary possession with feet")

func check_rosters_and_ratings()->void:
 var Squad=preload("res://squad.gd")
 var Library=preload("res://player_library.gd")
 var Ratings=preload("res://player_ratings.gd")
 var roster:Array=Squad.DEFAULT.duplicate()
 check(Squad.valid(roster),"default six-player lineup is valid")
 check(not Squad.valid(["bad-id"]),"malformed roster rejected")
 roster[0]=roster[1]
 check(not Squad.valid(roster),"duplicate and missing keeper rejected")
 roster=Squad.DEFAULT.duplicate()
 roster[1]="legend-courtois"
 check(not Squad.valid(roster),"keepers cannot enter outfield slots")
 var all_usable:=true
 for record in Library.all():
  roster=Squad.DEFAULT.duplicate()
  var slot:=0 if record.role=="GK" else 1
  var previous:int=roster.find(record.id)
  if previous>=0: roster[previous]=roster[slot]
  roster[slot]=record.id
  var match_value=Match.new()
  match_value.setup(Campaign.new(),32,roster,Squad.DEFAULT,true)
  all_usable=all_usable and match_value.players[slot].player_id==record.id and match_value.players[slot].attributes==record.attributes and match_value.players[slot].body.height_cm==record.heightCm
 check(all_usable,"all 386 players enter matches with authentic attributes and height")
 var previous_path:String=Squad.save_path
 var previous_ids:Array=Squad.ids.duplicate()
 Squad.save_path="user://roster-unit-test.json"
 Squad.ids=Squad.DEFAULT.duplicate()
 check(Squad.assign_player("legend-mbappe",1),"new starter saves")
 Squad.ids=Squad.DEFAULT.duplicate()
 Squad.load_squad()
 check(Squad.ids[1]=="legend-mbappe","lineup survives save and reload")
 check(Squad.assign_player("legend-messi",1) and Squad.ids[2]=="legend-mbappe","existing starter swaps positions without duplicates")
 check(not Squad.assign_player("legend-messi",0),"illegal keeper assignment preserves lineup")
 Squad.ids=previous_ids
 Squad.save_path=previous_path
 var low:Dictionary={}
 var high:Dictionary={}
 for key in Ratings.ACTIVE: low[key]=20;high[key]=95
 var weak:=Ratings.derive(low)
 var strong:=Ratings.derive(high)
 var a=fixture()
 var b=fixture()
 a.owner=-1;b.owner=-1
 a.players[1].ratings=weak;b.players[1].ratings=strong
 a.players[1].speed=weak.speed;b.players[1].speed=strong.speed
 a.move_player(1,0.1,Vector2.RIGHT,true,false)
 b.move_player(1,0.1,Vector2.RIGHT,true,false)
 check(b.players[1].vel.length()>a.players[1].vel.length(),"acceleration changes actual movement")
 check(b.players[1].stamina>a.players[1].stamina,"endurance changes actual sprint drain")
 for i in 60:
  a.move_player(1,1.0/60,Vector2.RIGHT,false,false)
  b.move_player(1,1.0/60,Vector2.RIGHT,false,false)
 check(b.players[1].vel.length()>a.players[1].vel.length(),"pace changes sustained running speed")
 a=fixture();b=fixture()
 a.players[1].ratings=weak;b.players[1].ratings=strong
 a.kick(1,Vector2(25,0),23,false)
 b.kick(1,Vector2(25,0),23,false)
 check(absf(b.velocity.angle())<absf(a.velocity.angle()),"passing reduces seeded angular error")
 a=fixture();b=fixture()
 a.players[1].ratings=weak;b.players[1].ratings=strong
 a.shoot();b.shoot()
 check(absf(b.velocity.angle())<absf(a.velocity.angle()) and b.velocity.length()>a.velocity.length(),"finishing and long shots influence actual shots")
 for pair in [["control",true],["stride",true],["tackle_reach",false],["keeper_radius",false],["keeper_anticipation",false],["keeper_hold",false]]:
  check(strong[pair[0]]<weak[pair[0]] if pair[1] else strong[pair[0]]>weak[pair[0]],"rating curve: "+pair[0])
 var c=Campaign.new()
 c.training=[5,5,5,5,5];c.keeper=1
 a=Match.new();a.setup(c,42,Squad.DEFAULT,Squad.DEFAULT,true)
 check(a.players[1].speed==a.players[7].speed and a.players[0].speed==a.players[6].speed,"online excludes all campaign bonuses")
 var Network=preload("res://match_network.gd")
 var net=Network.new()
 net.sim=a
 var roundtrip:Dictionary=net.unpack_state(net.pack_state(a.snapshot()))
 check(roundtrip.players[1].attributes==a.players[1].attributes and roundtrip.players[1].ratings==a.players[1].ratings,"network preserves trusted abilities")
 net.prediction_index=1;net.prediction_pos=a.players[1].pos;net.prediction_vel=Vector2.ZERO
 a.owner=-1
 var move:={"move":Vector2.RIGHT,"sprint":false,"jockey":false}
 net._predict(move,1.0/60)
 a.move_player(1,1.0/60,Vector2.RIGHT,false,false)
 check(net.prediction_pos.is_equal_approx(a.players[1].pos),"client and server use identical acceleration curves")
 net.free()

func check(condition: bool, label: String) -> void:
 if not condition:
  push_error("TEST FAILED: "+label)
  failures+=1
 checks+=1

func check_body_profiles()->void:
 var Library=preload("res://player_library.gd")
 var definitions:=Library.all()
 check(definitions.size()==386,"complete illustrated catalog is available in Godot")
 check(definitions.all(func(p): return p.attributes.size()==26 and p.attributes.values().all(func(v): return typeof(v) in [TYPE_INT,TYPE_FLOAT])),"all 26 numeric attributes survive Godot loading")
 check(definitions.all(func(p): return ResourceLoader.exists(p.portrait)),"every catalog portrait resolves inside this project")
 var Body=preload("res://player_body.gd")
 var small:=Body.profile(2)
 var tall:=Body.profile(1)
 check(small.height_cm==170 and tall.height_cm==195,"body height comes from the catalog")
 check(is_equal_approx(tall.height/small.height,195.0/170),"visual height preserves real relative scale")
 check(tall.body_radius>small.body_radius,"larger frame occupies more horizontal space")
 check(tall.leg_length/tall.height>small.leg_length/small.height,"leg proportions are independently authored")
 check(Body.contact_zone(small,0.5)=="foot","low ball can be controlled with feet")
 check(Body.contact_zone(small,small.chest_height)=="chest","chest zone does not become foot pickup")
 check(Body.contact_zone(small,tall.head_height)=="none","ball above shorter player's head clears them")
 check(Body.contact_zone(tall,tall.head_height)=="head","same ball intersects taller player's head")
 check(Body.contact_zone(small,small.head_height+small.jump_height)=="none","jump potential grants no standing reach")
 check(Body.contact_zone(small,small.head_height+small.jump_height,small.jump_height)=="head","actual vertical displacement moves head contact zone")
 for slot in [1,2]:
  var s=fixture()
  for p in s.players:
   p.pos=Vector2(-25,15)
   p.cooldown=10
  s.players[slot].pos=Vector2.ZERO
  s.players[slot].cooldown=0
  s.selected=slot
  s.owner=-1
  s.ball=Vector2.ZERO
  s.ball_height=tall.head_height+0.18
  s.velocity=Vector2(3,0)
  s.last_touch=7
  s.step(1.0/60.0)
  check(s.owner==-1,"high contact never teleports ball into dribbling possession")
  check(s.last_touch==slot if slot==1 else s.last_touch==7,"authority uses height to distinguish head contact from clearance")
 var network_script=preload("res://match_network.gd")
 var net=network_script.new()
 var source=fixture()
 net.sim=source
 var decoded:Dictionary=net.unpack_state(net.pack_state(source.snapshot()))
 check(decoded.players[1].body==source.players[1].body,"compact network updates retain static body profiles")
 net.free()

func fixture(stage: int=0):
 var c=Campaign.new()
 c.stage=stage
 var s=Match.new()
 s.setup(c,451)
 s.freeze=0
 return s

func _initialize() -> void:
 await process_frame
 preload("res://teamplay_tests.gd").new().run(self)
 preload("res://ai_style_tests.gd").new().run(self)
 preload("res://contact_keeper_tests.gd").new().run(self)
 preload("res://motion_tests.gd").new().run(self)
 preload("res://locomotion_tests.gd").new().run(self)
 preload("res://rules_tests.gd").new().run(self)
 check_ball_and_keeper()
 check_assistance()
 check_six_a_side()
 check_core_v2()
 check_body_profiles()
 check_rosters_and_ratings()
 check_quick_matches()
 var c=Campaign.new()
 c.save_path="user://model-test-save.json"
 check(c.train(0) and c.credits==180 and c.training[0]==1,"training spends correct credits")
 check(not c.train(0) and c.credits==180,"insufficient funds are not spent")
 check(not c.recruit(),"keeper purchase requires funds")
 check(c.save_game(),"atomic save succeeds")
 var loaded=Campaign.new()
 loaded.save_path=c.save_path
 check(loaded.load_game() and loaded.data()==c.data(),"save/load round trip")
 var file:=FileAccess.open(c.save_path,FileAccess.WRITE)
 file.store_string('{"version":1,"training":["broken",0,0]}')
 file.close()
 check(not loaded.load_game(),"invalid save is rejected without partial mutation")
 var loss: Dictionary=c.finish([0,2])
 check(not loss.won and c.stage==0 and c.credits==280,"loss rewards retry without advancing")
 var draw: Dictionary=c.finish([1,1])
 check(not draw.won and c.stage==0,"draw does not advance")
 for i in 3: c.finish([2,1])
 check(c.stage==3 and c.wins==3,"three victories complete campaign")
 check(c.recruit() and not c.recruit(),"recruitment can only be purchased once")
 var s=fixture()
 var initial: Vector2=s.players[1].pos
 s.tick(0.1,Vector2.RIGHT)
 check(s.players[1].pos.x>initial.x,"controlled movement works")
 check(s.elapsed>0,"clock advances")
 s.freeze=2
 var before: float=s.elapsed
 s.tick(0.1,Vector2.RIGHT)
 check(s.elapsed==before,"kickoff pause freezes match clock")
 s.freeze=0
 s.do_dash()
 check(s.energy<100 and s.dash>0,"dash consumes energy")
 var energy: float=s.energy
 s.do_dash()
 check(s.energy==energy,"dash cooldown prevents repeat spending")
 s.overdrive()
 check(s.teams[0].jockey and s.energy==energy,"jockey replaces the arcade team ability")
 s=fixture()
 s.start_charge()
 s.tick(0.3,Vector2.ZERO)
 check(s.charge>0.1,"charge grows while held")
 s.shoot(-1)
 check(s.owner==-1 and s.velocity.x>0 and s.velocity.y<0 and s.shots[0]==1,"aimed shooting releases ball")
 s=fixture()
 s.pass_ball()
 check(s.owner==-1 and s.selected!=1 and s.passes[0]==1,"pass selects teammate")
 s=fixture()
 s.owner=-1
 s.ball=Vector2(Pitch.HALF_LENGTH-0.2,1)
 s.velocity=Vector2(35,0)
 s.tick(0.05,Vector2.ZERO)
 check(s.score==[1,0] and s.phase=="goal" and s.owner==-1,"goal enters celebration before opponent kickoff")
 s.step(s.Rules.GOAL_DURATION+0.1)
 check(s.phase=="restart" and s.restart_team==1 and s.owner==-1,"celebration ends with opponent kickoff")
 s=fixture()
 s.owner=-1
 s.ball=Vector2(-Pitch.HALF_LENGTH+0.2,1)
 s.velocity=Vector2(-35,0)
 s.tick(0.05,Vector2.ZERO)
 check(s.score==[0,1] and s.phase=="goal","opponent goal celebration")
 s.step(s.Rules.GOAL_DURATION+0.1)
 check(s.phase=="restart" and s.restart_team==0 and s.owner==-1,"opponent celebration ends with home kickoff")
 s=fixture()
 s.owner=-1
 s.ball=Vector2(Pitch.HALF_LENGTH-0.2,12)
 s.velocity=Vector2(35,0)
 s.tick(0.05,Vector2.ZERO)
 check(s.score==[0,0] and s.restart_kind=="goal_kick" and s.restart_taker==6 and s.owner==-1,"wide shot awards opponent goal kick")
 s=fixture()
 s.elapsed=100
 s.tick(0.02,Vector2.ZERO)
 check(s.overtime and not s.finished,"tie enters golden goal")
 s.owner=-1
 s.ball=Vector2(Pitch.HALF_LENGTH-0.2,1)
 s.velocity=Vector2(35,0)
 s.tick(0.05,Vector2.ZERO)
 check(not s.finished and s.phase=="goal" and s.score[0]==1,"overtime goal celebrates first")
 s.step(s.Rules.GOAL_DURATION+0.1)
 check(s.finished,"overtime goal ends match after celebration")
 s=fixture()
 s.elapsed=100
 s.tick(0.02,Vector2.ZERO)
 s.elapsed=130
 s.tick(0.02,Vector2.ZERO)
 check(s.finished and s.score==[0,0],"scoreless overtime ends in retry draw")
 s=fixture(1)
 s.arcade=true
 s.elapsed=13
 s.owner=-1
 s.ball=Vector2(0,15)
 s.velocity=Vector2(1,0)
 s.tick(0.02,Vector2.ZERO)
 check(s.wind_active() and s.velocity.y>0,"solar wind changes free-ball trajectory")
 # Unforced full matches ensure the AI and ball cannot deadlock.
 var total_goals:=0
 for stage in 3:
  var results:=[]
  for seed_value in range(1,5):
   var cc=Campaign.new()
   cc.stage=stage
   s=Match.new()
   s.setup(cc,seed_value)
   s.human=false
   for tick in 15000:
    s.tick(1.0/60,Vector2.ZERO)
    if s.finished: break
   check(s.finished,"AI fixture terminates")
   total_goals+=s.score[0]+s.score[1]
   results.append(s.score)
  print("BALANCE stage=",stage," scores=",results)
 check(total_goals>0,"AI can score in unforced play")
 # A command-driving player can move, charge, aim and win without forced scores.
 var pilot_goals:=0
 for stage in 3:
  s=fixture(stage)
  # Difficulty no longer changes hidden run speed; exercise distinct shot seeds.
  s.rng.seed=451+stage*137
  # Stop-clock play can include ten goals and complete retrieval/restart scenes.
  # Bound total simulated time to 400 s; the former 250 s budget expired at 91 s
  # of the 100 s match, despite every restart progressing normally.
  for tick in 24000:
   var move:=Vector2.ZERO
   var p: Dictionary=s.players[s.selected]
   if s.owner==s.selected:
    move=Vector2(1,0)
    if p.pos.x>Pitch.HALF_LENGTH-15:
     if not s.charging: s.start_charge()
     if s.charge>0.60: s.shoot(-0.85 if s.players[6].pos.y>0 else 0.85)
    elif s.dash_cd<=0: s.do_dash()
   else:
    if tick%30==0: s.switch_player()
    move=(s.ball-s.players[s.selected].pos).normalized()
   s.tick(1.0/60,move)
   if s.finished: break
  check(s.finished,"command-driven fixture terminates")
  pilot_goals+=s.score[0]
  print("PILOT stage=",stage," score=",s.score," shots=",s.shots)
 check(pilot_goals>0,"command-driven player can score naturally")
 if failures==0: print("MODEL_TESTS_PASS checks=",checks," total_AI_goals=",total_goals)
 else: print("MODEL_TESTS_FAILED failures=",failures)
 quit(0 if failures==0 else 1)

func check_six_a_side() -> void:
 var s=fixture()
 check(s.players.size()==Team.COUNT,"twelve players in match")
 check(s.players.filter(func(p):return p.team==0).size()==Team.SIZE and s.players.filter(func(p):return p.team==1).size()==Team.SIZE,"six per team")
 check(s.players.filter(func(p):return p.slot==0).size()==2,"exactly two keepers")
 check(s.players[4].name=="范戴克" and s.players[4].team==0 and s.players[6].team==1,"defender and away keeper are on correct teams")
 check(s.players[4].pos.x<s.players[2].pos.x and s.players[10].pos.x>s.players[8].pos.x,"mirrored covering defenders")
 s.ball=s.players[4].pos
 s.switch_player()
 check(s.selected==4,"new defender can be selected")
 s.selected=1
 s.players[4].pos=Vector2(6,10)
 s.pass_ball()
 check(s.selected==4 and s.pass_receiver==4,"pass targets new defender")
 s=fixture()
 s.owner=4
 s.selected=4
 s.players[4].pos=Vector2(0,8)
 s.ball=s.players[4].pos
 s.tick(0.1,Vector2.RIGHT)
 check(s.players[4].pos.x>0 and s.possession[0]>0 and s.possession[1]==0,"defender movement and home possession")
 s.start_charge()
 s.shoot(1)
 check(s.owner==-1 and s.shots==[1,0],"defender shot counts for home team")
 s=fixture()
 s.owner=10
 s.kick(10,Vector2(-33,3),30,true)
 check(s.shots==[0,1],"away defender shot counts for away team")
 s=fixture()
 s.owner=2
 s.ball=Vector2(12,-8)
 s.players[4].pos=Vector2(6,10)
 check(s.ai_direction(4).x<0,"defender holds behind attack")
 var c=Campaign.new()
 check(c.train(3) and c.training==[0,0,0,1,0],"new defender can train independently")
 c.save_path="user://five-a-side-migration-test.json"
 var old:=c.data()
 old.version=1
 old.training=[2,1,3]
 old.stage=2
 old.credits=720
 old.keeper=1
 var file:=FileAccess.open(c.save_path,FileAccess.WRITE)
 file.store_string(JSON.stringify(old))
 file.close()
 check(c.load_game() and c.training==[2,1,3,0,0],"four-a-side save gains untrained defender and midfielder")
 check(c.stage==2 and c.credits==720 and c.keeper==1,"migration preserves progress and purchases")
 check(c.save_game(),"migrated save writes successfully")
 var loaded=Campaign.new()
 loaded.save_path=c.save_path
 check(loaded.load_game() and loaded.data()==c.data(),"six-a-side save reloads migrated progress")


func check_core_v2()->void:
 var s=fixture()
 var first:Vector2=s.players[1].pos
 s.tick(1.0/60,Vector2.RIGHT)
 check(s.players[1].vel.x>0 and s.players[1].vel.x<s.players[1].speed,"movement accelerates instead of teleporting to maximum speed")
 for i in 30: s.tick(1.0/60,Vector2.RIGHT)
 var running:float=s.players[1].vel.length()
 s.tick(1.0/60,Vector2.LEFT)
 check(s.players[1].vel.x>0,"reversal preserves momentum briefly")
 for i in 30: s.tick(1.0/60,Vector2.ZERO)
 check(s.players[1].vel.length()<0.1,"release input brakes to a stop")
 s=fixture()
 s.teams[1].human=true
 s.apply_command(1,{"move":Vector2.LEFT,"sprint":true,"action":0})
 var away:Vector2=s.players[7].pos
 s.step(0.1)
 check(s.players[7].pos.x<away.x and s.players[7].stamina<100,"away team moves independently and consumes stamina")
 check(s.teams[0].selected==1 and s.teams[1].selected==7,"independent selected players")
 s.view_team=1
 s.owner=7
 s.start_charge()
 s.charge=0.5
 s.shoot(1)
 check(s.velocity.x<0 and s.shots==[0,1],"away team shoots toward left goal")
 s=fixture()
 s.owner=-1
 s.last_touch=1
 s.ball=Vector2(0,Pitch.HALF_WIDTH-0.05)
 s.velocity=Vector2(0,15)
 s.tick(0.05,Vector2.ZERO)
 check(s.restart_kind=="kick_in" and s.restart_team==1 and s.owner==-1,"touchline exit awards opponent kick-in")
 s=fixture()
 s.owner=-1
 s.last_touch=10
 s.ball=Vector2(Pitch.HALF_LENGTH-0.05,10)
 s.velocity=Vector2(15,0)
 s.tick(0.05,Vector2.ZERO)
 check(s.restart_kind=="corner" and s.restart_team==0 and s.owner==-1,"defensive last touch awards attacking corner")
 s=fixture()
 s.arcade=true
 s.owner=-1
 s.ball=Vector2(Pitch.HALF_LENGTH-0.05,10)
 s.velocity=Vector2(15,0)
 s.tick(0.05,Vector2.ZERO)
 check(s.velocity.x<0,"arcade rule retains energy-wall bounce")
 s=fixture()
 s.owner=7
 s.players[1].pos=Vector2(0,0)
 s.players[1].dir=Vector2.RIGHT
 s.players[7].pos=Vector2(1.5,0)
 s.ball=Vector2(1.5,0)
 s.tackle(1)
 check(s.owner==7 and s.players[1].action=="tackle","standing tackle has a contact preparation phase")
 s.players[1].action_time=s.Motion.TACKLE_DURATION-0.10;s.resolve_tackle(1,false)
 check(s.owner==-1 and s.tackles==[1,0] and s.players[1].tackle_cd>0,"manual facing tackle releases ball and enters recovery")
 var cooldown:float=s.players[1].tackle_cd
 s.tackle(1)
 check(s.players[1].tackle_cd==cooldown,"recovery prevents tackle spam")
 s=fixture()
 s.players[1].pos=Vector2(-15,0)
 s.players[1].dir=Vector2.LEFT
 s.tackle(1)
 check(s.players[1].action!="tackle" and s.owner==1,"tackling while in possession is ignored")
 var snapshot:Dictionary=s.snapshot()
 var copy=Match.new()
 copy.restore(snapshot)
 check(copy.snapshot()==snapshot,"authoritative snapshot round trip")
 copy.players[1].pos+=Vector2(1,0)
 check(copy.players[1].pos!=s.players[1].pos,"snapshots do not alias authoritative player state")
 var input=load("res://football_input.gd").new()
 var joy:=InputEventJoypadButton.new()
 # DesktopInput selects one source explicitly; FootballInput never polls an arbitrary first pad.
 input.gamepad=joy.device
 input.sync_context(1,1,1)
 joy.button_index=JOY_BUTTON_B
 joy.pressed=true
 check(input.handle(joy) and int(input.command().action)==1,"gamepad B starts shot charge in possession")
 joy.pressed=false
 input.handle(joy)
 check(int(input.command().action)==2,"gamepad B release shoots")
 joy.pressed=true
 joy.button_index=JOY_BUTTON_A
 input.handle(joy)
 joy.pressed=false;input.handle(joy);joy.pressed=true
 check(int(input.command().action)==4,"gamepad A release passes")
 joy.button_index=JOY_BUTTON_Y
 input.handle(joy)
 joy.pressed=false;input.handle(joy);joy.pressed=true
 check(int(input.command().action)==8,"gamepad Y release plays through ball")
 joy.button_index=JOY_BUTTON_B
 input.sync_context(1,6,1)
 input.handle(joy)
 check(int(input.command().action)==32,"gamepad B tackles")
 joy.button_index=JOY_BUTTON_LEFT_SHOULDER
 input.handle(joy)
 check(int(input.command().action)==16,"gamepad shoulder switches player")
 check(int(input.command().action)==0,"input action only consumed once")
 check_classic_controls()

 # Network packets stay below a normal MTU, retain side ownership, and preserve movement.
 var transport=load("res://match_network.gd").new()
 transport.sim=s
 var wire:Dictionary=transport.pack_state(s.snapshot())
 check(var_to_bytes(wire).size()<1200,"state snapshot stays below MTU budget")
 var decoded:Dictionary=transport.unpack_state(wire)
 check(decoded.players[1].pos.distance_to(s.players[1].pos)<0.001 and decoded.teams[0].selected==s.teams[0].selected,"compact snapshot preserves player and team state")
 transport.free()
 s=fixture()
 s.players[1].pos=Vector2(Pitch.PLAYER_LIMIT.x,0)
 s.players[1].dir=Vector2.RIGHT
 s.players[1].touch=0.9
 s.ball=Vector2(Pitch.HALF_LENGTH+0.1,0)
 s.tick(0.01,Vector2.ZERO)
 check(s.score[0]==0,"partly crossed carried ball does not yet score")
 s.ball=Vector2(Pitch.HALF_LENGTH+0.5,0)
 s.tick(0.01,Vector2.ZERO)
 check(s.score[0]==1,"whole carried ball crossing goal line scores")
 s=fixture()
 s.players[1].pos=Vector2(0,Pitch.PLAYER_LIMIT.y)
 s.players[1].dir=Vector2.DOWN
 s.ball=Vector2(0,Pitch.HALF_WIDTH+0.2)
 s.tick(0.01,Vector2.ZERO)
 check(s.restart_kind=="kick_in" and s.restart_team==1 and s.owner==-1,"carried ball crossing touchline awards kick-in")
