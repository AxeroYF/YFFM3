extends Node3D

const PlayerCard=preload("res://player_card.gd")
const ACCENTS=[Color("e9c181"),Color("73d8f5"),Color("d3d7f5")]
const TITLES=["恒星传说", "深空锋刃", "光谱新星"]
const SUBTITLES=["金色传奇  /  SOLAR LEGACY", "冷蓝金属  /  DEEPSPACE ALLOY", "白银全息  /  PRISM ASCENDANT"]
var cards: Array[Node3D]=[]
var records: Array=[]
var camera: Camera3D
var ui: Control
var overlay: Control
var font: SystemFont
var bold: SystemFont
var backdrop: ShaderMaterial
var clock:=0.0
var effects:=true
var presentation:=true
var detail_index:=-1
var detail_panel: Control
var status_label: Label
var effect_button: Button
var presentation_button: Button
var frame:=0
var verify:=false
var capture:=false
var keyboard_focus:=-1
var drag_card:=-1
var drag_distance:=0.0
var beams: Array[ShaderMaterial]=[]

func _ready() -> void:
	verify="--verify" in OS.get_cmdline_user_args()
	capture="--capture" in OS.get_cmdline_user_args()
	font=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Segoe UI"])
	bold=SystemFont.new()
	bold.font_names=font.font_names
	bold.font_weight=700
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/players.json"))
	assert(parsed is Array and parsed.size()==3,"Three player records are required")
	records=parsed
	_create_world()
	_create_ui()
	for i in 3:
		var card:=PlayerCard.new()
		card.record=records[i]
		card.theme_id=i
		card.font=font
		card.bold=bold
		card.home=Vector3((i-1)*5.85,-0.25,0)
		card.position=card.home
		add_child(card)
		cards.append(card)
		_create_dock(i,card.home)
	print("PLAYER_CARDS_READY native=2560x1440 players=3")

func _create_world() -> void:
	var env_node:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_CANVAS
	env.background_canvas_max_layer=-1
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("849db8")
	env.ambient_light_energy=0.7
	env.glow_enabled=true
	env.glow_intensity=0.65
	env.glow_bloom=0.03
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env_node.environment=env
	add_child(env_node)
	var lamp:=DirectionalLight3D.new()
	lamp.rotation_degrees=Vector3(-30,-25,0)
	lamp.light_energy=1.3
	add_child(lamp)
	camera=Camera3D.new()
	camera.position=Vector3(0,2.5,23)
	camera.fov=30
	camera.near=0.1
	camera.far=100
	add_child(camera)
	camera.look_at(Vector3(0,-0.15,0),Vector3.UP)
	var background_layer:=CanvasLayer.new()
	background_layer.layer=-1
	add_child(background_layer)
	var bg:=ColorRect.new()
	bg.size=Vector2(2560,1440)
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	backdrop=ShaderMaterial.new()
	backdrop.shader=load("res://shaders/backdrop.gdshader")
	bg.material=backdrop
	background_layer.add_child(bg)
	_create_distant_world()

func _emissive(color: Color,energy: float=1.0) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=color
	material.emission_enabled=true
	material.emission=color
	material.emission_energy_multiplier=energy
	return material

func _ring(parent: Node3D,radius: float,thickness: float,mat: Material) -> MeshInstance3D:
	var mesh:=TorusMesh.new()
	mesh.inner_radius=radius-thickness
	mesh.outer_radius=radius+thickness
	mesh.rings=128
	mesh.ring_segments=8
	var node:=MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=mat
	parent.add_child(node)
	return node

