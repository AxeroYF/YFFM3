extends RefCounted
const JOBS={"keeper":"门将","hold":"持球","anchor":"留后","support":"短接应","run":"前插","one_two":"二过一","press":"压迫","cover":"保护","mark":"盯防","recover":"回收","intercept":"争球","receive":"迎球"}

func run(game)->void:
 game.practice=true
 game.quick_fixture=preload("res://quick_match.gd").generate(451)
 await game.start_match()
 game.screen="ai_verification";game.camera_motion=false
 game.ui.visible=false;game.desktop_input.overlay.visible=false
 game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=76
 game.camera.position=Vector3(0,64,36);game.camera.look_at(Vector3.ZERO)
 var layer:=CanvasLayer.new();game.add_child(layer)
 var root:=Control.new();layer.add_child(root)
 var caption=game.text(root,"",Vector2(75,60),34,game.INK,true)
 var labels:Array=[]
 for i in 10:
  labels.append(game.text(root,"",Vector2.ZERO,22,game.CYAN if i<5 else Color("ffa48b"),true,220))
 var s=game.sim
 s.freeze=0;s.teams[0].human=false;s.teams[1].human=false
 for sample in 3:
  for frame in 240:
   s.step(1.0/60);game.render_match(1.0/60)
   if frame%30==0: await game.get_tree().process_frame
  caption.text="五人制 AI / 统一职责、动态接应与补位   ·   比赛 %.1f 秒" % s.elapsed
  for i in 10:
   labels[i].position=game.camera.unproject_position(game.actors[i].position+Vector3(0,3.8,0))-Vector2(72,0)
   labels[i].text=s.players[i].name+"\n"+JOBS.get(s.brain.jobs[i],s.brain.jobs[i])
   game.selected_labels[i].visible=false
  game.indicator.visible=false
  await game.capture("ai-teamplay-"+str(sample))
 root.visible=false
 game.ui.visible=true;game.show_menu()
 game.library_screen.details(preload("res://player_library.gd").find("legend-messi"))
 await game.capture("player-style-messi")
 game.library_screen.details(preload("res://player_library.gd").find("legend-haaland"))
 await game.capture("player-style-haaland")
 print("AI_STYLE_VISUAL_PASS teamplay_frames=720 style_details=2")
 game.get_tree().quit()
