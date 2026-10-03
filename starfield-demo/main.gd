extends Node3D

const GOLD = Color("e7c68a")
const MUTED = Color("8493a7")
const WHITE = Color("e9eef6")
const BODIES = [
	{"name":"卡西尼", "en":"CASSINI · VI", "type":"环带巨行星", "position":Vector3(4.5,0,0), "radius":3.3, "color":Color("886044"), "second":Color("e7c997"), "atmo":Color("ecba79"), "kind":0, "description":"冰与尘埃环绕着这颗古老的巨行星。\n环带外缘的空间站，是远征舰队的下一站。", "distance":"08.4", "gravity":"1.26", "temperature":"−142°", "tag":"空间站 · 环带竞技场"},
	{"name":"澜星", "en":"PELAGIA · III", "type":"海洋类地行星", "position":Vector3(-6.0,0,5.2), "radius":1.55, "color":Color("074377"), "second":Color("25898c"), "atmo":Color("41a9ff"), "kind":1, "description":"海洋覆盖了星球的大部分表面。\n漂浮城市之间，一场新的星际联赛即将开始。", "distance":"03.2", "gravity":"0.94", "temperature":"+18°", "tag":"宜居世界 · 海上球场"},
	{"name":"余烬", "en":"EMBER · II", "type":"铁质岩石行星", "position":Vector3(-0.8,0,-9.5), "radius":0.92, "color":Color("612d39"), "second":Color("e39468"), "atmo":Color("ef8368"), "kind":2, "description":"红色峡谷切开了风化的岩石平原。\n这里的低重力训练基地，吸引着远方的球队。", "distance":"05.7", "gravity":"0.62", "temperature":"+67°", "tag":"边境基地 · 低重力训练"},
	{"name":"霜境", "en":"NIVALIS · VIII", "type":"冰封边缘世界", "position":Vector3(10.5,0,-10), "radius":1.2, "color":Color("456580"), "second":Color("b5d5dd"), "atmo":Color("9ad6ff"), "kind":2, "description":"漫长的极夜笼罩着远日冰原。\n观测站的灯光，是星系边缘最后的航行坐标。", "distance":"16.8", "gravity":"0.81", "temperature":"−208°", "tag":"深空观测站 · 未探索"}
]

var camera: Camera3D
var planets: Array[Node3D] = []
var ship: Node3D
var selected := 0
var yaw := 0.08
var pitch := 0.48
var distance := 33.0
var target_distance := 33.0
var focus := Vector3.ZERO
var target_focus := Vector3.ZERO
var elapsed := 0.0
var paused := false
var orbit_mode := false
var ship_travel := false
var travel_progress := 0.0
var travel_start := Vector3.ZERO
var travel_end := Vector3.ZERO
var drag_distance := 0.0
var overlay: Control
var name_label: Label
var english_label: Label
var type_label: Label
var description_label: Label
var tag_label: Label
var distance_label: Label
var gravity_label: Label
var temperature_label: Label
var status_label: Label
var telemetry_label: Label
var pause_button: Button
var orbit_button: Button
var travel_button: Button
var planet_buttons: Array[Button] = []
var marker_labels: Array[Label] = []
var ui_font: SystemFont
var frames := 0
var capture_mode := false
var verify_mode := false
var capture_stage := 0
var start_ship_position := Vector3(-1.3,0,7.5)
var corona: MeshInstance3D

func _ready() -> void:
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	verify_mode = "--verify" in OS.get_cmdline_user_args()
	ui_font = SystemFont.new()
	ui_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI"])
	_create_world()
	_create_interface()
	_select_body(0)
	_update_camera(1.0)
	print("STARFIELD_DEMO_READY")

