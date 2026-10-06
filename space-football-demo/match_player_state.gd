extends RefCounted
## Canonical player construction. Network decoding uses the same catalog-derived identity.
const Team=preload("res://team_config.gd")
const Body=preload("res://player_body.gd")
const Ratings=preload("res://player_ratings.gd")
const Style=preload("res://player_style.gd")
static func create(record:Dictionary,i:int,training:Array=[0,0,0,0,0],keeper_upgrade:int=0,competitive:bool=true)->Dictionary:
 var body:=Body.from_record(record,i%Team.SIZE)
 var ratings:=Ratings.for_player(record,body)
 var speed:float=ratings.speed
 if not competitive:
  if i>0 and i<Team.SIZE: speed+=float(training[[0,1,0,2,3,4][i]])*0.12*Ratings.MOVEMENT_SCALE
  if i==0: speed+=keeper_upgrade*0.5*Ratings.MOVEMENT_SCALE
 var p:Dictionary={"pos":Vector2.ZERO,"vel":Vector2.ZERO,"dir":Vector2.RIGHT if i<Team.SIZE else Vector2.LEFT,"team":i/Team.SIZE,"slot":i%Team.SIZE,"name":record.name,"cooldown":0.0,"speed":speed,"stamina":100.0,"action":"idle","action_time":0.0,"tackle_cd":0.0,"touch":0.0,"keeper_cd":0.0,"keeper_side":0.0,"keeper_height":0.0,"player_id":record.id,"attributes":record.attributes.duplicate(true),"ratings":ratings}
 p["body"]=body
 p["action_strength"]=0.0
 p["keeper_holding"]=false
 p["role"]=record.role
 p["preferred_foot"]=record.get("preferredFoot","right")
 p["style"]=Style.derive(record)
 return p
