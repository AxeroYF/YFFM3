extends Node3D
const Palette=preload("res://ui_palette.gd")
## Owns stadium nodes and actor lifetime; has no menu or network dependencies.
const Team=preload("res://team_config.gd")
const Pitch=preload("res://pitch_geometry.gd")
const Match=preload("res://match_sim.gd")
const Conditions=preload("res://match_environment.gd")
const CYAN=Palette.CYAN
const GOLD=Palette.GOLD
const FootballActor=preload("res://skinned_player.gd")
var environment_visual:Node3D
var sky_material:ShaderMaterial
var pitch_material:ShaderMaterial
var camera: Camera3D
var arena: Node3D
var planet: MeshInstance3D
var planet_material: ShaderMaterial
var orbit: Node3D
var actors: Array[Node3D] = []
var rigs:Array[Node3D]=[]
var indicator: MeshInstance3D
var football: Node3D
var ball_shadow: MeshInstance3D
var trail: Array[MeshInstance3D] = []
var trail_points: Array[Vector3] = []
var selected_labels: Array[Label3D] = []
var aim_marker: MeshInstance3D
var pass_arrow:MeshInstance3D
var goal_nets:Array=[]
var arena_walls:Array[MeshInstance3D]=[]
func material(color: Color, glow: float=0.0, metal: float=0.0) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new()
 m.albedo_color=color
 m.metallic=metal
 m.roughness=0.4
 if glow>0:
  m.emission_enabled=true
  m.emission=color
  m.emission_energy_multiplier=glow
 return m

