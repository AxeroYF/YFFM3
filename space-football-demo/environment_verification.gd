extends RefCounted
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures+=1;push_error("ENVIRONMENT_VISUAL_FAILED "+label)
func capture(game,label:String)->void:
 game.desktop_input.window_active=true
 game.desktop_input.step(0)
 await game.capture(label)
func run(game)->void:
 game.set_process(false);game.set_physics_process(false)
 game.show_menu();game.show_quick_options()
 var fixture:Dictionary=game.quick_fixture.duplicate(true)
 game.cycle_environment("stadium",2)
 for i in 3: game.cycle_environment("weather",4)
 game.cycle_environment("gravity",2)
 check(game.quick_fixture==fixture,"changing environment preserves previewed lineup")
 check(game.quick_environment=={"stadium":1,"weather":3,"gravity":1},"quick options select independent environment values")
 await capture(game,"environment-options")
 game.practice=true;await game.start_match()
 check(game.sim.environment==game.quick_environment,"start applies chosen environment")
 check(not game.planet.visible and game.environment_visual.meteors.visible,"galaxy replaces planet and enables meteors")
 check(game.environment_visual.rain.visible and game.environment_visual.wind.visible,"storm combines visible rain and wind")
 game.camera_motion=false
 game.sim.freeze=0
 game.sim.environment=game.Conditions.normalize({"stadium":1})
 game.apply_environment_visual(game.sim.environment)
 game.environment_visual.update(3.2)
 game.render_match(0)
 game.environment_visual.meteors.visible=false
 await capture(game,"environment-galaxy-sky")
 game.environment_visual.meteors.visible=true
 await capture(game,"environment-galaxy")
 var image:Image=game.get_viewport().get_texture().get_image()
 check(image.get_size()==Vector2i(2560,1440),"actual 2K render")
 game.sim.environment=game.Conditions.normalize({"stadium":1,"weather":3,"gravity":1})
 game.apply_environment_visual(game.sim.environment)
 game.environment_visual.update(1.1);game.render_match(0)
 await capture(game,"environment-storm")
 var state:PackedByteArray=var_to_bytes(game.sim.snapshot())
 game.environment_visual.lightning_wait=0
 game.environment_visual.update(0.04)
 check(game.environment_visual.lightning.visible and game.environment_visual.lightning_light.light_energy>0,"rainstorm flashes light the pitch")
 await capture(game,"environment-lightning")
 game.environment_visual.update(0.65)
 check(not game.environment_visual.lightning.visible and game.environment_visual.lightning_light.light_energy==0,"lightning fades instead of staying bright")
 check(state==var_to_bytes(game.sim.snapshot()),"lightning never changes gameplay or RNG")
 game.sim.environment=game.Conditions.normalize({"weather":2})
 game.apply_environment_visual(game.sim.environment);game.environment_visual.update(0.7);game.render_match(0)
 await capture(game,"environment-planet-rain")
 game.environment_visual.lightning_wait=0
 game.environment_visual.update(0.04)
 check(game.environment_visual.lightning.visible,"heavy rain also enables intermittent lightning")
 await game.start_match()
 check(game.sim.environment==game.quick_environment,"rematch reapplies selected options")
 game.show_menu()
 check(game.planet.visible and not game.environment_visual.rain.visible and not game.environment_visual.meteors.visible and not game.environment_visual.lightning.visible and game.environment_visual.lightning_light.light_energy==0,"leaving match restores clean menu background")
 print("ENVIRONMENT_VISUAL_", "PASS" if failures==0 else "FAILED", " checks=",checks," failures=",failures)
 game.get_tree().quit(0 if failures==0 else 1)
