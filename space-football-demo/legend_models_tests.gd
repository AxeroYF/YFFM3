extends SceneTree
const Library=preload("res://player_library.gd")
const Appearance=preload("res://player_appearance.gd")
const Body=preload("res://player_body.gd")
const Model=preload("res://skinned_player.gd")
const Match=preload("res://match_sim.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures+=1;push_error("LEGEND_MODEL_FAILED "+label)

func _initialize()->void:
 call_deferred("run")

func run()->void:
 var legends:=Library.all().filter(Appearance.is_legend)
 check(legends.size()==67 and Appearance.ids().size()==67,"all catalog legendary flags and legacy legend IDs covered")
 var sim:=Match.new();sim.setup(preload("res://campaign.gd").new(),731)
 var original:=Library.all()
 var signatures:Dictionary={}
 for record in legends:
  var b:=Body.from_record(record,0 if record.role=="GK" else 1)
  check(b.get("appearance_id","")==record.id,"stable appearance identity "+record.id)
  check(is_equal_approx(b.height,record.heightCm*0.0145),"catalog height "+record.id)
  var independent:=true
  for slot in 6: independent=independent and Body.from_record(record,slot)==b
  check(independent,"same player appearance in all team slots "+record.id)
  check(is_equal_approx(b.body_radius,b.height*(0.225+b.muscle*0.035)*0.69*b.physique.collision_scale) and is_equal_approx(b.head_height,b.height*0.935),"bounded girth collision and source-height heading reach "+record.id)
  var rig:=Model.new();root.add_child(rig)
  # CPU geometry/rig checks avoid dummy-renderer ShaderMaterial disposal errors.
  # The companion graphical suite builds the actual materials, skins and caches.
  rig.is_keeper=record.role=="GK";rig.build_skeleton(b)
  var mesh:=rig.build_geometry()
  check(rig.skeleton.get_bone_count()==163 and mesh.get_surface_count()==6,"continuous fitted body, kit and skeleton "+record.id)
  if b.hair_style!="bald":
   var hair:ArrayMesh=Model.Groom.scalp_geometry(rig,b.hair_style) if b.hair_style in ["buzz","shaved","receding"] else Model.Groom.hair_geometry(rig,b.hair_style)
   check(hair.get_surface_count()>0,"nonempty personal hair geometry "+record.id)
  var bounds:AABB=mesh.get_aabb()
  check(bounds.size.y>b.height*0.96 and bounds.size.y<b.height*1.02,"height preserved through morph "+record.id)
  var finite:=true
  for name in ["head","spine02","upperarm01.L","upperarm01.R","foot.L","foot.R"]:
   var id:int=rig.bone_ids[name]
   var expected:Vector3=rig.dimensions(Model.asset.bones[id].head)
   finite=finite and rig.skeleton.get_bone_global_rest(id).origin.distance_to(expected)<0.0001
  check(finite,"skeleton rests share the skin deformation "+record.id)
  var p:Dictionary=sim.players[0 if record.role=="GK" else 1].duplicate(true)
  p.body=b;p.dir=Vector2.DOWN;p.vel=Vector2(0,6)
  var actions:Array=["idle","shoot","slide","header","dive_high"] if record.role=="GK" else ["idle","shoot","slide","header"]
  for action in actions:
   p.action=action;p.action_time=0.35;p.action_strength=0.8;p.contact_height=b.chest_height
   for frame in 6: rig.animate_player(p,1.0/60,false)
   for bone in Model.ACTION_BONES: finite=finite and rig.skeleton.get_bone_global_pose(rig.bone_ids[bone]).origin.is_finite()
  check(finite,"animation deformation finite "+record.id)
  signatures[Model.Morph.signature(b)]=true
  rig.free()
 check(signatures.size()==67,"individually authored body/head geometry for every legend")
 check(original==Library.all(),"source catalog and 26 ability values remain immutable")
 var base:=Body.from_record(Library.find("legend-messi"))
 var altered:=base.duplicate(true);altered.jaw_width+=0.1
 check(Model.Morph.signature(base)!=Model.Morph.signature(altered),"same-height distinct face morphs cannot alias cache")
 altered=base.duplicate(true);altered.muscle+=0.05
 check(Model.Morph.signature(base)!=Model.Morph.signature(altered),"muscle depth participates in mesh cache")
 altered=base.duplicate(true);altered.skin="663c22"
 check(Model.Morph.signature(base)==Model.Morph.signature(altered),"per-instance skin colour does not multiply geometry cache")
 var non_legend:=Library.find("s4-fc26-252371")
 check(not Body.from_record(non_legend).has("appearance_id"),"first batch limited to legends")
 print("LEGEND_MODELS_","PASS" if failures==0 else "FAILED"," checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
