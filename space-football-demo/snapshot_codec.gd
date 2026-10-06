extends RefCounted
## Pure, versioned codec: never reads a live simulation or merges client state.
const Team=preload("res://team_config.gd")
const Library=preload("res://player_library.gd")
const PlayerState=preload("res://match_player_state.gd")
const State=preload("res://match_state.gd")
const Rules=preload("res://match_rules.gd")
const GoalNet=preload("res://goal_net.gd")
const Brain=preload("res://team_ai.gd")
const VERSION:=7
const MAX_BYTES:=262144
const MAX_COMPRESSED:=16000
const META_FIELDS=["ice_mode","arcade","elapsed","duration","regulation","freeze","owner","height","vertical","finished","overtime","event","frame","pass_receiver","last_touch","kick_age","ball_is_shot","spin","impact_id","impact_frame","impact_kind","impact_strength","impact_x","impact_y"]
const TEAM_FIELDS=["selected","tactic","charge","charging","dash","dash_cd","sprint","jockey","human","assist","assist_active","receive_cancelled","keeper_rush","run_player","run_time"]
const ACTIONS=["idle","shoot","pass","tackle","save","receive","block","dive","catch","throw","slide","cross","chip","header","volley","feint","fall","appeal","wall","set_piece","set_kick","celebrate","disappointed","windup","power_shot","finesse","dive_low","dive_high","scoop","foot_save","parry","tip","catch_high","shield","smother","rush","jump","land","stumble","slide_still","retrieve_ball","carry_ball","place_ball","driven_pass","block_chest","block_head"]
const EVENTS=["kickoff","pass","shot","tackle","goal","overtime","end","save","block","restart","foul","post"]
const RESTARTS=["kickoff","kick_in","corner","goal_kick","free_kick","indirect","penalty","accumulated"]


const VECTORS=["ball","velocity","pass_destination"]
const COUNTERS=["score","shots","passes","tackles","saves","possession"]
const PLAYER_VECTORS=["pos","vel","dir","action_dir"]
const PLAYER_NUMBERS=["cooldown","stamina","action_time","tackle_cd","touch","action_strength","contact_height"]
const KEEPER_NUMBERS=["keeper_cd","keeper_side","keeper_height","keeper_holding"]
const PLAYER_EXTRA=["active","fatigue","yellow","sinbin","jump_z","jump_v","jump_kind","jump_aim","jump_direction","landing","balance","release_wait","touch_ready","sub_revision","tackle_resolved","tackle_target","slide_speed"]
const TEAM_EXTRA=["contain","contain_player","receive_assist","shot_assist","auto_switch","pass_power","pass_charging","request_player","request_time","sub_pending","corner_plan"]
const MECHANICS_FIELDS=["buffered","releases","requests","advantage","benches","sent_off","last_keeper_pass","keeper_clock","keeper_owner","strict_rules","clock"]
const REST_FIELDS=["environment","goal_net","rules","mechanics","rng_state","message","overtime_duration","pickup_lock","stage","difficulty","strength","training","keeper_upgrade"]
static var identity_cache:Dictionary={}

static func identity(id:String,index:int)->Dictionary:
 var key:=id+":"+str(index)
 if not identity_cache.has(key):
  if identity_cache.size()>=64: identity_cache.erase(identity_cache.keys()[0])
  identity_cache[key]=PlayerState.create(Library.find(id),index)
 return identity_cache[key]

static func pack_fields(value:Dictionary,fields:Array)->Array:
 var row:Array=[]
 var extra:Dictionary=value.duplicate()
 for key in fields:
  row.append(value[key])
  extra.erase(key)
 row.append(extra)
 return row

static func unpack_fields(row,fields:Array)->Dictionary:
 if not row is Array or row.size()!=fields.size()+1 or not row.back() is Dictionary: return {}
 var value:Dictionary=row.back().duplicate(true)
 for i in fields.size(): value[fields[i]]=row[i]
 return value

