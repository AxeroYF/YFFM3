extends RefCounted
## Fixed-width input samples: bounded, numeric, and tied to a roster identity.
const WIDTH:=20
const REDUNDANCY:=6
const FLAGS:=["sprint","jockey","assist_active","keeper_rush","finesse","chip","skip_restart","driven","contain","skill_sprint"]
const Match=preload("res://match_sim.gd")

static func bind(s,team:int,command:Dictionary,seq:int,action_id:int)->Dictionary:
 s.Library.load_catalog()
 var c:=command.duplicate(true)
 var index:int=s.teams[team].selected
 c.seq=seq;c.action_id=action_id;c.player=index;c.revision=s.players[index].sub_revision
 c.catalog=s.Library.indices[s.players[index].player_id]
 return c

static func encode(c:Dictionary)->PackedFloat32Array:
 var flags:=0
 for i in FLAGS.size():
  if bool(c.get(FLAGS[i],FLAGS[i]=="assist_active")): flags|=1<<i
 var move:Vector2=c.get("move",Vector2.ZERO);var direction:Vector2=c.get("direction",Vector2.ZERO)
 return PackedFloat32Array([c.seq,c.action_id,c.player,c.revision,c.catalog,c.get("action",0),move.x,move.y,c.get("aim",0),c.get("power",0.35),direction.x,direction.y,flags,c.get("tactic",1),c.get("assist",1),c.get("receive_assist",-1),c.get("shot_assist",-1),c.get("auto_switch",1),c.get("reserve",0),c.get("out",1)])

static func decode(data:PackedFloat32Array)->Dictionary:
 if data.size()!=WIDTH: return {}
 for value in data:
  if not is_finite(value): return {}
 for i in [0,1,2,3,4,5,12,13,14,15,16,17,18,19]:
  if data[i]!=floorf(data[i]): return {}
 if data[0]<1 or data[0]>1000000 or data[1]<0 or data[1]>1000000 or data[2]<0 or data[2]>=12 or data[3]<0 or data[3]>10000 or data[4]<0 or data[4]>=386 or data[5]<0 or data[5]>Match.Mechanics.MAX_ACTION or data[12]<0 or data[12]>=1024: return {}
 var c:={"seq":int(data[0]),"action_id":int(data[1]),"player":int(data[2]),"revision":int(data[3]),"catalog":int(data[4]),"action":int(data[5]),"move":Vector2(data[6],data[7]).limit_length(),"aim":clampf(data[8],-1,1),"power":clampf(data[9],0,1),"direction":Vector2(data[10],data[11]).limit_length(),"tactic":clampi(int(data[13]),0,2),"assist":clampi(int(data[14]),0,2),"receive_assist":clampi(int(data[15]),-1,2),"shot_assist":clampi(int(data[16]),-1,2),"auto_switch":clampi(int(data[17]),0,2),"reserve":clampi(int(data[18]),0,3),"out":clampi(int(data[19]),0,5)}
 if (c.action==0)!=(c.action_id==0): return {}
 for i in FLAGS.size(): c[FLAGS[i]]=(int(data[12])&(1<<i))!=0
 return c

static func matches(s,team:int,c:Dictionary)->bool:
 s.Library.load_catalog()
 var index:int=c.get("player",-1)
 if index<team*6 or index>=team*6+6 or index!=int(s.teams[team].selected): return false
 var p:Dictionary=s.players[index]
 return p.active and p.sub_revision==c.get("revision",-1) and s.Library.indices[p.player_id]==c.get("catalog",-1)

static func neutral()->Dictionary:
 return {"move":Vector2.ZERO,"sprint":false,"jockey":false,"action":0,"aim":0.0,"tactic":1,"assist_active":false,"keeper_rush":false,"contain":false,"skip_restart":false}
