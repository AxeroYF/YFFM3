extends RefCounted
## Pixel-calibrated contact recoil. Authority frame + ID rejects stale/repeated hits.
const DURATION:=0.24
const MAX_EVENT_AGE:=0.18
var last_sim:RefCounted
var last_id:=0
var age:=1.0
var strength:=0.0
var direction:=Vector2.RIGHT
var kind:=0

static func offset(elapsed:float,power:float,axis:Vector2,level:int,type:int)->Vector2:
 if level<=0 or elapsed>=DURATION or elapsed<0: return Vector2.ZERO
 var envelope:float=pow(1-elapsed/DURATION,2)
 var amplitude:float=(11.0 if level==1 else 19.0)*clampf(power,0,1)
 var recoil:=axis.normalized() if axis.length()>0.01 else Vector2.RIGHT
 # Immediate push, one diminishing return; no delayed fade-in past contact.
 return (recoil*cos(elapsed*43)+recoil.orthogonal()*sin(elapsed*68)*0.22*(1 if type%2==0 else -1))*amplitude*envelope

static func fresh(event_frame:int,current_frame:int)->bool:
 return event_frame>=0 and current_frame>=event_frame and (current_frame-event_frame)/60.0<MAX_EVENT_AGE

func update(camera:Camera3D,s,playing:bool,level:int,dt:float)->void:
 if not is_instance_valid(camera): return
 camera.h_offset=0;camera.v_offset=0
 if s==null: last_sim=null;age=1;return
 if s!=last_sim: last_sim=s;last_id=0;age=1
 var allowed:bool=playing and s.phase=="play" and not s.finished
 age+=dt
 if s.impact_id!=last_id:
  last_id=s.impact_id
  if allowed and level>0 and fresh(s.impact_frame,s.frame):
   strength=s.impact_strength;direction=Vector2(s.impact_x,s.impact_y);kind=s.impact_kind
   age=maxf(0,(s.frame-s.impact_frame)/60.0)
 if not allowed or level==0: age=1;return
 var world_axis:=Vector3(direction.x,0,direction.y)
 var screen_axis:=Vector2(world_axis.dot(camera.global_basis.x),world_axis.dot(camera.global_basis.y))
 var pixels:=offset(age,strength,screen_axis,level,kind)
 var viewport_size:=camera.get_viewport().get_visible_rect().size
 var center:=viewport_size*0.5
 var ball_world:=Vector3(s.ball.x,s.ball_height,s.ball.y)
 var depth:=maxf(1,-(camera.global_transform.affine_inverse()*ball_world).z)
 var pixel_world:float=camera.project_position(center+Vector2.RIGHT,depth).distance_to(camera.project_position(center,depth))
 pixels*=viewport_size.y/1440.0
 camera.h_offset=pixels.x*pixel_world;camera.v_offset=pixels.y*pixel_world
