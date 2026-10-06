extends SceneTree
const Match=preload("res://match_sim.gd")
const Codec=preload("res://snapshot_codec.gd")
const Network=preload("res://match_network.gd")
const Session=preload("res://match_session.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  push_error("REFACTOR_FAILED "+label)

func fixture(seed_value:int=813):
 var s=Match.new()
 s.setup(preload("res://campaign.gd").new(),seed_value)
 return s

func envelope(payload:Dictionary)->Dictionary:
 return {"compressed":var_to_bytes(payload).compress(FileAccess.COMPRESSION_DEFLATE)}

func _initialize()->void:
 var original=fixture()
 original.environment={"stadium":1,"weather":3,"gravity":1}
 original.pickup_lock=0.7
 original.overtime_duration=17
 original.players[1].fatigue=0.42
 original.mechanics.clock=8.5
 original.mechanics.releases[0]={"left":0.2,"action":1,"player":1}
 var saved:Dictionary=original.snapshot()
 var net=Network.new()
 net.sim=original
 var encoded:Dictionary=net.pack_state(saved)
 original.players[1].fatigue=0.91
 original.mechanics.clock=999
 original.mechanics.releases[0]={}
 check(encoded==net.pack_state(saved),"encoding an old snapshot ignores live simulation mutations")
 var decoded:Dictionary=net.unpack_state(encoded)
 check(not decoded.is_empty(),"stateless decode succeeds")
 check(decoded.players[1].fatigue==saved.players[1].fatigue,"snapshot fatigue comes from supplied snapshot")
 check(decoded.mechanics==saved.mechanics,"complete mechanics state is authoritative")
 check(decoded.ai==saved.ai,"wire starts from canonical AI memory, never receiver history")
 check(decoded.pickup_lock==0.7 and decoded.overtime_duration==17,"previously omitted match timers survive")
 check(decoded.rng_state==saved.rng_state,"random sequence preserved")
 check(decoded.environment==saved.environment,"weather and gravity preserved")
 net.sim=fixture(999)
 net.sim.mechanics.clock=-1
 check(net.unpack_state(encoded)==decoded,"receiver history cannot leak into decoded state")
 net.sim=null
 check(net.unpack_state(encoded)==decoded,"codec needs no running match")
 net.free()
 # Exact local restore includes RNG, AI, pickup lock and difficulty-dependent decisions.
 for phase in ["play","restart","goal","foul"]:
  var a=fixture(42)
  a.environment={"stadium":1,"weather":3,"gravity":1}
  a.freeze=0
  if phase=="restart" or phase=="foul":
   a.Rules.restart(a,0,"free_kick",Vector2(10,3))
   if phase=="foul": a.phase="foul";a.phase_time=0.4
  elif phase=="goal": a.Rules.goal(a,0)
  var b=Match.new()
  b.restore(a.snapshot())
  check(b.snapshot()==a.snapshot(),phase+" immediate restore is complete")
  for i in 120:
   a.step(1.0/60)
   b.step(1.0/60)
  check(b.snapshot()==a.snapshot(),phase+" restored simulation continues identically")
  var wire:Dictionary=Codec.encode(a.snapshot())
  check(wire.compressed.size()<Codec.MAX_COMPRESSED,phase+" packet fits fragment budget")
  var state:Dictionary=Codec.decode(wire)
  check(not state.is_empty() and state.rules.phase==a.phase and absf(state.rules.phase_time-a.phase_time)<0.00001,phase+" wire retains restart/goal state within float32 precision")
 # Unknown future noncompact fields are explicit extras, never inherited defaults.
 saved.players[1].effect_timer=1.75
 saved.teams[0].special_charge=0.6
 saved.special_mode={"remaining":3.0}
 var extended:Dictionary=Codec.decode(Codec.encode(saved))
 check(extended.players[1].effect_timer==1.75 and extended.teams[0].special_charge==0.6 and extended.special_mode.remaining==3.0,"additional state fields survive codec without parallel field lists")
 var payload:Dictionary=bytes_to_var(encoded.compressed.decompress_dynamic(Codec.MAX_BYTES,FileAccess.COMPRESSION_DEFLATE))
 var bad:Dictionary=payload.duplicate(true)
 bad.version=6
 check(Codec.decode(envelope(bad)).is_empty(),"old protocol rejected")
 bad=payload.duplicate(true);bad.values=bad.values.slice(0,3)
 check(Codec.decode(envelope(bad)).is_empty(),"truncated numeric payload rejected")
 bad=payload.duplicate(true);bad.values[0]=NAN
 check(Codec.decode(envelope(bad)).is_empty(),"nonfinite numbers rejected")
 bad=payload.duplicate(true);bad.players.pop_back()
 check(Codec.decode(envelope(bad)).is_empty(),"incomplete roster rejected")
 bad=payload.duplicate(true);bad.players[0][0]=-1
 check(Codec.decode(envelope(bad)).is_empty(),"unknown identity rejected")
 bad=payload.duplicate(true);bad.state[Codec.REST_FIELDS.find("mechanics")]=[]
 check(Codec.decode(envelope(bad)).is_empty(),"missing authoritative subsystem rejected")
 bad=payload.duplicate(true);bad.state[Codec.REST_FIELDS.find("rules")][6]=-1
 check(Codec.decode(envelope(bad)).is_empty(),"invalid match phase rejected")
 bad=payload.duplicate(true);bad.players[0][1][Codec.PLAYER_EXTRA.find("active")]=[]
 check(Codec.decode(envelope(bad)).is_empty(),"wrong player field type rejected")
 bad=payload.duplicate(true);bad.teams[0][Codec.TEAM_EXTRA.find("request_time")]=INF
 check(Codec.decode(envelope(bad)).is_empty(),"nonfinite nested state rejected")
 var isolated:Dictionary=Codec.decode(encoded)
 isolated.players[0].ratings.speed=-999
 check(Codec.decode(encoded).players[0].ratings.speed>0,"decoded identities never mutate canonical cache")
 var session=Session.new()
 session.sim=fixture()
 for page in ["pause","help","assist_settings","substitutions","loading","menu","result"]:
  session.screen=page
  check(not session.runs_local_simulation() and not session.accepts_match_input(),page+" suspends local play")
 session.screen="match"
 check(session.runs_local_simulation(),"match runs local play")
 session.online=true
 for page in ["online_menu","help","assist_settings","substitutions"]:
  session.screen=page
  check(not session.runs_local_simulation() and session.renders_match("match") and session.updates_replay(),page+" keeps online presentation alive without local authority")
 print("REFACTOR_TESTS_PASS checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
