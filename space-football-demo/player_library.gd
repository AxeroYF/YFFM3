extends RefCounted
## Immutable definitions. Campaign progress must be stored separately by player ID.
const PATH:="res://assets/player-library/catalog.json"
static var records:Array=[]
static var by_id:Dictionary={}
static var indices:Dictionary={}

static func load_catalog()->void:
 if not records.is_empty(): return
 var parsed=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 assert(parsed is Array,"Player library must be a JSON array")
 records=parsed
 for player in records:
  assert(not by_id.has(player.id),"Duplicate player ID")
  by_id[player.id]=player
  indices[player.id]=indices.size()

static func find(id:String)->Dictionary:
 load_catalog()
 return by_id.get(id,{}).duplicate(true)

static func all()->Array:
 load_catalog()
 return records.duplicate(true)
