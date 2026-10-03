extends RefCounted
## Height/jumping/heading come from the existing player catalog. Proportions and
## appearance are authored game art, not measured anatomy or scanned likenesses.
const WORLD_UNITS_PER_METRE:=1.45
const SLOT_RECORD:=[-1,1,0,2,3]
const Library=preload("res://player_library.gd")
static var catalog:Array=[]

static func profile(slot:int)->Dictionary:
 if catalog.is_empty():
  for id in ["legend-messi","legend-haaland","s4-fc26-252371","s4-fc26-203376"]: catalog.append(Library.find(id))
 var record:Dictionary=catalog[SLOT_RECORD[slot]] if slot>0 else {}
 return from_record(record,slot)

static func from_record(record:Dictionary,slot:int=1)->Dictionary:
 var attributes:Dictionary=record.get("attributes",{})
 var cm:=float(record.get("heightCm",192))
 var h:=cm*0.01*WORLD_UNITS_PER_METRE
 var muscle:=float(attributes.get("strength",85))/100.0
 var shoulder:=h*(0.225+muscle*0.035)
 var leg_ratio:float=clampf(0.49+(cm-170)*0.0016,0.485,0.54)
 var jumping:=float(attributes.get("jumping",80))
 var appearance_slot:int={"legend-haaland":1,"legend-messi":2,"s4-fc26-252371":3,"s4-fc26-203376":4,"legend-courtois":0}.get(record.get("id",""),-1)
 var skin_color:String=["bf8e70","e2b18e","d4a07b","996b51","a77a59"][appearance_slot] if appearance_slot>=0 else "bf8e70"
 var hair_color:String=["241e1b","b79953","32271e","201e1c","261d18"][appearance_slot] if appearance_slot>=0 else "241e1b"
 if record.get("id","")=="legend-mbappe": skin_color="a77a59"
 return {
  "height_cm":cm,"height":h,"shoulder":shoulder,"hip_width":shoulder*0.69,
  "leg_length":h*leg_ratio,"muscle":muscle,"head_size":h*0.128,
  "body_radius":shoulder*0.69,"foot_reach":h*0.36,
  "foot_height":h*0.40,"chest_height":h*0.74,"head_height":h*0.935,
  "hand_reach":h*1.12,"jump_height":(0.25+jumping*0.004)*WORLD_UNITS_PER_METRE,
  "jumping":jumping,"heading":float(attributes.get("heading",60)),
  "skin":skin_color,
  "hair":hair_color,
  "hair_style":["short","tied","crop","curly","tied"][slot],
  "beard":slot==2,"build_name":["门将 / 长臂","高大型 / 强壮","紧凑型 / 灵活","修长型 / 均衡","高大型 / 宽肩"][slot]
 }

static func contact_zone(body:Dictionary,ball_center:float,jump_offset:float=0.0,keeper:bool=false)->String:
 # Only actual jump displacement belongs here, never the maximum jump potential.
 var y:=ball_center-maxf(0,jump_offset)
 if y<0: return "none"
 if keeper and y<=body.hand_reach: return "hands"
 if y<=body.foot_height: return "foot"
 if absf(y-body.chest_height)<=body.height*0.115: return "chest"
 if absf(y-body.head_height)<=body.head_size*0.60: return "head"
 return "none"
