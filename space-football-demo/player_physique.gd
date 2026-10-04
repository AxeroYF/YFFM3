extends RefCounted
## Bounded gameplay interpretation of body proportions, not measured body mass.
## Colour, hair, face, player name and nationality never enter these coefficients.
const VERSION:=1

static func derive(body:Dictionary)->Dictionary:
 var tall:=clampf((float(body.height_cm)-180.0)/20.0,-1,1)
 var leg:=clampf((float(body.leg_length)/float(body.height)-0.515)/0.04,-1,1)
 # Authored shape residuals only: base shoulder already includes the strength stat.
 var girth:=clampf((float(body.get("shoulder_scale",1))-1)*4.0+(float(body.get("torso_depth",1))-1)*2.5+(float(body.get("hip_scale",1))-1)*1.5,-1,1)
 var center:=clampf(tall*0.65+leg*0.20-girth*0.15,-1,1)
 var inertia:=clampf(tall*0.45+leg*0.15+girth*0.40,-1,1)
 return {
  "version":VERSION,"center":center,"inertia":inertia,"girth":girth,
  "center_height":float(body.height)*(0.56+center*0.012),
  "acceleration_scale":clampf(1-inertia*0.08,0.92,1.08),
  "braking_scale":clampf(1-center*0.09-inertia*0.025,0.90,1.10),
  "turn_scale":clampf(1+inertia*0.09+center*0.025,0.90,1.10),
  "running_turn_scale":clampf(0.96-inertia*0.07,0.89,1.0),
  "cut_grip":clampf(0.76-inertia*0.06,0.70,0.82),
  "shield_bonus":clampf(girth*0.065-center*0.018,-0.07,0.085),
  "stability":clampf(1+girth*0.08-center*0.04,0.90,1.12),
  "contact_mass":clampf(1+tall*0.07+girth*0.12,0.84,1.20),
  "collision_scale":1+girth*0.035,
  "foot_reach_scale":1+leg*0.025,
  "tackle_reach_scale":clampf(1+tall*0.04+leg*0.028,0.935,1.07),
  "stride_scale":1+leg*0.035
 }
