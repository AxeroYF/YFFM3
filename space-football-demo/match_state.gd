extends RefCounted
## Authoritative snapshot schema. view_team is a local presentation preference.
const Conditions=preload("res://match_environment.gd")
const GoalNet=preload("res://goal_net.gd")
const FIELDS={
 "ice_mode":"ice_mode",
 "arcade":"arcade",
 "ball":"ball",
 "velocity":"velocity",
 "height":"ball_height",
 "vertical":"vertical_speed",
 "owner":"owner",
 "score":"score",
 "shots":"shots",
 "passes":"passes",
 "tackles":"tackles",
 "saves":"saves",
 "possession":"possession",
 "elapsed":"elapsed",
 "duration":"duration",
 "regulation":"regulation",
 "freeze":"freeze",
 "finished":"finished",
 "overtime":"overtime",
 "impact_id":"impact_id",
 "impact_frame":"impact_frame",
 "impact_kind":"impact_kind",
 "impact_strength":"impact_strength",
 "impact_x":"impact_x",
 "impact_y":"impact_y",
 "event":"event_serial",
 "kind":"event_kind",
 "message":"message",
 "frame":"frame",
 "restart":"restart_kind",
 "pass_receiver":"pass_receiver",
 "pass_destination":"pass_destination",
 "last_touch":"last_touch",
 "kick_age":"kick_age",
 "ball_is_shot":"ball_is_shot",
 "spin":"ball_spin",
 "overtime_duration":"overtime_duration",
 "pickup_lock":"pickup_lock",
 "stage":"stage",
 "difficulty":"difficulty",
 "strength":"strength",
 "training":"training",
 "keeper_upgrade":"keeper_upgrade",
}

static func copy(value):
 return value.duplicate(true) if value is Array or value is Dictionary else value

static func capture(sim)->Dictionary:
 var result:Dictionary={}
 for key in FIELDS: result[key]=copy(sim.get(FIELDS[key]))
 result.environment=sim.environment.duplicate(true)
 result.goal_net=sim.goal_net.duplicate(true)
 result.players=sim.players.duplicate(true)
 result.teams=sim.teams.duplicate(true)
 result.rules=sim.Rules.state(sim)
 result.ai=sim.brain.state()
 result.mechanics=sim.mechanics.state()
 result.rng_state=sim.rng.state
 return result

static func restore(sim,state:Dictionary)->void:
 for key in FIELDS:
  if state.has(key): sim.set(FIELDS[key],copy(state[key]))
 sim.environment=Conditions.normalize(state.get("environment",{}))
 sim.goal_net=state.get("goal_net",GoalNet.empty()).duplicate(true)
 sim.players.assign(state.players.duplicate(true))
 sim.teams.assign(state.teams.duplicate(true))
 sim.Rules.restore(sim,state.rules)
 sim.brain.restore(state.get("ai",{}))
 sim.mechanics.restore(state.get("mechanics",{}))
 if state.has("rng_state"): sim.rng.state=int(state.rng_state)