func _create_dock(index: int,point: Vector3) -> void:
	var dock:=Node3D.new()
	dock.position=Vector3(point.x,-4.14,0)
	add_child(dock)
	var base:=MeshInstance3D.new()
	var cylinder:=CylinderMesh.new()
	cylinder.top_radius=2.7
	cylinder.bottom_radius=2.58
	cylinder.height=0.20
	cylinder.radial_segments=96
	base.mesh=cylinder
	var metal:=StandardMaterial3D.new()
	metal.albedo_color=Color("162430")
	metal.metallic=0.78
	metal.roughness=0.3
	base.material_override=metal
	dock.add_child(base)
	for radius in [1.75,2.35,2.68]:
		var ring:=_ring(dock,radius,0.012,_emissive(ACCENTS[index],1.5))
		ring.position.y=0.12
	for i in 16:
		var a:=TAU*float(i)/16
		var tick:=MeshInstance3D.new()
		var tickmesh:=BoxMesh.new()
		tickmesh.size=Vector3(0.12,0.025,0.23)
		tick.mesh=tickmesh
		tick.position=Vector3(cos(a)*2.50,0.13,sin(a)*2.50)
		tick.rotation.y=-a
		tick.material_override=_emissive(ACCENTS[index].darkened(0.30))
		dock.add_child(tick)
	var beam:=MeshInstance3D.new()
	var cone:=CylinderMesh.new()
	cone.top_radius=1.90
	cone.bottom_radius=2.40
	cone.height=3.6
	cone.radial_segments=64
	cone.cap_top=false
	cone.cap_bottom=false
	beam.mesh=cone
	beam.position=Vector3(0,1.9,-0.45)
	var mat:=ShaderMaterial.new()
	mat.shader=load("res://shaders/beam.gdshader")
	mat.set_shader_parameter("tint",ACCENTS[index])
	beam.material_override=mat
	beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beams.append(mat)
	dock.add_child(beam)

func _create_distant_world() -> void:
	var planet:=MeshInstance3D.new()
	var sphere:=SphereMesh.new()
	sphere.radius=6.4
	sphere.height=12.8
	sphere.radial_segments=96
	sphere.rings=48
	planet.mesh=sphere
	planet.position=Vector3(18.0,6,-24)
	var mat:=ShaderMaterial.new()
	mat.shader=load("res://shaders/world_planet.gdshader")
	mat.set_shader_parameter("kind",2)
	mat.set_shader_parameter("base_color",Color("111d39"))
	mat.set_shader_parameter("secondary_color",Color("334768"))
	planet.material_override=mat
	add_child(planet)
	var air:=MeshInstance3D.new()
	air.mesh=sphere
	air.scale=Vector3.ONE*1.018
	var atmosphere:=ShaderMaterial.new()
	atmosphere.shader=load("res://shaders/world_atmosphere.gdshader")
	atmosphere.set_shader_parameter("tint",Color("37619b"))
	air.material_override=atmosphere
	planet.add_child(air)
	var ring:=_ring(planet,10.5,0.013,_emissive(Color("31455c")))
	ring.rotation_degrees=Vector3(19,0,-25)
	var grid:=ImmediateMesh.new()
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-14,15,2):
		grid.surface_add_vertex(Vector3(i,-4.34,-14))
		grid.surface_add_vertex(Vector3(i,-4.34,6))
	for z in range(-14,7,2):
		grid.surface_add_vertex(Vector3(-14,-4.34,z))
		grid.surface_add_vertex(Vector3(14,-4.34,z))
	grid.surface_end()
	var floor_lines:=MeshInstance3D.new()
	floor_lines.mesh=grid
	floor_lines.material_override=_emissive(Color("112332"),0.1)
	add_child(floor_lines)

