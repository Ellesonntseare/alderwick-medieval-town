extends SceneTree

var stage: Node3D
var camera: Camera3D
var failures: Array[String]=[]

func _initialize() -> void:
	call_deferred("review")

func check(value: bool,message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func animator(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:return node
	for child in node.get_children():
		var found := animator(child)
		if found:return found
	return null

func review() -> void:
	stage=Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("3e4d58")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=0.8
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees=Vector3(-35,-25,0)
	light.light_energy=1.7
	var floor_mesh := MeshInstance3D.new()
	var floor_shape := BoxMesh.new()
	floor_shape.size=Vector3(30,0.2,30)
	floor_mesh.mesh=floor_shape
	floor_mesh.position.y=-0.1
	stage.add_child(floor_mesh)
	floor_mesh.create_trimesh_collision()
	camera=Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=9.0
	camera.position=Vector3(0,2.6,7)
	camera.look_at(Vector3(0,0.95,0))
	root.size=Vector2i(1440,850)
	if "--dog" in OS.get_cmdline_user_args():
		await review_dog()
	elif "--player" in OS.get_cmdline_user_args():
		await review_player()
	else:
		await review_rigs()
	print("RIG_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)

func review_dog() -> void:
	var person: Node3D=load("res://characters/medieval.glb").instantiate()
	stage.add_child(person)
	person.position.x=-0.65
	animator(person).play("Idle")
	var animal := CharacterBody3D.new()
	animal.set_script(load("res://animal.gd"))
	animal.species="Pug"
	animal.desired_height=0.3
	stage.add_child(animal)
	animal.set_physics_process(false)
	animal.position.x=0.65
	camera.size=2.6
	camera.position=Vector3(0,1.5,5)
	camera.look_at(Vector3(0,0.85,0))
	for clip in ["Idle","Walk"]:
		animal.animator.play(clip)
		animal.animator.seek(0.2,true)
		animal.animator.pause()
		var size: Vector3=(animal.visual.global_transform*animal.animated_bounds()).size
		check(size.y>0.25 and size.y<0.36,"Dog's animated visible height must be about 30cm")
		print("DOG_VISIBLE_SIZE_OK ",clip," ",size)
		await capture("dog-size-"+clip.to_lower()+".png")

func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../"+path))

func review_rigs() -> void:
	var styles := ["emlyn"] if "--emlyn" in OS.get_cmdline_user_args() else ["knight","mercenary","night_hunter","viking"]
	if "--approved-adults" in OS.get_cmdline_user_args():styles=["saxon","bruce","armoured_assassin","robed_scholar","medieval_woman","cult_archer"]
	if "--approved-outfits" in OS.get_cmdline_user_args():styles=["male_peasant","female_peasant","male_ranger","female_ranger","runner_child","runner_youth"]
	if styles.size()>4:camera.size=14
	var models: Array[Node3D]=[]
	var players: Array[AnimationPlayer]=[]
	for i in range(styles.size()):
		var model := CharacterBody3D.new()
		model.set_script(load("res://villager.gd"))
		model.style=styles[i]
		stage.add_child(model)
		model.position.x=(i-(styles.size()-1)/2.0)*2.0
		model.set_physics_process(false)
		models.append(model)
		var motion := animator(model)
		players.append(motion)
		check(motion!=null,styles[i]+" has an AnimationPlayer")
		for clip in ["Idle","Walk","Run","SitEnter","SitIdle","SitExit","SleepExit","WorkTable","WorkHarvest"]:
			check(motion.has_animation(clip),styles[i]+" missing "+clip)
		var skeleton := model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
		check(skeleton.get_bone_count()>=22,styles[i]+" missing fitted skeleton")
		motion.play("Walk")
		motion.seek(0.05,true)
		skeleton.force_update_all_bone_transforms()
		var before: Array[Vector3]=[]
		for b in range(skeleton.get_bone_count()):before.append(skeleton.get_bone_global_pose(b).origin)
		motion.seek(0.45,true)
		skeleton.force_update_all_bone_transforms()
		var moving := 0
		for b in range(skeleton.get_bone_count()):
			if before[b].distance_to(skeleton.get_bone_global_pose(b).origin)>0.015:moving+=1
		check(moving>=8,styles[i]+" walk must move limbs")
		print("RIG_ENGINE_OK ",styles[i]," bones=",skeleton.get_bone_count()," moving_walk_bones=",moving)
	for clip in ["Idle","Walk","SitIdle","SleepExit"]:
		for motion in players:
			motion.play(clip)
			motion.seek(0.25 if clip!="SleepExit" else 0.0,true)
			motion.pause()
		await capture("characters-engine-"+clip.to_lower()+".png")
	for i in range(models.size()):
		camera.size=2.5
		camera.position=Vector3(models[i].position.x,1.45,4.0)
		camera.look_at(models[i].position+Vector3(0,1.0,0))
		players[i].play("Idle")
		players[i].seek(0,true)
		players[i].pause()
		await capture("character-close-"+styles[i]+".png")
	for model in models:model.queue_free()

func review_player() -> void:
	var player := CharacterBody3D.new()
	player.set_script(load("res://player.gd"))
	stage.add_child(player)
	player.set_view(2)
	player.third_camera.current=false
	camera.current=true
	player.enabled=false
	camera.size=3.0
	camera.position=Vector3(0,1.6,-5)
	camera.look_at(Vector3(0,0.95,0))
	var skeleton := player.avatar.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	for clip in ["Idle","PlayerIdle","Walk","RunnerRun","RunnerJump"]:
		check(player.animator.has_animation(clip),"Player missing "+clip)
		player.animator.play(clip,0)
		player.animator.seek(0.25,true)
		player.animator.pause()
		skeleton.force_update_all_bone_transforms()
		var hips := skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
		var head := skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
		print("PLAYER_POSTURE ",clip," sideways=",head.x-hips.x," hips=",hips," head=",head)
		await capture("player-review-"+clip.to_lower()+".png")
	player.position=Vector3(0,0.05,0)
	player.enabled=true
	for i in range(20):await physics_frame
	var ground_y := player.position.y
	player.jump_requested=true
	var top := ground_y
	var jump_seen := false
	for i in range(90):
		await physics_frame
		top=maxf(top,player.position.y)
		if player.animator.current_animation=="RunnerJump":jump_seen=true
	check(jump_seen and top-ground_y>0.5 and player.is_on_floor(),"Player must jump, animate and land")
	print("PLAYER_JUMP_OK height=",top-ground_y," landed=",player.is_on_floor())
	var chair := Marker3D.new()
	stage.add_child(chair)
	chair.position=Vector3(-18,0.52,12)
	var bed := Marker3D.new()
	stage.add_child(bed)
	bed.position=Vector3(20,-59.4,12)
	player.use_furniture(chair,"sitting")
	player.stand_from_furniture()
	player.use_furniture(bed,"sleeping")
	player.stand_from_furniture()
	player.getting_up=0
	player.position=Vector3(0,0.1,0)
	player.set_view(2)
	for i in range(20):await physics_frame
	check(player.avatar.position.length()<0.01,"Furniture transitions must not leave the avatar away from its body")
	check(root.get_camera_3d()==player.third_camera and player.avatar.visible,"Third-person view must select its own camera and show the avatar")
	check(player.third_camera.global_position.distance_to(player.global_position)>1.0,"Third-person camera must sit outside the body")
	print("THIRD_PERSON_AFTER_FURNITURE_OK avatar_offset=",player.avatar.position.length()," camera_distance=",player.third_camera.global_position.distance_to(player.global_position))
	await capture("third-person-after-furniture.png")
