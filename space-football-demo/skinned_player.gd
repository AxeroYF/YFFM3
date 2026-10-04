extends Node3D
## CC0 MakeHuman continuous mesh + official skin weights, driven by game actions.
const Body=preload("res://player_body.gd")
const Locomotion=preload("res://locomotion.gd")
const Motion=preload("res://football_motion.gd")
const Morph=preload("res://player_morph.gd")
const Groom=preload("res://player_groom.gd")
static var asset:Dictionary={}
static var geometry_cache:Dictionary={}
const MAX_CACHED_BODIES:=32
var body:Dictionary
var skeleton:Skeleton3D
var bone_ids:Dictionary={}
var body_mesh:MeshInstance3D
var phase:=0.0
var gait:=0.0
var kit_materials:Dictionary={}
var shirt_labels:Array[Label3D]=[]
var is_keeper:=false
var leg_rest:Dictionary={}
var arm_rest:Dictionary={}
var palm_normals:Dictionary={}
var finger_curl_axes:Dictionary={}
var stride_length:=0.0
var cadence:=0.0
var locomotion_speed:=0.0
var previous_travel:=Vector3.ZERO
var momentum_lean:=Vector2.ZERO
const ACTION_BONES:=["spine02","head","upperleg01.L","upperleg01.R","lowerleg01.L","lowerleg01.R","foot.L","foot.R","upperarm01.L","upperarm01.R","lowerarm01.L","lowerarm01.R","wrist.L","wrist.R"]

func dimensions(v:Array)->Vector3:
 return Morph.point(body,v)

func active_surfaces()->Array:
 return asset.surfaces.filter(func(s):return not body.has("appearance_id") or s.material!="hair")

func build(color:Color,number:String,keeper:bool=false,profile:Dictionary={})->void:
 is_keeper=keeper
 build_skeleton(Body.profile(0 if keeper else 1) if profile.is_empty() else profile)
 build_surfaces(color,number)

func build_skeleton(profile:Dictionary)->void:
 body=profile.duplicate(true)
 if asset.is_empty(): asset=JSON.parse_string(FileAccess.get_file_as_string("res://assets/humanoid/human_mesh.json"))
 skeleton=Skeleton3D.new()
 skeleton.name="Skeleton3D"
 add_child(skeleton)
 for i in asset.bones.size():
  var b:Dictionary=asset.bones[i]
  skeleton.add_bone(b.name)
  bone_ids[b.name]=i
  skeleton.set_bone_parent(i,int(b.parent))
  var head:=dimensions(b.head)
  var parent_head:=dimensions(asset.bones[int(b.parent)].head) if b.parent>=0 else Vector3.ZERO
  skeleton.set_bone_rest(i,Transform3D(Basis.IDENTITY,head-parent_head))
 skeleton.reset_bone_poses()
 for suffix in [".L",".R"]:
  leg_rest[suffix]=[dimensions(asset.bones[bone_ids["upperleg01"+suffix]].head),dimensions(asset.bones[bone_ids["lowerleg01"+suffix]].head),dimensions(asset.bones[bone_ids["foot"+suffix]].head)]
  arm_rest[suffix]=[dimensions(asset.bones[bone_ids["lowerarm01"+suffix]].head)-dimensions(asset.bones[bone_ids["upperarm01"+suffix]].head),dimensions(asset.bones[bone_ids["wrist"+suffix]].head)-dimensions(asset.bones[bone_ids["lowerarm01"+suffix]].head)]
  var wrist:=dimensions(asset.bones[bone_ids["wrist"+suffix]].head)
  var fingers:=dimensions(asset.bones[bone_ids["finger3-1"+suffix]].head)-wrist
  var across:=dimensions(asset.bones[bone_ids["finger2-1"+suffix]].head)-dimensions(asset.bones[bone_ids["finger5-1"+suffix]].head)
  var palm:Vector3=across.cross(fingers).normalized()*(-1 if suffix==".L" else 1)
  palm_normals[suffix]=palm
  for finger in range(2,6):
   var finger_axis:Vector3=(dimensions(asset.bones[bone_ids["finger%d-2%s" % [finger,suffix]]].head)-dimensions(asset.bones[bone_ids["finger%d-1%s" % [finger,suffix]]].head)).cross(palm).normalized()
   finger_curl_axes[str(finger)+suffix]=finger_axis