func _label(parent: Node,text: String,pos: Vector2,size: int,color: Color=Color("e8eef4"),heavy: bool=false) -> Label:
	var label:=Label.new()
	label.text=text
	label.position=pos
	label.add_theme_font_override("font",bold if heavy else font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _box(color: Color,border: Color) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=color
	s.border_color=border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	return s

func _button(parent: Node,text: String,pos: Vector2,dimensions: Vector2,callback: Callable) -> Button:
	var button:=Button.new()
	button.text=text
	button.position=pos
	button.size=dimensions
	button.add_theme_font_override("font",font)
	button.add_theme_font_size_override("font_size",20)
	button.add_theme_color_override("font_color",Color("bfcbd8"))
	button.add_theme_stylebox_override("normal",_box(Color(0.04,0.055,0.077,0.9),Color("344255")))
	button.add_theme_stylebox_override("hover",_box(Color("172637"),Color("8caabd")))
	button.add_theme_stylebox_override("pressed",_box(Color("20334a"),Color("c3dcea")))
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _create_ui() -> void:
	var layer:=CanvasLayer.new()
	layer.layer=2
	add_child(layer)
	ui=Control.new()
	ui.size=Vector2(2560,1440)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_label(ui,"Y F F M   /   I N T E R S T E L L A R   F O O T B A L L",Vector2(124,65),19,Color("9daebc"))
	_label(ui,"群星 · 全息档案舱",Vector2(119,113),64,Color("ecf0f3"),true)
	_label(ui,"轨道旗舰 / 球员意识投影已就绪",Vector2(126,207),24,Color("77899e"))
	_label(ui,"O R I G I N   C O L L E C T I O N",Vector2(1948,71),19,Color("a4b1c0"))
	_label(ui,"创始系列   /   001 — 003",Vector2(1985,113),25)
	_label(ui,"●  三席待命     /     ORBITAL VAULT",Vector2(1927,164),18,Color("718c9c"))
	for i in 3:
		var center:=1280.0+(i-1)*686.5
		_label(ui,"0%d" % [i+1],Vector2(center-278,292),18,ACCENTS[i])
		_label(ui,TITLES[i],Vector2(center-235,282),29,Color("d5dfe7"),true)
		_label(ui,["LEGEND","STRIKER","PLAYMAKER"][i],Vector2(center+147,295),14,ACCENTS[i])
		_label(ui,SUBTITLES[i],Vector2(center-263,1250),18,ACCENTS[i])
		_button(ui,"查看档案  ↗",Vector2(center+102,1237),Vector2(180,48),_open_details.bind(i))
	effect_button=_button(ui,"动态光效  开",Vector2(1536,1340),Vector2(210,54),_toggle_effects)
	presentation_button=_button(ui,"停止巡展",Vector2(1762,1340),Vector2(180,54),_toggle_presentation)
	_button(ui,"重置  R",Vector2(1958,1340),Vector2(170,54),_reset)
	_button(ui,"全屏  F11",Vector2(2144,1340),Vector2(210,54),_fullscreen)
	status_label=_label(ui,"拖动卡体 · 旋转     /     悬停 · 视差     /     点击 · 档案     /     1—3 · 选择球员",Vector2(126,1354),19,Color("7d8da0"))
	overlay=Control.new()
	overlay.size=Vector2(2560,1440)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_chrome)
	ui.add_child(overlay)

func _draw_chrome() -> void:
	overlay.draw_line(Vector2(125,258),Vector2(2435,258),Color(0.46,0.55,0.65,0.17),1,true)
	overlay.draw_line(Vector2(125,1314),Vector2(2435,1314),Color(0.46,0.55,0.65,0.17),1,true)
	for i in 3:
		var c:=1280.0+(i-1)*686.5
		var color:=Color(ACCENTS[i],0.16)
		overlay.draw_line(Vector2(c-279,1218),Vector2(c+279,1218),color,1,true)
		for x in [c-290,c+290]:
			overlay.draw_line(Vector2(x,771),Vector2(x,796),color,1,true)
			overlay.draw_line(Vector2(c-7,1205),Vector2(c+7,1205),color,1,true)

func _toggle_effects() -> void:
	effects=not effects
	effect_button.text="动态光效  开" if effects else "动态光效  关"

func _toggle_presentation() -> void:
	presentation=not presentation
	presentation_button.text="停止巡展" if presentation else "自动巡展"
	keyboard_focus=-1

func _reset() -> void:
	_close_details()
	keyboard_focus=-1
	presentation=false
	presentation_button.text="自动巡展"
	for card in cards:
		card.target_tilt=Vector2.ZERO
		card.manual_tilt=Vector2.ZERO
		card.hovered=false