func _create_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/space.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("637fa4")
	env.ambient_light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.1
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.light_color = Color("ffe1b5")
	light.light_energy = 2.4
	light.rotation_degrees = Vector3(-24,-48,0)
	light.shadow_enabled = true
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("608dcb")
	fill.light_energy = 0.22
	fill.rotation_degrees = Vector3(20,135,0)
	add_child(fill)
	camera = Camera3D.new()
	camera.fov = 46
	camera.near = 0.1
	camera.far = 1500
	add_child(camera)
	for i in BODIES.size():
		var b: Dictionary = BODIES[i]
		var root := Node3D.new()
		root.position = b.position
		add_child(root)
		planets.append(root)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/planet.gdshader")
		mat.set_shader_parameter("base_color", b.color)
		mat.set_shader_parameter("secondary_color", b.second)
		mat.set_shader_parameter("kind", b.kind)
		mat.set_shader_parameter("seed", float(i)*19.1)
		_sphere(root, b.radius, mat)
		var atmosphere := ShaderMaterial.new()
		atmosphere.shader = load("res://shaders/atmosphere.gdshader")
		atmosphere.set_shader_parameter("tint", b.atmo)
		_sphere(root, b.radius*1.025, atmosphere)
		if i == 0:
			var ring := _make_ring(4.15,6.35)
			ring.rotation_degrees = Vector3(11,0,-16)
			root.add_child(ring)
	var sun := Node3D.new()
	sun.position = Vector3(-12,0,-9)
	add_child(sun)
	var sunmat := ShaderMaterial.new()
	sunmat.shader = load("res://shaders/sun.gdshader")
	_sphere(sun,1.85,sunmat)
	var aura := ShaderMaterial.new()
	aura.shader = load("res://shaders/atmosphere.gdshader")
	aura.set_shader_parameter("tint",Color(1.0,0.35,0.05))
	_sphere(sun,2.12,aura)
	corona=MeshInstance3D.new()
	var corona_quad:=QuadMesh.new()
	corona_quad.size=Vector2(15,15)
	corona.mesh=corona_quad
	var corona_mat:=ShaderMaterial.new()
	corona_mat.shader=load("res://shaders/corona.gdshader")
	corona.material_override=corona_mat
	corona.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun.add_child(corona)
	for radius in [8.0,13.0,18.0,24.0]:
		_orbit_line(Vector3(-12,-0.25,-9),radius)
	_create_ship()

func _sphere(parent: Node3D, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius*2
	sphere.radial_segments = 96
	sphere.rings = 48
	mesh.mesh = sphere
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

func _make_ring(inner: float, outer: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 256:
		var a := float(i)/256.0*TAU
		var b := float(i+1)/256.0*TAU
		for point in [Vector2(inner,a),Vector2(outer,a),Vector2(outer,b),Vector2(inner,a),Vector2(outer,b),Vector2(inner,b)]:
			st.set_uv(Vector2((point.x-inner)/(outer-inner),point.y/TAU))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(cos(point.y)*point.x,0,sin(point.y)*point.x))
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/rings.gdshader")
	mesh.material_override = mat
	return mesh

func _orbit_line(center: Vector3, radius: float) -> void:
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 256:
		for angle in [float(i)/256.0*TAU,float(i+1)/256.0*TAU]:
			immediate.surface_add_vertex(center+Vector3(cos(angle)*radius,0,sin(angle)*radius))
	immediate.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = immediate
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.31,0.49,0.62,0.17)
	instance.material_override = mat
	add_child(instance)

func _create_ship() -> void:
	ship = Node3D.new()
	ship.position = start_ship_position
	ship.rotation.y = -0.6
	add_child(ship)
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color("d7e0df")
	hull_mat.metallic = 0.65
	hull_mat.roughness = 0.3
	var body := MeshInstance3D.new()
	var shape := PrismMesh.new()
	shape.size = Vector3(0.42,1.3,0.22)
	body.mesh = shape
	body.material_override = hull_mat
	body.rotation.x = -PI/2
	ship.add_child(body)
	for side in [-1.0,1.0]:
		var wing := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7,0.06,0.48)
		wing.mesh = box
		wing.position = Vector3(side*0.34,-0.03,0.18)
		wing.rotation.z = side*-0.16
		wing.material_override = hull_mat
		ship.add_child(wing)
		var engine := StandardMaterial3D.new()
		engine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		engine.albedo_color = Color("64dfff")
		engine.emission_enabled = true
		engine.emission = Color("45c9ff")
		engine.emission_energy_multiplier = 5
		var flame := _sphere(ship,0.11,engine)
		flame.position = Vector3(side*0.28,0,0.5)
		flame.scale = Vector3(0.7,0.7,3.8)