func build_surfaces(color:Color,number:String)->void:
 var skin:=Skin.new()
 for i in asset.bones.size(): skin.add_bind(i,Transform3D(Basis.IDENTITY,-dimensions(asset.bones[i].head)))
 var key:=Morph.signature(body)
 if not geometry_cache.has(key):
  if geometry_cache.size()>=MAX_CACHED_BODIES: geometry_cache.erase(geometry_cache.keys()[0])
  geometry_cache[key]=build_geometry()
 body_mesh=MeshInstance3D.new()
 body_mesh.name="Footballer"
 body_mesh.mesh=geometry_cache[key]
 body_mesh.skin=skin
 body_mesh.skeleton=NodePath("../Skeleton3D")
 body_mesh.extra_cull_margin=body.height
 add_child(body_mesh)
 var surfaces:=active_surfaces()
 for i in surfaces.size():
  var category:String=surfaces[i].material
  if category=="skin" and body.has("appearance_id"):
   body_mesh.set_surface_override_material(i,Groom.skin_material(body))
   continue
  var m:=StandardMaterial3D.new()
  m.roughness=0.88
  if category=="skin":
   m.albedo_texture=load("res://assets/humanoid/skin.png")
   m.albedo_color=Color(body.skin).lerp(Color.WHITE,0.20)
  elif category=="eyes": m.albedo_texture=load("res://assets/humanoid/eyes.png")
  elif category=="hair":
   m.albedo_texture=load("res://assets/humanoid/hair.png")
   m.albedo_color=Color(body.hair).lightened(0.35)
   m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
   m.cull_mode=BaseMaterial3D.CULL_DISABLED
  else:
   m.albedo_color=color if category in ["jersey","socks"] else Color("132438")
   if category=="boots": m.albedo_color=Color("e3e8eb"); m.roughness=0.56
   kit_materials[category]=m
  body_mesh.set_surface_override_material(i,m)
 var chest_attachment:=BoneAttachment3D.new()
 chest_attachment.bone_name="spine02"
 skeleton.add_child(chest_attachment)
 var chest_origin:=dimensions(asset.bones[bone_ids.spine02].head)
 for front in [false,true]:
  var label:=Label3D.new()
  label.text=number
  label.font_size=96
  label.pixel_size=body.height*(0.0011 if front else 0.0017)
  label.position=dimensions([0,0.71,0.109 if front else -0.074])-chest_origin
  if not front: label.rotation.y=PI
  label.outline_size=2
  chest_attachment.add_child(label)
  shirt_labels.append(label)
 add_boot_details()
 if body.has("appearance_id"): Groom.build(self,skin)
 animate_player({"vel":Vector2.ZERO,"action":"idle","action_time":0},0,false)

func add_boot_details()->void:
 for side in [".L",".R"]:
  var foot:=BoneAttachment3D.new()
  foot.bone_name="foot"+side
  skeleton.add_child(foot)
  var origin:=dimensions(asset.bones[bone_ids["foot"+side]].head)
  var h:float=body.height
  var dark:=StandardMaterial3D.new()
  dark.albedo_color=Color("142437")
  for i in 6:
   var stud:=MeshInstance3D.new()
   var shape:=CylinderMesh.new()
   shape.top_radius=h*0.006
   shape.bottom_radius=h*0.005
   shape.height=h*0.011
   shape.radial_segments=8
   stud.mesh=shape
   stud.material_override=dark
   stud.position=Vector3(origin.x+(-1 if i%2==0 else 1)*h*0.021,h*0.009,origin.z+h*(0.012+(i/2)*0.034))-origin
   foot.add_child(stud)
  for i in 4:
   var lace:=MeshInstance3D.new()
   var shape:=BoxMesh.new()
   shape.size=Vector3(h*0.033,h*0.002,h*0.003)
   lace.mesh=shape
   lace.material_override=dark
   lace.position=Vector3(origin.x,h*(0.046-i*0.004),origin.z+h*(0.035+i*0.011))-origin
   foot.add_child(lace)

func build_geometry()->ArrayMesh:
 var mesh:=ArrayMesh.new()
 var positions:=PackedVector3Array()
 for v in asset.vertices: positions.append(dimensions(v))
 # Shared normals before UV/material splits preserve the smooth neck/shoulder surface.
 var normals:=PackedVector3Array()
 normals.resize(positions.size())
 for surface in active_surfaces():
  var ids:Array=surface.indices
  for i in range(0,ids.size(),3):
   var a:int=ids[i]; var b:int=ids[i+1]; var c:int=ids[i+2]
   var n:Vector3=(positions[b]-positions[a]).cross(positions[c]-positions[a])
   normals[a]+=n; normals[b]+=n; normals[c]+=n
 for i in normals.size(): normals[i]=normals[i].normalized()
 for surface in active_surfaces():
  var st:=SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for t in range(0,surface.indices.size(),3):
   for k in [0,2,1]:
    var i:int=t+k
    var index:int=surface.indices[i]
    var binds:=PackedInt32Array([0,0,0,0])
    var weights:=PackedFloat32Array([0,0,0,0])
    for w in asset.weights[index].size():
     binds[w]=int(asset.weights[index][w][0]); weights[w]=float(asset.weights[index][w][1])
    st.set_bones(binds)
    st.set_weights(weights)
    st.set_normal(normals[index])
    st.set_uv(Vector2(surface.uv[i][0],1.0-surface.uv[i][1]))
    if surface.material=="skin" and body.has("appearance_id"): st.set_color(Groom.beard_mask(asset.vertices[index]))
    st.add_vertex(positions[index])
  st.index()
  st.commit(mesh)
 return mesh