func _fullscreen() -> void:
	var full:=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _hit(point: Vector2) -> int:
	var ray_origin:=camera.project_ray_origin(point)
	var ray_direction:=camera.project_ray_normal(point)
	for i in cards.size():
		var card: Node3D=cards[i]
		var plane:=Plane(card.global_basis.z,card.to_global(Vector3(0,0,0.65)))
		var intersection: Variant=plane.intersects_ray(ray_origin,ray_direction)
		if intersection!=null:
			var local: Vector3=card.to_local(intersection)
			if absf(local.x)<2.45 and absf(local.y)<3.5: return i
	return -1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: _close_details()
			KEY_R: _reset()
			KEY_F11: _fullscreen()
			KEY_SPACE: _toggle_effects()
			KEY_1,KEY_2,KEY_3:
				_open_details(event.keycode-KEY_1)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and detail_index<0:
		if event.pressed:
			drag_card=_hit(event.position)
			drag_distance=0
		else:
			if drag_card>=0 and drag_distance<7: _open_details(drag_card)
			drag_card=-1
	if event is InputEventMouseMotion and drag_card>=0:
		drag_distance+=event.relative.length()
		cards[drag_card].manual_tilt+=event.relative*Vector2(0.005,0.003)
		cards[drag_card].manual_tilt=cards[drag_card].manual_tilt.clamp(Vector2(-0.7,-0.35),Vector2(0.7,0.35))

func _open_details(index: int) -> void:
	_close_details()
	detail_index=index
	var data: Dictionary=records[index]
	var shade:=ColorRect.new()
	shade.size=Vector2(2560,1440)
	shade.color=Color(0.005,0.008,0.015,0.88)
	shade.mouse_filter=Control.MOUSE_FILTER_STOP
	ui.add_child(shade)
	detail_panel=shade
	var panel:=Panel.new()
	panel.position=Vector2(390,245)
	panel.size=Vector2(1780,950)
	panel.add_theme_stylebox_override("panel",_box(Color("0d1622"),Color(ACCENTS[index],0.45)))
	shade.add_child(panel)
	_label(panel,"P L A Y E R   A R C H I V E   /   0%d" % [index+1],Vector2(66,43),19,ACCENTS[index])
	_label(panel,data.name,Vector2(60,95),64,Color("edf1f5"),true)
	_label(panel,"%s  ·  %s  ·  %s  ·  %s 级" % [data.role,data.nationality,data.club,data.grade],Vector2(64,183),23,Color("9fb0c1"))
	_label(panel,"%d" % int(data.overall),Vector2(1534,82),83,ACCENTS[index],true)
	_label(panel,"综合评分",Vector2(1543,185),18,Color("a0afbe"))
	_button(panel,"关闭  Esc",Vector2(1537,37),Vector2(170,44),_close_details)
	var pic:=Sprite2D.new()
	pic.texture=load(data.portrait)
	var fit:=minf(560.0/pic.texture.get_width(),580.0/pic.texture.get_height())
	pic.scale=Vector2.ONE*fit
	pic.position=Vector2(327,560)
	panel.add_child(pic)
	_label(panel,"完整能力档案",Vector2(662,269),26,Color("dce5eb"),true)
	var attribute_names:={"passing":"传球","firstTouch":"停球","dribbling":"盘带","crossing":"传中","finishing":"射门","longShots":"远射","heading":"头球","setPieces":"定位球","tackling":"抢断","marking":"盯人","positioning":"选位","vision":"视野","decisions":"决断","composure":"冷静","offBall":"无球跑动","discipline":"纪律","pace":"速度","acceleration":"加速","strength":"力量","stamina":"体能","agility":"灵活","jumping":"弹跳","workRate":"工作投入","aggression":"侵略性","goalkeeping":"守门","reflexes":"反应"}
	var keys:=attribute_names.keys()
	for n in keys.size():
		var col:=n%3
		var row:=n/3
		var x:=665+col*338
		var y:=333+row*56
		_label(panel,attribute_names[keys[n]],Vector2(x,y),19,Color("91a2b6"))
		_label(panel,str(int(data.attributes[keys[n]])),Vector2(x+233,y-4),25,Color("e4ebf3"),true)
	_label(panel,"来源：Rougelite 球员库  ·  展示原始评分与能力值",Vector2(663,866),17,Color("718497"))
	_label(panel,"卡面主题为视觉设计，不改变球员评级或属性。",Vector2(64,879),18,ACCENTS[index])

