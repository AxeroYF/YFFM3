extends RefCounted
const Team=preload("res://team_config.gd")
const Library=preload("res://player_library.gd")
const DEFAULT=["legend-courtois","legend-haaland","legend-messi","s4-fc26-252371","s4-fc26-203376","legend-modric"]
const SLOTS=["门将","前锋","右翼","左翼","后卫","中场"]
static var ids:Array=DEFAULT.duplicate()
static var save_path:="user://starborne-squad.json"

static func valid(value:Variant)->bool:
 if not value is Array or value.size()!=Team.SIZE: return false
 var seen:Dictionary={}
 for i in Team.SIZE:
  if not value[i] is String or seen.has(value[i]): return false
  var p:=Library.find(value[i])
  if p.is_empty() or (p.role=="GK")!=(i==0): return false
  seen[value[i]]=true
 return true

static func load_squad()->void:
 if not FileAccess.file_exists(save_path): return
 var value=JSON.parse_string(FileAccess.get_file_as_string(save_path))
 # Preserve all five chosen players; append a unique central creator to old saves.
 if value is Array and value.size()==Team.SIZE-1:
  value=value.duplicate()
  if not "legend-modric" in value: value.append("legend-modric")
  else:
   for record in Library.all():
    if record.role in ["AM","DM","CM"] and record.id not in value:
     value.append(record.id);break
 if valid(value): ids=value

static func assign_player(id:String,slot:int)->bool:
 if slot<0 or slot>=Team.SIZE: return false
 var next:=ids.duplicate()
 var previous:=next.find(id)
 if previous>=0: next[previous]=next[slot]
 next[slot]=id
 if not valid(next): return false
 var file:=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
 if file==null: return false
 file.store_string(JSON.stringify(next))
 file.close()
 if DirAccess.rename_absolute(save_path+".tmp",save_path)!=OK: return false
 ids=next
 return true
