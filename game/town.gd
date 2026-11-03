extends Node3D

const ASSETS := "res://assets/quaternius/"
var library: Dictionary = {}
var colour_checks: Dictionary={}
var colour_materials: Dictionary={}
var player: CharacterBody3D
var overview: Camera3D
var music: AudioStreamPlayer
var walking := false
var orbit := 0.72
var distance := 230.0
var dragging := false
var status: Label
var music_button: Button
var view_button: Button
var view_selector: OptionButton
var view_mode := 0
var life: Node
var windmill_sails: Node3D
var day_night: Node
var expansion: Node3D
var jobs: Node3D
var speech: Node
var character_directory: Node
var chateaux: Node3D
var families: Node
var adventures: Node
var builder: Node
var events: Node
var weather: Node3D
var discoveries: Node3D
var player_home: Node
var home_district: Node3D
var industrial_workforce: Node3D
var character_life: Node
var cooking: Node3D
var economy: Node
var routines: Node
var atmosphere: Node3D
var menu_body: VBoxContainer
var menu_panel: PanelContainer
var menu_toggle: Button
var menu_collapsed := false
var menu_scroll: ScrollContainer
var locations: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	if DisplayServer.get_name()!="headless":Engine.max_fps=45
	get_window().title="Alderwick — 53 Residents · Jobs & Voices"
	rng.seed = 41729
	print("TOWN_BUILD_WORLD")
	world()
	print("TOWN_BUILD_CENTRE")
	town()
	print("TOWN_BUILD_DISTRICTS")
	expansion=Node3D.new()
	expansion.set_script(load("res://native_districts.gd"))
	add_child(expansion)
	chateaux=load("res://chateau_districts.gd").new()
	add_child(chateaux)
	var neighbouring_town: Node3D=load("res://neighbouring_town.gd").new()
	add_child(neighbouring_town)
	var woodlands: Node3D=load("res://forest_districts.gd").new()
	add_child(woodlands)
	jobs=Node3D.new()
	jobs.set_script(load("res://town_jobs.gd"))
	add_child(jobs)
	atmosphere=Node3D.new()
	atmosphere.set_script(load("res://town_atmosphere.gd"))
	add_child(atmosphere)
	player = CharacterBody3D.new()
	player.set_script(load("res://player.gd"))
	player.position = Vector3(0, 1, 23)
	add_child(player)
	overview = Camera3D.new()
	overview.far = 800
	overview.fov = 48
	add_child(overview)
	overview.current = true
	music = AudioStreamPlayer.new()
	var stream := load("res://audio/village.mp3") as AudioStreamMP3
	stream.loop = true
	music.stream = stream
	music.volume_db = -80.0
	add_child(music)
	interface()
	economy=Node.new()
	economy.set_script(load("res://town_economy.gd"))
	add_child(economy)
	update_camera()
	set_view(1)
	life=Node.new()
	life.set_script(load("res://village_life.gd"))
	add_child(life)
	day_night=Node.new()
	day_night.set_script(load("res://day_night.gd"))
	add_child(day_night)
	routines=Node.new()
	routines.set_script(load("res://town_routines.gd"))
	add_child(routines)
	speech=Node.new()
	speech.set_script(load("res://town_speech.gd"))
	add_child(speech)
	character_directory=load("res://player_appearance_menu.gd").new()
	add_child(character_directory)
	families=load("res://town_families.gd").new()
	add_child(families)
	adventures=load("res://town_adventures.gd").new()
	add_child(adventures)
	var wildlife: Node=load("res://farm_wildlife.gd").new()
	add_child(wildlife)
	builder=load("res://town_builder.gd").new()
	add_child(builder)
	var places: Node=load("res://town_places.gd").new()
	add_child(places)
	events=load("res://town_events.gd").new()
	add_child(events)
	weather=load("res://town_weather.gd").new()
	add_child(weather)
	discoveries=load("res://town_discoveries.gd").new()
	add_child(discoveries)
	player_home=load("res://player_home.gd").new()
	add_child(player_home)
	home_district=load("res://player_home_district.gd").new()
	add_child(home_district)
	cooking=load("res://town_cooking.gd").new()
	add_child(cooking)
	character_life=load("res://character_life.gd").new()
	add_child(character_life)
	industrial_workforce=load("res://industrial_workforce.gd").new()
	add_child(industrial_workforce)
	var performance: Node=load("res://town_performance.gd").new()
	add_child(performance)
	var cycle_check := CheckBox.new()
	cycle_check.text="Day/night cycle"
	cycle_check.toggled.connect(day_night.set_enabled)
	view_selector.get_parent().add_child(cycle_check)
	day_night.toggle=cycle_check
	var cycle_speed := OptionButton.new()
	cycle_speed.add_item("Preview · 1-minute cycle")
	cycle_speed.add_item("Relaxed · 4-minute cycle")
	cycle_speed.add_item("Slow · 20-minute cycle")
	cycle_speed.add_item("Very slow · 40-minute cycle")
	cycle_speed.item_selected.connect(func(index: int):day_night.cycle_seconds=[60.0,240.0,1200.0,2400.0][index])
	view_selector.get_parent().add_child(cycle_speed)
	var clock_text := Label.new()
	view_selector.get_parent().add_child(clock_text)
	day_night.clock_label=clock_text
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture"):get_viewport().gui_disable_input=true
	if "--capture" in OS.get_cmdline_user_args(): capture.call_deferred()
	if "--capture-walk" in OS.get_cmdline_user_args(): capture_walk.call_deferred()
	if "--capture-third" in OS.get_cmdline_user_args(): capture_third.call_deferred()
	if "--capture-dialogue" in OS.get_cmdline_user_args(): capture_dialogue.call_deferred()
	if "--validate" in OS.get_cmdline_user_args(): validate.call_deferred()
	if "--validate-behavior" in OS.get_cmdline_user_args(): validate_behavior.call_deferred()
	if "--validate-entrances" in OS.get_cmdline_user_args(): validate_entrances.call_deferred()
	if "--validate-navigation" in OS.get_cmdline_user_args(): validate_navigation.call_deferred()
	if "--capture-interior" in OS.get_cmdline_user_args(): capture_interior.call_deferred()
	if "--capture-social" in OS.get_cmdline_user_args(): capture_social.call_deferred()
	if "--validate-occupants" in OS.get_cmdline_user_args(): validate_occupants.call_deferred()
	if "--capture-market" in OS.get_cmdline_user_args(): capture_market.call_deferred()
	if "--validate-cycle" in OS.get_cmdline_user_args(): validate_cycle.call_deferred()
	if "--validate-camera" in OS.get_cmdline_user_args(): validate_camera.call_deferred()
	if "--capture-night" in OS.get_cmdline_user_args(): capture_night.call_deferred()
	if "--validate-additions" in OS.get_cmdline_user_args(): validate_additions.call_deferred()
	if "--capture-animals" in OS.get_cmdline_user_args(): capture_animals.call_deferred()
	if "--capture-rest" in OS.get_cmdline_user_args(): capture_rest.call_deferred()
	if "--validate-player-motion" in OS.get_cmdline_user_args(): validate_player_motion.call_deferred()
	if "--validate-interactions" in OS.get_cmdline_user_args(): validate_interactions.call_deferred()
	if "--validate-expansion" in OS.get_cmdline_user_args(): validate_expansion.call_deferred()
	if "--capture-expansion" in OS.get_cmdline_user_args(): capture_expansion.call_deferred()
	if "--review-live" in OS.get_cmdline_user_args():
		get_viewport().gui_disable_input=true
		capture_expansion.call_deferred()
	if "--validate-native" in OS.get_cmdline_user_args() or "--review-native-live" in OS.get_cmdline_user_args():
		var review := Node.new()
		review.set_script(load("res://native_review.gd"))
		add_child(review)
	if "--validate-residents" in OS.get_cmdline_user_args() or "--review-residents-live" in OS.get_cmdline_user_args():
		var resident_review := Node.new()
		resident_review.set_script(load("res://resident_review.gd"))
		add_child(resident_review)
	if "--validate-activities" in OS.get_cmdline_user_args() or "--review-activities-live" in OS.get_cmdline_user_args():
		var activity_review := Node.new()
		activity_review.set_script(load("res://activity_review.gd"))
		add_child(activity_review)
	if "--show-work-update" in OS.get_cmdline_user_args():
		var work_preview := Node.new()
		work_preview.set_script(load("res://work_preview.gd"))
		add_child(work_preview)
	if "--validate-town-life" in OS.get_cmdline_user_args():
		var town_life_review := Node.new()
		town_life_review.set_script(load("res://town_life_review.gd"))
		add_child(town_life_review)
	if "--show-town-life" in OS.get_cmdline_user_args() or "--capture-town-life" in OS.get_cmdline_user_args():
		var town_life_preview := Node.new()
		town_life_preview.set_script(load("res://town_life_preview.gd"))
		add_child(town_life_preview)
	if "--review-character-chat" in OS.get_cmdline_user_args() or "--validate-character-chat" in OS.get_cmdline_user_args():
		var character_review := Node.new()
		character_review.set_script(load("res://character_chat_review.gd"))
		add_child(character_review)
	setup_animals.call_deferred()

