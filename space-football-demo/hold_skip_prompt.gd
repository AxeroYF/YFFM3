extends Control
var progress:=0.0
var glyph:Control
var caption:Label
func build(game)->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 position=Vector2(2010,1080);size=Vector2(440,80)
 glyph=game.desktop_input.make_glyph(self,Vector2(8,8),game.desktop_input.symbol("pass"))
 glyph.size=Vector2(48,48)
 caption=game.text(self,"长按跳过准备",Vector2(82,17),25,game.INK,false,320)
func refresh(game)->void:
 var s=game.sim
 visible=game.screen=="match" and s.phase=="restart" and not s.Rules.Flow.ready(s) and s.restart_flow.get("skip_time",-1)<0
 progress=clampf(float(s.restart_flow.get("hold",[0,0])[s.view_team])/s.Rules.Flow.HOLD_SECONDS,0,1) if visible else 0
 glyph.set_symbol(game.desktop_input.symbol("pass"),game.desktop_input.family())
 queue_redraw()
func _draw()->void:
 draw_arc(Vector2(32,32),31,-PI/2,TAU-PI/2,64,Color(0.4,0.6,0.65,0.35),4,true)
 if progress>0: draw_arc(Vector2(32,32),31,-PI/2,-PI/2+TAU*progress,64,Color("65f3db"),4,true)