func customize_kit(jersey:Color,shorts:Color,socks:Color,boots:Color,number:String)->void:
 # Presentation-only extension point; equipment must never change body reach.
 for item in [["jersey",jersey],["shorts",shorts],["socks",socks],["boots",boots]]:
  if kit_materials.has(item[0]): kit_materials[item[0]].albedo_color=item[1]
 for label in shirt_labels: label.text=number

func pose(name:String,x:float=0.0,y:float=0.0,z:float=0.0)->void:
 skeleton.set_bone_pose_rotation(bone_ids[name],Quaternion.from_euler(Vector3(x,y,z)))

func animate_player(p:Dictionary,dt:float,holding:bool,local_velocity:Vector3=Vector3.INF)->void:
 if local_velocity==Vector3.INF:
  var facing:Vector2=p.get("dir",Vector2.DOWN)
  local_velocity=Vector3(p.vel.dot(Vector2(facing.y,-facing.x)),0,p.vel.dot(facing))
 var speed:=Vector2(local_velocity.x,local_velocity.z).length()
 locomotion_speed=speed
 if dt>0:
  # Displayed displacement drives the lean, just as it drives the planted feet.
  # Bound snapshot corrections and keep the legs grounded through spine-only tilt.
  var acceleration:Vector3=(local_velocity-previous_travel)/dt if dt<0.1 else Vector3.ZERO
  var center:float=body.physique.center
  var target_lean:=Vector2(clampf(acceleration.z*0.004,-0.10,0.12),clampf(-acceleration.x*0.004,-0.10,0.10))*(1+center*0.12)
  momentum_lean=momentum_lean.lerp(target_lean,1-exp(-dt*14))
  previous_travel=local_velocity
 var hand_holding:bool=holding and p.get("keeper_holding",false)
 var field_posture:bool=is_keeper and ((holding and not hand_holding) or (p.action_time>0 and p.action in Motion.KICKS+["receive","windup","tackle","slide","slide_still","header","shield","block","block_chest","block_head","retrieve_ball","carry_ball","place_ball"]))
 var compact:bool=(is_keeper and not field_posture and p.action!="rush") or (p.action=="shield" and p.action_time>0)
 var travel:=Locomotion.profile(speed,body.leg_length,compact)
 # Backpedalling and lateral shuffles use shorter steps while the body finishes turning.
 var forward_weight:=maxf(0,local_velocity.z/maxf(0.01,speed))
 travel.stride*=lerpf(0.76,1.0,forward_weight)
 stride_length=travel.stride
 cadence=speed/stride_length
 gait=lerpf(gait,clampf(speed/0.9,0,1),1.0-exp(-dt*18))
 phase=fposmod(phase+dt*cadence*TAU,TAU)
 var root_action:bool=p.action_time>0 and p.action in ["slide","slide_still","fall","header","celebrate"]
 if p.action not in ["slide","slide_still"] or p.action_time<=0: position.z=lerpf(position.z,0,1.0-exp(-dt*22))
 if not root_action: rotation.x=lerp_angle(rotation.x,0,minf(1,dt*18))
 if not is_keeper or field_posture:
  rotation.z=lerp_angle(rotation.z,0,minf(1,dt*18))
  if not root_action:
   position.y=lerpf(position.y,body.height*(-travel.crouch+absf(sin(phase))*0.014*travel.run)*gait,1.0-exp(-dt*22))
 var opposition:=Locomotion.arm_opposition(phase/TAU,travel)
 var shoulder_twist:float=opposition*(0.025+0.045*travel.run+0.025*travel.sprint)*gait
 pose("spine02",travel.lean*gait+momentum_lean.x,shoulder_twist,opposition*0.018*gait+momentum_lean.y)
 pose("head",0,-shoulder_twist*0.65)
 for i in 2:
  var suffix:String=[".L",".R"][i]
  var step:=Locomotion.foot(phase/TAU+i*0.5,travel)
  var direction:=local_velocity.normalized() if speed>0.05 else Vector3.FORWARD
  var ankle:Vector3=leg_rest[suffix][2]+direction*step.x*gait
  ankle.y+=step.y*body.height*gait-position.y
  solve_leg(suffix,ankle)
 animate_running_arms(travel,opposition,local_velocity)
 var relaxed_hands:bool=not hand_holding and (p.action_time<=0 or p.action in ["idle","rush"])
 for suffix in [".L",".R"]:
  for finger in range(2,6):
   for joint in range(1,4):
    var curl:float=(0.30 if joint==1 else 0.65 if joint==2 else 0.45)*gait if relaxed_hands else 0.16
    skeleton.set_bone_pose_rotation(bone_ids["finger%d-%d%s" % [finger,joint,suffix]],Quaternion(finger_curl_axes[str(finger)+suffix],curl))
 if holding and speed<0.3: pose("upperleg01.R",-0.07,0,0.07)
 if is_keeper and not field_posture: animate_keeper(p,dt,hand_holding)
 var base_poses:Array=[]
 for bone in ACTION_BONES: base_poses.append(skeleton.get_bone_pose_rotation(bone_ids[bone]))
 animate_match_action(p,dt)
 if p.action_time>0 and p.action in Motion.KICKS+["windup"]:
  strike_arms(p)
 if p.get("preferred_foot","right")=="left" and p.action_time>0 and p.action in Motion.KICKS+["windup","receive","feint"]:
  mirror_kick_pose()
 # Blend the release/recovery into current travel instead of snapping back to gait.
 if p.action_time>0 and p.action in Motion.KICKS+["receive","block","block_chest","block_head","land","stumble","header","feint"]:
  var weight:float=smoothstep(0,0.24,float(p.action_time)/Motion.action_duration(p))
  for i in ACTION_BONES.size():
   var id:int=bone_ids[ACTION_BONES[i]]
   skeleton.set_bone_pose_rotation(id,base_poses[i].slerp(skeleton.get_bone_pose_rotation(id),weight))

