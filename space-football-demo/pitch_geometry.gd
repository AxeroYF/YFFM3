extends RefCounted
## Scale playing area by 20%; goals, footballers and movement units stay unchanged.
const AREA_SCALE:=1.20
const SCALE:=1.0954451150103322
const HALF_LENGTH:=32.0*SCALE
const HALF_WIDTH:=18.0*SCALE
const GOAL_HALF_WIDTH:=5.0
const GOAL_HEIGHT:=3.6
const GOAL_DEPTH:=3.0
const GOAL_BACK_HEIGHT:=3.0
const PLAYER_LIMIT:=Vector2(HALF_LENGTH-0.9,HALF_WIDTH-0.7)
const RESTART_LIMIT:=Vector2(HALF_LENGTH-1.0,HALF_WIDTH-1.0)
const AI_LIMIT:=Vector2(HALF_LENGTH-3.3,HALF_WIDTH-3.0)
const CAMERA:=Vector3(0,51,43)*SCALE
const FORMATION:=[Vector2(-HALF_LENGTH+3,0),Vector2(-5.5,0),Vector2(-13.2,-12),Vector2(-13.2,12),Vector2(-24,0)]

static func movement_limit(body:Dictionary,rebound:bool)->Vector2:
 if not rebound: return PLAYER_LIMIT
 # Leave room for the body, but allow the feet to reach a ball in either corner.
 var inset:float=body.body_radius+0.04
 return Vector2(HALF_LENGTH-inset,HALF_WIDTH-inset)
