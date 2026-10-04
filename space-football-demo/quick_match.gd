extends RefCounted
const Team=preload("res://team_config.gd")
## Seeded development fixtures; never changes the saved squad or campaign.
const Library=preload("res://player_library.gd")
const ROLES=[["GK"],["ST"],["RW","RM","AM"],["LW","LM","AM"],["CB","DM","RB","LB"],["AM","DM","CM"]]
const LABELS=["门将","前锋","右翼","左翼","后卫","中场"]

static func generate(seed_value:int=0)->Dictionary:
 var rng:=RandomNumberGenerator.new()
 if seed_value==0:
  rng.randomize()
  seed_value=rng.randi_range(1,2147483646)
 rng.seed=seed_value
 var records:=Library.all()
 var taken:Dictionary={}
 var lineups:Array=[[],[]]
 for team in 2:
  for slot in Team.SIZE:
   var choices:Array=[]
   for record in records:
    if taken.has(record.id) or record.role not in ROLES[slot]: continue
    # Prefer native positions while allowing sensible six-a-side alternatives.
    var weight:=4 if record.role==ROLES[slot][0] else (1 if record.role=="AM" else 2)
    for i in weight: choices.append(record.id)
   assert(not choices.is_empty(),"Quick match requires enough illustrated players for each position")
   var id:String=choices[rng.randi_range(0,choices.size()-1)]
   lineups[team].append(id)
   taken[id]=true
 return {"seed":seed_value,"home":lineups[0],"away":lineups[1]}

static func valid_fixture(fixture:Dictionary)->bool:
 if not fixture.has("seed") or not fixture.has("home") or not fixture.has("away"): return false
 var seen:Dictionary={}
 for side in ["home","away"]:
  var lineup=fixture[side]
  if not lineup is Array or lineup.size()!=Team.SIZE: return false
  for slot in Team.SIZE:
   var record:=Library.find(str(lineup[slot]))
   if record.is_empty() or seen.has(record.id) or record.role not in ROLES[slot]: return false
   seen[record.id]=true
 return true