func mirror_kick_pose()->void:
 # Mirror the existing kick, including support leg and counterbalancing arms.
 for bone in ["upperleg01","lowerleg01","foot","upperarm01","lowerarm01","wrist"]:
  var left:=skeleton.get_bone_pose_rotation(bone_ids[bone+".L"])
  var right:=skeleton.get_bone_pose_rotation(bone_ids[bone+".R"])
  skeleton.set_bone_pose_rotation(bone_ids[bone+".L"],Quaternion(right.x,-right.y,-right.z,right.w))
  skeleton.set_bone_pose_rotation(bone_ids[bone+".R"],Quaternion(left.x,-left.y,-left.z,left.w))
 var spine:=skeleton.get_bone_pose_rotation(bone_ids["spine02"])
 skeleton.set_bone_pose_rotation(bone_ids["spine02"],Quaternion(spine.x,-spine.y,-spine.z,spine.w))

func animate_running_arms(travel:Dictionary,opposition:float,velocity:Vector3)->void:
 var forward:float=velocity.z/maxf(0.01,locomotion_speed)
 var swing_scale:float=lerpf(0.65,1.0,absf(forward))
 for i in 2:
  var suffix:String=[".L",".R"][i]
  var side:float=1 if i==0 else -1
  var drive:float=opposition*side
  # Same-side leg forward => shoulder back; elbow opens on the backswing and
  # folds on the forward swing. Calibrate from the mesh's A-pose bone directions.
  var shoulder_pitch:float=drive*(0.26+0.38*travel.run+0.22*travel.sprint)*gait*forward*swing_scale
  var elbow_flex:float=0.16+(0.24+0.70*travel.run+0.12*travel.sprint-shoulder_pitch*0.32)*gait
  var outward:float=side*(0.12+0.05*travel.sprint*gait)
  var upper_direction:=Vector3(outward,-cos(shoulder_pitch),-sin(shoulder_pitch)).normalized()
  var lower_pitch:=shoulder_pitch-elbow_flex
  var lower_direction:=Vector3(side*0.035,-cos(lower_pitch),-sin(lower_pitch)).normalized()
  var upper:=Quaternion(arm_rest[suffix][0].normalized(),upper_direction)
  var lower:=Quaternion(arm_rest[suffix][1].normalized(),lower_direction)
  # Forearm roll keeps palms facing inward instead of drooping flat toward the turf.
  var palm:Vector3=lower*palm_normals[suffix]
  palm=(palm-lower_direction*palm.dot(lower_direction)).normalized()
  var inward:=Vector3(-side,0,0)
  inward=(inward-lower_direction*inward.dot(lower_direction)).normalized()
  lower=Quaternion(lower_direction,palm.signed_angle_to(inward,lower_direction))*lower
  skeleton.set_bone_pose_rotation(bone_ids["upperarm01"+suffix],upper)
  skeleton.set_bone_pose_rotation(bone_ids["lowerarm01"+suffix],upper.inverse()*lower)
  pose("wrist"+suffix)

func strike_arms(p:Dictionary)->void:
 # Bone rest axes are an A-pose: Euler offsets alone would keep both arms spread.
 var power:float=clampf(p.action_strength,0,1)
 if p.action=="pass": power*=0.35
 var recovery:float=clampf(float(p.action_time)/Motion.action_duration(p)*2,0,1)
 for i in 2:
  var suffix:String=[".L",".R"][i];var side:float=1 if i==0 else -1
  var outward:float=(0.26+power*0.35)*recovery
  arm_directions(suffix,Vector3(side*outward,-0.85,0.12*side),Vector3(side*0.18,-0.45,0.65))

func arm_directions(suffix:String,upper_direction:Vector3,lower_direction:Vector3)->void:
 var upper:=Quaternion(arm_rest[suffix][0].normalized(),upper_direction.normalized())
 var lower:=Quaternion(arm_rest[suffix][1].normalized(),lower_direction.normalized())
 skeleton.set_bone_pose_rotation(bone_ids["upperarm01"+suffix],upper)
 skeleton.set_bone_pose_rotation(bone_ids["lowerarm01"+suffix],upper.inverse()*lower)
 pose("wrist"+suffix)

