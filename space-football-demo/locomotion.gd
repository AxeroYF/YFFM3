extends RefCounted
## Presentation only. One cycle is the distance between two contacts of the same foot.
static func profile(speed:float,leg_length:float,compact:bool=false)->Dictionary:
 var run:=smoothstep(1.2,5.8,speed)
 var sprint:=smoothstep(5.8,9.6,speed)
 var stride:=leg_length*(1.8+0.9*run+0.45*sprint)*(0.72 if compact else 1.0)
 return {"run":run,"sprint":sprint,"stride":stride,"duty":lerpf(0.62,0.42,run)-0.02*sprint,
  "lift":0.035+0.075*run+0.065*sprint,"lean":0.025+0.10*run+0.10*sprint,
  "crouch":0.08+0.015*run+0.02*sprint}

static func foot(cycle:float,profile:Dictionary)->Vector2:
 var t:=fposmod(cycle,1.0)
 var span:float=profile.stride*profile.duty
 if t<profile.duty:
  # Plant travels backwards at exactly the ground speed during contact.
  return Vector2(span*(0.5-t/profile.duty),0)
 var swing:float=(t-profile.duty)/(1-profile.duty)
 return Vector2(lerpf(-span/2,span/2,smoothstep(0,1,swing)),sin(PI*swing)*profile.lift)

static func arm_opposition(cycle:float,profile:Dictionary)->float:
 # Use the actual foot trajectory (including its stance/swing timing), not a separate sine.
 var left:=foot(cycle,profile).x
 var right:=foot(cycle+0.5,profile).x
 return clampf((left-right)/(profile.stride*profile.duty),-1,1)