func capture_expansion() -> void:
	while not life.navigation_ready:await get_tree().process_frame
	set_view(1)
	overview.position=Vector3(195,155,240)
	overview.look_at(Vector3(0,0,0))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../town-expanded-overview.png")
	overview.position=Vector3(150,40,-100)
	overview.look_at(Vector3(115,5,-30))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../town-castle-district.png")
	var room: Node3D=expansion.rooms[0]
	overview.position=room.to_global(Vector3(0,2.2,-5.8))
	overview.look_at(room.to_global(Vector3(0,1.2,2)))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../town-castle-interior.png")
	var stone_room: Node3D=expansion.rooms[-1]
	overview.position=stone_room.to_global(Vector3(0,2.2,-5.8))
	overview.look_at(stone_room.to_global(Vector3(0,1.2,2)))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../town-arnstein-interior.png")
	overview.position=Vector3(215,32,-135)
	overview.look_at(Vector3(182,5,-95))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../town-arnstein-castle.png")
	while get_tree().get_nodes_in_group("animals").size()<9:await get_tree().physics_frame
	var saved: Array[Dictionary]=[]
	for person in life.people:
		if person.person_name not in ["Eirik","Corvin","Kael","Astrid"]:continue
		saved.append({"node":person,"transform":person.global_transform,"visual":person.visual.transform})
		person.set_physics_process(false)
		person.position=Vector3((saved.size()-2.5)*1.9,0.05,23)
		person.visual.rotation.y=0
		person.animator.play("Idle")
	var dog: Node3D=null
	var dog_original := Vector3.ZERO
	for animal in get_tree().get_nodes_in_group("animals"):
		if animal.species=="Pug":dog=animal
	if dog:
		dog_original=dog.position
		dog.set_physics_process(false)
		dog.position=Vector3(0,0.05,25)
	overview.position=Vector3(0,2.3,30)
	overview.look_at(Vector3(0,0.9,23.7))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../town-new-characters-and-dog.png")
	for record in saved:
		record.node.global_transform=record.transform
		record.node.visual.transform=record.visual
		record.node.set_physics_process(true)
	if dog:
		dog.position=dog_original
		dog.set_physics_process(true)
	print("EXPANDED_MAP_CAPTURED")
	await validate_expansion()

func validate_expansion() -> void:
	while not life.navigation_ready or get_tree().get_nodes_in_group("animals").size()<9:await get_tree().physics_frame
	assert(expansion.rooms.size()==10)
	assert(expansion.portals.size()==20)
	assert(get_tree().get_nodes_in_group("paintings").size()==23)
	assert(get_tree().get_nodes_in_group("detailed_furniture").size()>200)
	player.enabled=false
	for pair in range(expansion.rooms.size()):
		var entrance: Dictionary=expansion.portals[pair*2]
		var exit: Dictionary=expansion.portals[pair*2+1]
		expansion.travel_cooldown=0
		if not entrance.door.is_open:entrance.door.toggle(entrance.position-Vector3(0,0,2))
		player.global_position=entrance.position
		await get_tree().physics_frame
		await get_tree().physics_frame
		assert(player.global_position.distance_to(entrance.to)<0.2,"Interior entry failed: "+entrance.label)
		expansion.travel_cooldown=0
		if not exit.door.is_open:exit.door.toggle(exit.position+Vector3(0,0,2))
		player.global_position=exit.position
		await get_tree().physics_frame
		await get_tree().physics_frame
		assert(player.global_position.distance_to(exit.to)<0.2,"Interior exit failed: "+entrance.label)
		var room: Node3D=expansion.rooms[pair]
		var seat: Node3D=null
		var bed: Node3D=null
		for item in room.get_children():
			if item.is_in_group("seats") and seat==null:seat=item
			if item.is_in_group("beds") and bed==null:bed=item
		assert(seat!=null and bed!=null)
		player.global_position=seat.global_position+Vector3(0,-seat.position.y,-0.9)
		life.heartbeat=1
		life._process(0.2)
		assert(life.nearest_furniture==seat,"Chair prompt must be visible: "+entrance.label)
		assert(player.use_furniture(seat,"sitting"))
		player.stand_from_furniture(true)
		assert(player.use_furniture(bed,"sleeping"))
		player.stand_from_furniture(true)
		print("EXPANSION_ENTRY_FURNITURE_OK ",entrance.label)
	var dog: Node3D=null
	for animal in get_tree().get_nodes_in_group("animals"):
		if animal.species=="Pug":dog=animal
	assert(dog!=null and is_equal_approx(dog.desired_height,0.30))
	print("EXPANSION_VALIDATION_OK rooms=10 portals=20 paintings=23 furniture=",get_tree().get_nodes_in_group("detailed_furniture").size()," dog_height=0.30 residents=",life.people.size())
	await validate_interactions()

func material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material(color)
	parent.add_child(instance)
	instance.position = pos
	if solid: instance.create_trimesh_collision()
	return instance

func model(parent: Node3D, asset: String, pos: Vector3, angle: float = 0.0, solid := false) -> Node3D:
	if not library.has(asset): library[asset] = load(ASSETS + asset + ".gltf")
	var instance: Node3D = library[asset].instantiate()
	parent.add_child(instance)
	restore_vertex_colours(instance)
	instance.position = pos
	instance.rotation.y = angle
	if solid: collisions(instance)
	return instance

func restore_vertex_colours(node: Node3D) -> void:
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		var key := mesh.mesh.get_instance_id()
		if not colour_checks.has(key):
			var surfaces: Array[int]=[]
			for surface in range(mesh.mesh.get_surface_count()):
				var colours=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				if colours!=null and not colours.is_empty():surfaces.append(surface)
			colour_checks[key]=surfaces
		for surface in colour_checks[key]:
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if not material or material.vertex_color_use_as_albedo:continue
			var material_key := material.get_instance_id()
			if not colour_materials.has(material_key):
				var tinted := material.duplicate() as StandardMaterial3D
				tinted.vertex_color_use_as_albedo=true
				colour_materials[material_key]=tinted
			mesh.set_surface_override_material(surface,colour_materials[material_key])

func collisions(node: Node) -> void:
	if node.is_in_group("doors"):return
	if node is MeshInstance3D and not node.visible:return
	if node is MeshInstance3D: node.create_trimesh_collision()
	for child in node.get_children():
		if not child is StaticBody3D: collisions(child)

func material_name(mat: Material) -> String:
	return "" if mat==null else mat.resource_name+" "+mat.resource_path

func append_triangles(output: ArrayMesh,arrays: Array,indices: Array[int],mat: Material) -> void:
	if indices.is_empty():return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for idx in indices:
		if arrays[Mesh.ARRAY_NORMAL]!=null and arrays[Mesh.ARRAY_NORMAL].size()>idx:tool.set_normal(arrays[Mesh.ARRAY_NORMAL][idx])
		if arrays[Mesh.ARRAY_TEX_UV]!=null and arrays[Mesh.ARRAY_TEX_UV].size()>idx:tool.set_uv(arrays[Mesh.ARRAY_TEX_UV][idx])
		if arrays[Mesh.ARRAY_COLOR]!=null and arrays[Mesh.ARRAY_COLOR].size()>idx:tool.set_color(arrays[Mesh.ARRAY_COLOR][idx])
		tool.add_vertex(arrays[Mesh.ARRAY_VERTEX][idx])
	tool.index()
	tool.set_material(mat)
	tool.commit(output)

func prepare_doors(structure: Node3D,title: String) -> void:
	for piece in structure.find_children("*Door_inst*","Node3D",true,false):
		var meshes := piece.find_children("*","MeshInstance3D",true,false)
		if meshes.is_empty():continue
		var mesh_node := meshes[0] as MeshInstance3D
		var source := mesh_node.mesh as ArrayMesh
		if source==null:continue
		var bounds := AABB()
		var has_bounds := false
		for surface in range(source.get_surface_count()):
			var mat := mesh_node.get_active_material(surface)
			if "Void" in material_name(mat) or ("Chapel" in piece.name and "Planks" in material_name(mat)):
				var vertices: PackedVector3Array = source.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				if vertices.is_empty():continue
				bounds=AABB(vertices[0],Vector3.ZERO)
				for point in vertices:bounds=bounds.expand(point)
				has_bounds=true
				break
		if not has_bounds:continue
		var wall_mesh := ArrayMesh.new()
		var leaf_mesh := ArrayMesh.new()
		for surface in range(source.get_surface_count()):
			var mat := mesh_node.get_active_material(surface)
			var mat_name := material_name(mat)
			if "Void" in mat_name:continue
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():indices=PackedInt32Array(range(vertices.size()))
			var walls: Array[int]=[]
			var leaves: Array[int]=[]
			for triangle in range(0,indices.size(),3):
				var centre := (vertices[indices[triangle]]+vertices[indices[triangle+1]]+vertices[indices[triangle+2]])/3.0
				var candidate := "Wood" in mat_name or "Planks" in mat_name or "Iron" in mat_name
				var in_opening := centre.x>bounds.position.x-0.07 and centre.x<bounds.end.x+0.07 and centre.y>bounds.position.y-0.05 and centre.y<bounds.end.y+0.05
				for corner in range(3):
					if candidate and in_opening:leaves.append(indices[triangle+corner])
					else:walls.append(indices[triangle+corner])
			append_triangles(wall_mesh,arrays,walls,mat)
			append_triangles(leaf_mesh,arrays,leaves,mat)
		if leaf_mesh.get_surface_count()==0:continue
		mesh_node.mesh=wall_mesh
		for surface in range(wall_mesh.get_surface_count()):mesh_node.set_surface_override_material(surface,null)
		var hinge := Vector3(bounds.position.x,bounds.position.y,bounds.get_center().z)
		var door := Node3D.new()
		door.set_script(load("res://door.gd"))
		door.door_name=title
		door.width=maxf(bounds.size.x,0.9)
		door.height=maxf(bounds.size.y,1.9)
		door.open_angle=1.65
		door.transform=mesh_node.transform*Transform3D(Basis.IDENTITY,hinge)
		piece.add_child(door)
		var leaf := MeshInstance3D.new()
		leaf.mesh=leaf_mesh
		leaf.position=-hinge
		door.add_child(leaf)