func box(parent: Node3D, pos: Vector3, size_value: Vector3, mat: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 var mesh:=BoxMesh.new()
 mesh.size=size_value
 node.mesh=mesh
 node.material_override=mat
 node.position=pos
 parent.add_child(node)
 return node

func sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 var mesh:=SphereMesh.new()
 mesh.radius=radius
 mesh.height=radius*2
 mesh.radial_segments=48
 mesh.rings=24
 node.mesh=mesh
 node.material_override=mat
 node.position=pos
 parent.add_child(node)
 return node

func beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 var mesh:=CylinderMesh.new()
 mesh.top_radius=radius
 mesh.bottom_radius=radius
 mesh.height=a.distance_to(b)
 mesh.radial_segments=8
 node.mesh=mesh
 node.material_override=mat
 node.position=(a+b)*0.5
 node.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
 parent.add_child(node)
 return node

func ring(parent: Node3D, pos: Vector3, radius: float, width: float, mat: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 var mesh:=TorusMesh.new()
 mesh.inner_radius=radius-width
 mesh.outer_radius=radius+width
 mesh.rings=80
 mesh.ring_segments=8
 node.mesh=mesh
 node.material_override=mat
 node.position=pos
 parent.add_child(node)
 return node

func build_world() -> void:
 var environment:=WorldEnvironment.new()
 var env:=Environment.new()
 env.background_mode=Environment.BG_SKY
 var sky:=Sky.new()
 sky_material=ShaderMaterial.new()
 sky_material.shader=load("res://shaders/space.gdshader")
 sky.sky_material=sky_material
 env.sky=sky
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color("96b9df")
 env.ambient_light_energy=0.8
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 env.glow_enabled=true
 env.glow_intensity=0.6
 environment.environment=env
 add_child(environment)
 var light:=DirectionalLight3D.new()
 light.light_cull_mask=1
 light.rotation_degrees=Vector3(-52,-30,0)
 light.light_energy=1.9
 light.shadow_enabled=true
 add_child(light)
 var fill:=DirectionalLight3D.new()
 fill.light_cull_mask=1
 fill.rotation_degrees=Vector3(-10,150,0)
 fill.light_color=Color("5bc5fa")
 fill.light_energy=0.8
 add_child(fill)
 camera=Camera3D.new()
 camera.far=1000
 camera.near=0.1
 add_child(camera)
 planet_material=ShaderMaterial.new()
 planet_material.shader=load("res://shaders/planet.gdshader")
 planet_material.set_shader_parameter("base_color",Color("094b8a"))
 planet_material.set_shader_parameter("secondary_color",Color("39b1a4"))
 planet_material.set_shader_parameter("kind",1)
 planet=sphere(self,Vector3(28,6,-93),36,planet_material)
 var atmosphere:=ShaderMaterial.new()
 atmosphere.shader=load("res://shaders/atmosphere.gdshader")
 atmosphere.set_shader_parameter("tint",Color("49bdec"))
 sphere(planet,Vector3.ZERO,36.6,atmosphere)
 orbit=Node3D.new()
 orbit.position=planet.position
 orbit.rotation_degrees=Vector3(15,0,-20)
 add_child(orbit)
 ring(orbit,Vector3.ZERO,49,0.07,material(Color("728cbd"),0.4))
 ring(orbit,Vector3.ZERO,52,0.22,material(Color("cbb48e"),0.3,0.7))
 var rng:=RandomNumberGenerator.new()
 rng.seed=44
 var stars:=MultiMeshInstance3D.new()
 var multimesh:=MultiMesh.new()
 multimesh.transform_format=MultiMesh.TRANSFORM_3D
 var star_mesh:=SphereMesh.new()
 star_mesh.radius=0.13
 star_mesh.height=0.26
 star_mesh.radial_segments=6
 star_mesh.rings=4
 star_mesh.material=material(Color("b0d4ff"),3)
 multimesh.mesh=star_mesh
 multimesh.instance_count=650
 for i in 650:
  var pos:=Vector3(rng.randf_range(-220,220),rng.randf_range(-60,160),rng.randf_range(-240,-100))
  multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(0.4,2)),pos))
 stars.multimesh=multimesh
 add_child(stars)
 environment_visual=preload("res://environment_visual.gd").new()
 add_child(environment_visual);environment_visual.build()
 arena=Node3D.new()
 add_child(arena)
 var steel:=material(Color("14263d"),0,0.8)
 var dark:=material(Color("0b1323"),0,0.8)
 var glow:=material(CYAN,1.9)
 var orange:=material(Color("ff8267"),1.4)
 box(arena,Vector3(0,-1.6,0),Vector3(Pitch.HALF_LENGTH*2+8,2.6,Pitch.HALF_WIDTH*2+7),steel)
 box(arena,Vector3(0,-3.1,0),Vector3(Pitch.HALF_LENGTH*2-2,1,Pitch.HALF_WIDTH*2-1),dark)
 box(arena,Vector3(0,-0.12,0),Vector3(Pitch.HALF_LENGTH*2,0.2,Pitch.HALF_WIDTH*2),load_pitch())
 for z in [-Pitch.HALF_WIDTH-3,Pitch.HALF_WIDTH+3]:
  box(arena,Vector3(0,-0.6,z),Vector3(Pitch.HALF_LENGTH*2+7,0.17,0.15),glow)
  for x in range(-32,33,8):
   box(arena,Vector3(x,0.25,z),Vector3(5.2,0.6,1.4),steel)
   box(arena,Vector3(x,0.62,z),Vector3(4.2,0.1,0.65),glow if x<0 else orange)
 for x in [-Pitch.HALF_LENGTH-3,Pitch.HALF_LENGTH+3]:
  box(arena,Vector3(x,-0.4,0),Vector3(0.16,0.2,Pitch.HALF_WIDTH*2+4),glow if x<0 else orange)
  for z in [-Pitch.HALF_WIDTH,Pitch.HALF_WIDTH]:
   box(arena,Vector3(x,-3.7,z),Vector3(3.4,4,3.4),steel)
   sphere(arena,Vector3(x,-5.9,z),1.1,material(Color("64d9ff"),3))
 var white:=material(Color("8cbac7"),0.45)
 for z in [-Pitch.HALF_WIDTH,Pitch.HALF_WIDTH]: beam(arena,Vector3(-Pitch.HALF_LENGTH,0.03,z),Vector3(Pitch.HALF_LENGTH,0.03,z),0.07,white)
 for x in [-Pitch.HALF_LENGTH,0,Pitch.HALF_LENGTH]: beam(arena,Vector3(x,0.03,-Pitch.HALF_WIDTH),Vector3(x,0.03,Pitch.HALF_WIDTH),0.07,white)
 ring(arena,Vector3(0,0.05,0),5,0.07,white)
 sphere(arena,Vector3(0,0.04,0),0.17,white)
 for side in [-1,1]:
  var goal_mat: Material=glow if side==-1 else orange
  box(arena,Vector3((Pitch.HALF_LENGTH+Pitch.GOAL_DEPTH*0.5)*side,-0.12,0),Vector3(Pitch.GOAL_DEPTH,0.2,Pitch.GOAL_HALF_WIDTH*2),material(Color("1c3547"),0.05))
  for z in [-Pitch.PENALTY_HALF_WIDTH,Pitch.PENALTY_HALF_WIDTH]: beam(arena,Vector3((Pitch.HALF_LENGTH-Pitch.PENALTY_DEPTH)*side,0.04,z),Vector3(Pitch.HALF_LENGTH*side,0.04,z),0.07,white)
  beam(arena,Vector3((Pitch.HALF_LENGTH-Pitch.PENALTY_DEPTH)*side,0.04,-Pitch.PENALTY_HALF_WIDTH),Vector3((Pitch.HALF_LENGTH-Pitch.PENALTY_DEPTH)*side,0.04,Pitch.PENALTY_HALF_WIDTH),0.07,white)
  for z in [-Pitch.GOAL_AREA_HALF_WIDTH,Pitch.GOAL_AREA_HALF_WIDTH]: beam(arena,Vector3((Pitch.HALF_LENGTH-Pitch.GOAL_AREA_DEPTH)*side,0.04,z),Vector3(Pitch.HALF_LENGTH*side,0.04,z),0.055,white)
  beam(arena,Vector3((Pitch.HALF_LENGTH-Pitch.GOAL_AREA_DEPTH)*side,0.04,-Pitch.GOAL_AREA_HALF_WIDTH),Vector3((Pitch.HALF_LENGTH-Pitch.GOAL_AREA_DEPTH)*side,0.04,Pitch.GOAL_AREA_HALF_WIDTH),0.055,white)
  for z in [-5,5]:
   beam(arena,Vector3(Pitch.HALF_LENGTH*side,0,z),Vector3(Pitch.HALF_LENGTH*side,3.6,z),0.12,goal_mat)
   beam(arena,Vector3(Pitch.HALF_LENGTH*side,3.6,z),Vector3((Pitch.HALF_LENGTH+3)*side,3.0,z),0.10,goal_mat)
  beam(arena,Vector3(Pitch.HALF_LENGTH*side,3.6,-5),Vector3(Pitch.HALF_LENGTH*side,3.6,5),0.12,goal_mat)
  var net:=preload("res://goal_net_visual.gd").new();arena.add_child(net);net.build(side);goal_nets.append(net)
  for z in [-Pitch.HALF_WIDTH,Pitch.HALF_WIDTH]:
   beam(arena,Vector3(Pitch.HALF_LENGTH*side,0,z),Vector3(Pitch.HALF_LENGTH*side,5.2,z),0.15,steel)
   sphere(arena,Vector3(Pitch.HALF_LENGTH*side,5.2,z),0.3,material(Color("e1edff"),4))
 var glass:=material(Color(0.15,0.55,0.7,0.09))
 glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 glass.cull_mode=BaseMaterial3D.CULL_DISABLED
 for z in [-Pitch.HALF_WIDTH-0.3,Pitch.HALF_WIDTH+0.3]: arena_walls.append(box(arena,Vector3(0,0.85,z),Vector3(Pitch.HALF_LENGTH*2,1.5,0.06),glass))
 for x in [-Pitch.HALF_LENGTH-0.3,Pitch.HALF_LENGTH+0.3]:
  for side in [-1,1]:
   arena_walls.append(box(arena,Vector3(x,0.85,side*(Pitch.HALF_WIDTH+5)*0.5),Vector3(0.06,1.5,Pitch.HALF_WIDTH-5),glass))
 # Match footballers are built when entering a fixture, not hidden behind the main menu.
 indicator=MeshInstance3D.new()
 var selection_mesh:=ImmediateMesh.new()
 for layer_index in 2:
  var selection_material:=material(Color("101c29") if layer_index==0 else GOLD)
  selection_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  selection_material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
  selection_material.no_depth_test=true
  selection_material.cull_mode=BaseMaterial3D.CULL_DISABLED
  selection_material.render_priority=10+layer_index
  selection_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,selection_material)
  var corners:Array=[Vector3(-0.65,0.45,0),Vector3(0.65,0.45,0),Vector3(0,-0.55,0)] if layer_index==0 else [Vector3(-0.50,0.36,0.01),Vector3(0.50,0.36,0.01),Vector3(0,-0.40,0.01)]
  for corner in corners: selection_mesh.surface_add_vertex(corner)
  selection_mesh.surface_end()
 indicator.mesh=selection_mesh
 indicator.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 arena.add_child(indicator)
 football=Node3D.new()
 arena.add_child(football)
 sphere(football,Vector3.ZERO,Match.BallPhysics.RADIUS,material(Color("f5faff"),0.1,0.15))
 var football_ring:=ring(football,Vector3.ZERO,Match.BallPhysics.RADIUS,0.018,material(Color("132138")))
 football_ring.rotation_degrees.x=90
 var football_ring2:=ring(football,Vector3.ZERO,Match.BallPhysics.RADIUS,0.018,material(Color("132138")))
 football_ring2.rotation_degrees.z=90
 ball_shadow=ring(arena,Vector3(0,0.06,0),0.34,0.025,material(Color("fbde91"),0.2))
 aim_marker=ring(arena,Vector3(Pitch.HALF_LENGTH,0.08,0),0.9,0.08,material(GOLD,2))
 aim_marker.visible=false
 pass_arrow=MeshInstance3D.new()
 var arrow_mesh:=ImmediateMesh.new()
 var arrow_material:=material(CYAN,0.3)
 arrow_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 arrow_material.cull_mode=BaseMaterial3D.CULL_DISABLED
 arrow_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,arrow_material)
 for vertex in [Vector3(0.65,0,0.10),Vector3(1.45,0,0.10),Vector3(0.65,0,-0.10),Vector3(0.65,0,-0.10),Vector3(1.45,0,0.10),Vector3(1.45,0,-0.10),Vector3(1.25,0,0.30),Vector3(1.95,0,0),Vector3(1.25,0,-0.30)]: arrow_mesh.surface_add_vertex(vertex)
 arrow_mesh.surface_end()
 pass_arrow.mesh=arrow_mesh
 pass_arrow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 arena.add_child(pass_arrow)
 pass_arrow.visible=false
 for i in 10:
  trail.append(sphere(arena,Vector3.ZERO,0.14*(1-float(i)/12),material(Color("f3cd8a"),1.4)))

