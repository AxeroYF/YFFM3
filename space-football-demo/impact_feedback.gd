extends RefCounted
## Render-only recoil. Consuming authority IDs prevents repeat shake on snapshots.
var last_sim:RefCounted
var last_id:=0
var age:=1.0
var strength:=0.0
var direction:=Vector2.RIGHT
var kind:=0

static func offset(elapsed:float,power:float,axis:Vector2,level:int,type:int)->Vector2:
 if level<=0 or elapsed>=0.26 or elapsed<0: return Vector2.ZERO
 var envelope:float=pow(1-elapsed/0.26,2)*minf(elapsed/0.018,1)
 var amplitude:float=(0.16 if level==1 else 0.28)*clampf(power,0,1)
 var recoil:=Vector2(axis.x,-axis.y*0.6).normalized()
 return (recoil*sin(elapsed*72)+recoil.orthogonal()*sin(elapsed*105+type)*0.32)*amplitude*envelope

func update(game,dt:float)->void:
 if not is_instance_valid(game.camera): return
 game.camera.h_offset=0;game.camera.v_offset=0
 if game.sim==null: last_sim=null;age=1;return
 var s=game.sim
 if s!=last_sim: last_sim=s;last_id=s.impact_id;age=1
 var allowed:bool=game.screen=="match" and s.phase=="play" and not s.finished
 var level:int=int(game.desktop_input.options.get("camera_impact",1))
 if s.impact_id!=last_id:
  last_id=s.impact_id
  if allowed and level>0:
   strength=s.impact_strength;direction=Vector2(s.impact_x,s.impact_y);kind=s.impact_kind;age=0
 if not allowed or level==0: age=1;return
 age+=dt
 var shake:=offset(age,strength,direction,level,kind)
 game.camera.h_offset=shake.x;game.camera.v_offset=shake.y
