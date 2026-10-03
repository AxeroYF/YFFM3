extends RefCounted
func run(game)->void:
 game.practice=true;await game.start_match()
 game.screen="motion_verification";game.camera_motion=false
 game.ui.visible=false;game.desktop_input.overlay.visible=false
 game.sim.freeze=0;game.sim.phase="play"
 game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=7.3
 game.camera.position=Vector3(4,3.6,9);game.camera.look_at(Vector3(0,1.3,0))
 var overlay:=CanvasLayer.new();game.add_child(overlay)
 var root:=Control.new();overlay.add_child(root)
 var caption=game.text(root,"",Vector2(70,70),36,game.INK,true)
 for index in 10: game.sim.players[index].pos=Vector2(-28,-16)
 var keeper:Dictionary=game.sim.players[0]
 keeper.pos=Vector2.ZERO;keeper.dir=Vector2.DOWN
 for action in ["scoop","foot_save","catch","parry","catch_high","tip","dive_low","dive","dive_high","throw","smother"]:
  keeper.action=action;keeper.action_time=0.45;keeper.keeper_side=1;keeper.cooldown=0.8
  keeper.keeper_height=0.35 if action in ["scoop","foot_save","dive_low","smother"] else keeper.body.height*(0.95 if action in ["catch_high","tip","dive_high"] else 0.65)
  game.sim.owner=0 if action in ["scoop","catch","catch_high","smother"] else -1
  keeper.keeper_holding=game.sim.owner==0
  game.sim.ball=Vector2(0,0.65);game.sim.ball_height=lerpf(keeper.keeper_height,keeper.body.height*0.65,1-keeper.cooldown/1.1) if game.sim.owner==0 else keeper.keeper_height
  caption.text="门将动作  /  "+action
  for frame in 25: game.render_match(1.0/60)
  game.indicator.visible=false
  await game.capture("motion-keeper-"+action)
 keeper.pos=Vector2(-28,-16)
 var p:Dictionary=game.sim.players[1]
 p.pos=Vector2.ZERO;p.dir=Vector2.DOWN;game.sim.owner=-1
 for action in ["windup","shoot","power_shot","finesse","chip","shield"]:
  p.action=action;p.action_time=0.28;p.action_strength=0.9 if action in ["power_shot","windup"] else 0.4
  game.sim.ball=Vector2(0.4,0.9);game.sim.ball_height=0.31
  caption.text="射门动作  /  "+action+"   蓄力 %d%%" % int(p.action_strength*100)
  for frame in 25: game.render_match(1.0/60)
  game.indicator.visible=false
  await game.capture("motion-shot-"+action)
 print("MOTION_VISUAL_PASS keeper_types=11 shot_types=5 shield=1")
 game.get_tree().quit()