func defensive_arms(sliding:bool)->void:
 for i in 2:
  var suffix:String=[".L",".R"][i]
  var side:float=1 if i==0 else -1
  var upper_direction:=Vector3(side*0.30,-0.85,-0.30 if sliding else 0.12).normalized()
  var lower_direction:=Vector3(side*0.15,-0.70,0.40).normalized()
  var upper:=Quaternion(arm_rest[suffix][0].normalized(),upper_direction)
  var lower:=Quaternion(arm_rest[suffix][1].normalized(),lower_direction)
  skeleton.set_bone_pose_rotation(bone_ids["upperarm01"+suffix],upper)
  skeleton.set_bone_pose_rotation(bone_ids["lowerarm01"+suffix],upper.inverse()*lower)
  pose("wrist"+suffix)

func solve_leg(suffix:String,target:Vector3)->void:
 # Two-bone solve uses this player's actual leg proportions; soles stay level on contact.
 var rest:Array=leg_rest[suffix]
 var hip:Vector3=rest[0]
 var thigh:Vector3=rest[1]-hip
 var shin:Vector3=rest[2]-rest[1]
 var upper_length:=thigh.length();var lower_length:=shin.length()
 var offset:=target-hip
 var distance:=clampf(offset.length(),0.01,upper_length+lower_length-0.001)
 var axis:=offset.normalized()
 var pole:=(Vector3.BACK-axis*axis.dot(Vector3.BACK)).normalized()
 var along:float=(upper_length*upper_length-lower_length*lower_length+distance*distance)/(2*distance)
 var knee:=hip+axis*along+pole*sqrt(maxf(0,upper_length*upper_length-along*along))
 var upper:=Quaternion(thigh.normalized(),(knee-hip).normalized())
 var lower_global:=Quaternion(shin.normalized(),(hip+axis*distance-knee).normalized())
 skeleton.set_bone_pose_rotation(bone_ids["upperleg01"+suffix],upper)
 skeleton.set_bone_pose_rotation(bone_ids["lowerleg01"+suffix],upper.inverse()*lower_global)
 skeleton.set_bone_pose_rotation(bone_ids["foot"+suffix],lower_global.inverse())

