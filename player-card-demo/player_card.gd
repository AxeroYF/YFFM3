extends Node3D

const FaceSurface=preload("res://card_surface.gd")
const ACCENTS=[Color("e9c181"),Color("73d8f5"),Color("d3d7f5")]
var record: Dictionary
var theme_id:=0
var font: Font
var bold: Font
var target_tilt:=Vector2.ZERO
var tilt:=Vector2.ZERO
var home:=Vector3.ZERO
var hovered:=false
var hover_weight:=0.0
var clock:=0.0
var bg_mat: ShaderMaterial
var foil_mat: ShaderMaterial
var faces: Array[SubViewport]=[]
var screen_rect:=Rect2()
var selected:=false
var manual_tilt:=Vector2.ZERO
var orbit: Node3D
var satellite: Node3D
var beam_mat: ShaderMaterial

func _ready() -> void:
	_create_slab()
	_create_orbital_hardware()
	var background:=_new_face()
	var rect:=ColorRect.new()
	rect.size=Vector2(720,1080)
	bg_mat=ShaderMaterial.new()
	bg_mat.shader=load("res://shaders/card_background.gdshader")
	bg_mat.set_shader_parameter("theme_id",theme_id)
	rect.material=bg_mat
	background.add_child(rect)
	_surface(background,0)
	_plane(background,0.06)
	var portrait:=_new_face()
	var picture:=Sprite2D.new()
	picture.texture=load(record.portrait)
	picture.centered=false
	var widths:=[1260.0,700.0,920.0]
	var positions:=[Vector2(-260,72),Vector2(15,76),Vector2(-81,80)]
	var image_size:=picture.texture.get_size()
	picture.scale=Vector2.ONE*widths[theme_id]/image_size.x
	picture.position=positions[theme_id]
	var portrait_mat:=ShaderMaterial.new()
	portrait_mat.shader=load("res://shaders/portrait.gdshader")
	portrait_mat.set_shader_parameter("tint",[Color(1.0,0.99,0.95),Color(0.91,0.98,1.0),Color(0.99,0.99,1.0)][theme_id])
	picture.material=portrait_mat
	portrait.add_child(picture)
	_plane(portrait,0.58)
	var info:=_new_face()
	_surface(info,1)
	_plane(info,0.88)
	var foil:=_new_face()
	var glint:=ColorRect.new()
	glint.size=Vector2(720,1080)
	foil_mat=ShaderMaterial.new()
	foil_mat.shader=load("res://shaders/foil.gdshader")
	foil_mat.set_shader_parameter("theme_id",theme_id)
	glint.material=foil_mat
	foil.add_child(glint)
	_plane(foil,0.90)

func _new_face() -> SubViewport:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(720,1080)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input=true
	add_child(viewport)
	faces.append(viewport)
	return viewport

func _surface(viewport: SubViewport, layer_kind: int) -> void:
	var surface:=FaceSurface.new()
	surface.theme_id=theme_id
	surface.layer_kind=layer_kind
	surface.record=record
	surface.accent=ACCENTS[theme_id]
	surface.font=font
	surface.bold=bold
	surface.size=Vector2(720,1080)
	viewport.add_child(surface)

func _plane(viewport: SubViewport, depth: float) -> void:
	var plane:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(4.6,6.9)
	plane.mesh=quad
	plane.position.z=depth
	plane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture=viewport.get_texture()
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.render_priority=0
	plane.material_override=mat
	add_child(plane)

func _create_slab() -> void:
	var body:=MeshInstance3D.new()
	var box:=BoxMesh.new()
	box.size=Vector3(4.67,6.96,0.42)
	body.position.z=-0.21
	body.mesh=box
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=ACCENTS[theme_id].darkened(0.60)
	mat.metallic=0.85
	mat.roughness=0.24
	body.material_override=mat
	add_child(body)
	var dark:=StandardMaterial3D.new()
	dark.albedo_color=Color("1f2c3b")
	dark.metallic=0.8
	dark.roughness=0.3
	var glow:=_glow_material(ACCENTS[theme_id],2.0)
	for side in [-1.0,1.0]:
		_hardware_box(Vector3(side*2.35,0,0.14),Vector3(0.14,6.75,0.34),dark)
		for y in [-2.25,0.0,2.25]:
			_hardware_box(Vector3(side*2.435,y,0.13),Vector3(0.045,1.4,0.12),glow)
		for y in [-3.40,3.40]:
			_hardware_box(Vector3(side*2.14,y,0.18),Vector3(0.54,0.16,0.40),mat)
			_hardware_box(Vector3(side*2.16,y,0.39),Vector3(0.25,0.035,0.03),glow)
	for y in [-3.49,3.49]:
		_hardware_box(Vector3(0,y,-0.1),Vector3(3.9,0.10,0.39),mat)
	# Detached front brackets visibly span the depth of the holographic layers.
	for x in [-2.23,2.23]:
		for y in [-3.20,3.20]:
			_hardware_box(Vector3(x,y,0.50),Vector3(0.12,0.30,0.92),dark)
			_hardware_box(Vector3(x,y,0.97),Vector3(0.11,0.23,0.025),glow)

