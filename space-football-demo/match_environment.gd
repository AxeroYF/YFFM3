extends RefCounted
## Stable numeric IDs are persisted on the wire. Registry order does not define effects.
const Weather=preload("res://environment/weather_profile.gd")
const Stadium=preload("res://environment/stadium_profile.gd")
const Gravity=preload("res://environment/gravity_profile.gd")
const Flight=preload("res://ball_flight_conditions.gd")
const CATALOG={
 "stadium":{0:preload("res://environment/planet.tres"),1:preload("res://environment/galaxy.tres")},
 "weather":{0:preload("res://environment/clear.tres"),1:preload("res://environment/wind.tres"),2:preload("res://environment/rain.tres"),3:preload("res://environment/storm.tres")},
 "gravity":{0:preload("res://environment/normal_gravity.tres"),1:preload("res://environment/low_gravity.tres")}
}

static func normalize(value:Dictionary)->Dictionary:
 var result:={"stadium":0,"weather":0,"gravity":0}
 for key in result:
  var raw=value.get(key,0)
  if (raw is int or raw is float) and is_finite(float(raw)):
   var ids:Array=CATALOG[key].keys()
   var id:=clampi(int(raw),int(ids.min()),int(ids.max()))
   result[key]=id if CATALOG[key].has(id) else 0
 return result

static func label(group:String,id:int)->String:
 return CATALOG[group].get(id,CATALOG[group][0]).display_name

static func next_option(group:String,id:int)->int:
 var ids:Array=CATALOG[group].keys()
 ids.sort()
 return int(ids[(ids.find(id)+1)%ids.size()])

static func weather(options:Dictionary)->Weather:
 return CATALOG.weather.get(int(options.get("weather",0)),CATALOG.weather[0])

static func stadium(options:Dictionary)->Stadium:
 return CATALOG.stadium.get(int(options.get("stadium",0)),CATALOG.stadium[0])

static func gravity(options:Dictionary)->Gravity:
 return CATALOG.gravity.get(int(options.get("gravity",0)),CATALOG.gravity[0])

static func rainy(options:Dictionary)->bool:
 return weather(options).rain

static func windy(options:Dictionary)->bool:
 return weather(options).windy()

static func gravity_scale(options:Dictionary)->float:
 return gravity(options).multiplier

static func wind(options:Dictionary,seconds:float)->float:
 return weather(options).wind_at(seconds)

static func physics(options:Dictionary,seconds:float=0.0,solar:float=0.0)->Flight:
 var settings:=Flight.new()
 var profile:=weather(options)
 settings.gravity_scale=gravity_scale(options)
 settings.rolling_drag=profile.rolling_drag
 settings.restitution=profile.ball_restitution
 settings.solar_wind=solar
 settings.crosswind=profile.wind_at(seconds)
 return settings

static func summary(options:Dictionary)->String:
 var c:=normalize(options)
 return label("stadium",c.stadium)+" / "+label("weather",c.weather)+" / "+label("gravity",c.gravity)+("  ↓ 横风" if windy(c) else "")

static func description(options:Dictionary)->String:
 var c:=normalize(options)
 var effects:Array[String]=[]
 if windy(c): effects.append("横风使高球偏移 ↓")
 if rainy(c): effects.append("雷雨湿地：刹车更慢、地滚球阻力增加")
 if gravity_scale(c)<1.0: effects.append("足球与起跳滞空更久")
 return " · ".join(effects) if not effects.is_empty() else "标准球路与抓地力 · 球场背景不改变比赛数值"