func animate_match_action(p:Dictionary,dt:float)->void:
 if p.action_time<=0: return
 var duration:float=Motion.action_duration(p)
 var strength:float=p.get("action_strength",0.4)
 var progress:=1-clampf(float(p.action_time)/duration,0,1)
 var wave:=sin(progress*PI)
 var blend:=minf(1,dt*22)
 if p.action in Motion.KICKS+["windup","receive"]:
  # The support boot no longer keeps running while the striking leg follows through.
  var ankle:Vector3=leg_rest[".L"][2];ankle.y-=position.y
  solve_leg(".L",ankle)
 if p.action in ["retrieve_ball","carry_ball","place_ball"]:
  var pickup:bool=p.action=="retrieve_ball"
  var amount:float=clampf(1-float(p.action_time)/0.55,0,1)
  var bend:float=(sin(amount*PI)*0.95 if pickup else sin(amount*PI*0.75)) if p.action!="carry_ball" else 0.0
  pose("spine02",bend*0.95)
  if p.action!="carry_ball":
   pose("upperleg01.L",-0.25*bend);pose("upperleg01.R",-0.25*bend)
   pose("lowerleg01.L",0.48*bend);pose("lowerleg01.R",0.48*bend)
  var height:float=body.height*0.52
  if pickup: height=lerpf(0.30,height,smoothstep(0.18,1,amount))
  elif p.action=="place_ball": height=lerpf(height,0.30,smoothstep(0,0.85,amount))
  var hand_ball:Vector3=transform.affine_inverse()*p.get("hand_ball",Vector3(0,height,0.45))
  reach_hand(".L",hand_ball+Vector3(0.34,0.08,-0.02))
  reach_hand(".R",hand_ball+Vector3(-0.34,0.08,-0.02))
 elif p.action=="shield":
  pose("spine02",0.10-float(body.physique.center)*0.025,0.28)
  pose("upperarm01.L",0.15,0,0.80)
  pose("upperarm01.R",-0.15,0,-0.65)
  pose("lowerarm01.L",-0.45);pose("lowerarm01.R",-0.50)
  if gait<0.1:
   pose("upperleg01.L",-0.15,0,-0.12);pose("upperleg01.R",-0.15,0,0.12)
   pose("lowerleg01.L",0.25);pose("lowerleg01.R",0.25)
 elif p.action=="windup":
  pose("spine02",0.10,-0.25*strength)
  pose("upperleg01.R",0.15+strength*0.42,0,0.10)
  pose("lowerleg01.R",0.25+strength*0.7)
  pose("upperleg01.L",-0.08,0,-0.07)
  pose("lowerleg01.L",0.16)
  pose("upperarm01.L",-0.25,0,0.45)
  pose("upperarm01.R",0.25,0,-0.50)
 elif p.action in ["pass","driven_pass"]:
  var swing:=cos(progress*PI*0.5)
  var driven:bool=p.action=="driven_pass"
  pose("upperleg01.R",-swing*(0.95 if driven else 0.52),0.12 if driven else 0.55,0.08)
  pose("lowerleg01.R",0.14);pose("foot.R",-0.15 if driven else 0,0.38 if not driven else 0)
  pose("spine02",0.15*swing if driven else 0.04,0.22*swing)
  pose("upperarm01.L",-0.25,0,0.68 if driven else 0.40);pose("lowerarm01.L",0.30)
  pose("upperarm01.R",0.20,0,-0.50);pose("lowerarm01.R",0.25)
 elif p.action=="receive":
  var cushion:=cos(progress*PI*0.5)
  var ankle:Vector3=leg_rest[".R"][2]+Vector3(0.06,0.10*cushion-position.y,body.height*lerpf(0.19,0.06,progress))
  solve_leg(".R",ankle);pose("foot.R",0,0.48*cushion)
  pose("spine02",0.14*cushion,-0.18*cushion)
  defensive_arms(false)
 elif p.action in ["block","block_chest","block_head"]:
  var recoil:=cos(progress*PI*0.5)
  defensive_arms(false)
  if p.action=="block":
   pose("upperleg01.R",-0.6*recoil,0,0.22*recoil);pose("lowerleg01.R",0.12)
   pose("upperleg01.L",-0.12);pose("lowerleg01.L",0.28);pose("spine02",0.18*recoil)
  elif p.action=="block_chest":
   pose("spine02",-0.32*recoil);pose("head",0.20*recoil)
   arm_directions(".L",Vector3(0.4,-0.85,-0.2),Vector3(0.1,-0.4,0.5))
   arm_directions(".R",Vector3(-0.4,-0.85,-0.2),Vector3(-0.1,-0.4,0.5))
   pose("upperleg01.L",-0.15);pose("upperleg01.R",-0.15)
  else:
   pose("spine02",-0.14*recoil);pose("head",-0.34*recoil)
 elif p.action in ["shoot","power_shot","finesse"]:
  var swing:=cos(minf(progress*1.1,1)*PI*0.5)
  pose("upperleg01.R",-swing*(0.75+strength*0.65),0.4*swing if p.action=="finesse" else 0,0.12)
  pose("lowerleg01.R",0.12+maxf(0,0.2-progress)*2.0)
  pose("foot.R",-0.18,0.35 if p.action=="finesse" else 0)
  pose("spine02",-swing*strength*0.18,swing*(0.5 if p.action=="finesse" else 0.2))
  pose("upperarm01.L",-0.3,0,0.55+strength*0.3)
  pose("upperarm01.R",0.25,0,-0.50-strength*0.3)
 elif p.action in ["cross","chip","set_kick","volley"]:
  var follow:=cos(progress*PI*0.5)
  pose("upperleg01.R",-follow*(1.45 if p.action=="volley" else 1.1),0,0.1)
  pose("lowerleg01.R",0.15+maxf(0,0.35-progress)*1.5)
  if p.action=="volley":
   var target:Vector3=leg_rest[".R"][2]
   target.y=lerpf(target.y,clampf(float(p.get("contact_height",body.height*0.5)),0.45,body.height*0.7),follow)-position.y
   target.z+=body.leg_length*0.62*follow
   solve_leg(".R",target);pose("foot.R",-0.12)
  pose("spine02",-follow*0.16,-follow*0.22)
  pose("upperarm01.L",-0.25,0,0.8*follow)
  pose("upperarm01.R",0.2,0,-0.7*follow)
 elif p.action=="tackle":
  var extension:float=sin(clampf(progress/0.46,0,1)*PI) if progress<0.46 else 0
  pose("upperleg01.R",-1.0*extension,0,0.08)
  pose("lowerleg01.R",0.10+0.10*extension);pose("foot.R",-0.12*extension)
  pose("upperleg01.L",-0.16*extension);pose("lowerleg01.L",0.30*extension)
  pose("spine02",0.24*extension,-0.12*extension)
  defensive_arms(false)
 elif p.action in ["slide","slide_still"]:
  var stationary:bool=p.action=="slide_still"
  var ground:float=clampf(progress/0.13,0,1) if progress<0.58 else clampf((1-progress)/0.42,0,1)
  rotation.x=lerp_angle(rotation.x,(-0.38 if stationary else -0.70)*ground,blend)
  rotation.z=lerp_angle(rotation.z,0.16*ground,blend)
  var hips_origin:Vector3=(leg_rest[".L"][0]+leg_rest[".R"][0])*0.5
  var rotated_hips:Vector3=basis*hips_origin
  position.y=lerpf(position.y,lerpf(hips_origin.y,body.height*(0.25 if stationary else 0.15),ground)-rotated_hips.y,blend)
  position.z=lerpf(position.z,-rotated_hips.z,blend)
  pose("spine02",0.10*ground,0.16*ground)
  # Keep both boots above the pitch while extending one leg and folding the other.
  for suffix in [".L",".R"]:
   var hip:Vector3=transform*leg_rest[suffix][0]
   var foot:Vector3=transform*leg_rest[suffix][2]
   foot.y=0.10
   foot.z=lerpf(foot.z,hip.z+body.leg_length*(0.75 if stationary and suffix==".R" else 0.90 if suffix==".R" else 0.20),ground)
   if suffix==".L": foot.x-=body.hip_width*0.65*ground
   solve_leg(suffix,transform.affine_inverse()*foot)
  defensive_arms(true)
 elif p.action=="fall":
  var fall:=sin(minf(progress/0.65,1)*PI*0.5) if progress<0.65 else (1-progress)/0.35
  rotation.x=lerp_angle(rotation.x,-1.35*fall,blend)
  position.y=lerpf(position.y,-body.height*0.05*fall,blend)
  pose("upperleg01.L",-0.55*fall,0,-0.15)
  pose("upperleg01.R",-0.8*fall,0,0.12)
  pose("lowerleg01.L",1.25*fall)
  pose("lowerleg01.R",0.9*fall)
  pose("upperarm01.L",-0.8,0,0.5)
  pose("upperarm01.R",-0.8,0,-0.5)
 elif p.action=="jump":
  pose("upperarm01.L",-0.5,0,0.8);pose("upperarm01.R",-0.5,0,-0.8)
  pose("lowerleg01.L",0.65);pose("lowerleg01.R",0.45);pose("spine02",-0.15)
 elif p.action=="land":
  pose("upperleg01.L",-0.3);pose("upperleg01.R",-0.3)
  pose("lowerleg01.L",0.6);pose("lowerleg01.R",0.6);pose("spine02",0.2)
 elif p.action=="stumble":
  pose("spine02",0.25,0,0.2);pose("upperarm01.L",0,0,1.0);pose("upperarm01.R",0,0,-1.0)
 elif p.action=="header":
  rotation.x=lerp_angle(rotation.x,0,blend)
  position.y=lerpf(position.y,0,blend)
  pose("spine02",-0.28+0.7*progress)
  pose("head",0.35*wave)
  pose("upperarm01.L",-0.4,0,0.85)
  pose("upperarm01.R",-0.4,0,-0.85)
  pose("lowerleg01.L",0.6*wave)
  pose("lowerleg01.R",0.45*wave)
 elif p.action=="feint":
  pose("spine02",0.05,wave*0.55)
  pose("upperleg01.R",-wave*0.6,0,wave*0.2)
 elif p.action=="wall":
  pose("upperleg01.L",-0.12,0,-0.10)
  pose("upperleg01.R",-0.12,0,0.10)
  pose("lowerleg01.L",0.20)
  pose("lowerleg01.R",0.20)
  reach_hand(".L",Vector3(0.1,body.height*0.50,body.height*0.16))
  reach_hand(".R",Vector3(-0.1,body.height*0.53,body.height*0.16))
 elif p.action=="set_piece":
  pose("spine02",0.10)
  pose("upperleg01.R",-0.10,0,0.08)
 elif p.action in ["celebrate","appeal"]:
  var cheer:bool=p.action=="celebrate"
  rotation.x=lerp_angle(rotation.x,0,blend)
  var pulse:=sin(progress*PI*6)
  if cheer: position.y=lerpf(position.y,maxf(0,pulse)*0.25,blend)
  pose("spine02",-0.12,0,pulse*0.04)
  pose("upperarm01.L",-0.2,0,2.45 if cheer else 0.95)
  pose("upperarm01.R",-0.2,0,-2.45 if cheer else -0.95)
  pose("lowerarm01.L",-0.25)
  pose("lowerarm01.R",-0.25)
 elif p.action=="disappointed":
  pose("head",0.35)
  pose("spine02",0.20)
  pose("upperarm01.L",0.12,0,-0.15)
  pose("upperarm01.R",0.12,0,0.15)

