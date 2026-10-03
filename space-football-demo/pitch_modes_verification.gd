extends RefCounted
var checks:=0
var failures:=0
func check(value:bool,label:String)->void:
 checks+=1
 if not value: failures+=1;push_error("PITCH_VISUAL_FAILED "+label)
func press(root:Node,title:String)->bool:
 for child in root.get_children():
  if child is Button and child.text==title: child.pressed.emit();return true
 return false
func run(game)->void:
 game.set_physics_process(false);game.set_process(false)
 check(press(game.ui,"冰球模式"),"main menu has dedicated rebound entry")
 check(game.quick_ice_mode and not game.quick_arcade,"entry selects standalone hockey rules")
 await game.capture("pitch-hockey-menu")
 game.practice=true;await game.start_match()
 game.set_physics_process(false);game.set_process(false)
 var s=game.sim
 check(s.ice_mode and game.arena_walls.size()==6 and game.arena_walls.all(func(w):return w.visible),"all four perimeter sides have mode-specific walls with two goal openings")
 for p in s.players:
  if p.active:
   var screen:Vector2=game.camera.unproject_position(Vector3(p.pos.x,p.body.height,p.pos.y))
   check(screen.x>0 and screen.y>0 and screen.x<game.get_viewport().get_visible_rect().size.x and screen.y<game.get_viewport().get_visible_rect().size.y,"expanded starting formation remains in camera")
 for i in 80: s.apply_command(0,{"skip_restart":true});s.step(1.0/60)
 s.pass_ball();game.render_match(0);game.desktop_input.step(0)
 await game.capture("pitch-hockey-match")
 game.quick_ice_mode=false;await game.start_match()
 game.set_physics_process(false);game.set_process(false);s=game.sim
 check(not s.ice_mode and game.arena_walls.all(func(w):return not w.visible),"classic replay hides rebound walls")
 s.ball=Vector2(game.Pitch.HALF_LENGTH,game.Pitch.HALF_WIDTH+1);s.Rules.restart(s,0,"kick_in",s.ball)
 for i in 27: s.apply_command(0,{"skip_restart":true});s.step(1.0/60)
 game.desktop_input.kind="keyboard";game.desktop_input.update_prompts();game.desktop_input.step(0);game.render_match(0)
 check(game.rules_view.skip_prompt.visible and game.rules_view.skip_prompt.progress>0.5,"hold ring displays authority progress")
 await game.capture("pitch-skip-keyboard")
 game.desktop_input.kind="gamepad";game.desktop_input.active_pad=93;game.desktop_input.devices[93]="Xbox Controller"
 game.desktop_input.update_prompts();game.desktop_input.step(0);game.render_match(0)
 check(game.rules_view.skip_prompt.glyph.token=="A","Xbox prompt uses pass A glyph")
 await game.capture("pitch-skip-xbox")
 for i in 33: s.apply_command(0,{"skip_restart":true});s.step(1.0/60)
 game.render_match(0)
 check(game.rules_view.skip_fade.visible and game.rules_view.skip_fade.color.a>0.9,"camera cut covered by fade")
 for i in 24: s.step(1.0/60)
 game.render_match(0)
 check(s.Rules.Flow.ready(s) and not game.rules_view.skip_prompt.visible,"hold transitions to playable restart")
 await game.capture("pitch-classic-ready")
 print("PITCH_VISUAL_", "PASS" if failures==0 else "FAILED"," checks=",checks," failures=",failures)
 game.get_tree().quit(0 if failures==0 else 1)
