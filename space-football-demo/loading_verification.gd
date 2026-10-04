extends RefCounted
const Team=preload("res://team_config.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
 checks+=1
 if not value:
  failures+=1;push_error("LOADING_CHECK_FAILED "+message)

func run(game)->void:
 check(game.loader.history[0]==0 and game.loader.history.back()==100 and game.loader.presented_frames>=4,"startup displayed staged progress to completion")
 check(game.actors.is_empty(),"main menu does not build hidden match footballers")
 game.practice=true
 game.desktop_input.stick=Vector2(0.8,0)
 game.start_match()
 var epoch:int=game.load_epoch
 check(game.screen=="loading" and game.loader.active and game.loader.visible,"loading screen appears before starting heavy match work")
 game.start_match()
 check(game.load_epoch==epoch,"duplicate launch cannot create a second match")
 var key:=InputEventKey.new();key.physical_keycode=KEY_ESCAPE;key.pressed=true
 game.get_viewport().push_input(key)
 check(game.screen=="loading","loading blocks menu and match input")
 key.pressed=false;game.get_viewport().push_input(key)
 var captured:=false;var frozen:=true;var tracked:=true;var frames:=0
 while game.loader.active and frames<1800:
  await game.get_tree().process_frame
  # Loading may have completed during the await; active play is allowed to tick.
  if not game.loader.active: break
  frames+=1
  if game.sim!=null: frozen=frozen and game.sim.elapsed==0 and game.sim.frame==0
  var percent:float=game.loader.progress.value
  if percent>=10 and percent<=80:
   tracked=tracked and is_equal_approx(percent,10+game.actors.size()*70.0/Team.COUNT)
  if not captured and percent>=38 and percent<=80:
   captured=true
   await game.capture("loading-match")
 check(not game.loader.active and game.screen=="match" and game.actors.size()==Team.COUNT,"match opens with twelve fully built players")
 check(game.desktop_input.stick==Vector2.ZERO and not game.desktop_input.neutral_required,"loading clears stale held menu navigation")
 check(frozen,"offline match clock and simulation wait until loading finishes")
 check(tracked and captured and game.loader.presented_frames>=14,"model progress follows completed player count across displayed frames")
 var monotonic:=true
 for i in range(1,game.loader.history.size()): monotonic=monotonic and game.loader.history[i]>=game.loader.history[i-1]
 check(monotonic and game.loader.history.back()==100,"progress never moves backward and reaches completion")
 game.pause_match()
 await game.start_match()
 check(game.load_epoch==epoch+1 and game.screen=="match" and game.sim.elapsed==0,"replay uses loading and starts a fresh match")
 # Cancel while the first loading frame is still pending; the old coroutine must not reopen play.
 game.start_match()
 game.on_network_lost("加载取消回归检查")
 for i in 5: await game.get_tree().process_frame
 check(not game.loader.active and game.screen=="connection_lost","disconnect cancels pending loading without stale UI restoration")
 print("LOADING_UI_", "PASS" if failures==0 else "FAILED", " checks=",checks," failures=",failures)
 game.get_tree().quit(0 if failures==0 else 2)
