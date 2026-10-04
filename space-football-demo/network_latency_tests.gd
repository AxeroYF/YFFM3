extends SceneTree
const Match=preload("res://match_sim.gd")
const Command=preload("res://network_command.gd")
const Timeline=preload("res://network_timeline.gd")
const Prediction=preload("res://network_prediction.gd")
const Snapshots=preload("res://network_snapshots.gd")
const Link=preload("res://network_link.gd")
const Fragments=preload("res://network_fragments.gd")
const Network=preload("res://match_network.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures+=1;push_error("NETWORK_LATENCY_FAILED "+label)
func fixture():
 var s=Match.new();s.setup(preload("res://campaign.gd").new(),719,Match.Squad.DEFAULT,Match.Squad.DEFAULT,true)
 s.freeze=0;s.phase="play";s.owner=1;s.ball=Vector2(0.8,0);s.velocity=Vector2.ZERO;s.duration=1000
 for team in 2: s.teams[team].human=true;s.teams[team].selected=team*6+1;s.teams[team].assist_active=false
 for i in 12:
  s.players[i].pos=Vector2(-25+i*4,15);s.players[i].vel=Vector2.ZERO;s.players[i].cooldown=0;s.players[i].dir=Vector2.RIGHT
 s.players[1].pos=Vector2.ZERO
 return s
func sample(s,seq:int,action:int=0,aid:int=0)->Dictionary:
 return Command.bind(s,0,{"action":action,"move":Vector2.ZERO,"sprint":false,"jockey":false,"aim":0.0,"tactic":1,"assist_active":false},seq,aid)
func codec_tests()->void:
 var s=fixture();var c:=sample(s,1,4,1);c.move=Vector2(4,5)
 var wire:=Command.encode(c);var decoded:=Command.decode(wire)
 check(decoded.move.length()<=1.00001 and decoded.player==1 and decoded.action_id==1,"numeric command bounds movement and binds actor")
 for index in Command.WIDTH:
  var corrupt:=wire.duplicate();corrupt[index]=NAN
  check(Command.decode(corrupt).is_empty(),"reject nonfinite field "+str(index))
 for index in [0,1,2,3,4,5,12,13,14,15,16,17,18,19]:
  var corrupt:=wire.duplicate();corrupt[index]+=0.5
  check(Command.decode(corrupt).is_empty(),"reject fractional identity/flags "+str(index))
 check(Command.decode(PackedFloat32Array()).is_empty(),"reject truncated sample")
 check(Command.matches(s,0,c) and not Command.matches(s,1,c),"team ownership cannot be forged")
 s.teams[0].selected=2
 check(not Command.matches(s,0,c),"old player's queued action cannot operate new selection")
 s.teams[0].selected=1;s.players[1].sub_revision+=1
 check(not Command.matches(s,0,c),"old roster revision cannot operate substitute")
func timeline_tests()->void:
 var s=fixture();var timeline=Timeline.new()
 var start:=sample(s,1,1,1);var release:=sample(s,21,2,2)
 timeline.receive(start,0);timeline.receive(release,0);timeline.receive(release,0)
 check(timeline.tick(0).move==Vector2.ZERO and timeline.cursor==0,"small authority input buffer")
 timeline.tick(1)
 for frame in range(2,35):
  var c:Dictionary=timeline.tick(frame)
  s.apply_command(0,c)
  for action in timeline.ready_actions(): timeline.apply_action(s,0,action)
  s.step(1.0/60)
 check(timeline.applied==2 and timeline.action_ack==2 and s.shots[0]==1,"out of order redundant shot edges execute exactly once")
 check(absf(s.players[1].action_strength-0.4)<0.01,"held shot power uses captured ticks")
 timeline.receive(release,35)
 check(timeline.ready_actions().is_empty(),"reliable fallback duplicate cannot shoot again")
 var old:=sample(s,1,32,3)
 timeline.receive(old,35)
 check(timeline.ready_actions().is_empty(),"expired input cannot tackle later")
 timeline=Timeline.new();var moving:=sample(s,1);moving.move=Vector2.RIGHT;moving.sprint=true;moving.keeper_rush=true
 timeline.receive(moving,0)
 var stopped:Dictionary={}
 for frame in 23: stopped=timeline.tick(frame)
 check(stopped.move==Vector2.ZERO and not stopped.sprint and not stopped.keeper_rush and not stopped.assist_active,"lost uplink releases held controls after 300ms")
 check(not timeline.receive(sample(s,9999),24),"future sample window is bounded")
 timeline=Timeline.new();var wrong:=sample(s,1,32,1);s.teams[0].selected=2
 check(not timeline.apply_action(s,0,wrong) and s.players[2].tackle_cd==0,"late tackle cannot transfer to switched player")
func prediction_tests()->void:
 var s=fixture();var prediction=Prediction.new();prediction.reset(s.snapshot(),0)
 var c:=sample(s,1);c.move=Vector2.RIGHT
 prediction.step(c,1.0/60)
 check(prediction.sim.players[1].pos.x>0 and s.players[1].pos==Vector2.ZERO,"local movement appears before server reply")
 prediction.step(sample(s,2,1,1),1.0/60)
 check(prediction.sim.charging and prediction.sim.players[1].action=="windup" and not s.charging,"windup is immediate and isolated")
 prediction.step(sample(s,3,2,2),1.0/60)
 for i in 5: prediction.step(sample(s,4+i),1.0/60)
 check(prediction.sim.owner<0 and s.owner==1 and s.shots[0]==0,"private kick release cannot alter authority possession or score")
 check(prediction.ball_visible,"uncontested early kick has a local ball preview")
 var flight_state:Dictionary=prediction.sim.snapshot();flight_state.kick_age=1.0
 prediction.reset(flight_state,0);prediction.step(sample(prediction.sim,12),1.0/60)
 check(prediction.ball_visible,"flight preview bound measures time since snapshot, not total shot age")
 for i in 17: prediction.step(sample(prediction.sim,13+i),1.0/60)
 check(not prediction.ball_visible,"unconfirmed ball extrapolation stops after 250ms")
 prediction.reset(s.snapshot(),0)
 check(prediction.sim.owner==1 and prediction.sim.players[1].pos==s.players[1].pos,"rejected prediction rebases to authority")
 prediction.step(sample(s,1,16,1),1.0/60)
 check(prediction.index()!=1 and s.selected==1,"selection responds locally without authority mutation")
 prediction.reset(s.snapshot(),0);s.owner=-1
 prediction.reset(s.snapshot(),0)
 prediction.step(sample(s,1,512,1),1.0/60)
 check(prediction.sim.players[1].action in ["slide","slide_still"] and s.players[1].tackle_cd==0,"slide animation predicts without awarding tackle")
 # A snapshot received between button release and foot contact preserves the release.
 s=fixture();s.apply_command(0,{"action":4,"move":Vector2.RIGHT})
 var network=Network.new();network.sim=s
 var restored:=network.unpack_state(network.pack_state(s.snapshot()))
 check(not restored.mechanics.releases[0].is_empty() and restored.mechanics.clock==s.mechanics.clock,"compact wire carries scheduled foot contact")
 prediction.reset(restored,0)
 for i in 8: prediction.step(sample(s,i+1),1.0/60)
 check(prediction.sim.owner<0 and s.owner==1,"confirmed pending release survives reconciliation")
 network.free()
func interpolation_tests()->void:
 var s=fixture();var ring=Snapshots.new()
 for frame in [0,2,4,8,10]:
  s.frame=frame;s.players[7].pos=Vector2(frame,0);s.ball=Vector2(frame,0)
  ring.push(s.snapshot(),int(frame*1000.0/60)+frame%3*8)
 var received:int=ring.received;ring.push(s.snapshot(),500)
 check(ring.received==received and ring.gaps==1,"discard duplicate snapshots and count sequence gaps")
 var previous:float=ring.playhead
 for i in 30:
  ring.advance(1.0/60)
  check(ring.playhead>=previous and ring.playhead<=13,"bounded monotonic playback")
  previous=ring.playhead
 check(ring.player(7,s.players[7]).pos.x<=10.01 and ring.ball(Vector3.ZERO).x<=10,"stale remote ball cannot predict a goal")
 s.frame=12;s.phase="goal";ring.push(s.snapshot(),550)
 check(ring.frames.size()==1,"rule transition resets interpolation across discontinuity")
 for i in range(14,80,2): s.frame=i;ring.push(s.snapshot(),i*17)
 check(ring.frames.size()<=12,"snapshot ring stays bounded")
func link_tests()->void:
 var link=Link.new();link.configure(100,25,4,5,17)
 for i in 120: link.send("action" if i%3==0 else "state",1,[i],i%3==0,0)
 var ready:Array=link.take(1000);var reliable:=0
 for item in ready:
  if item.kind=="action": reliable+=1
 check(reliable==40 and link.dropped>0 and link.retried>0,"fault model delays reliable retries and drops unreliable packets")
 check(link.queue.is_empty(),"scheduler drains all due packets")
 link.reset();check(link.queue.is_empty() and link.sent==0,"new round clears delayed old traffic")
 var bytes:=PackedByteArray();bytes.resize(4200)
 for i in bytes.size(): bytes[i]=i%251
 var parts:=Fragments.split(bytes);var assembler=Fragments.new()
 var rebuilt:=PackedByteArray()
 for i in [3,0,0,4,2,1]: rebuilt=assembler.accept(12,i,parts.size(),parts[i],100)
 check(rebuilt==bytes and parts[0].size()<=1000,"reordered duplicate fragments reassemble exactly below MTU")
 assembler.accept(14,0,parts.size(),parts[0],100)
 assembler.accept(60,0,parts.size(),parts[0],900)
 check(not assembler.pending.has(14),"missing fragment cannot block a new snapshot")
 check(assembler.accept(62,0,100,parts[0],900).is_empty(),"fragment count bounded")
func _initialize()->void:
 codec_tests();timeline_tests();prediction_tests();interpolation_tests();link_tests()
 print("NETWORK_LATENCY_PASS checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
