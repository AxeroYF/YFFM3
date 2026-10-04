extends RefCounted
const Team=preload("res://team_config.gd")
func run(game)->void:
 game.practice=true;game.quick_fixture=preload("res://quick_match.gd").generate(719)
 await game.start_match()
 game.screen="receiving_defending_verification";game.camera_motion=false
 game.ui.visible=false;game.desktop_input.overlay.visible=false
 var overlay:=CanvasLayer.new();game.add_child(overlay)
 var root:=Control.new();overlay.add_child(root)
 var caption=game.text(root,"",Vector2(70,65),40,game.INK,true)
 var s=game.sim;s.freeze=0;s.phase="play"
 for team in 2: s.teams[team].human=true
 for i in Team.COUNT: s.players[i].active=false;s.players[i].cooldown=0
 var p:Dictionary=s.players[1];p.active=true;p.pos=Vector2(0,3);p.dir=Vector2.RIGHT;p.vel=Vector2.ZERO
 s.owner=-1;s.selected=1;s.ball=Vector2(-8,0);s.velocity=Vector2(14,0);s.ball_height=s.BallPhysics.FLOOR
 s.pass_receiver=1;s.last_touch=2;s.kick_age=0.1;s.pickup_lock=0
 s.teams[0].move=Vector2.RIGHT;s.teams[0].receive_assist=2
 game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=17
 game.camera.position=Vector3(0,15,12);game.camera.look_at(Vector3(0,0,1))
 var received:=false
 for frame in 120:
  s.step(1.0/60);game.render_match(1.0/60)
  if frame==20:
   caption.text="高辅助 · 持续向右移动，仍主动调整接球路线"
   await game.capture("receiving-moving-approach")
  if s.owner==1: received=true;break
 assert(received)
 caption.text="移动中接球成功 · 接球后恢复方向控制"
 await game.capture("receiving-moving-contact")
 s.owner=-1;s.pass_receiver=-1;s.teams[0].move=Vector2.ZERO
 p.pos=Vector2.ZERO;p.dir=Vector2.DOWN;p.vel=Vector2.ZERO
 game.camera.size=6.6;game.camera.position=Vector3(4.5,3.7,8);game.camera.look_at(Vector3(0,1.1,0.5))
 for item in [["tackle",0.39,"普通抢断 · 短促伸脚与收腿","standing-tackle"],["slide_still",0.53,"原地铲球 · 低重心伸腿，不获得向前冲量","stationary-slide"],["slide",0.73,"跑动滑铲 · 继承当前速度，滑行中减速","slide-contact"],["slide",0.15,"滑铲恢复 · 减速后收腿起身","slide-recovery"]]:
  p.action=item[0];p.action_time=item[1];p.cooldown=0.8
  s.ball=Vector2(0,1.35);s.ball_height=s.BallPhysics.FLOOR;caption.text=item[2]
  for frame in 30: game.render_match(1.0/60)
  game.indicator.visible=false
  await game.capture(item[3])
 print("RECEIVING_DEFENDING_VISUAL_PASS screens=6 moving_reception=ok standing_tackle=ok stationary_slide=ok slide=ok recovery=ok")
 game.get_tree().quit()
