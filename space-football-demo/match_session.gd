extends RefCounted
## Match lifecycle and command boundary. UI never selects the authority transport.
const Match=preload("res://match_sim.gd")
const Conditions=preload("res://match_environment.gd")
const Campaign=preload("res://campaign.gd")
const Squad=preload("res://squad.gd")
const QuickMatch=preload("res://quick_match.gd")
var network:Node
var sim
var screen := "menu"
var online:=false
var practice:=false
var quick_fixture:Dictionary={}
var quick_environment:Dictionary=Conditions.normalize({})
var quick_arcade:=false
var quick_ice_mode:=false
var load_epoch:=0
func prepare(campaign,tactic:int,arcade_rules:bool,verify:bool,strict_rules:bool)->void:
 if online:
  sim=network.sim
 else:
  sim=Match.new()
  if practice:
   if not QuickMatch.valid_fixture(quick_fixture): quick_fixture=QuickMatch.generate()
   sim.setup(Campaign.new(),quick_fixture.seed,quick_fixture.home,quick_fixture.away,true)
   sim.teams[0].human=true
   sim.teams[1].human=false
   print("QUICK_MATCH_STARTED seed=",quick_fixture.seed," home=",quick_fixture.home," away=",quick_fixture.away)
  else: sim.setup(campaign,731 if verify else 0,Squad.ids)
  sim.arcade=quick_arcade if practice else arcade_rules
  sim.ice_mode=practice and quick_ice_mode
  sim.environment=Conditions.normalize(quick_environment if practice else {})
  if sim.ice_mode: sim.arcade=false
  sim.tactic=tactic
  sim.regulation=100
  sim.Rules.restart(sim,0,"kickoff",Vector2.ZERO)
 if not online: sim.mechanics.strict_rules=strict_rules
func submit(command:Dictionary,dt:float=1.0/60)->void:
 if sim==null: return
 if online: network.submit_local(command,dt)
 else: sim.apply_command(sim.view_team,command)

func submit_action(command:Dictionary)->void:
 if sim==null: return
 var intent:Dictionary=command.duplicate(true)
 intent.merge({"move":Vector2.ZERO,"sprint":false,"jockey":false,"aim":0.0,"tactic":sim.tactic,"assist_active":false},false)
 submit(intent)

func accepts_match_input()->bool:
 return screen=="match"

func runs_local_simulation()->bool:
 return not online and accepts_match_input() and sim!=null

func renders_match(previous_screen:String)->bool:
 return screen=="match" or screen=="online_menu" or (online and screen in ["assist_settings","substitutions"]) or (online and screen=="help" and previous_screen=="match")

func updates_replay()->bool:
 return sim!=null and (screen=="match" or (online and screen in ["online_menu","help","assist_settings","substitutions"]))

func animates_environment()->bool:
 return screen not in ["pause","help","assist_settings","substitutions"]

func shows_rules()->bool:
 return screen in ["match","online_menu","help","assist_settings","rules_verification"]