func _hardware_box(point: Vector3, dimensions: Vector3, material: Material) -> void:
	var part:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=dimensions
	part.mesh=mesh
	part.position=point
	part.material_override=material
	add_child(part)

func _glow_material(color: Color,energy: float=1.0) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=color
	material.emission_enabled=true
	material.emission=color
	material.emission_energy_multiplier=energy
	return material

func _torus(parent: Node3D,radius: float,thickness: float,material: Material) -> MeshInstance3D:
	var mesh:=TorusMesh.new()
	mesh.inner_radius=radius-thickness
	mesh.outer_radius=radius+thickness
	mesh.rings=96
	mesh.ring_segments=8
	var node:=MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=material
	parent.add_child(node)
	return node

func _create_orbital_hardware() -> void:
	var glow:=_glow_material(ACCENTS[theme_id],1.3)
	orbit=Node3D.new()
	orbit.position=Vector3(0,0,-0.85)
	orbit.rotation=Vector3(PI/2,0,0.4)
	add_child(orbit)
	var ring:=_torus(orbit,3.75,0.012,glow)
	ring.scale=Vector3(0.82,1,1.04)
	var second:=_torus(orbit,3.87,0.006,_glow_material(ACCENTS[theme_id].darkened(0.45)))
	second.scale=ring.scale
	for i in 12:
		var marker:=MeshInstance3D.new()
		var marker_mesh:=BoxMesh.new()
		marker_mesh.size=Vector3(0.065,0.04,0.16)
		marker.mesh=marker_mesh
		var a:=TAU*float(i)/12.0
		marker.position=Vector3(cos(a)*3.75*0.82,0,sin(a)*3.75*1.04)
		marker.rotation.y=-a
		marker.material_override=glow
		orbit.add_child(marker)
	satellite=Node3D.new()
	satellite.position=Vector3(2.6,2.35,0.6)
	add_child(satellite)
	var globe:=MeshInstance3D.new()
	var sphere:=SphereMesh.new()
	sphere.radius=0.30
	sphere.height=0.60
	globe.mesh=sphere
	var planet_mat:=ShaderMaterial.new()
	planet_mat.shader=load("res://shaders/world_planet.gdshader")
	planet_mat.set_shader_parameter("kind",0 if theme_id==0 else 2)
	planet_mat.set_shader_parameter("base_color",ACCENTS[theme_id].darkened(0.6))
	planet_mat.set_shader_parameter("secondary_color",ACCENTS[theme_id])
	globe.material_override=planet_mat
	satellite.add_child(globe)
	var satellite_ring:=_torus(satellite,0.52,0.009,glow)
	satellite_ring.rotation_degrees=Vector3(20,0,-24)
	var rng:=RandomNumberGenerator.new()
	rng.seed=791+theme_id
	var particles:=MultiMeshInstance3D.new()
	var multimesh:=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	var spark:=SphereMesh.new()
	spark.radius=0.018
	spark.height=0.036
	spark.radial_segments=6
	spark.rings=4
	multimesh.mesh=spark
	multimesh.instance_count=65
	for i in 65:
		var p:=Vector3(rng.randf_range(-3.1,3.1),rng.randf_range(-3.8,3.8),rng.randf_range(-1.1,1.1))
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,p))
	particles.multimesh=multimesh
	particles.material_override=glow
	add_child(particles)

func animate(delta: float, effects: bool, presentation: bool, time: float) -> void:
	if effects: clock+=delta
	var resting:=Vector2([-0.24,0.15,0.26][theme_id],-0.075)
	var wished:=resting+manual_tilt+(target_tilt if hovered else Vector2.ZERO)
	if presentation and not hovered: wished+=Vector2(sin(time*0.55+theme_id)*0.17,cos(time*0.38+theme_id)*0.06)
	tilt=tilt.lerp(wished,1.0-exp(-delta*8.0))
	hover_weight=lerpf(hover_weight,1.0 if hovered else 0.0,1.0-exp(-delta*8))
	rotation=Vector3(-tilt.y,tilt.x,0)
	position=home+Vector3(0,sin(clock*0.6+theme_id)*0.055+hover_weight*0.10,hover_weight*0.20)
	orbit.rotation.z=0.4+sin(clock*0.17+theme_id)*0.13
	satellite.rotation.y=clock*0.16
	bg_mat.set_shader_parameter("clock",clock)
	bg_mat.set_shader_parameter("pointer",tilt*3.0)
	foil_mat.set_shader_parameter("clock",clock)
	foil_mat.set_shader_parameter("pointer",tilt*3.0)
	foil_mat.set_shader_parameter("hover",hover_weight if effects else 0.0)
	visible=true
