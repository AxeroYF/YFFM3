extends RefCounted
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures+=1;push_error("LEGEND_VISUAL_FAILED "+label)
func run(game)->void:
 game.set_physics_process(false)
 game.show_player_bodies()
 var showroom=game.body_showroom
 var seen:Array=[]
 var sheet:=Image.create(1600,2700,false,Image.FORMAT_RGBA8)
 sheet.fill(Color("101921"))
 for page in showroom.page_count():
  game.show_player_bodies(page)
  for frame in 3: await game.get_tree().process_frame
  await game.capture("legend-page-%02d" % (page+1))
  var shot:Image=game.get_viewport().get_texture().get_image()
  shot.convert(Image.FORMAT_RGBA8)
  for i in showroom.page_records.size():
   var record:Dictionary=showroom.page_records[i]
   seen.append(record.id)
   check(showroom.models[i].body.appearance_id==record.id,"gallery profile binding "+record.id)
   var rig=showroom.models[i]
   var binds:=true
   for bone in ["head","spine02","upperarm01.L","foot.L"]:
    var id:int=rig.bone_ids[bone]
    binds=binds and (rig.skeleton.get_bone_global_rest(id)*rig.body_mesh.skin.get_bind_pose(id)).origin.length()<0.0001
   check(binds,"actual skin inverse binds "+record.id)
   # Contact sheet is verification evidence from real rendered frames.
   var crop:=shot.get_region(Rect2i(i*610+60,440,610,645))
   crop.resize(200,230,Image.INTERPOLATE_LANCZOS)
   var n:int=seen.size()-1
   sheet.blit_rect(crop,Rect2i(0,0,200,230),Vector2i((n%8)*200,(n/8)*300))
   var label:=shot.get_region(Rect2i(i*610+230,1108,390,115))
   label.resize(200,59,Image.INTERPOLATE_LANCZOS)
   sheet.blit_rect(label,Rect2i(0,0,200,59),Vector2i((n%8)*200,(n/8)*300+231))
 check(seen.size()==67,"all 67 models rendered at 2K")
 check(showroom.Model.geometry_cache.size()<=32 and showroom.Model.Groom.cache.size()<=32,"bounded body and hair caches after all pages")
 sheet.save_png("res://artifacts/legend-contact-sheet.png")
 for pair in [[0,0],[0,1],[0,3],[5,1],[16,2]]:
  game.show_player_bodies(pair[0],pair[1])
  for frame in 3: await game.get_tree().process_frame
  await game.capture("legend-close-%d-%d" % [pair[0],pair[1]])
 game.show_player_bodies(0)
 showroom.running=true;showroom.angle=0.55
 for frame in 45: await game.get_tree().process_frame
 await game.capture("legend-running")
 check(game.get_viewport().get_visible_rect().size==Vector2(2560,1440),"native 2K rendered gallery")
 game.show_menu()
 game.practice=true
 var legends:Array=game.PlayerLibrary.all().filter(game.Body.Appearance.is_legend)
 var used:Array=[];var sides:Array=[[],[]]
 for side in 2:
  for slot in game.Team.SIZE:
   var choices:Array=legends.filter(func(p):return p.id not in used and p.role in game.QuickMatch.ROLES[slot])
   var id:String=choices[0].id
   sides[side].append(id);used.append(id)
 game.quick_fixture={"seed":731,"home":sides[0],"away":sides[1]}
 await game.start_match()
 game.set_process(false);game.set_physics_process(false)
 var s=game.sim
 for i in game.Team.COUNT:
  check(game.rigs[i].body.appearance_id==s.players[i].player_id,"actual match uses legend profile %d" % i)
 var transport=game.MatchNetwork.new();transport.sim=s
 var state:Dictionary=transport.unpack_state(transport.pack_state(s.snapshot()))
 for i in game.Team.COUNT:
  check(state.players[i].body==s.players[i].body,"network rebuilds same profile by player ID %d" % i)
 transport.free()
 var replacement:Dictionary=legends.filter(func(p):return p.id not in used and p.role=="ST")[0]
 s.mechanics.benches[0].append({"id":replacement.id,"fatigue":0.0,"yellow":0})
 s.mechanics.requests[0]={"out":1,"reserve":s.mechanics.benches[0].size()-1}
 s.mechanics.substitute(s,0)
 game.render_match(0)
 check(game.rigs[1].body.appearance_id==replacement.id,"substitution rebuilds body and hair together")
 s.freeze=0;s.phase="play";s.owner=-1
 game.ui.visible=false;game.desktop_input.overlay.visible=false
 game.camera_motion=false;game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=13
 game.camera.position=Vector3(3,12,24);game.camera.look_at(Vector3(0,1,0))
 var slots:Array=[1,2,3,4,6,7,8,9]
 var actions:Array=["shoot","header","slide","tackle","dive_high","volley","driven_pass","receive"]
 for p in s.players: p.active=false
 for n in slots.size():
  var p:Dictionary=s.players[slots[n]]
  p.active=true;p.pos=Vector2((n%4)*5.6-8.4,(n/4)*7-3.5);p.dir=Vector2.DOWN;p.vel=Vector2.ZERO
  p.action=actions[n];p.action_dir=p.dir;p.action_time=s.Motion.action_duration(p)*0.68;p.action_strength=0.8;p.contact_height=p.body.chest_height
 game.render_match(0)
 for frame in 24:
  for i in slots: game.rigs[i].animate_player(s.players[i],1.0/60,false,Vector3.ZERO)
 for label in game.selected_labels: label.visible=false
 game.indicator.visible=false;game.pass_arrow.visible=false;game.football.visible=false;game.ball_shadow.visible=false
 await game.capture("legend-match-actions")
 print("LEGEND_VISUAL_","PASS" if failures==0 else "FAILED"," checks=",checks," failures=",failures)
 game.get_tree().quit(0 if failures==0 else 1)
