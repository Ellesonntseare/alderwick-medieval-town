extends SceneTree

func _initialize() -> void:run.call_deferred()

func run() -> void:
	root.title="Creating character portraits"
	root.size=Vector2i(320,400)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(256,320)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var env_node := WorldEnvironment.new()
	stage.add_child(env_node)
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("34443c")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("f7e8d4")
	environment.ambient_light_energy=0.7
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env_node.environment=environment
	var key := DirectionalLight3D.new()
	stage.add_child(key)
	key.rotation_degrees=Vector3(-25,-30,0)
	key.light_color=Color("ffe8c8")
	key.light_energy=1.0
	key.shadow_enabled=false
	var fill := OmniLight3D.new()
	stage.add_child(fill)
	fill.position=Vector3(-1,2,2)
	fill.light_color=Color("c8dcff")
	fill.light_energy=0.7
	fill.omni_range=5
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.fov=32
	var display := TextureRect.new()
	display.texture=viewport.get_texture()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(display)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://portraits"))
	var roster=JSON.parse_string(FileAccess.get_file_as_string("res://characters/roster_appearance.json"))
	var made := 0
	for entry in roster:
		var person: CharacterBody3D=load("res://villager.gd").new()
		person.person_name=entry.name
		person.style=entry.style
		stage.add_child(person)
		person.set_physics_process(false)
		person.bubble.hide()
		person.animator.play("Idle")
		person.animator.advance(0.3)
		person.animator.pause()
		var skeleton: Skeleton3D=person.visual.find_children("*","Skeleton3D",true,false)[0]
		var head := skeleton.find_bone("Head")
		var target := Vector3(0,1.6,0)
		if head>=0:target=skeleton.to_global(skeleton.get_bone_global_pose(head).origin)+Vector3.UP*0.10
		camera.position=target+Vector3(0,0.025,1.12)
		camera.look_at(target)
		root.title="Character portrait: "+person.person_name+" ("+str(made+1)+"/"+str(roster.size())+")"
		for frame in range(3):await process_frame
		await RenderingServer.frame_post_draw
		var portrait := viewport.get_texture().get_image()
		var error := portrait.save_png("res://portraits/"+person.person_name+".png")
		if error!=OK:push_error("Portrait could not save: "+person.person_name);quit(1);return
		print("CHARACTER_PORTRAIT_READY name=",person.person_name," style=",person.style," size=",portrait.get_size())
		made+=1
		person.queue_free()
		await process_frame
	print("PORTRAIT_CAPTURE_COMPLETE faces=",made)
	quit(0 if made==roster.size() else 1)