func load_pitch() -> ShaderMaterial:
 var mat:=ShaderMaterial.new()
 mat.shader=load("res://shaders/pitch.gdshader")
 pitch_material=mat
 return mat

func apply_environment_visual(value:Dictionary)->void:
 var config:=Conditions.normalize(value)
 planet.visible=Conditions.stadium(config).show_planet
 orbit.visible=planet.visible
 sky_material.set_shader_parameter("galaxy",Conditions.stadium(config).galaxy_blend)
 pitch_material.set_shader_parameter("wetness",Conditions.weather(config).wetness)
 environment_visual.configure(config)

func camera_hub() -> void:
 apply_environment_visual({})
 camera.environment=null
 camera.cull_mask=1
 planet.position=Vector3(28,6,-93)
 orbit.position=planet.position
 planet_material.set_shader_parameter("base_color",Color("094b8a"))
 planet_material.set_shader_parameter("secondary_color",Color("39b1a4"))
 planet_material.set_shader_parameter("kind",1)
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 camera.fov=48
 camera.position=Vector3(69,46,85)
 camera.look_at(Vector3(-13,0,0))
 for actor in actors: actor.visible=false
 football.visible=false
 indicator.visible=false
 ball_shadow.visible=false
 aim_marker.visible=false
 for t in trail: t.visible=false