func _process(delta: float) -> void:
	if windmill_sails:windmill_sails.rotate_object_local(Vector3(0,0,1),delta*0.65)

func world() -> void:
	var environment := WorldEnvironment.new()
	environment.name="WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("7198b5")
	sky_mat.sky_horizon_color = Color("e7dac0")
	sky_mat.ground_horizon_color = Color("d9d3b4")
	sky_mat.ground_bottom_color = Color("667653")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d4dbdd")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("cbd4be")
	env.fog_density = 0.0018
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name="Sun"
	sun.rotation_degrees = Vector3(-43, -32, 0)
	sun.light_color = Color("fff0d8")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160
	add_child(sun)
	var ground := box(self, Vector3(1000, 30, 1000), Vector3(0,-15.05,0), Color("667447"), true)
	ground.name="SharedGround"
	var grass := ShaderMaterial.new()
	var grass_shader := Shader.new()
	grass_shader.code = "shader_type spatial; varying vec3 wp; void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);} void fragment(){vec2 p=wp.xz*0.08; vec2 i=floor(p);vec2 f=smoothstep(vec2(0.0),vec2(1.0),fract(p));float n=mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); ALBEDO=mix(vec3(0.19,0.27,0.12),vec3(0.34,0.41,0.20),n);ROUGHNESS=1.0;}"
	grass.shader = grass_shader
	ground.material_override = grass
	# Softly rolling wooded hills frame the settlement.
	for i in range(30):
		var hill := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radial_segments = 16
		sphere.rings = 8
		hill.mesh = sphere
		hill.material_override = material(Color("6c8059").darkened(rng.randf_range(0,0.16)))
		var angle := TAU * i / 30.0
		hill.position = Vector3(cos(angle)*rng.randf_range(400,450), -5, sin(angle)*rng.randf_range(400,450))
		hill.scale = Vector3(rng.randf_range(32,55),rng.randf_range(17,33),rng.randf_range(30,50))
		add_child(hill)
		hill.add_to_group("backdrop_scenery")
	# Roads and square use the actual brick-floor model from the pack.
	var paving := Node3D.new()
	paving.name = "CobblestoneSquareAndLanes"
	add_child(paving)
	for x in range(-35,36):
		for z in range(-30,31):
			if (abs(x) <= 5 and abs(z) <= 5) or abs(x) <= 1 or abs(z) <= 1 or (abs(x) <= 27 and (abs(z)==9 or abs(z)==24)) or (abs(x)==24 and abs(z)<=26):
				model(paving,"Floor_UnevenBrick",Vector3(x*2,0.015,z*2))
	preload("res://static_paving.gd").batch(paving)
	# Peripheral trees are original simple supporting geometry.
	for i in range(135):
		var angle := rng.randf_range(0,TAU)
		var radius := rng.randf_range(350,390)
		tree(Vector3(cos(angle)*radius,0,sin(angle)*radius),rng.randf_range(0.8,1.8))
	for pos in [Vector3(-10,0,15),Vector3(10,0,-15),Vector3(23,0,6),Vector3(-25,0,-5)]: tree(pos,0.85)