static func encode(state:Dictionary)->Dictionary:
 var data:=PackedFloat32Array()
 for key in META_FIELDS: data.append(float(state[key]))
 for key in VECTORS: data.append(state[key].x); data.append(state[key].y)
 for key in COUNTERS:
  data.append(float(state[key][0])); data.append(float(state[key][1]))
 data.append(EVENTS.find(state.kind))
 data.append(RESTARTS.find(state.restart))
 for team in state.teams:
  for key in TEAM_FIELDS: data.append(float(team[key]))
  data.append(team.move.x); data.append(team.move.y)
 for p in state.players:
  for key in PLAYER_VECTORS: data.append(p[key].x); data.append(p[key].y)
  for key in PLAYER_NUMBERS: data.append(float(p[key]))
  if p.slot==0:
   for key in KEEPER_NUMBERS: data.append(float(p[key]))
  data.append(ACTIONS.find(p.action))
 var rest:Dictionary=state.duplicate()
 # AI planning is authority-only. Complete local snapshots retain it, wire snapshots
 # explicitly reset it instead of inheriting a client's stale planning memory.
 for key in META_FIELDS+VECTORS+COUNTERS+["players","teams","kind","restart","ai"]: rest.erase(key)
 rest.rules=Rules.pack(state.rules)
 rest.goal_net=GoalNet.pack(state.goal_net)
 rest.mechanics=pack_fields(state.mechanics,MECHANICS_FIELDS)
 var player_extra:Array=[]
 for p in state.players:
  var extra:Dictionary=p.duplicate()
  for key in PLAYER_VECTORS+PLAYER_NUMBERS+["action"]: extra.erase(key)
  if p.slot==0:
   for key in KEEPER_NUMBERS: extra.erase(key)
  # Remove only canonical identity values; campaign overrides survive as explicit extras.
  var base:Dictionary=identity(p.player_id,int(p.team)*Team.SIZE+int(p.slot))
  for key in base:
   if extra.has(key) and extra[key]==base[key]: extra.erase(key)
  extra.erase("player_id")
  player_extra.append([Library.indices[p.player_id],pack_fields(extra,PLAYER_EXTRA)])
 var team_extra:Array=[]
 for t in state.teams:
  var extra:Dictionary=t.duplicate()
  for key in TEAM_FIELDS+["move"]: extra.erase(key)
  team_extra.append(pack_fields(extra,TEAM_EXTRA))
 var payload:Dictionary={"version":VERSION,"values":data,"state":pack_fields(rest,REST_FIELDS),"players":player_extra,"teams":team_extra}
 return {"compressed":var_to_bytes(payload).compress(FileAccess.COMPRESSION_DEFLATE)}


static func decode(envelope:Dictionary)->Dictionary:
 if not envelope.get("compressed") is PackedByteArray: return {}
 var compressed:PackedByteArray=envelope.compressed
 if compressed.is_empty() or compressed.size()>MAX_COMPRESSED: return {}
 var bytes:=compressed.decompress_dynamic(MAX_BYTES,FileAccess.COMPRESSION_DEFLATE)
 if bytes.is_empty(): return {}
 var wire=bytes_to_var(bytes)
 if not wire is Dictionary or wire.get("version")!=VERSION: return {}
 if not finite_values(wire): return {}
 if not wire.get("values") is PackedFloat32Array: return {}
 if not wire.get("players") is Array or wire.players.size()!=Team.COUNT: return {}
 if not wire.get("teams") is Array or wire.teams.size()!=2: return {}
 var data:PackedFloat32Array=wire.values
 var expected:int=META_FIELDS.size()+VECTORS.size()*2+COUNTERS.size()*2+2+2*(TEAM_FIELDS.size()+2)+Team.COUNT*(PLAYER_VECTORS.size()*2+PLAYER_NUMBERS.size()+1)+2*KEEPER_NUMBERS.size()
 if data.size()!=expected: return {}
 for value in data:
  if not is_finite(value): return {}
 var enum_offset:int=META_FIELDS.size()+VECTORS.size()*2+COUNTERS.size()*2
 if not valid_index(data[enum_offset],EVENTS.size()) or not valid_index(data[enum_offset+1],RESTARTS.size()): return {}
 var state:Dictionary=unpack_fields(wire.get("state"),REST_FIELDS)
 if state.is_empty(): return {}
 if not state.rules is PackedFloat32Array or state.rules.size() not in [12,22+2*Team.COUNT]: return {}
 for value in state.rules:
  if not is_finite(value): return {}
 if not valid_index(state.rules[6],Rules.PHASES.size()) or not valid_index(state.rules[7]+1,Rules.TITLES.size()+1): return {}
 if state.rules.size()>12 and not valid_index(state.rules[12],Rules.Flow.STAGES.size()): return {}
 if not valid_index(state.rules[1],2) or not valid_index(state.rules[2],Team.COUNT): return {}
 state.rules=Rules.unpack(state.rules)
 if not state.goal_net is PackedFloat32Array or state.goal_net.size()!=GoalNet.pack(GoalNet.empty()).size(): return {}
 state.goal_net=GoalNet.unpack(state.goal_net)
 state.mechanics=unpack_fields(state.mechanics,MECHANICS_FIELDS)
 if state.mechanics.is_empty(): return {}
 var brain=Brain.new()
 brain.reset()
 state.ai=brain.state()
 if not valid_rest(state): return {}
 state.players=[];state.teams=[]
 for i in Team.COUNT:
  var row=wire.players[i]
  if not row is Array or row.size()!=2 or not row[0] is int: return {}
  var extra:Dictionary=unpack_fields(row[1],PLAYER_EXTRA)
  if extra.is_empty(): return {}
  Library.load_catalog()
  if row[0]<0 or row[0]>=Library.records.size(): return {}
  var p:Dictionary=identity(Library.records[row[0]].id,i).duplicate(true)
  p.merge(extra,true)
  if not valid_player(p) or p.team!=i/Team.SIZE or p.slot!=i%Team.SIZE: return {}
  state.players.append(p)
 for row in wire.teams:
  var extra:=unpack_fields(row,TEAM_EXTRA)
  if extra.is_empty() or not valid_team(extra): return {}
  state.teams.append(extra)
 # Validate action indices before using them for array access.
 var offset:int=enum_offset+2+2*(TEAM_FIELDS.size()+2)
 for i in Team.COUNT:
  offset+=PLAYER_VECTORS.size()*2+PLAYER_NUMBERS.size()+(KEEPER_NUMBERS.size() if i%Team.SIZE==0 else 0)
  if not valid_index(data[offset],ACTIONS.size()): return {}
  offset+=1
 var cursor:=0
 for key in META_FIELDS:
  state[key]=data[cursor]
  cursor+=1
 for key in ["owner","frame","event","pass_receiver","last_touch","impact_id","impact_frame","impact_kind"]: state[key]=int(state[key])
 for key in ["ice_mode","arcade","finished","overtime","ball_is_shot"]: state[key]=bool(state[key])
 for key in VECTORS:
  state[key]=Vector2(data[cursor],data[cursor+1]); cursor+=2
 for key in COUNTERS:
  state[key]=[data[cursor],data[cursor+1]] if key=="possession" else [int(data[cursor]),int(data[cursor+1])]
  cursor+=2
 state.kind=EVENTS[int(data[cursor])]; cursor+=1
 state.restart=RESTARTS[int(data[cursor])]; cursor+=1
 for team in state.teams:
  for key in TEAM_FIELDS:
   team[key]=data[cursor]; cursor+=1
  for key in ["selected","tactic","assist","run_player"]: team[key]=int(team[key])
  for key in ["charging","sprint","jockey","human","assist_active","receive_cancelled","keeper_rush"]: team[key]=bool(team[key])
  team.move=Vector2(data[cursor],data[cursor+1]); cursor+=2
 for p in state.players:
  for key in PLAYER_VECTORS:
   p[key]=Vector2(data[cursor],data[cursor+1]); cursor+=2
  for key in PLAYER_NUMBERS:
   p[key]=data[cursor]; cursor+=1
  if p.slot==0:
   for key in KEEPER_NUMBERS: p[key]=data[cursor];cursor+=1
   p.keeper_holding=bool(p.keeper_holding)
  p.action=ACTIONS[int(data[cursor])]; cursor+=1

 if not valid_index(state.owner+1,Team.COUNT+1): return {}
 for i in 2:
  if not valid_index(state.teams[i].selected-i*Team.SIZE,Team.SIZE): return {}
 return state