func _close_details() -> void:
	if is_instance_valid(detail_panel):
		detail_panel.queue_free()
		detail_panel=null
	detail_index=-1

func _process(delta: float) -> void:
	frame+=1
	if effects: clock+=delta
	backdrop.set_shader_parameter("clock",clock)
	for beam in beams: beam.set_shader_parameter("clock",clock)
	var mouse:=get_viewport().get_mouse_position()
	for i in cards.size():
		var card: Node3D=cards[i]
		var center:=camera.unproject_position(card.home)
		var top_left:=camera.unproject_position(card.home+Vector3(-2.30,3.45,0))
		var bottom_right:=camera.unproject_position(card.home+Vector3(2.30,-3.45,0))
		card.screen_rect=Rect2(top_left,bottom_right-top_left)
		card.hovered=(_hit(mouse)==i or drag_card==i) and detail_index<0 and not verify and not capture
		if card.hovered:
			card.target_tilt=(mouse-center)/(card.screen_rect.size*0.5)*Vector2(0.22,0.14)
		card.animate(delta,effects,presentation,clock)
	if verify: _verify()
	elif capture and frame==120: _save_capture("cards-overview.png",true)

func _save_capture(filename: String,finish: bool=false) -> void:
	await RenderingServer.frame_post_draw
	var output_dir:=ProjectSettings.globalize_path("res://artifacts")
	var image:=get_viewport().get_texture().get_image()
	assert(image.get_size()==Vector2i(2560,1440),"Native screenshot must be 2K")
	var error:=image.save_png(output_dir.path_join(filename))
	print("CAPTURE ",filename," size=",image.get_size()," result=",error)
	if finish: get_tree().quit(0 if error==OK else 1)

func _verify() -> void:
	if frame==30:
		assert(cards.size()==3)
		_reset()
		for i in 3:
			assert(_hit(camera.unproject_position(cards[i].home))==i)
		effect_button.pressed.emit()
		assert(not effects)
		effect_button.pressed.emit()
		presentation_button.pressed.emit()
		assert(presentation)
		presentation_button.pressed.emit()
		var press:=InputEventMouseButton.new()
		press.button_index=MOUSE_BUTTON_LEFT
		press.pressed=true
		press.position=camera.unproject_position(cards[1].home)
		_unhandled_input(press)
		assert(drag_card==1)
		var move:=InputEventMouseMotion.new()
		move.relative=Vector2(70,-20)
		_unhandled_input(move)
		var release:=InputEventMouseButton.new()
		release.button_index=MOUSE_BUTTON_LEFT
		release.pressed=false
		release.position=press.position+move.relative
		_unhandled_input(release)
		assert(cards[1].manual_tilt.length()>0.2 and detail_index==-1)
		_reset()
		_unhandled_input(press)
		release.position=press.position
		_unhandled_input(release)
		assert(detail_index==1)
		_close_details()
		_open_details(2)
		assert(detail_index==2)
		print("CARD_CHECKS_OK data ray-picking mouse-drag click-details effects presentation reset")
	if frame==60:
		_save_capture("player-details.png")
	if frame==65:
		_close_details()
	if frame==90:
		cards[0].manual_tilt=Vector2(-0.30,0.10)
	if frame==110:
		_save_capture("card-perspective.png")
	if frame==120:
		_reset()
	if frame==150:
		_save_capture("cards-overview.png",true)
