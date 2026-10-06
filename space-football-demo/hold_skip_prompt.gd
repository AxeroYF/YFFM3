extends Control
var progress:=0.0
var glyph:Control
var caption:Label
func build(kit,router)->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 position=Vector2(2010,1080);size=Vector2(440,80)
 glyph=router.make_glyph(self,Vector2(8,8),router.symbol("pass"))
 glyph.size=Vector2(48,48)
 caption=kit.text(self,"长按跳过准备",Vector2(82,17),25,kit.INK,false,320)
func refresh(s,router,playing:bool)->void:
 visible=playing and s.phase=="restart" and not s.Rules.Flow.ready(s) and s.restart_flow.get("skip_time",-1)<0
 progress=clampf(float(s.restart_flow.get("hold",[0,0])[s.view_team])/s.Rules.Flow.HOLD_SECONDS,0,1) if visible else 0
 glyph.set_symbol(router.symbol("pass"),router.family())
 queue_redraw()
func _draw()->void:
 draw_arc(Vector2(32,32),31,-PI/2,TAU-PI/2,64,Color(0.4,0.6,0.65,0.35),4,true)
 if progress>0: draw_arc(Vector2(32,32),31,-PI/2,-PI/2+TAU*progress,64,Color("65f3db"),4,true)
