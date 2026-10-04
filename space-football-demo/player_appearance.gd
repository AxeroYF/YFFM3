extends RefCounted
## Stable presentation data keyed by player ID; never by nationality or team slot.
const PATH:="res://assets/humanoid/legend_appearances.json"
const VERSION:=1
static var profiles:Dictionary={}

static func load_profiles()->void:
 if profiles.is_empty(): profiles=JSON.parse_string(FileAccess.get_file_as_string(PATH)).profiles

static func find(id:String)->Dictionary:
 load_profiles()
 return profiles.get(id,{}).duplicate(true)

static func is_legend(record:Dictionary)->bool:
 return record.get("legendary",false) or str(record.get("id","")).begins_with("legend-")

static func ids()->Array:
 load_profiles()
 return profiles.keys()
