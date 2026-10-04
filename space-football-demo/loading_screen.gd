extends CanvasLayer
## Progress advances only when a loading stage completes. No timer-based fake progress.
var active:=false
var root:Control
var title:Label
var stage:Label
var percent:Label
var progress:ProgressBar
var history:Array[float]=[]
var presented_frames:=0

func build(game)->void:
 layer=30
 root=Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(root)
 game.panel(root,Rect2(0,0,2560,1440),Color("07111f"),Color.TRANSPARENT,0)
 game.text(root,"YFFM 3  /  STARBORNE",Vector2(208,176),28,game.CYAN,true)
 game.text(root,"群星绿茵",Vector2(203,486),88,game.INK,true)
 title=game.text(root,"正在启动",Vector2(208,654),38,game.INK,true)
 stage=game.text(root,"准备资源",Vector2(209,816),26,game.MUTED)
 percent=game.text(root,"0%",Vector2(2220,804),36,game.CYAN,true,130)
 percent.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 progress=ProgressBar.new()
 progress.step=0.0 # Twelve player builds produce fractional completion percentages.
 progress.position=Vector2(210,889);progress.size=Vector2(2140,16)
 progress.show_percentage=false
 progress.add_theme_stylebox_override("background",game.style(Color("203449"),Color.TRANSPARENT,8))
 progress.add_theme_stylebox_override("fill",game.style(game.CYAN,Color.TRANSPARENT,8))
 root.add_child(progress)
 game.text(root,"正在准备你的球场",Vector2(210,1192),23,game.MUTED)
 root.mouse_filter=Control.MOUSE_FILTER_STOP
 hide()

func begin(message:String)->void:
 active=true;history.clear();presented_frames=0
 title.text=message;progress.value=0;percent.text="0%"
 show()

func present(value:float,message:String)->void:
 progress.value=maxf(progress.value,clampf(value,0,100))
 stage.text=message
 percent.text="%d%%" % roundi(progress.value)
 history.append(progress.value)
 # Submit the visible overlay before the next CPU-heavy stage starts.
 await RenderingServer.frame_post_draw
 presented_frames+=1
 await get_tree().process_frame

func finish()->void:
 active=false
 hide()
