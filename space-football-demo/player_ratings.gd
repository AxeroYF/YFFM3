extends RefCounted
## Gameplay coefficients derived from immutable catalog values. Input is never delayed.
const ACTIVE=["pace","acceleration","agility","stamina","strength","dribbling","firstTouch","passing","finishing","longShots","tackling","marking","positioning","offBall","decisions","workRate","goalkeeping","reflexes","heading","crossing","setPieces","vision","composure","discipline","aggression","jumping"]
const MOVEMENT_SCALE:=0.78
const TURN_TIME_SCALE:=1.6
const TURN_MIN:=0.14*TURN_TIME_SCALE
const TURN_MAX:=0.22*TURN_TIME_SCALE

static func unit(a:Dictionary,key:String)->float:
 return clampf(float(a.get(key,50)),1,99)/99.0

static func derive(a:Dictionary,height_cm:float=180)->Dictionary:
 var responsiveness:=unit(a,"agility")*0.65+unit(a,"acceleration")*0.20+unit(a,"dribbling")*0.15
 var frame_size:=clampf((height_cm-175)/30,0,1)*0.7+maxf(0,unit(a,"strength")-0.70)*1.0
 var turn_time:=clampf(0.14+(1-responsiveness)*0.07+frame_size*0.014,0.14,0.22)*TURN_TIME_SCALE
 return {
  "speed":(5.8+unit(a,"pace")*2.9)*MOVEMENT_SCALE,
  "acceleration":(14.0+unit(a,"acceleration")*16.0)*MOVEMENT_SCALE,
  "braking":(24.0+unit(a,"agility")*15.0)*MOVEMENT_SCALE,
  "turn_rate":PI/turn_time,
  "turn_time":turn_time,
  "turn_drag":0.14+(1-responsiveness)*0.08,
  "drain":21.0-unit(a,"stamina")*10.0,
  "recovery":5.0+unit(a,"stamina")*6.0,
  "dribble_speed":0.84+unit(a,"dribbling")*0.13,
  "stride":0.72+(1-unit(a,"dribbling"))*0.70+frame_size*0.10,
  "touch_wave":0.10+(1-unit(a,"firstTouch"))*0.26,
  "touch_follow":14.0+unit(a,"firstTouch")*10,
  "sprint_touch":0.25+(1-unit(a,"dribbling"))*0.55+frame_size*0.08,
  "carry_acceleration":0.80+(unit(a,"agility")+unit(a,"dribbling"))*0.10,
  "control":0.36-unit(a,"firstTouch")*0.24,
  "pass_error":0.050*(1.0-unit(a,"passing")),
  "cross_error":0.10*(1.0-unit(a,"crossing")),
  "set_piece_error":0.070*(1.0-unit(a,"setPieces")),
  "shot_error":0.085*(1.0-unit(a,"finishing")),
  "long_error":0.105*(1.0-unit(a,"longShots")),
  "shot_power":23.0+unit(a,"finishing")*4.0,
  "finishing_curve":unit(a,"finishing")*1.5,
  "tackle_reach":1.55+unit(a,"tackling")*0.80,
  "tackle_recovery":1.25-unit(a,"tackling")*0.40,
  "shield":unit(a,"strength"),
  "marking":unit(a,"marking"),"positioning":unit(a,"positioning"),
  "off_ball":unit(a,"offBall"),"decisions":unit(a,"decisions"),"work_rate":unit(a,"workRate"),
  "keeper_radius":0.68+unit(a,"goalkeeping")*0.34,
  "keeper_anticipation":0.06+unit(a,"reflexes")*0.18,
  "keeper_hold":18.0+unit(a,"goalkeeping")*18.0,
  "header_control":0.20+unit(a,"heading")*0.35
 }