func create_actor(index: int,player:Dictionary,label_font:Font) -> void:
 var actor:=Node3D.new()
 arena.add_child(actor)
 actors.append(actor)
 var color:=CYAN if index<Match.TEAM_SIZE else Color("ff866c")
 if index%Team.SIZE==0: color=GOLD if index<Team.SIZE else Color("b79bff")
 var rig:=FootballActor.new()
 actor.add_child(rig)
 var profile:Dictionary=player.body
 rig.build(color,Match.JERSEY_NUMBERS[index],index%Team.SIZE==0,profile)
 rig.set_meta("player_id",player.player_id)
 rigs.append(rig)
 var label:=Label3D.new()
 label.font=label_font
 label.font_size=44
 label.pixel_size=0.012
 label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 label.no_depth_test=true
 label.position.y=profile.height+0.35
 label.modulate=color
 label.outline_size=10
 label.text=Match.JERSEY_NUMBERS[index]
 actor.add_child(label)
 selected_labels.append(label)
func clear_actors()->void:
 for actor in actors:
  arena.remove_child(actor)
  actor.queue_free()
 actors.clear()
 rigs.clear()
 selected_labels.clear()

func prepare_match(sim,stage:int)->void:
 trail_points.clear()
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 camera.fov=44
 camera.position=Pitch.CAMERA
 camera.look_at(Vector3(0,0,-1))
 planet.position=Vector3(40,-18,-76)
 orbit.position=planet.position
 planet_material.set_shader_parameter("kind",[1,2,0][stage])
 planet_material.set_shader_parameter("base_color",[Color("094b8a"),Color("762e23"),Color("392466")][stage])
 planet_material.set_shader_parameter("secondary_color",[Color("39b1a4"),Color("e9863d"),Color("d7a98e")][stage])
 apply_environment_visual(sim.environment)
 for actor in actors: actor.visible=true
 for wall in arena_walls: wall.visible=sim.arcade or sim.ice_mode
 football.visible=true
 indicator.visible=true
 ball_shadow.visible=true
 for segment in trail: segment.visible=true

func sync_actor(p:Dictionary,index:int)->void:
 if rigs[index].get_meta("player_id",p.player_id)==p.player_id:
  rigs[index].set_meta("player_id",p.player_id);return
 var old=rigs[index];actors[index].remove_child(old);old.queue_free()
 var rig=FootballActor.new();actors[index].add_child(rig)
 var color:Color=CYAN if index<Team.SIZE else Color("ff866c")
 if index%Team.SIZE==0: color=GOLD if index<Team.SIZE else Color("b79bff")
 rig.build(color,Match.JERSEY_NUMBERS[index],index%Team.SIZE==0,p.body)
 rig.set_meta("player_id",p.player_id);rigs[index]=rig

## Camera follow belongs to the world view; replay owns the camera while active.
func follow_ball(s,replaying:bool,enabled:bool,dt:float)->void:
 if not enabled or replaying: return
 var look:=Vector3(clampf(s.ball.x*0.055,-1.6,1.6),0,-1+s.ball.y*0.025)
 camera.position=camera.position.lerp(Pitch.CAMERA,minf(1,dt*3))
 camera.look_at(look)
