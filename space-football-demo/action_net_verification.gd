extends RefCounted
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures+=1;push_error("ACTION_VISUAL_FAILED "+label)
func run(game)->void:
 game.practice=true;await game.start_match()
 game.set_physics_process(false);game.set_process(false);game.camera_motion=false
 game.ui.visible=false;game.desktop_input.overlay.visible=false;game.clear_modal()
 var s=game.sim;s.freeze=0;s.phase="play";s.owner=-1
 var layer:=CanvasLayer.new();game.add_child(layer)
 var root:=Control.new();layer.add_child(root)
 game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=13
 game.camera.position=Vector3(4,12,22);game.camera.look_at(Vector3(0,0.8,0))
 var labels:={"pass":"脚内侧短传","driven_pass":"大力地滚球","receive":"缓冲停球","shoot":"正脚背射门","finesse":"内脚背搓射","volley":"凌空抽射","block":"伸腿封堵","block_chest":"胸部封堵","block_head":"头部封堵","tackle":"站立抢断","slide":"滑铲","slide_still":"原地铲球"}
 var groups:Array=[["pass","driven_pass","receive","shoot","finesse","volley"],["block","block_chest","block_head","tackle","slide","slide_still"]]
 for row in groups.size():
  for child in root.get_children(): child.queue_free()
  for p in s.players: p.active=false
  for n in 6:
   var index:int=[1,2,3,4,6,7][n];var p:Dictionary=s.players[index]
   p.active=true;p.pos=Vector2((n%3-1)*6,(n/3)*6-3);p.vel=Vector2.ZERO;p.dir=Vector2.DOWN;p.action_dir=p.dir;p.preferred_foot="right"
   p.action=groups[row][n];p.action_strength=0.75;p.contact_height=p.body.height*0.57
   p.action_time=s.Motion.action_duration(p)*0.72;p.jump_z=0;p.keeper_holding=false
  game.render_match(0)
  for frame in 20:
   for n in 6:
    var index:int=[1,2,3,4,6,7][n]
    game.rigs[index].animate_player(s.players[index],1.0/60,false,Vector3.ZERO)
  for n in 6:
   var index:int=[1,2,3,4,6,7][n];var actor=game.actors[index]
   var at:Vector2=game.camera.unproject_position(actor.position+Vector3(0,-0.4,0))
   game.text(root,labels[groups[row][n]],at-Vector2(95,0),28,game.INK,true,340)
  for label in game.selected_labels: label.visible=false
  game.indicator.visible=false;game.pass_arrow.visible=false;game.aim_marker.visible=false;game.football.visible=false;game.ball_shadow.visible=false
  await game.capture("actions-"+str(row+1))
 check(game.get_viewport().get_visible_rect().size==Vector2(2560,1440),"native 2K action captures")
 layer.queue_free()
 # Actual shot and authority net simulation, followed by presentation-only replay.
 s.reset_positions(0);s.freeze=0;s.phase="play";s.owner=1;s.selected=1;s.restart_touch=-1
 for p in s.players: p.active=false
 s.players[1].active=true;s.players[1].pos=Vector2(game.Pitch.HALF_LENGTH-12,0);s.players[1].dir=Vector2.RIGHT
 s.ball=s.players[1].pos+Vector2.RIGHT;s.ball_height=s.BallPhysics.FLOOR;s.charge=0.5
 game.football.visible=true;game.match_tools.reset();game.desktop_input.options.replay=1
 game.camera.size=11;game.camera.position=Vector3(game.Pitch.HALF_LENGTH-11,9,17);game.camera.look_at(Vector3(game.Pitch.HALF_LENGTH,1,0))
 for frame in 30: game.render_match(1.0/60);game.update_match_tools(1.0/60)
 s.shoot(0.3)
 var got_goal:=false
 for frame in 90:
  s.step(1.0/120);game.render_match(1.0/120);game.update_match_tools(1.0/120)
  if s.phase=="goal": got_goal=true;break
 check(got_goal,"real charged shot reaches goal")
 var last_age:=0.0
 for age in [0.04,0.15,0.40]:
  for frame in ceili((age-last_age)*120):
   s.step(1.0/120);game.render_match(1.0/120);game.update_match_tools(1.0/120)
  last_age=age
  await game.capture("goal-net-"+str(int(age*100)))
 check(s.goal_net.serial>0,"rendered live goal reaches net")
 game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 for frame in 110:
  s.step(1.0/120);game.render_match(1.0/120);game.update_match_tools(1.0/120)
 check(game.match_tools.showing_replay(game.sim),"replay follows visible net entry")
 check(game.match_tools.replay.any(func(f):return f.net.serial>0),"replay records actual net contact")
 var frame_count:int=game.match_tools.replay.size();var authoritative:Vector2=s.ball
 s.phase_time=s.Rules.GOAL_DURATION-s.Rules.GOAL_INTRO-s.Rules.REPLAY_DURATION*0.96
 game.render_match(0);game.update_match_tools(0)
 check(s.ball==authoritative and game.match_tools.replay.size()==frame_count,"replay is presentation-only with frozen frame buffer")
 await game.capture("goal-net-replay")
 print("ACTION_NET_VISUAL_","PASS" if failures==0 else "FAILED"," checks=",checks," failures=",failures)
 game.get_tree().quit(0 if failures==0 else 1)
