extends RefCounted
const Team=preload("res://team_config.gd")
var game:Node
var checks:=0
var failures:=0

func check(condition:bool,description:String)->void:
 checks+=1
 if not condition:
  failures+=1
  push_error("QUICK_CHECK_FAILED "+description)

func settle()->void:
 await game.get_tree().process_frame
 await game.get_tree().process_frame
 var frames:=0
 while game.loader.active and frames<1800:
  await game.get_tree().process_frame
  frames+=1
 if game.loader.active:
  check(false,"loading did not complete before UI timeout")
  game.get_tree().quit(2)

func click_named(root:Node,title:String)->void:
 for node in root.get_children():
  if node is Button and node.text==title:
   node.pressed.emit()
   return
 check(false,"missing button: "+title)

func run(target:Node)->void:
 game=target
 var squad_before:Array=game.Squad.ids.duplicate()
 var campaign_before:Dictionary=game.campaign.data().duplicate(true)
 game.show_quick_options()
 await settle()
 check(game.QuickMatch.valid_fixture(game.quick_fixture),"preview has sensible random lineups")
 await game.capture("quick-match-lineups")
 var first:Dictionary=game.quick_fixture.duplicate(true)
 click_named(game.modal,"镜头：跟随足球" if game.camera_motion else "镜头：固定")
 await settle()
 check(first==game.quick_fixture,"changing camera preserves previewed teams")
 click_named(game.modal,"重新随机")
 await settle()
 check(first.seed!=game.quick_fixture.seed and (first.home!=game.quick_fixture.home or first.away!=game.quick_fixture.away),"preview reroll replaces both-team fixture")
 var chosen:Dictionary=game.quick_fixture.duplicate(true)
 click_named(game.modal,"开始比赛")
 await settle()
 check(game.screen=="match" and game.practice and not game.online,"start opens offline developer match")
 check(game.sim.teams[0].human and not game.sim.teams[1].human,"opponent is AI")
 var correct:=true
 for i in Team.COUNT:
  var ids:Array=chosen.home if i<Team.SIZE else chosen.away
  correct=correct and game.sim.players[i].player_id==ids[i%Team.SIZE] and game.rigs[i].body.height_cm==game.PlayerLibrary.find(ids[i%Team.SIZE]).heightCm
 check(correct,"all twelve previewed players and physiques appear in match")
 game.show_help("match")
 game.close_help()
 check(game.campaign.data()==campaign_before,"quick-match help does not write campaign tutorial progress")
 await game.get_tree().create_timer(2.0).timeout
 await game.capture("quick-match-gameplay")
 game.pause_match()
 await settle()
 await game.capture("quick-match-pause")
 click_named(game.modal,"同阵容重赛")
 await settle()
 check(game.quick_fixture==chosen and game.sim.score==[0,0] and game.sim.elapsed<0.2,"same-lineup replay preserves seed and resets match")
 game.pause_match()
 await settle()
 click_named(game.modal,"重新随机并开赛")
 await settle()
 check(game.quick_fixture.seed!=chosen.seed and game.screen=="match","pause reroll immediately starts a new fixture")
 game.sim.score=[1,0]
 game.sim.freeze=0
 game.sim.pass_ball()
 game.sim.elapsed=game.sim.duration
 game.sim.step(1.0/60)
 game.show_result()
 await settle()
 check(game.screen=="practice_result","quick match uses independent result screen")
 await game.capture("quick-match-result")
 var completed:Dictionary=game.quick_fixture.duplicate(true)
 click_named(game.ui,"同阵容重赛")
 await settle()
 check(game.quick_fixture==completed and game.screen=="match","result supports same-fixture replay")
 check(game.campaign.data()==campaign_before and game.Squad.ids==squad_before,"full preview/play/result cycle leaves campaign and squad untouched")
 check(game.FootballActor.geometry_cache.size()<=32,"random player previews keep geometry cache bounded")
 game.show_menu()
 print("QUICK_MATCH_UI_", "PASS" if failures==0 else "FAILED", " checks=",checks," failures=",failures)
 game.get_tree().quit(0 if failures==0 else 2)
