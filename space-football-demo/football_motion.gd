extends RefCounted
## Responsive gameplay profiles, not measured real-player biomechanics.
const DIVES=["dive","dive_low","dive_high"]
const TACKLE_DURATION:=0.50
const SLIDE_DURATION:=1.05
const GROUND_TACKLE_DURATION:=0.78
const DEFENSIVE_ACTIONS:=["tackle","slide","slide_still"]
const KICKS:=["shoot","power_shot","finesse","pass","driven_pass","cross","chip","set_kick","volley"]

static func action_duration(p:Dictionary)->float:
 var strength:float=p.get("action_strength",0.4)
 if p.action in ["shoot","power_shot","finesse","chip"]:
  return (0.48+strength*0.16) if p.action=="finesse" else (0.44+strength*0.16) if p.action=="chip" else 0.38+strength*0.20
 if p.action=="receive": return maxf(0.08,float(p.ratings.control))
 return {"slide":SLIDE_DURATION,"slide_still":GROUND_TACKLE_DURATION,"tackle":TACKLE_DURATION,"fall":1.2,"cross":0.6,"header":0.55,"volley":0.55,"set_kick":0.65,"feint":0.35,"celebrate":3.0,"disappointed":3.0,"appeal":1.2,"pass":0.4,"driven_pass":0.48,"block":0.3,"block_chest":0.3,"block_head":0.3,"land":0.2,"stumble":0.25,"jump":0.75,"throw":0.5,"retrieve_ball":0.55,"place_ball":0.50}.get(p.action,0.8)

static func tackle_duration(sliding:bool)->float:
 return SLIDE_DURATION if sliding else TACKLE_DURATION

static func tackle_contact(action:String,remaining:float)->bool:
 if action not in DEFENSIVE_ACTIONS or remaining<=0: return false
 var duration:float=GROUND_TACKLE_DURATION if action=="slide_still" else tackle_duration(action=="slide")
 var elapsed:float=duration-remaining
 return elapsed>=0.09 and elapsed<=(0.56 if action=="slide" else 0.32 if action=="slide_still" else 0.23)

static func defensive_velocity(action:String,remaining:float,direction:Vector2,speed:float,entry_speed:float=0)->Vector2:
 if action=="slide_still": return Vector2.ZERO
 var sliding:bool=action=="slide"
 var elapsed:float=tackle_duration(sliding)-remaining
 if sliding:
  # Drop into the slide, decelerate on the turf, then stop while getting up.
  return direction*entry_speed*clampf(1.0-elapsed/0.65,0,1)
 return direction*minf(3.2,speed*0.50)*sin(clampf(elapsed/0.26,0,1)*PI) if elapsed<0.26 else Vector2.ZERO

static func shot(charge:float,kind:String,ratings:Dictionary)->Dictionary:
 var q:=clampf(charge,0,1)
 var power:float=ratings.shot_power
 # Full charge deliberately risks going over the bar. A tap stays low.
 var result:={"speed":power*(0.74+0.70*pow(q,0.7)),"vertical":0.95+9.5*pow(q,1.15)+1.8*smoothstep(0.85,1.0,q),"spin_scale":0.0,"duration":0.38+q*0.20}
 if kind=="finesse":
  result.speed=power*(0.63+0.65*q)
  result.vertical=2.2+8.8*pow(q,1.25)
  result.spin_scale=0.8+q*0.4
  result.duration=0.48+q*0.16
 elif kind=="chip":
  result.speed=power*(0.46+0.54*q)
  result.vertical=5.5+6.5*q
  result.duration=0.44+q*0.16
 return result

static func turn_scale(direction:Vector2,movement:Vector2,ratings:Dictionary)->float:
 if movement.length()<0.1: return 1.0
 var reversal:=maxf(0,absf(direction.angle_to(movement))-PI*0.25)/(PI*0.75)
 return 1.0-reversal*ratings.turn_drag

static func keeper_action(height:float,speed:float,lateral:float,body:Dictionary,hold_speed:float)->String:
 if absf(lateral)>0.55:
  return "dive_low" if height<body.height*0.40 else "dive_high" if height>body.height*0.80 else "dive"
 if height<body.height*0.38: return "foot_save" if speed>hold_speed else "scoop"
 if height>body.height*0.85: return "tip" if speed>hold_speed or height>body.height*1.03 else "catch_high"
 return "parry" if speed>hold_speed else "catch"