func animate_keeper(p:Dictionary,dt:float,holding:bool)->void:
 # A keeper shuffles facing play instead of using the outfield sprint posture.
 var lean:=0.0
 var lift:float=-body.height*0.095*gait
 pose("spine02",0.16)
 for suffix in [".L",".R"]:
  var side_value:float=1 if suffix==".L" else -1
  if gait<0.1:
   pose("upperleg01"+suffix,-0.18,0,-side_value*0.14)
   pose("lowerleg01"+suffix,0.34)
  if not (p.action=="rush" and p.action_time>0 and not holding):
   pose("upperarm01"+suffix,-0.30,0,-side_value*0.65)
   pose("lowerarm01"+suffix,-0.70)
 if holding or (p.action in ["catch","scoop","catch_high","smother"] and p.action_time>0):
  pose("upperarm01.L",-0.85,0,-0.18)
  pose("upperarm01.R",-0.85,0,0.18)
  pose("lowerarm01.L",-1.05)
  pose("lowerarm01.R",-1.05)
  var catch_height:float=lerpf(float(p.get("keeper_height",body.height*0.65)),body.height*0.65,1-clampf(float(p.get("cooldown",0))/1.1,0,1)) if holding else float(p.get("keeper_height",body.height*0.65))
  if catch_height<body.height*0.42:
   pose("spine02",0.65)
   pose("upperleg01.L",-0.55,0,-0.18);pose("upperleg01.R",-0.55,0,0.18)
   pose("lowerleg01.L",0.9);pose("lowerleg01.R",0.9)
   lift=-0.22
  if p.action=="smother":
   pose("spine02",0.45)
   pose("upperleg01.L",-0.9,0,-0.1);pose("lowerleg01.L",1.6)
   pose("upperleg01.R",-0.3,0,0.1);pose("lowerleg01.R",0.75)
   lift=-0.35
  reach_hand(".L",Vector3(0.24,catch_height-lift,0.65))
  reach_hand(".R",Vector3(-0.24,catch_height-lift,0.65))
 elif p.action in ["dive","dive_low","dive_high"] and p.action_time>0:
  var progress:=1.0-clampf(float(p.action_time)/0.8,0,1)
  var envelope:=sin(clampf(progress/0.7,0,1)*PI*0.5) if progress<0.7 else (1.0-progress)/0.3
  var side_value:float=p.get("keeper_side",1.0)
  lean=-side_value*(1.35 if p.action=="dive_low" else 1.05)*envelope
  lift=(-0.20 if p.action=="dive_low" else 0.55 if p.action=="dive_high" else 0.22)*sin(progress*PI)
  pose("upperarm01.L",-1.1,0,0.65)
  pose("upperarm01.R",-1.1,0,-0.65)
  pose("lowerarm01.L",-0.12)
  pose("lowerarm01.R",-0.12)
  pose("upperleg01.L",-0.12,0,-0.22)
  pose("upperleg01.R",0.25,0,0.18)
  var hand_height:float=body.height*(1.25 if p.action=="dive_low" else 1.36 if p.action=="dive_high" else 1.30)
  reach_hand(".L",Vector3(side_value*0.12,hand_height,0.38))
  reach_hand(".R",Vector3(side_value*0.12,hand_height,0.38)+Vector3(-0.18,0,0))
 elif p.action=="foot_save" and p.action_time>0:
  pose("spine02",-0.15)
  pose("upperleg01.R",-0.50,0,0.75)
  pose("lowerleg01.R",0.08)
  pose("upperleg01.L",-0.25,0,-0.2)
  pose("lowerleg01.L",0.5)
  pose("upperarm01.L",-0.45,0,0.85)
  pose("upperarm01.R",-0.45,0,-0.85)
 elif p.action=="rush" and p.action_time>0:
  pose("spine02",0.28)
 elif p.action in ["parry","tip"] and p.action_time>0:
  var high:bool=p.action=="tip"
  var hand_height:float=body.height*1.14 if high else body.height*0.72
  lift=sin(clampf(1-float(p.action_time)/0.8,0,1)*PI)*0.35 if high else 0.0
  pose("spine02",-0.08)
  reach_hand(".L",Vector3(0.18,hand_height,0.75))
  reach_hand(".R",Vector3(-0.18,hand_height,0.75))
 elif p.action=="save" and p.action_time>0:
  pose("upperarm01.L",-1.5,0,0.25)
  pose("upperarm01.R",-1.5,0,-0.25)
  pose("lowerarm01.L",-0.15)
  pose("lowerarm01.R",-0.15)
 elif p.action=="throw" and p.action_time>0:
  var progress:=1.0-clampf(float(p.action_time)/0.5,0,1)
  pose("upperarm01.R",-2.3+progress*2.0,0,0.15)
  pose("lowerarm01.R",-0.3)
 rotation.z=lerp_angle(rotation.z,lean,minf(1,dt*18))
 position.y=lerpf(position.y,lift,minf(1,dt*18))

func reach_hand(suffix:String,target:Vector3)->void:
 # Small CCD arm solver keeps the continuous skinned elbows/wrists on the ball.
 var wrist:int=bone_ids["wrist"+suffix]
 for iteration in 7:
  for name_value in ["lowerarm01","upperarm01"]:
   var bone:int=bone_ids[name_value+suffix]
   var global_pose:Transform3D=skeleton.get_bone_global_pose(bone)
   var origin:=global_pose.origin
   var current:Vector3=skeleton.get_bone_global_pose(wrist).origin-origin
   var desired:=target-origin
   if current.length()<0.001 or desired.length()<0.001: continue
   var delta:=Quaternion(current.normalized(),desired.normalized())
   var parent_pose:Transform3D=skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone))
   var local_rotation:Quaternion=parent_pose.basis.get_rotation_quaternion().inverse()*delta*global_pose.basis.get_rotation_quaternion()
   skeleton.set_bone_pose_rotation(bone,local_rotation.normalized())