func tree(pos: Vector3, size: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.add_to_group("backdrop_scenery")
	root.position = pos
	root.scale = Vector3.ONE*size
	box(root,Vector3(0.35,2.8,0.35),Vector3(0,1.4,0),Color("5c4633"),true)
	for j in range(3):
		var crown := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.12
		mesh.bottom_radius = 2.1-j*0.38
		mesh.height = 2.7
		mesh.radial_segments = 7
		crown.mesh = mesh
		crown.material_override = material(Color("3d6040").lightened(j*0.045))
		root.add_child(crown)
		crown.position.y = 2.8+j*1.15

func town() -> void:
	building("The Copper Stag · Tavern",Vector3(-16,0,10),6,8,2,PI/2)
	building("Bramble Bakery",Vector3(15,0,10),6,6,1,-PI/2)
	building("Forge & Anvil",Vector3(15,0,-10),6,8,1,-PI/2,true)
	building("Alderwick Town Hall",Vector3(0,0,-19),8,10,2,PI)
	building("Herbalist",Vector3(-15,0,-10),6,6,1,PI/2)
	building("Weaver's House",Vector3(-30,0,10),6,8,2,0)
	building("Carpenter",Vector3(30,0,10),6,8,1,0)
	building("Brew House",Vector3(-29,0,-10),6,8,1,PI)
	building("Granary",Vector3(29,0,-10),6,8,2,PI)
	building("Hearth House",Vector3(-14,0,27),6,6,1,0)
	building("Willow House",Vector3(14,0,27),6,8,2,0)
	building("North Cottage",Vector3(-17,0,-34),6,6,1,PI)
	building("Orchard Cottage",Vector3(17,0,-34),6,6,1,PI)
	for entry in [["Chapel",Vector3(-31,0,-34),0.0],["Windmill",Vector3(32,0,-34),0.0],["GuardTower",Vector3(8,0,60),0.0],
		["Barn",Vector3(-52,0,-38),0.0],["Stable",Vector3(51,0,26),0.0],["Brewery",Vector3(-52,0,10),0.0],
		["Inn",Vector3(-52,0,-12),0.0],["Apiary",Vector3(-34,0,51),0.0],["Pigsty",Vector3(27,0,51),0.0],
		["TrainingYard",Vector3(49,0,51),0.0],["ForesterHut",Vector3(-54,0,38),0.0],
		["Watermill",Vector3(59,0,-12),0.0],["Woodcutter",Vector3(-54,0,55),0.0],
		["Pottery",Vector3(-34,0,-52),0.0],["Tannery",Vector3(-52,0,-56),0.0],
		["Storehouse",Vector3(48,0,-52),0.0],["Smokehouse",Vector3(15,0,-52),0.0],
		["Longhouse",Vector3(-12,0,52),0.0],["TownhouseGablefront",Vector3(12,0,52),0.0]]:
		var scene := load("res://kit/structures/"+entry[0]+".tscn") as PackedScene
		if scene:
			var structure := scene.instantiate() as Node3D
			add_child(structure)
			structure.position = entry[1]
			structure.rotation.y = entry[2]
			prepare_doors(structure,entry[0])
			collisions(structure)
			clear_doorway_collisions(structure)
			if entry[0]=="Windmill":
				for node in structure.find_children("*Sails_inst*","Node3D",true,false):
					windmill_sails=node
					break
			locations.append({"name":entry[0],"position":[structure.position.x,0,structure.position.z]})
	# A quiet river and two timber bridges connect the eastern lane.
	box(self,Vector3(7,0.04,148),Vector3(64,-0.015,0),Color("527d82"))
	for bridge_z in [0.0,48.0]:
		box(self,Vector3(10,0.18,4),Vector3(64,0.04,bridge_z),Color("806449"),true)
		for side in [-1.0,1.0]:
			box(self,Vector3(10,0.12,0.12),Vector3(64,0.85,bridge_z+side*1.9),Color("5e4936"),true)
	for patch_x in [-35.0,32.0]:
		for row in range(5):
			box(self,Vector3(10,0.06,0.8),Vector3(patch_x,0,38+row*1.5),Color("66513a"))
			for plant in range(12):
				box(self,Vector3(0.2,0.5,0.2),Vector3(patch_x-4.5+plant*0.8,0.25,38+row*1.5),Color("718248"))
	# Market stalls face the square, leaving its crossing open.
	for x in [-7.0,7.0]:
		for z in [-5.0,5.0]: stall(Vector3(x,0,z),x<0)
	well(Vector3(0,0,0))
	model(self,"Prop_Wagon",Vector3(23,0,3),PI/2,true)
	model(self,"Prop_Wagon",Vector3(-24,0,-19),PI*0.2,true)
	for i in range(16):
		var side := -1.0 if i%2==0 else 1.0
		model(self,"Prop_Crate",Vector3(side*(36+rng.randf()*3),0,rng.randf_range(-14,14)),rng.randf_range(0,TAU),true)
	for x in range(-36,37):
		if abs(x)>2:
			model(self,"Prop_WoodenFence_Single",Vector3(x*2,0,65))
		model(self,"Prop_WoodenFence_Single",Vector3(x*2,0,-65))
	for z in range(-32,33):
		if abs(z)<=1:continue
		model(self,"Prop_WoodenFence_Single",Vector3(-73,0,z*2),PI/2)
		model(self,"Prop_WoodenFence_Single",Vector3(73,0,z*2),PI/2)
	# Timber entry arch, with a clear approach to the market.
	box(self,Vector3(0.7,5,0.7),Vector3(-4,2.5,65),Color("4f3d2d"),true)
	box(self,Vector3(0.7,5,0.7),Vector3(4,2.5,65),Color("4f3d2d"),true)
	box(self,Vector3(8.8,0.6,0.8),Vector3(0,5,65),Color("4f3d2d"),true)
	add_sign("ALDERWICK",Vector3(0,4.9,65.5),0,44)
	for x in [-8.0,8.0]:
		for z in [-13.0,13.0,30.0]: lamp(Vector3(x,0,z))
	# Work and home anchors are saved for the character phase.
	var data := FileAccess.open("user://town_locations.json",FileAccess.WRITE)
	data.store_string(JSON.stringify(locations,"\t"))

func building(title: String, pos: Vector3, width: int, depth: int, floors: int, angle: float, forge := false) -> void:
	var root := Node3D.new()
	root.name = title.split(" · ")[0].replace("'", "")
	add_child(root)
	root.position = pos
	root.rotation.y = angle
	root.set_meta("width",width)
	root.set_meta("depth",depth)
	root.set_meta("modular_house",true)
	locations.append({"name":title,"position":[pos.x,pos.y,pos.z],"entry":[pos.x+sin(angle)*(-depth/2.0-1),0,pos.z+cos(angle)*(-depth/2.0-1)]})
	box(root,Vector3(width+0.2,0.18,depth+0.2),Vector3(0,-0.14,0),Color("817b68"),true)
	for level in range(floors):
		for x in range(width/2):
			var xx := -width/2.0+1+x*2
			var front := "Wall_Plaster_Window_Wide_Flat"
			if level==0 and x==int(width/4): front="Wall_Plaster_Door_Round"
			model(root,front,Vector3(xx,level*3,-depth/2.0),0,true)
			if front.contains("Door"):
				var door := Node3D.new()
				door.set_script(load("res://door.gd"))
				door.door_name=title
				door.position=Vector3(xx-0.52,0,-depth/2.0-0.1)
				model(door,"Door_2_Round",Vector3.ZERO)
				root.add_child(door)
			else:
				model(root,"Window_Wide_Flat1",Vector3(xx,level*3,-depth/2.0))
				model(root,"WindowShutters_Wide_Flat_Open",Vector3(xx,level*3,-depth/2.0))
			model(root,"Wall_Plaster_Straight",Vector3(xx,level*3,depth/2.0),PI,true)
		for z in range(depth/2):
			var zz := -depth/2.0+1+z*2
			model(root,"Wall_Plaster_Window_Wide_Flat",Vector3(width/2.0,level*3,zz),-PI/2,true)
			model(root,"Window_Wide_Flat1",Vector3(width/2.0,level*3,zz),-PI/2)
			model(root,"Wall_Plaster_Straight",Vector3(-width/2.0,level*3,zz),PI/2,true)
		for x in range(width/2):
			for z in range(depth/2): model(root,"Floor_WoodDark",Vector3(-width/2.0+1+x*2,level*3+0.06,-depth/2.0+1+z*2))
	model(root,"Roof_RoundTiles_%dx%d"%[width,depth],Vector3(0,floors*3,0),0,true)
	model(root,"Roof_Front_Brick%d"%width,Vector3(0,floors*3,-depth/2.0))
	model(root,"Roof_Front_Brick%d"%width,Vector3(0,floors*3,depth/2.0),PI)
	model(root,"Prop_Chimney",Vector3(width/2.0-1,floors*3+1.8,1))
	model(root,"Prop_Vine4",Vector3(-width/2.0+0.7,0,-depth/2.0-0.12))
	add_sign(title,root.position+root.basis*Vector3(0,2.55,-depth/2.0-0.4),angle,26)
	# A table and stored goods make the open ground-floor entrances useful.
	root.add_to_group("enterable_houses")
	box(root,Vector3(width-0.3,0.08,depth-0.3),Vector3(0,-0.09,0),Color("766044"),true)
	box(root,Vector3(width-0.2,0.12,depth-0.2),Vector3(0,2.94,0),Color("58432e"),true)
	add_sleeping_furniture(root,width,depth)
	interior_table(root,Vector3(-width/2.0+1.2,0,-1.2),Vector2(1.5,1.1))
	interior_stool(root,Vector3(-width/2.0+1.2,0,-2.2))
	interior_stool(root,Vector3(-width/2.0+1.2,0,-0.2))
	var room_light := OmniLight3D.new()
	room_light.position=Vector3(0,2.45,0)
	room_light.light_color=Color("ffe4b8")
	room_light.light_energy=1.35
	room_light.omni_range=9
	room_light.add_to_group("interior_lamps")
	root.add_child(room_light)
	# Shelves stay against the back wall, leaving a clear path from each entrance.
	detailed_prop("Bookcase_2",root,Vector3(0,0,depth/2.0-0.5),Vector3(2.3,2.1,0.5),true)
	detailed_prop("Chandelier",root,Vector3(0,2.4,0),Vector3(0.65,0.4,0.65),false)
	if "Tavern" in title:
		interior_table(root,Vector3(width/2.0-1.3,0,-1.2),Vector2(1.7,1.1))
		interior_stool(root,Vector3(width/2.0-1.3,0,-2.2))
		interior_stool(root,Vector3(width/2.0-1.3,0,-0.2))
	model(root,"Prop_Crate",Vector3(width/2.0-0.7,0,-depth/2.0+0.7),0,true)
	if forge:
		box(root,Vector3(1.8,0.8,1.5),Vector3(0,0.4,-1),Color("514d46"),true)
		var fire := OmniLight3D.new()
		fire.position = Vector3(0,1,-1)
		fire.light_color = Color("ff9540")
		fire.light_energy = 2
		fire.omni_range = 6
		root.add_child(fire)

func interior_table(root: Node3D,pos: Vector3,size: Vector2) -> void:
	detailed_prop("Table_Large",root,pos,Vector3(size.x,0.88,size.y),true)
	detailed_prop("Table_Plate",root,pos+Vector3(0,0.9,0),Vector3(0.3,0.03,0.3),false)
	detailed_prop("Mug",root,pos+Vector3(0.4,0.9,0),Vector3(0.14,0.19,0.14),false)

func interior_stool(root: Node3D,pos: Vector3) -> void:
	detailed_prop("Stool",root,pos,Vector3(0.5,0.52,0.5),true)
	var seat := Marker3D.new()
	seat.name="Seat"
	seat.position=pos+Vector3(0,0.52,0)
	seat.rotation.y=PI if pos.z> -1.2 else 0
	seat.add_to_group("seats")
	root.add_child(seat)

func detailed_prop(asset: String,parent: Node3D,pos: Vector3,size: Vector3,solid: bool) -> Node3D:
	var path := "res://assets/furniture/"+asset+".gltf"
	if not library.has(path):
		print("FURNITURE_LOAD ",asset)
		library[path]=load(path)
	var node: Node3D=library[path].instantiate()
	parent.add_child(node)
	restore_vertex_colours(node)
	var combined := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		var relative: Transform3D=node.global_transform.affine_inverse()*mesh.global_transform
		var part: AABB=relative*mesh.get_aabb()
		combined=part if first else combined.merge(part)
		first=false
	node.scale=Vector3(size.x/maxf(0.001,combined.size.x),size.y/maxf(0.001,combined.size.y),size.z/maxf(0.001,combined.size.z))
	node.position=pos-Vector3(combined.get_center().x,combined.position.y,combined.get_center().z)*node.scale
	node.add_to_group("detailed_furniture")
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size=size
		collider.shape=shape
		body.add_child(collider)
		parent.add_child(body)
		body.position=pos+Vector3(0,size.y/2,0)
	return node

func add_sleeping_furniture(root: Node3D,width: int,depth: int) -> void:
	for side in [-1.0,1.0]:
		var pos := Vector3(side*(width/2.0-0.85),0,depth/2.0-1.65)
		detailed_prop("Bed_Twin1",root,pos,Vector3(1.25,0.6,2.15),true)
		var bed := Marker3D.new()
		bed.name="Bed"
		bed.position=pos+Vector3(0,0.6,-0.85)
		bed.add_to_group("beds")
		root.add_child(bed)
	# Cupboard and a small rug add detail without narrowing the entry path.
	detailed_prop("Cabinet",root,Vector3(-width/2.0+0.5,0,-depth/2.0+0.7),Vector3(0.65,1.8,0.5),true)
	box(root,Vector3(1.3,0.012,1.6),Vector3(0,0.025,-0.2),Color("76584d"))

func setup_animals() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	var specs := [
		["Cow",Vector3(-41,0,-22),1.4,4.0],["Cow",Vector3(-42,0,-34),1.3,4.0],
		["Horse",Vector3(40,0,28),1.65,4.0],["Horse",Vector3(40,0,36),1.55,4.0],
		["Pig",Vector3(32,0,56),0.72,4.0],["Pig",Vector3(35,0,58),0.65,4.0],
		["Sheep",Vector3(-37,0,29),0.85,4.0],["Sheep",Vector3(-34,0,33),0.8,4.0],
		["Pug",Vector3(4,0,15),0.30,5.0]
	]
	for i in range(specs.size()):
		var spec: Array=specs[i]
		var cell: Vector2i=life.free_cell(spec[1])
		var animal := CharacterBody3D.new()
		animal.name=spec[0]+str(i+1)
		animal.set_script(load("res://animal.gd"))
		animal.species=spec[0]
		animal.desired_height=spec[2]
		animal.radius=spec[3]
		if animal.species=="Pug":
			animal.radius=8.0
			animal.pace=0.9
		animal.home=Vector3(cell.x,0.03,cell.y)
		animal.position=animal.home
		add_child(animal)
	print("ANIMALS_READY count=",specs.size())

func clip_polygon(points: Array,axis: int,value: float,keep_less: bool) -> Array:
	var result: Array=[]
	if points.is_empty():return result
	var previous: Vector3=points[-1]
	var previous_inside: bool=previous[axis]<=value if keep_less else previous[axis]>=value
	for point: Vector3 in points:
		var inside: bool=point[axis]<=value if keep_less else point[axis]>=value
		if inside!=previous_inside:
			var t := (value-previous[axis])/(point[axis]-previous[axis])
			result.append(previous.lerp(point,t))
		if inside:result.append(point)
		previous=point
		previous_inside=inside
	return result

func subtract_opening(triangle: Array,width: float,height: float) -> Array:
	var remaining: Array=triangle
	var outside: Array=[]
	for plane in [[0,-0.08,false],[0,width+0.08,true],[1,-0.8,false],[1,height+0.04,true],[2,-0.85,false],[2,1.6,true]]:
		var rejected := clip_polygon(remaining,plane[0],plane[1],not plane[2])
		if rejected.size()>=3:outside.append(rejected)
		remaining=clip_polygon(remaining,plane[0],plane[1],plane[2])
		if remaining.is_empty():break
	return outside

func clear_doorway_collisions(structure: Node3D) -> void:
	var doors: Array=[]
	for node in structure.find_children("*","Node3D",true,false):
		if node.is_in_group("doors"):doors.append(node)
	for mesh_node: MeshInstance3D in structure.find_children("*","MeshInstance3D",true,false):
		if mesh_node.get_parent().is_in_group("doors"):continue
		for body in mesh_node.get_children():
			if not body is StaticBody3D:continue
			for collider in body.get_children():
				if not collider is CollisionShape3D or not collider.shape is ConcavePolygonShape3D:continue
				var faces: PackedVector3Array=collider.shape.get_faces()
				for door: Node3D in doors:
					var to_door: Transform3D=door.global_transform.affine_inverse()*mesh_node.global_transform
					var from_door := to_door.affine_inverse()
					var carved := PackedVector3Array()
					var box_bounds := AABB(Vector3(-0.08,-0.8,-0.85),Vector3(door.width+0.16,door.height+0.84,2.45))
					for i in range(0,faces.size(),3):
						var triangle: Array=[to_door*faces[i],to_door*faces[i+1],to_door*faces[i+2]]
						var bounds := AABB(triangle[0],Vector3.ZERO).expand(triangle[1]).expand(triangle[2])
						if not bounds.intersects(box_bounds):
							carved.append_array(PackedVector3Array([faces[i],faces[i+1],faces[i+2]]))
							continue
						for polygon in subtract_opening(triangle,door.width,door.height):
							for k in range(1,polygon.size()-1):
								carved.append(from_door*polygon[0])
								carved.append(from_door*polygon[k])
								carved.append(from_door*polygon[k+1])
					faces=carved
				var shape := ConcavePolygonShape3D.new()
				shape.set_faces(faces)
				collider.shape=shape

func add_sign(text: String,pos: Vector3,angle: float,font_size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.009
	label.modulate = Color("fff1cf")
	label.outline_modulate = Color("332b23")
	label.outline_size = 10
	label.position = pos
	label.rotation.y = angle + PI
	label.no_depth_test = false
	add_child(label)

func stall(pos: Vector3,left: bool) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = PI/2 if left else -PI/2
	add_child(root)
	box(root,Vector3(3,0.15,1.6),Vector3(0,1,0),Color("765738"),true)
	for x in [-1.4,1.4]:
		for z in [-0.65,0.65]: box(root,Vector3(0.12,2.7,0.12),Vector3(x,1.35,z),Color("5a422b"))
	for stripe in range(6):
		var color := Color("9b4d36") if stripe%2==0 else Color("e2c89b")
		var canopy := box(root,Vector3(0.5,0.06,2.3),Vector3(-1.25+stripe*0.5,2.7,0),color)
		canopy.rotation.x = -0.13
	for x in [-0.9,0.0,0.9]:
		var crate := model(root,"Prop_Crate",Vector3(x,1.06,0))
		crate.scale = Vector3(0.7,0.12,0.7)
	var produce := load("res://kit/models/VK/Prop/SM_VK_Prop_ShopGoods_Produce.glb").instantiate() as Node3D
	root.add_child(produce)
	produce.name="VegetableDisplay"
	produce.add_to_group("market_produce")
	produce.position=Vector3(0,1.2,0)
	produce.scale=Vector3(1.4,0.9,1.4)
	for mesh: MeshInstance3D in produce.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var source := mesh.get_active_material(surface)
			if not source:continue
			var palette := {"M_VK_Wood":Color("8d6542"),"M_VK_FlowerYellow":Color("dd8e38"),"M_VK_Leaf":Color("79a34c"),"M_VK_Goods":Color("bc9470"),"M_VK_Void":Color("4a3928")}
			var display_mat := material(palette.get(source.resource_name,Color("869651")))
			display_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
			mesh.set_surface_override_material(surface,display_mat)
	var placard := Label3D.new()
	placard.text="FRESH VEGETABLES"
	placard.position=Vector3(0,0.8,0.86)
	placard.font_size=24
	placard.pixel_size=0.006
	placard.outline_size=8
	root.add_child(placard)
	model(root,"Prop_Crate",Vector3(2,0,0),0,true)

func well(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	for i in range(12):
		var a := i*TAU/12
		var stone := box(root,Vector3(0.65,0.9,0.4),Vector3(sin(a)*1.15,0.45,cos(a)*1.15),Color("8b8977"),true)
		stone.rotation.y = a
	for x in [-1.5,1.5]: box(root,Vector3(0.2,3.2,0.2),Vector3(x,1.6,0),Color("674c32"),true)
	box(root,Vector3(3.4,0.2,0.3),Vector3(0,3.1,0),Color("674c32"))
	var water:=MeshInstance3D.new()
	water.name="WellWater"
	var surface:=CylinderMesh.new()
	surface.top_radius=.94;surface.bottom_radius=.94;surface.height=.035
	surface.radial_segments=48
	water.mesh=surface;water.position.y=.43
	var water_material:=ShaderMaterial.new()
	water_material.shader=preload("res://well_water.gdshader")
	water.material_override=water_material
	root.add_child(water)

func lamp(pos: Vector3) -> void:
	box(self,Vector3(0.16,3.2,0.16),pos+Vector3(0,1.6,0),Color("594631"),true)
	box(self,Vector3(0.45,0.55,0.45),pos+Vector3(0,3,0),Color("e6b55b"))
	var light := OmniLight3D.new()
	light.add_to_group("street_lamps")
	light.position = pos+Vector3(0,3,0)
	light.light_color = Color("ffd196")
	light.light_energy = 0.5
	light.omni_range = 6
	add_child(light)

func interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	menu_panel=panel
	panel.position = Vector2(26,24)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08,0.12,0.1,0.88)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	style.corner_radius_top_left=8
	style.corner_radius_top_right=8
	style.corner_radius_bottom_left=8
	style.corner_radius_bottom_right=8
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := Label.new()
	title.text = "A L D E R W I C K"
	title.add_theme_font_size_override("font_size",25)
	title.modulate = Color("efd7a8")
	header.add_child(title)
	menu_toggle=Button.new()
	menu_toggle.text="−"
	menu_toggle.tooltip_text="Collapse menu [H]"
	menu_toggle.pressed.connect(toggle_menu)
	header.add_child(menu_toggle)
	menu_body=VBoxContainer.new()
	menu_scroll=ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(menu_scroll)
	menu_scroll.add_child(menu_body)
	menu_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	menu_body.minimum_size_changed.connect(func():fit_menu.call_deferred())
	get_viewport().size_changed.connect(fit_menu)
	fit_menu.call_deferred()
	var vbox := menu_body
	var subtitle := Label.new()
	subtitle.text = "A medieval town · Life in Alderwick"
	subtitle.modulate = Color("a9b9aa")
	vbox.add_child(subtitle)
	status = Label.new()
	status.text = "Overview · Drag to orbit · Scroll to zoom"
	vbox.add_child(status)
	var row := HBoxContainer.new()
	vbox.add_child(row)
	view_button = Button.new()
	view_button.text = "Explore town [Tab]"
	view_button.pressed.connect(toggle_view)
	row.add_child(view_button)
	view_selector=OptionButton.new()
	view_selector.add_item("First person",0)
	view_selector.add_item("Overhead",1)
	view_selector.add_item("Third person",2)
	view_selector.item_selected.connect(set_view)
	vbox.add_child(view_selector)
	var places := OptionButton.new()
	places.add_item("Visit a place…")
	places.add_item("Town square")
	var approaches: Array[Vector3]=[Vector3.ZERO,Vector3(0,0.2,23)]
	var sights: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
	for portal in expansion.entrances:
		places.add_item(portal.label)
		approaches.append(portal.position+Vector3(0,0.15,0))
		sights.append(portal.inside)
	for portal in chateaux.entrances:
		places.add_item(portal.label)
		approaches.append(portal.position)
		sights.append(portal.inside)
	places.add_item("Western Village")
	approaches.append(Vector3(-90,0.2,100))
	sights.append(Vector3(-170,1,95))
	for stop in [["South gate watch",Vector3(0,0.3,57),Vector3(0,1,65)],
		["Carpenter workyard",Vector3(34,0.3,23),Vector3(35,1,12)],
		["Farm deliveries",Vector3(-30,0.3,34),Vector3(-37,1,38)],
		["Western market",Vector3(-90,0.3,103),Vector3(-101,1,103)],
		["Forest trail",Vector3(0,0.3,120),Vector3(0,1,160)],
		["Industrial town — north gate",Vector3(0,0.3,252),Vector3(0,1,280)]]:
		places.add_item(stop[0])
		approaches.append(stop[1])
		sights.append(stop[2])
	places.item_selected.connect(func(index: int):
		if index==0:return
		if not player.resting.is_empty():player.stand_from_furniture(true)
		player.global_position=approaches[index]
		var facing: Vector3=sights[index]-approaches[index]
		player.rotation.y=atan2(-facing.x,-facing.z)
		player.velocity=Vector3.ZERO
		set_view(2)
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		places.select(0))
	vbox.add_child(places)
	music_button = Button.new()
	music_button.text = "Music: off [M]"
	music_button.pressed.connect(toggle_music)
	row.add_child(music_button)
	var hint := Label.new()
	hint.text = "WASD Move · Shift Run · Space Jump · E Use · F Talk · Tab View · N Day/night · H Menu"
	hint.position = Vector2(28,750)
	hint.add_theme_color_override("font_shadow_color",Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x",2)
	hint.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(hint)

func _input(event: InputEvent) -> void:
	if builder and builder.active:return
	if character_directory and character_directory.is_open():
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:character_directory.hide_directory();get_viewport().set_input_as_handled()
		return
	if adventures and adventures.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if not player.resting.is_empty() and event.physical_keycode in [KEY_E,KEY_SPACE]:
			player.stand_from_furniture()
			get_viewport().set_input_as_handled()
			return
		if life and life.active:
			if event.physical_keycode==KEY_ESCAPE:
				life.close_dialog()
				get_viewport().set_input_as_handled()
			return
		match event.physical_keycode:
			KEY_TAB: toggle_view()
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_M: toggle_music()
			KEY_N: day_night.set_enabled(not day_night.enabled)
			KEY_H: toggle_menu()
			KEY_R:
				if home_district and home_district.inside:player.position=home_district.safe_spawn();player.velocity=Vector3.ZERO
				else:player.position=Vector3(0,2,23)
		if event.physical_keycode in [KEY_TAB,KEY_ESCAPE,KEY_M,KEY_N,KEY_R,KEY_H]:
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not walking:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
			if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(28,distance-4)
			if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(450,distance+4)
		if event is InputEventMouseMotion and dragging: orbit -= event.relative.x*0.005
		update_camera()

func update_camera() -> void:
	if home_district and home_district.inside:
		var focus: Vector3=home_district.room_origin+Vector3(2,1,0)
		overview.position=focus+Vector3(sin(orbit)*15,13,cos(orbit)*15)
		overview.look_at(focus)
		return
	overview.position = Vector3(sin(orbit)*distance,distance*0.72,cos(orbit)*distance)
	overview.look_at(Vector3(0,1,0))

func toggle_view() -> void:
	set_view((view_mode+1)%3)

func set_view(mode: int) -> void:
	if life and life.active:life.close_dialog()
	view_mode=mode
	walking = mode!=1
	dragging = false
	player.set_view(mode)
	overview.current = mode==1
	if mode==1:update_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if walking else Input.MOUSE_MODE_VISIBLE
	status.text = "First person · F talks · E uses items · Esc frees mouse" if mode==0 else "Third person · F talks · E uses items · Esc frees mouse" if mode==2 else "Overview · Drag to orbit · Scroll to zoom"
	view_button.text = "Change view [Tab]"
	view_selector.select(mode)

func toggle_music() -> void:
	if music.playing:
		music.stop()
		music.volume_db=-80
	else:
		music.volume_db=-34
		music.play()
	music_button.text = "Music: soft [M]" if music.playing else "Music: off [M]"
	if life and life.active:
		life.previous_music=-34.0 if music.playing else -80.0
		if music.playing:music.volume_db=-40

func fit_menu() -> void:
	if not menu_scroll or not menu_panel:return
	var minimum := menu_body.get_combined_minimum_size()
	menu_scroll.custom_minimum_size=Vector2(maxf(280,minimum.x+12),minf(minimum.y,maxf(120,get_viewport().get_visible_rect().size.y-130)))
	menu_panel.reset_size()

func toggle_menu() -> void:
	menu_collapsed=not menu_collapsed
	menu_body.visible=not menu_collapsed
	if menu_scroll:menu_scroll.visible=not menu_collapsed
	menu_toggle.text="+" if menu_collapsed else "−"
	menu_toggle.tooltip_text=("Expand" if menu_collapsed else "Collapse")+" menu [H]"
	menu_panel.set_deferred("size",Vector2.ZERO)
	if life:
		life.hint.position.y=100 if menu_collapsed else 395
		life.talk_button.position.y=130 if menu_collapsed else 425

func capture_walk() -> void:
	while not life.navigation_ready:await get_tree().process_frame
	set_view(0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in range(35):await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://../town-street-preview.png")
	print("STREET_CAPTURE_SAVED")
	get_tree().quit()

func capture() -> void:
	while not life.navigation_ready:await get_tree().process_frame
	set_view(1)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://../town-preview.png")
	print("CAPTURE_SAVED")
	get_tree().quit()

func capture_third() -> void:
	while not life.navigation_ready:await get_tree().process_frame
	set_view(2)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(35):await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://../town-third-person.png")
	print("THIRD_CAPTURE_SAVED")
	get_tree().quit()

func capture_dialogue() -> void:
	while not life.navigation_ready:await get_tree().process_frame
	set_view(0)
	var person: CharacterBody3D=life.people[0]
	person.position=Vector3(2,0.1,16)
	person.talking=true
	player.position=Vector3(2,0.1,19)
	player.look_at(Vector3(person.position.x,player.position.y,person.position.z))
	for i in range(35):await get_tree().physics_frame
	life.open_dialog(person)
	life.send("Your work")
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://../town-dialogue.png")
	print("DIALOGUE_CAPTURE_SAVED")
	get_tree().quit()

func validate() -> void:
	while not life.navigation_ready:await get_tree().process_frame
	player.enabled=false
	await get_tree().physics_frame
	assert(locations.size()>=43,"Expected 32 locations from both packs")
	assert(music.playing,"Music should be playing")
	assert(music.volume_db==-34,"Music should start softly")
	assert(library.size()>15,"Town must use imported models")
	toggle_music()
	assert(music.volume_db==-80 and music_button.text.contains("off"),"Mute should work")
	toggle_music()
	assert(music.volume_db==-34,"Music should restore softly")
	# Traverse the main lane with the actual player capsule and collision world.
	for i in range(240):
		await get_tree().physics_frame
		player.velocity = Vector3(0,-2,-3.5)
		player.move_and_slide()
	assert(player.position.z<10 and player.position.z>7,"Main lane should be walkable")
	assert(player.is_on_floor(),"Player must remain grounded")
	var lane_end := player.position
	# Verify a building wall blocks movement rather than allowing passage through it.
	player.position = Vector3(15,0.1,16)
	for i in range(120):
		await get_tree().physics_frame
		player.velocity = Vector3(0,-2,-3.5)
		player.move_and_slide()
	assert(player.position.z>13,"Bakery wall must block the player")
	print("PHYSICS_VALIDATION_OK lane_end=",lane_end," blocked_at=",player.position)
	assert(life.people.size()==45,"Expected 45 residents")
	var moving_count := 0
	for person in life.people:
		assert(person.animator and person.animator.has_animation("Walk"),"Every resident needs a walk animation")
		assert(not person.visual.find_children("*","MeshInstance3D",true,false).is_empty(),"Every resident must have visible meshes")
		assert(person.position.y>-1 and person.position.y<1,"Residents should remain on the ground")
		if person.travelled>1:moving_count+=1
	assert(moving_count>=12,"Most residents should move through the town")
	var speaker: CharacterBody3D=life.people[0]
	life.open_dialog(speaker)
	assert(speaker.talking and not player.enabled,"Conversation should stop the speaker and player")
	assert(speaker.speak("Your work").contains("bread"),"Baker should discuss baking")
	life.send("Where do you live?")
	assert(life.transcript.get_parsed_text().contains("Willow House"),"Dialogue should include the resident's home")
	life.close_dialog()
	assert(not speaker.talking and music.volume_db==-34,"Closing conversation should restore movement and quiet music")
	for mode in range(3):
		set_view(mode)
		assert(get_viewport().get_camera_3d()==(player.camera if mode==0 else overview if mode==1 else player.third_camera),"View selector must activate the right camera")
	player.enabled=false
	var doors := get_tree().get_nodes_in_group("doors")
	assert(doors.size()>=20,"Custom and imported buildings need interactive doors")
	var door: Node3D=doors[0]
	assert(not door.is_open,"Doors start closed")
	assert(door.toggle(Vector3(0,0,100)),"Door should open")
	await get_tree().create_timer(0.6).timeout
	assert(door.is_open and door.collider.disabled,"Open door must allow passage")
	assert(absf(door.rotation.y-door.closed_angle)>1.4,"Door leaf should visibly swing")
	player.collision_mask=1
	player.position=door.global_transform*Vector3(0.52,0.1,-1.1)
	# Use the closed doorway's axes while the hinge is open.
	var closed_basis := door.global_basis*Basis(Vector3.UP,-door.open_angle)
	player.position=door.global_position+closed_basis*Vector3(0.52,0.1,-1.1)
	for i in range(45):
		await get_tree().physics_frame
		player.velocity=closed_basis*Vector3(0,-2,3.5)
		player.move_and_slide()
	var through := closed_basis.inverse()*(player.position-door.global_position)
	print("DOOR_PASSAGE position=",through," door=",door.global_position," angle=",door.rotation.y)
	assert(through.z>0.8,"The player capsule must pass through the open doorway")
	assert(door.toggle(Vector3(0,0,100)),"Door should close")
	await get_tree().create_timer(0.6).timeout
	assert(not door.is_open and not door.collider.disabled,"Closed door must block passage")
	assert(windmill_sails!=null,"Windmill sails should be found")
	var old_rotation := windmill_sails.rotation
	await get_tree().create_timer(0.5).timeout
	assert(windmill_sails.rotation.distance_to(old_rotation)>0.2,"Windmill must rotate")
	print("VILLAGE_LIFE_VALIDATION_OK moving=",moving_count," doors=",doors.size()," dialogue=ok cameras=3 windmill=spinning")
	print("TOWN_VALIDATION_OK locations=",locations.size()," models=",library.size()," music_db=",music.volume_db)
	music.stop()
	library.clear()
	await get_tree().process_frame
	get_tree().quit()

func validate_behavior() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	player.enabled=false
	var a: CharacterBody3D=life.people[0]
	var b: CharacterBody3D=life.people[1]
	a.position=Vector3(0,0.1,16)
	b.position=Vector3(1.55,0.1,16)
	a.social_cooldown=0
	b.social_cooldown=0
	assert(life.start_meetup(a,b,6),"Nearby villagers must be able to meet")
	var a_start := a.position
	var b_start := b.position
	for i in range(180):await get_tree().physics_frame
	assert(a.social_partner==b and b.social_partner==a,"Pair should remain together for a few seconds")
	assert(a.position.distance_to(a_start)<0.2 and b.position.distance_to(b_start)<0.2,"Talking pair should stand still")
	assert(a.activity.contains("Chatting") and b.activity.contains("Chatting"))
	for i in range(230):await get_tree().physics_frame
	assert(a.social_partner==null and b.social_partner==null,"Meetup must finish and release both villagers")
	assert(a.social_cooldown>0 and b.social_cooldown>0,"Cooldown must prevent immediate repeat conversations")
	a.social_cooldown=0
	b.social_cooldown=0
	a.position=Vector3(0,0.1,16)
	b.position=Vector3(1.55,0.1,16)
	assert(life.start_meetup(a,b,6))
	b.position=Vector3(8,0.1,16)
	for i in range(3):await get_tree().physics_frame
	assert(a.social_partner==null and b.social_partner==null and not a.bubble.visible and not b.bubble.visible,"A separated villager must not keep talking alone")
	a.position=Vector3(0,0.1,16)
	b.position=Vector3(1.55,0.1,16)
	a.social_cooldown=0
	b.social_cooldown=0
	assert(life.start_meetup(a,b,6))
	life.open_dialog(a)
	assert(a.talking and b.social_partner==null,"Player conversation must politely interrupt the pair")
	life.close_dialog()
	a.social_cooldown=50
	a.wait_time=0
	a.destination=0
	a.path=PackedVector3Array()
	a.path_index=0
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(a.work_stops>0 and a.wait_time>=7.8,"Villager must spend real time working")
	assert(a.activity=="Preparing bread" and a.animator.current_animation==a.work_animation(),"Work should show an activity and animation")
	print("BEHAVIOR_VALIDATION_OK paired_stops=6s stationary=true cooldown=true interruption=true work=true events=",life.social_events)
	get_tree().quit()

func validate_entrances() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	player.enabled=false
	player.collision_mask=1
	var checked := 0
	var failed := 0
	for door in get_tree().get_nodes_in_group("doors"):
		var basis_closed: Basis=door.global_basis
		var x: float=door.width/2
		var from: Vector3 = door.global_position+basis_closed*Vector3(x,0.1,-1.2)
		player.position=from
		if not door.is_open:door.toggle(Vector3(0,0,200))
		for i in range(32):await get_tree().physics_frame
		for i in range(48):
			await get_tree().physics_frame
			player.velocity=basis_closed*Vector3(0,-2,3.5)
			player.move_with_steps(1.0/60.0)
		var local: Vector3=basis_closed.inverse()*(player.position-door.global_position)
		var success := local.z>0.9
		if success:checked+=1
		else:failed+=1
		print("ENTRANCE_CHECK ",door.door_name," pass=",success," local=",local)
	assert(checked>=13,"All 13 original houses must be enterable")
	print("ENTRANCE_VALIDATION entered=",checked," failed=",failed)
	get_tree().quit()

func capture_interior() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	set_view(0)
	var house := get_tree().get_nodes_in_group("enterable_houses")[0] as Node3D
	player.position=house.to_global(Vector3(0,0.05,-2.5))
	player.rotation.y=house.rotation.y+PI
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(10):await get_tree().physics_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://../town-interior.png")
	print("INTERIOR_CAPTURE_SAVED")
	get_tree().quit()

func validate_navigation() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	player.enabled=false
	player.position=Vector3(0,0.1,58)
	var segments := 0
	var obstructed := 0
	for person in life.people:
		for i in range(1,person.path.size()):
			var probe: Transform3D=person.global_transform
			probe.origin=person.path[i-1]+Vector3(0,0.06,0)
			var motion: Vector3=person.path[i]-person.path[i-1]
			segments+=1
			if person.test_move(probe,motion):
				obstructed+=1
				print("BLOCKED_SEGMENT ",person.person_name," from=",probe.origin," motion=",motion)
	assert(segments>100,"Need substantial planned routes to audit")
	print("ROUTE_AUDIT segments=",segments," obstructed=",obstructed)
	assert(obstructed==0,"Every planned route segment must clear the actual villager capsule")
	var max_stationary_walking := 0.0
	var stationary: Dictionary={}
	var previous: Dictionary={}
	for person in life.people:previous[person.person_name]=person.position
	for frame in range(1800):
		await get_tree().physics_frame
		if frame%60!=0:continue
		for person in life.people:
			var time: float=stationary.get(person.person_name,0.0)
			if person.activity.begins_with("Walking") and person.wait_time<=0 and not person.social_partner and person.position.distance_to(previous[person.person_name])<0.1:time+=1
			else:time=0
			stationary[person.person_name]=time
			if time>=4:print("STALLED ",person.person_name," position=",person.position," state=",person.activity," wait=",person.wait_time," replans=",person.replans," path_index=",person.path_index," path_size=",person.path.size())
			previous[person.person_name]=person.position
			max_stationary_walking=maxf(max_stationary_walking,time)
	assert(max_stationary_walking<4,"Blocked residents must stop and replan rather than push indefinitely")
	var moving := 0
	var stops := 0
	for person in life.people:
		if person.travelled>2:moving+=1
		stops+=person.work_stops+person.breaks
	assert(moving>=12,"Residents should still travel around town")
	assert(stops>0 and life.social_events>0,"The town should include work/breaks and social stops")
	print("NAVIGATION_VALIDATION_OK segments=",segments," obstructed=",obstructed," movers=",moving," work_break_stops=",stops," social_events=",life.social_events," longest_blocked_walk=",max_stationary_walking)
	get_tree().quit()

func capture_social() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	set_view(0)
	var a: CharacterBody3D=life.people[0]
	var b: CharacterBody3D=life.people[1]
	if a.social_partner:a.end_social()
	if b.social_partner:b.end_social()
	a.position=Vector3(-1,0.1,16)
	b.position=Vector3(1,0.1,16)
	a.social_cooldown=0
	b.social_cooldown=0
	life.start_meetup(a,b,12)
	player.position=Vector3(0,0.1,20)
	player.rotation.y=0
	player.camera.rotation.x=-0.04
	player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(90):await get_tree().physics_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://../town-social.png")
	print("SOCIAL_CAPTURE_SAVED")
	get_tree().quit()

func validate_occupants() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	player.enabled=false
	player.position=Vector3(0,0.1,58)
	var inside := 0
	var vendors := 0
	var stocky := 0
	var start: Dictionary={}
	for person in life.people:
		start[person.person_name]=person.position
		if person.indoor_house:inside+=1
		if not person.stall_name.is_empty():vendors+=1
		if person.appearance_build>1.15:stocky+=1
	assert(inside==6 and vendors==4,"Six interior residents and four stall vendors should be placed")
	assert(stocky==4,"Four villagers should have modest stockier builds")
	assert(get_tree().get_nodes_in_group("market_produce").size()==4,"All four stalls need produce")
	for frame in range(2100):
		await get_tree().physics_frame
		for person in life.people:
			if person.indoor_house:
				var local: Vector3=person.indoor_house.to_local(person.position)
				assert(abs(local.x)<3.5 and abs(local.z)<4.5 and local.y>-0.2,"Interior residents must remain in the room")
			if not person.stall_name.is_empty():assert(person.position.distance_to(person.stall_anchor)<0.2,"Vendors must stay at their stalls")
	var speaker: CharacterBody3D=life.people[6]
	assert(not speaker.stall_name.is_empty())
	life.open_dialog(speaker)
	assert(speaker.speak("What do you sell?").contains("cabbages"),"Vendor must describe their produce")
	life.close_dialog()
	print("OCCUPANTS_VALIDATION_OK indoors=",inside," vendors=",vendors," stocked_stalls=4 stocky=",stocky," duration=35s dialogue=ok")
	get_tree().quit()

func capture_market() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	set_view(0)
	player.position=Vector3(-3,0.1,5)
	player.rotation.y=PI/2
	player.camera.rotation.x=-0.08
	player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(60):await get_tree().physics_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://../town-market.png")
	print("MARKET_CAPTURE_SAVED")
	get_tree().quit()

func validate_cycle() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	player.enabled=false
	assert(not day_night.enabled and not day_night.night,"Cycle must be optional and off by default")
	assert(day_night.cycle_seconds==60,"Default preview must be one minute")
	day_night.set_enabled(true)
	day_night.phase=0.8
	day_night.apply_time()
	day_night.enabled=false # Hold the night while auditing travel.
	assert(day_night.night and get_node("Sun").light_energy<0.3)
	for frame in range(1500):await get_tree().physics_frame
	var sheltered := 0
	for person in life.people:
		if person.indoor_house or person.resting_indoors:sheltered+=1
		else:print("NIGHT_TRAVEL_PENDING ",person.person_name," phase=",person.night_stage," position=",person.position," index=",person.night_index," count=",person.night_path.size())
	assert(sheltered==life.people.size(),"All villagers must reach a building during the preview night")
	day_night.set_enabled(false)
	assert(not day_night.night and get_node("Sun").light_energy>0.6)
	for frame in range(1200):await get_tree().physics_frame
	var vendors_back := 0
	for person in life.people:
		if not person.stall_name.is_empty() and not person.night_schedule:vendors_back+=1
	assert(vendors_back==4,"All vendors should return to their stalls after night")
	print("CYCLE_VALIDATION_OK optional=true default=60s sheltered=",sheltered," vendors_returned=",vendors_back)
	get_tree().quit()

func validate_camera() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	set_view(2)
	player.enabled=false
	var sphere := SphereShape3D.new()
	sphere.radius=0.17
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=sphere
	query.collision_mask=1
	query.exclude=[player.get_rid()]
	var checked := 0
	for house: Node3D in get_tree().get_nodes_in_group("enterable_houses"):
		for angle in [0.0,PI/2,PI,PI*1.5]:
			player.position=house.to_global(Vector3(0,0.03,-1.8))
			player.rotation.y=angle+house.rotation.y
			player.arm.rotation.x=-0.7
			for i in range(4):await get_tree().physics_frame
			query.transform=Transform3D(Basis.IDENTITY,player.third_camera.global_position)
			assert(get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Third-person camera must clear interior walls and ceilings")
			checked+=1
	print("CAMERA_VALIDATION_OK indoor_angles=",checked," wall_roof_clearance=true")
	get_tree().quit()

func capture_night() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	set_view(1)
	day_night.set_enabled(true)
	day_night.phase=0.88
	day_night.apply_time()
	day_night.enabled=false
	for i in range(90):await get_tree().physics_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://../town-night.png")
	print("NIGHT_CAPTURE_SAVED")
	get_tree().quit()

func validate_additions() -> void:
	while get_tree().get_nodes_in_group("animals").size()<9:await get_tree().physics_frame
	player.enabled=false
	assert(locations.size()>=43,"Six extra buildings should be present")
	assert(player.animator.has_animation("RunnerRun") and player.animator.has_animation("RunnerJump"),"Runner animations must be on the player rig")
	assert(get_tree().get_nodes_in_group("beds").size()>=26 and get_tree().get_nodes_in_group("seats").size()>=26)
	for animal in get_tree().get_nodes_in_group("animals"):
		assert(animal.animator and animal.animator.has_animation("Walk") and animal.animator.has_animation("Idle"))
		assert(not animal.visual.find_children("*","MeshInstance3D",true,false).is_empty())
	for frame in range(900):await get_tree().physics_frame
	var moving := 0
	for animal in get_tree().get_nodes_in_group("animals"):
		if animal.travelled>0.5:moving+=1
		assert(animal.position.y> -1 and animal.position.y<1,"Animals must stay grounded")
	assert(moving>=6,"Most animals should roam and rest")
	var person: CharacterBody3D=life.people[3]
	var seat: Node3D=person.indoor_house.find_child("Seat",false,false)
	person.sit_at(seat)
	await get_tree().physics_frame
	assert(person.posture=="sitting" and person.animator.has_animation("SitIdle"))
	person.stand_up()
	assert(person.posture=="standing")
	day_night.set_enabled(true)
	day_night.phase=0.8
	day_night.apply_time()
	day_night.enabled=false
	for frame in range(1650):await get_tree().physics_frame
	var sleepers := 0
	for resident in life.people:
		if resident.posture=="sleeping":sleepers+=1
		else:print("NOT_SLEEPING ",resident.person_name," night_stage=",resident.night_stage," position=",resident.position)
	assert(sleepers==life.people.size(),"Every resident must have a bed at night")
	day_night.set_enabled(false)
	for frame in range(30):await get_tree().physics_frame
	for resident in life.people:assert(resident.posture!="sleeping","Residents must wake up for morning")
	print("ADDITIONS_VALIDATION_OK animals=9 roaming=",moving," locations=32 runner_run_jump=true sitting=true sleeping=",sleepers," wakeup=true")
	get_tree().quit()

func capture_animals() -> void:
	while get_tree().get_nodes_in_group("animals").size()<9:await get_tree().physics_frame
	set_view(1)
	var cow: Node3D=get_tree().get_nodes_in_group("animals")[0]
	overview.position=cow.position+Vector3(5,4,6)
	overview.look_at(cow.position+Vector3(0,0.8,0))
	player.enabled=false
	for i in range(60):await get_tree().physics_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://../town-animals.png")
	print("ANIMALS_CAPTURE_SAVED")
	get_tree().quit()

func capture_rest() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	set_view(0)
	var person: CharacterBody3D=life.people[3]
	var house: Node3D=person.indoor_house
	var seats: Array=[]
	for child in house.get_children():
		if child.is_in_group("seats"):seats.append(child)
	var seat: Node3D=seats[1]
	person.sit_at(seat)
	life.put_to_bed(life.people[9],house)
	player.position=house.to_global(Vector3(0,0.1,-3.1))
	player.rotation.y=house.rotation.y+PI
	player.camera.rotation.x=-0.14
	player.enabled=false
	for i in range(90):await get_tree().physics_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://../town-resting.png")
	print("REST_CAPTURE_SAVED")
	get_tree().quit()

func validate_player_motion() -> void:
	while not life.navigation_ready:await get_tree().physics_frame
	set_view(2)
	player.enabled=false
	var skeleton := player.avatar.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	for clip_name in ["RunnerRun","RunnerJump"]:
		player.animator.play(clip_name)
		player.animator.seek(0.05,true)
		var rotations: Array[Quaternion]=[]
		for bone in range(skeleton.get_bone_count()):rotations.append(skeleton.get_bone_pose_rotation(bone))
		player.animator.seek(0.35,true)
		var changed := 0
		for bone in range(skeleton.get_bone_count()):
			if rotations[bone].angle_to(skeleton.get_bone_pose_rotation(bone))>0.02:changed+=1
		assert(changed>=8,"Transferred motion must animate the actual player skeleton")
		print("PLAYER_CLIP_OK ",clip_name," moving_bones=",changed)
	player.position=Vector3(0,0.1,23)
	player.enabled=true
	for i in range(30):await get_tree().physics_frame
	var ground_y := player.position.y
	player.jump_requested=true
	var top := ground_y
	var played_jump := false
	for i in range(75):
		await get_tree().physics_frame
		top=maxf(top,player.position.y)
		if player.animator.current_animation=="RunnerJump":played_jump=true
	assert(top-ground_y>0.5 and played_jump and player.is_on_floor(),"Space jump must animate, rise, and land")
	print("PLAYER_MOTION_VALIDATION_OK jump_height=",top-ground_y," landed=true")
	get_tree().quit()

func validate_interactions() -> void:
	while get_tree().get_nodes_in_group("animals").size()<9:await get_tree().physics_frame
	set_view(2)
	player.enabled=false
	var seat: Node3D=null
	var bed: Node3D=null
	for item in get_tree().get_nodes_in_group("seats"):
		if not item.has_meta("occupant"):seat=item;break
	for item in get_tree().get_nodes_in_group("beds"):
		if not item.has_meta("occupant"):bed=item;break
	var original := player.global_transform
	assert(player.use_furniture(seat,"sitting") and seat.get_meta("occupant")=="player")
	assert(player.animator.has_animation("SitEnter") and player.animator.has_animation("SitIdle"))
	player.stand_from_furniture()
	assert(player.resting.is_empty() and not seat.has_meta("occupant") and player.global_transform==original)
	assert(player.use_furniture(bed,"sleeping") and player.resting=="sleeping")
	player.stand_from_furniture()
	assert(not bed.has_meta("occupant"))
	var speaker: CharacterBody3D=life.people[0]
	life.nearest=speaker
	var talk_event := InputEventKey.new()
	talk_event.physical_keycode=KEY_F
	talk_event.pressed=true
	life._unhandled_input(talk_event)
	assert(life.active==speaker,"F must open a conversation")
	for topic in ["Your work","Your home","Life here","Animals","Any rumours?","About town"]:
		assert(speaker.speak(topic).length()>200,"Dialogue should provide longer replies")
	var work: String=speaker.speak("Your work")
	var followup: String=speaker.speak("Tell me more")
	assert(work!=followup and followup.length()>200)
	life.send("Your home")
	assert(life.transcript.get_parsed_text().contains("Willow House"))
	life.close_dialog()
	assert(music.volume_db==-34,"Music should be quieter and restored after dialogue")
	for animal in get_tree().get_nodes_in_group("animals"):
		assert(animal.voice.stream and animal.voice.stream.get_length()>0)
		assert(animal.voice.max_distance==38 and animal.voice.unit_size==7)
	var cow: Node3D=get_tree().get_nodes_in_group("animals")[0]
	player.position=cow.position+Vector3(2,0,2)
	set_view(0)
	player.enabled=false
	cow.voice_delay=0
	for frame in range(2):await get_tree().physics_frame
	assert(cow.calls>0,"A nearby animal should emit a positional sound")
	player.position=Vector3(0,0.1,60)
	day_night.set_enabled(true)
	day_night.phase=0.8
	day_night.apply_time()
	day_night.enabled=false
	for frame in range(1800):await get_tree().physics_frame
	var asleep := 0
	var closed := 0
	for resident in life.people:
		if resident.posture=="sleeping":asleep+=1
		if resident.home_door:
			assert(not resident.home_door.is_open,"Occupied houses should close after the last arrival")
			closed+=1
	assert(asleep==life.people.size() and closed>=12)
	print("INTERACTIONS_VALIDATION_OK player_sit_sleep=true F_talk=true longer_dialogue=true spatial_audio=true music=-34dB sleeping=",asleep," closed_doors_for=",closed)
	if "--review-live" in OS.get_cmdline_user_args():
		day_night.set_enabled(false)
		player.position=Vector3(0,0.1,23)
		player.velocity=Vector3.ZERO
		player.rotation=Vector3.ZERO
		player.getting_up=0
		set_view(1)
		update_camera()
		get_viewport().gui_disable_input=false
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		print("UPDATED_PREVIEW_READY residents=22 locations=",locations.size())
	else:get_tree().quit()

