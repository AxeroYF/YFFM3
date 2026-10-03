extends RefCounted
## Authored tendencies derived from catalog data, not measured real-player behaviour.
const Ratings=preload("res://player_ratings.gd")

static func derive(record:Dictionary)->Dictionary:
 var a:Dictionary=record.attributes
 var role:String=record.role
 var creator:=Ratings.unit(a,"passing")*0.4+Ratings.unit(a,"vision")*0.4+Ratings.unit(a,"decisions")*0.2
 var runner:=Ratings.unit(a,"offBall")*0.5+Ratings.unit(a,"pace")*0.25+Ratings.unit(a,"acceleration")*0.25
 var defender:=Ratings.unit(a,"marking")*0.3+Ratings.unit(a,"positioning")*0.3+Ratings.unit(a,"tackling")*0.4
 var power:=Ratings.unit(a,"strength")*0.55+Ratings.unit(a,"heading")*0.45
 var technical:=Ratings.unit(a,"dribbling")*0.55+Ratings.unit(a,"agility")*0.45
 var name:="均衡连接者"
 if role=="GK": name="出球型门将" if creator>0.65 else "门线门将"
 elif role in ["CB","DM"]: name="组织后卫" if creator>0.78 else "强力屏障"
 elif role in ["RB","LB"]: name="边路支援者"
 elif role=="ST": name="强力终结者" if power>0.85 and float(record.heightCm)>=185 else "穿插射手"
 elif role=="AM" and Ratings.unit(a,"workRate")>0.85 and defender>0.65: name="全能接应者"
 elif creator>0.85 and technical>0.85: name="持球组织者"
 elif role in ["AM","CM"]: name="中场组织者"
 elif role in ["RW","LW","RM","LM"]: name="边路输送者" if Ratings.unit(a,"crossing")>technical+0.05 else "突破边锋"
 return {"name":name,"creator":clampf(creator+(0.10 if role in ["AM","CM","DM"] else 0),0,1),"runner":clampf(runner+(0.12 if role=="ST" else 0),0,1),"defender":clampf(defender+(0.12 if role in ["CB","DM"] else 0),0,1),"power":power,"technical":technical,"width":0.95 if role in ["RW","LW","RM","LM","RB","LB"] else 0.45,"press":Ratings.unit(a,"aggression")*0.5+Ratings.unit(a,"workRate")*0.5,"discipline":Ratings.unit(a,"discipline"),"composure":Ratings.unit(a,"composure"),"vision":Ratings.unit(a,"vision")}

static func description(profile:Dictionary)->String:
 return {"门线门将":"优先守位，安全分球","出球型门将":"主动寻找后场出球路线","强力屏障":"留后保护，贴身盯防，力量护球","组织后卫":"留后接应，安全推进与转移","边路支援者":"边路接应，及时回追","强力终结者":"前插占位，背身护球，禁区终结","穿插射手":"寻找身后空间，快速前插","全能接应者":"短传连接，后插上，积极回防","持球组织者":"细密触球，回撤接应，寻找直塞","中场组织者":"连接三角，优先寻找空位队友","边路输送者":"保持宽度，寻找传中与倒三角","突破边锋":"沿边推进，斜插空当","均衡连接者":"保持间距，按局势接应与补位"}.get(profile.name,"")
