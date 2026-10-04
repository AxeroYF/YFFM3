extends RefCounted
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures+=1;push_error("PHYSIQUE_VISUAL_FAILED "+label)

func run(game)->void:
 game.set_physics_process(false)
 game.library_screen.show_library()
 for id in ["legend-messi","legend-haaland"]:
  game.library_screen.details(game.PlayerLibrary.find(id))
  for frame in 3: await game.get_tree().process_frame
  var shown:=false
  for label in game.modal.get_children():
   if label is Label and label.text.begins_with("体型修正"):
    shown=label.text.contains("%")
    check(label.get_rect().end.y<=1180 and label.get_rect().end.x<2200,"physique detail clears lineup buttons and panel edge")
  check(shown,"body effects displayed for "+id)
  await game.capture("physique-details-"+id)
 game.clear_modal();game.show_menu();game.practice=true
 await game.start_match()
 game.set_process(false);game.set_physics_process(false)
 game.screen="physique_verification";game.camera_motion=false
 game.ui.visible=false;game.desktop_input.overlay.visible=false
 var s=game.sim;s.freeze=0;s.phase="play";s.owner=-1
 for p in s.players: p.active=false
 # Use the same substitution route as a match to fit both the rig and physics.
 for pair in [[1,"legend-messi"],[7,"legend-haaland"]]:
  var index:int=pair[0];var team:int=index/6
  s.players[index].active=true
  s.mechanics.benches[team]=[{"id":pair[1],"fatigue":0.0,"yellow":0}]
  s.mechanics.requests[team]={"out":index,"reserve":0};s.mechanics.substitute(s,team)
  s.players[index].pos=Vector2(-2.2 if index==1 else 2.2,0);s.players[index].dir=Vector2.DOWN
 game.render_match(0)
 game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=7.4
 game.camera.position=Vector3(5,4,12);game.camera.look_at(Vector3(0,1.1,0))
 for label in game.selected_labels: label.visible=false
 game.indicator.visible=false;game.football.visible=false;game.pass_arrow.visible=false;game.ball_shadow.visible=false
 for i in [1,7]:
  var rig=game.rigs[i];var p:Dictionary=s.players[i]
  for frame in 60: rig.animate_player(p,1.0/60,false,Vector3.ZERO)
  for frame in 12: rig.animate_player(p,1.0/60,false,Vector3.BACK*(frame+1)*0.45)
  check(rig.momentum_lean.x>0.01 and rig.momentum_lean.length()<0.15,"visible acceleration leans bounded torso "+p.name)
 await game.capture("physique-acceleration")
 for i in [1,7]:
  var rig=game.rigs[i];var p:Dictionary=s.players[i]
  for frame in 12: rig.animate_player(p,1.0/60,false,Vector3.BACK*(11-frame)*0.45)
  check(rig.momentum_lean.x< -0.01,"braking shifts torso back "+p.name)
 await game.capture("physique-braking")
 for i in [1,7]:
  var rig=game.rigs[i];var p:Dictionary=s.players[i]
  p.vel=Vector2(9,0)
  for frame in 90: rig.animate_player(p,1.0/60,false,Vector3.ZERO)
  check(rig.momentum_lean.length()<0.001 and rig.gait<0.001,"stale snapshot cannot sustain lean or running "+p.name)
  p.action="shield";p.action_time=0.15
  rig.animate_player(p,1.0/60,true,Vector3.ZERO)
 await game.capture("physique-shield")
 check(game.get_viewport().get_visible_rect().size==Vector2(2560,1440),"native 2K verification")
 print("PHYSIQUE_VISUAL_","PASS" if failures==0 else "FAILED"," checks=",checks," failures=",failures)
 game.get_tree().quit(0 if failures==0 else 1)
