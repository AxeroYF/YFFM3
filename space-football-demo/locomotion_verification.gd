extends RefCounted
const Team=preload("res://team_config.gd")
func run(game)->void:
 game.practice=true;await game.start_match()
 game.screen="locomotion_verification";game.camera_motion=false
 game.ui.visible=false;game.desktop_input.overlay.visible=false
 game.sim.freeze=0;game.sim.phase="play";game.sim.owner=-1
 game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=6.5
 var overlay:=CanvasLayer.new();game.add_child(overlay)
 var root:=Control.new();overlay.add_child(root)
 var caption=game.text(root,"",Vector2(70,70),36,game.INK,true)
 for index in Team.COUNT: game.sim.players[index].pos=Vector2(-28,-16)
 var p:Dictionary=game.sim.players[1]
 p.dir=Vector2.DOWN;p.action="idle";p.action_time=0
 var results:Array=[]
 for mode in ["walk","run","sprint","stop"]:
  p.pos=Vector2.ZERO;p.vel=Vector2.ZERO
  game.render_match(0)
  var strength:=0.3 if mode=="walk" else 1.0
  for frame in 60:
   game.sim.move_player(1,1.0/60,Vector2.DOWN*strength,mode=="sprint",false)
   game.render_match(1.0/60)
  if mode=="stop":
   for frame in 60:
    game.sim.move_player(1,1.0/60,Vector2.ZERO,false,false)
    game.render_match(1.0/60)
  var rig=game.rigs[1]
  results.append({"mode":mode,"speed":p.vel.length(),"visual_speed":rig.locomotion_speed,"stride":rig.stride_length,"cycles_per_second":rig.cadence})
  caption.text={"walk":"慢走","run":"跑动","sprint":"冲刺","stop":"停止"}[mode]+"  /  %.2f 场地单位/秒   ·   步频 %.2f 次/秒" % [p.vel.length(),rig.cadence*2]
  var actor:Vector3=game.actors[1].position
  game.camera.position=actor+Vector3(7,3.0,3.4);game.camera.look_at(actor+Vector3(0,1.25,0))
  game.indicator.visible=false;game.football.visible=false;game.selected_labels[1].visible=false
  await game.capture("locomotion-"+mode)
 var out:=FileAccess.open("res://artifacts/locomotion-measurements.json",FileAccess.WRITE)
 out.store_string(JSON.stringify(results,"  "))
 # Compare the real mesh at four points in the same gait cycle, from both sides.
 p.pos=Vector2.ZERO;p.dir=Vector2.DOWN;p.vel=Vector2(0,6.5)
 game.render_match(0)
 var rig=game.rigs[1]
 for frame in 90: rig.animate_player(p,1.0/60,false,Vector3.BACK*6.5)
 for view in ["front","side"]:
  game.camera.position=Vector3(3.8,2.6,8) if view=="front" else Vector3(8,2.6,2)
  game.camera.look_at(Vector3(0,1.3,0))
  for step in 4:
   rig.phase=TAU*step/4.0
   rig.animate_player(p,0,false,Vector3.BACK*6.5)
   caption.text="手脚协调  /  跑动周期 %d%%  ·  %s" % [step*25,"正面" if view=="front" else "侧面"]
   await game.capture("arm-cycle-"+view+"-"+str(step))
 print("LOCOMOTION_VISUAL_PASS ",results)
 game.get_tree().quit()