static func valid_index(value:float,count:int)->bool:
 return value==floorf(value) and value>=0 and value<count

static func valid_rest(state:Dictionary)->bool:
 for key in ["environment","goal_net","rules","ai","mechanics"]:
  if not state.get(key) is Dictionary: return false
 for key in State.FIELDS:
  if key not in META_FIELDS+VECTORS+COUNTERS+["kind","restart"] and not state.has(key): return false
 for key in ["overtime_duration","pickup_lock","stage","difficulty","strength","keeper_upgrade"]:
  if not numeric(state[key]): return false
 if not state.training is Array or state.training.size()!=5: return false
 for value in state.training:
  if not numeric(value): return false
 for key in ["buffered","releases","requests","benches","last_keeper_pass","keeper_clock"]:
  if not state.mechanics.get(key) is Array or state.mechanics[key].size()!=2: return false
 for key in ["buffered","releases","requests"]:
  for value in state.mechanics[key]:
   if not value is Dictionary: return false
 for value in state.mechanics.benches:
  if not value is Array: return false
  for reserve in value:
   if not reserve is Dictionary or not reserve.get("id") is String: return false
 for key in ["advantage","sent_off"]:
  if not state.mechanics.get(key) is Dictionary: return false
 if not numeric(state.mechanics.get("clock")) or not numeric(state.mechanics.get("keeper_owner")): return false
 if not state.mechanics.get("strict_rules") is bool: return false
 return state.get("rng_state") is int and state.get("message") is String and state.rules.get("phase") in Rules.PHASES

static func valid_player(p:Dictionary)->bool:
 for key in PLAYER_EXTRA:
  if key in ["active","tackle_resolved"]:
   if not p.get(key) is bool: return false
  elif key=="jump_kind":
   if not p.get(key) is String: return false
  elif key=="jump_direction":
   if not p.get(key) is Vector2: return false
  elif not numeric(p.get(key)): return false
 return true

static func valid_team(team:Dictionary)->bool:
 for key in TEAM_EXTRA:
  if key in ["contain","pass_charging"]:
   if not team.get(key) is bool: return false
  elif not numeric(team.get(key)): return false
 return true

static func numeric(value)->bool:
 return value is int or value is float

static func finite_values(value,depth:int=0)->bool:
 if depth>16: return false
 if value is float: return is_finite(value)
 if value is Vector2 or value is Vector3: return value.is_finite()
 if value is Array or value is PackedFloat32Array:
  for child in value:
   if not finite_values(child,depth+1): return false
 elif value is Dictionary:
  for child in value.values():
   if not finite_values(child,depth+1): return false
 return true
