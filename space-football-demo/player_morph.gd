extends RefCounted
## One continuous deformation is shared by skin, kit, hair, rests and bind poses.
const FIELDS:=["height","shoulder","leg_length","muscle","shoulder_scale","waist_scale","hip_scale","torso_depth","limb_scale","arm_span","head_width","head_depth","jaw_width","nose_scale"]

static func signature(body:Dictionary)->String:
 var parts:Array=[]
 for key in FIELDS: parts.append(body.get(key,1.0))
 parts.append(body.has("appearance_id"))
 return JSON.stringify(parts)

static func point(body:Dictionary,v:Array)->Vector3:
 var h:float=body.height
 var x:float=v[0];var y:float=v[1];var z:float=v[2]
 var split:float=body.leg_length/h
 var out_y:float=y/0.53*split if y<0.53 else split+(y-0.53)/0.47*(1.0-split)
 var width:float=(body.shoulder/h)/0.255
 if not body.has("appearance_id"): return Vector3(x*h*width,out_y*h,z*h*(0.94+body.muscle*0.08))
 var ax:=absf(x)
 var head:=smoothstep(0.845,0.90,y)
 var waist:=lerpf(float(body.hip_scale),float(body.waist_scale),smoothstep(0.54,0.63,y))
 var torso:=lerpf(waist,float(body.shoulder_scale),smoothstep(0.65,0.78,y))
 var arm:=smoothstep(0.12,0.20,ax)*smoothstep(0.53,0.61,y)*(1.0-head)
 # Preserve the limb centreline and vary the cross-section around it.
 var leg:=1.0-smoothstep(0.40,0.54,y)
 var leg_x:=signf(x)*0.054+(x-signf(x)*0.054)*float(body.limb_scale)
 var out_x:=lerpf(x*width*torso,leg_x*width*float(body.hip_scale),leg)
 out_x*=lerpf(1.0,float(body.arm_span),arm)
 var jaw:=exp(-pow((y-0.891)/0.024,2))*smoothstep(0.015,0.065,z)
 var face_x:=x*float(body.head_width)*lerpf(1.0,float(body.jaw_width),jaw)
 out_x=lerpf(out_x,face_x,head)
 var depth:=lerpf(float(body.torso_depth),float(body.limb_scale),maxf(leg,arm))
 var out_z:float=z*(0.94+body.muscle*0.08)*depth
 var face_z:=0.026+(z-0.026)*float(body.head_depth)
 var nose:=exp(-pow(x/0.017,2)-pow((y-0.919)/0.020,2))*smoothstep(0.074,0.099,z)
 face_z+=(float(body.nose_scale)-1.0)*0.05*nose
 out_z=lerpf(out_z,face_z,head)
 return Vector3(out_x*h,out_y*h,out_z*h)