func _label(parent: Node, text: String, pos: Vector2, font_size: int, color: Color=WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", ui_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _style(bg: Color, border: Color, padding: int=14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=bg
	style.border_color=border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left=padding
	style.content_margin_right=padding
	return style

func _button(parent: Node, text: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text=text
	button.position=pos
	button.size=dimensions
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",ui_font)
	button.add_theme_font_size_override("font_size",14)
	button.add_theme_color_override("font_color",WHITE)
	button.add_theme_stylebox_override("normal",_style(Color(0.025,0.045,0.075,0.87),Color(0.3,0.4,0.52,0.3)))
	button.add_theme_stylebox_override("hover",_style(Color(0.1,0.14,0.19,0.95),GOLD))
	button.add_theme_stylebox_override("pressed",_style(Color(0.16,0.15,0.12,0.96),GOLD))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _create_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font=ui_font
	ui.theme=theme
	layer.add_child(ui)
	# A subtle left veil leaves the scene uninterrupted while keeping text readable.
	var veil := ColorRect.new()
	veil.size=Vector2(470,900)
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var veil_shader := Shader.new()
	veil_shader.code="shader_type canvas_item; void fragment(){COLOR=vec4(0.012,0.021,0.039,pow(1.0-UV.x,1.5)*0.93);}"
	var veil_mat := ShaderMaterial.new()
	veil_mat.shader=veil_shader
	veil.material=veil_mat
	ui.add_child(veil)
	_label(ui,"Y F F M   /   E X P E D I T I O N   0 0 3",Vector2(42,30),13,GOLD)
	_label(ui,"星际远征",Vector2(40,65),40)
	_label(ui,"一支球队，一艘飞船，一片尚未抵达的星空。",Vector2(43,125),13,MUTED)
	_label(ui,"●  舰载导航在线",Vector2(1210,33),13,Color("8cc4bc"))
	_label(ui,"KEPLER SECTOR  /  开普勒星域",Vector2(1100,58),12,MUTED)
	_label(ui,"01   /   目的地档案",Vector2(44,220),12,GOLD)
	name_label=_label(ui,"",Vector2(40,253),48)
	english_label=_label(ui,"",Vector2(44,321),14,MUTED)
	type_label=_label(ui,"",Vector2(44,365),15,GOLD)
	description_label=_label(ui,"",Vector2(44,406),13,Color("aab5c5"))
	description_label.add_theme_constant_override("line_spacing",9)
	_label(ui,"航程 / LY",Vector2(44,486),11,MUTED)
	_label(ui,"重力 / G",Vector2(157,486),11,MUTED)
	_label(ui,"地表 / °C",Vector2(264,486),11,MUTED)
	distance_label=_label(ui,"",Vector2(42,509),27)
	gravity_label=_label(ui,"",Vector2(155,509),27)
	temperature_label=_label(ui,"",Vector2(262,509),27)
	tag_label=_label(ui,"",Vector2(44,567),12,Color("80a9c1"))
	travel_button=_button(ui,"设为航行目的地   ↗",Vector2(44,612),Vector2(284,48),_travel)
	travel_button.add_theme_color_override("font_color",GOLD)
	status_label=_label(ui,"远征一号  /  等待航行指令",Vector2(44,676),12,MUTED)
	_label(ui,"星域目的地",Vector2(44,767),12,MUTED)
	for i in BODIES.size():
		var button:=_button(ui,"%02d  %s" % [i+1,BODIES[i].name],Vector2(44+i*149,801),Vector2(136,43),_select_body.bind(i))
		planet_buttons.append(button)
	orbit_button=_button(ui,"环绕视角",Vector2(1028,801),Vector2(110,43),_toggle_orbit)
	pause_button=_button(ui,"暂停时间",Vector2(1150,801),Vector2(110,43),_toggle_pause)
	_button(ui,"总览  R",Vector2(1272,801),Vector2(120,43),_reset_view)
	_label(ui,"拖动旋转  ·  滚轮缩放  ·  点击星球选择  ·  双击聚焦  ·  空格暂停",Vector2(44,866),11,MUTED)
	telemetry_label=_label(ui,"",Vector2(1110,866),11,MUTED)
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	ui.add_child(overlay)
	for i in BODIES.size():
		var label:=_label(overlay,BODIES[i].name,Vector2.ZERO,12,Color("afbdcf"))
		label.add_theme_color_override("font_shadow_color",Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x",1)
		label.add_theme_constant_override("shadow_offset_y",1)
		marker_labels.append(label)

func _select_body(index: int) -> void:
	selected=index
	var body: Dictionary=BODIES[index]
	name_label.text=body.name
	english_label.text=body.en
	type_label.text=body.type
	description_label.text=body.description
	distance_label.text=body.distance
	gravity_label.text=body.gravity
	temperature_label.text=body.temperature
	tag_label.text=body.tag
	for i in planet_buttons.size():
		planet_buttons[i].add_theme_color_override("font_color",GOLD if i==index else MUTED)
		planet_buttons[i].add_theme_stylebox_override("normal",_style(Color(0.09,0.09,0.085,0.9) if i==index else Color(0.025,0.045,0.075,0.87),Color(0.7,0.58,0.36,0.65) if i==index else Color(0.3,0.4,0.52,0.3)))
	if not ship_travel:
		status_label.text="远征一号  /  等待航行指令"

func _travel() -> void:
	travel_start=ship.position
	travel_end=BODIES[selected].position+Vector3(0,0,float(BODIES[selected].radius)+2.5)
	travel_progress=0
	ship_travel=true
	travel_button.disabled=true
	status_label.text="航线已锁定  /  正在驶向"+BODIES[selected].name
	if travel_start.distance_to(travel_end)>0.1:
		ship.look_at(travel_end,Vector3.UP)

func _toggle_pause() -> void:
	paused=not paused
	pause_button.text="继续时间" if paused else "暂停时间"

func _toggle_orbit() -> void:
	orbit_mode=not orbit_mode
	orbit_button.text="停止环绕" if orbit_mode else "环绕视角"

func _reset_view() -> void:
	target_focus=Vector3.ZERO
	target_distance=33
	yaw=0.08
	pitch=0.48
	orbit_mode=false
	orbit_button.text="环绕视角"

func _focus_selected() -> void:
	target_focus=BODIES[selected].position
	target_distance=float(BODIES[selected].radius)*5.5+7.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_distance=clampf(target_distance*0.90,10,65)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_distance=clampf(target_distance*1.10,10,65)
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_distance=0
			else:
				if drag_distance<7:
					_pick_body(event.position)
			if event.double_click:
				_pick_body(event.position)
				_focus_selected()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT or event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			drag_distance+=event.relative.length()
			yaw-=event.relative.x*0.004
			pitch=clampf(pitch+event.relative.y*0.004,-0.15,1.35)
			orbit_mode=false
			orbit_button.text="环绕视角"
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: _toggle_pause()
			KEY_R: _reset_view()
			KEY_F: _focus_selected()
			KEY_ESCAPE: _reset_view()
			KEY_1,KEY_2,KEY_3,KEY_4: _select_body(event.keycode-KEY_1)

func _pick_body(point: Vector2) -> void:
	var best:=-1
	var nearest:=INF
	for i in BODIES.size():
		var pos:Vector3=BODIES[i].position
		if camera.is_position_behind(pos): continue
		var screen:=camera.unproject_position(pos)
		var edge:=camera.unproject_position(pos+camera.global_basis.x*float(BODIES[i].radius))
		if screen.distance_to(point)<maxf(screen.distance_to(edge),22):
			var depth:=camera.global_position.distance_to(pos)
			if depth<nearest:
				nearest=depth
				best=i
	if best>=0: _select_body(best)

func _update_camera(delta: float) -> void:
	focus=focus.lerp(target_focus,minf(delta*4,1.0))
	distance=lerpf(distance,target_distance,minf(delta*5,1.0))
	camera.position=focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(focus,Vector3.UP)

func _draw_overlay() -> void:
	var line_color:=Color(0.5,0.61,0.72,0.17)
	overlay.draw_line(Vector2(44,193),Vector2(332,193),line_color,1,true)
	overlay.draw_line(Vector2(44,470),Vector2(332,470),line_color,1,true)
	overlay.draw_line(Vector2(44,748),Vector2(1392,748),line_color,1,true)
	for i in BODIES.size():
		var pos:Vector3=BODIES[i].position
		var label:=marker_labels[i]
		if camera.is_position_behind(pos):
			label.visible=false
			continue
		var center:=camera.unproject_position(pos)
		var edge:=camera.unproject_position(pos+camera.global_basis.x*float(BODIES[i].radius))
		var radius:=center.distance_to(edge)
		label.position=center+Vector2(radius+15,-14)
		label.visible=label.position.x>355 and label.position.x<1330 and label.position.y>150 and label.position.y<715
		if i==selected and center.x>355 and center.x<1380 and center.y>150 and center.y<710:
			var r:=radius+14
			for angle in [0.0,PI*0.5,PI,PI*1.5]:
				overlay.draw_arc(center,r,angle-0.09,angle+0.09,12,Color(0.91,0.78,0.54,0.7),1.3,true)
			if label.visible:
				overlay.draw_line(center+Vector2(r+4,0),label.position+Vector2(-4,14),Color(0.91,0.78,0.54,0.45),1,true)
	if not camera.is_position_behind(ship.position):
		var p:=camera.unproject_position(ship.position)
		if p.x>370 and p.y>160 and p.y<715:
			overlay.draw_circle(p,13,Color(0.37,0.79,0.93,0.55),false,1,true)
			overlay.draw_string(ui_font,p+Vector2(40,20),"远征一号",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("8bbdce"))

func _process(delta: float) -> void:
	frames+=1
	if not paused:
		elapsed+=delta
		for i in planets.size():
			planets[i].get_child(0).rotation.y+=delta*(0.035+float(i)*0.014)
		if ship_travel:
			travel_progress=minf(travel_progress+delta/7.0,1.0)
			ship.position=travel_start.lerp(travel_end,smoothstep(0,1,travel_progress))+Vector3(0,sin(travel_progress*PI)*1.7,0)
			if travel_progress>=1:
				ship_travel=false
				travel_button.disabled=false
				status_label.text="远征一号  /  已抵达目标轨道"
		else:
			ship.position.y=sin(elapsed*0.7)*0.10
	if orbit_mode: yaw+=delta*0.06
	_update_camera(delta)
	telemetry_label.text="GODOT  /  实时 3D    ·    VULKAN"
	corona.look_at(camera.global_position,Vector3.UP)
	overlay.queue_redraw()
	if capture_mode and frames==90:
		_capture_and_quit()
	if verify_mode:
		_verify_interactions()

func _capture_and_quit() -> void:
	await RenderingServer.frame_post_draw
	var result:=get_viewport().get_texture().get_image().save_png("res://artifacts/starfield-preview.png")
	print("CAPTURE_RESULT ",result)
	get_tree().quit(0 if result==OK else 1)

func _verify_interactions() -> void:
	if frames==30:
		planet_buttons[1].pressed.emit()
		assert(selected==1 and name_label.text=="澜星")
		var scroll:=InputEventMouseButton.new()
		scroll.button_index=MOUSE_BUTTON_WHEEL_UP
		scroll.pressed=true
		_unhandled_input(scroll)
		assert(target_distance<33)
		pause_button.pressed.emit()
		assert(paused)
		pause_button.pressed.emit()
		orbit_button.pressed.emit()
		assert(orbit_mode)
		_reset_view()
		travel_button.pressed.emit()
		assert(ship_travel and travel_button.disabled)
		print("INTERACTION_CHECKS_OK selection zoom pause orbit travel")
	if frames==60:
		assert(ship.position.distance_to(travel_start)>0.0)
		travel_progress=1.0
	if frames==65:
		assert(not ship_travel and not travel_button.disabled)
		assert(status_label.text.contains("已抵达"))
		var mouse_move:=InputEventMouseMotion.new()
		mouse_move.button_mask=MOUSE_BUTTON_MASK_LEFT
		mouse_move.relative=Vector2(25,12)
		_unhandled_input(mouse_move)
		assert(yaw!=0.08)
		print("INTERACTION_CHECKS_OK arrival camera-drag")
		_select_body(1)
		_focus_selected()
		focus=target_focus
		distance=target_distance
	if frames==100:
		await RenderingServer.frame_post_draw
		var closeup_result:=get_viewport().get_texture().get_image().save_png("res://artifacts/planet-closeup.png")
		assert(closeup_result==OK)
		print("CLOSEUP_CAPTURE_OK")
		ship.position=start_ship_position
		_select_body(0)
		_reset_view()
		focus=target_focus
		distance=target_distance
	if frames==140:
		_capture_and_quit()
