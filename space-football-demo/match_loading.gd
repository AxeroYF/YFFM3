extends RefCounted
## Cancellable scene preparation. All UI transitions are explicit callbacks.
const Team=preload("res://team_config.gd")
func run(session,loader,stadium,controls,router,label_font:Font,prepare:Callable,build_ui:Callable,render:Callable,complete:Callable)->void:
 if loader.active: return
 stadium.camera.cull_mask=1
 session.load_epoch+=1
 var epoch:int=session.load_epoch
 controls.reset()
 controls.enabled=false
 loader.begin("正在进入比赛")
 session.screen="loading"
 await loader.present(0,"准备双方阵容")
 if epoch!=session.load_epoch: return
 prepare.call()
 stadium.clear_actors()
 await loader.present(10,"双方阵容已就绪 · 准备球员 0 / 12")
 if epoch!=session.load_epoch: return
 for i in Team.COUNT:
  stadium.create_actor(i,session.sim.players[i],label_font)
  await loader.present(10+(i+1)*70.0/Team.COUNT,"球员已就绪 %d / 12" % (i+1))
  if epoch!=session.load_epoch: return
 build_ui.call()
 render.call(0)
 await loader.present(92,"球员已就位 · 完成球场画面")
 if epoch!=session.load_epoch: return
 if session.online and session.network.active:
  await loader.present(96,"本机已就绪 · 等待对手加载")
  if epoch!=session.load_epoch: return
  session.network.scene_ready()
  while session.network.preparing and epoch==session.load_epoch:
   await stadium.get_tree().process_frame
  if epoch!=session.load_epoch or not session.network.active: return
 await loader.present(100,"准备开球")
 if epoch!=session.load_epoch: return
 loader.finish()
 router.reset_navigation()
 controls.reset()
 controls.enabled=true
 session.screen="match"
 complete.call()
