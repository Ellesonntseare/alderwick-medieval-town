extends SceneTree
var town: Node3D
var results: Array[Dictionary]=[]
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800)
	town=load("res://town.tscn").instantiate();root.add_child(town)
	# A test window must not pan its camera when the user types in another app.
	if "--performance-leave-open" not in OS.get_cmdline_user_args():
		town.set_process(false);town.set_process_input(false);town.set_process_unhandled_input(false)
	while not town.life.navigation_ready:await process_frame
	if "--night-homes-only" in OS.get_cmdline_user_args():
		town.speech.enabled=false
		if "--review-objective-anchors" in OS.get_cmdline_user_args():check_objective_anchors()
		await check_night_homes()
		quit(0 if failures.is_empty() else 1)
		return
	if "--profile-lag" in OS.get_cmdline_user_args():
		await profile_lag()
		if "--review-homes" in OS.get_cmdline_user_args():await check_night_homes()
		if "--performance-leave-open" in OS.get_cmdline_user_args():
			town.set_view(1)
			if not town.menu_collapsed:town.toggle_menu()
			return
		quit(0 if failures.is_empty() else 1)
		return
	town.speech.set_enabled(false)
	town.player.position=Vector3(0,.1,23);town.set_view(2)
	Engine.max_fps=60
	for frame in range(240):await process_frame
	print("PERFORMANCE_REVIEW_COMPLETE fps=",Engine.get_frames_per_second()," resident_count=",town.life.people.size())
	if "--performance-leave-open" in OS.get_cmdline_user_args():
		Engine.max_fps=45
		return
	quit()

func profile_lag() -> void:
	var speech_enabled: bool=town.speech.enabled
	var cycle_enabled: bool=town.day_night.enabled
	town.speech.enabled=false
	while not town.home_district.ready_for_spawn:await process_frame
	if town.home_district.inside:town.home_district.leave_home()
	town.day_night.set_enabled(false)
	town.player.position=Vector3(0,.1,23)
	town.player.rotation.y=0
	town.set_view(2)
	town.player.enabled=false
	var settings: Node=town.find_child("*",false,false)
	for child in town.get_children():
		if child.get_script()==load("res://town_performance.gd"):settings=child;break
	while settings.actors.is_empty():await process_frame
	if "--activity-check" in OS.get_cmdline_user_args():
		await check_activity_routes()
	elif "--district-profile" in OS.get_cmdline_user_args():
		settings.choose_quality(0,false)
		for spec in [["archery_overhead",Vector3(35,0,43),26.0]]:
			town.set_view(1);town.overview_focus=spec[1];town.distance=spec[2];town.update_camera()
			if not town.menu_collapsed:town.toggle_menu()
			await create_timer(3).timeout
			await sample(spec[0],5.0)
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../"+spec[0]+"-optimized.png")
		town.set_view(2);town.player.enabled=false
	for quality in [1,0]:
		settings.choose_quality(quality,false)
		await create_timer(3).timeout
		await sample("square_"+str(quality),6.0)
	town.set_view(1)
	town.distance=35.0
	town.update_camera()
	await create_timer(2).timeout
	await sample("square_overhead_0",4.0)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../lag-overhead-preview.png")
	town.set_view(2)
	town.player.enabled=false
	settings.choose_quality(0,false)
	town.speech.enabled=speech_enabled
	town.day_night.set_enabled(cycle_enabled)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../lag-fixed-preview.png")
	var file:=FileAccess.open("res://../lag-profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	print("LAG_PROFILE_COMPLETE residents=",town.life.people.size())

func check_activity_routes() -> void:
	for frame in range(3):await physics_frame
	if town.life.people.size()!=53:failures.append("Town must retain 53 residents")
	for spec in [["Roslin","garden"]]:
		var person: CharacterBody3D
		for resident in town.life.people:
			if resident.person_name==spec[0]:person=resident;break
		if not person:
			failures.append("missing resident "+spec[0]);continue
		town.routines.cancel(person)
		if person.social_partner:person.end_social()
		if person.meeting_partner:town.life.cancel_meeting(person)
		if not town.routines.actions.begin(person,spec[1]):
			failures.append(spec[0]+" cannot route to "+spec[1])
		else:
			print("WORLD_ACTIVITY_ROUTE ",person.person_name," action=",spec[1]," nodes=",person.path.size()," target=",person.routine.target)
	for frame in range(1800):await physics_frame
	if town.routines.actions.completed.training<1:failures.append("training session must finish")
	if town.routines.actions.completed.garden<1:failures.append("gardening session must finish")
	var school: Node=town.routines.actions.get("school")
	if school:
		if school.pupils.size()!=10:failures.append("archery class must contain ten residents")
		if school.shots<10:failures.append("archery class must visibly fire arrows")
		print("WORLD_ARCHERY_REVIEW pupils=",school.pupils.size()," shots=",school.shots)
	print("WORLD_ACTIVITY_REVIEW_COMPLETE failures=",failures," completed=",town.routines.actions.completed)
	var camera_mode: int=town.view_mode
	town.set_view(1)
	var school_camera: Vector3=Vector3(35,0,43)
	town.overview_focus=school_camera;town.distance=26;town.update_camera()
	await create_timer(1).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../archery-town-preview.png")
	town.set_view(camera_mode);town.player.enabled=false


func check_objective_anchors() -> void:
	var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.8
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	for spec in [["missing_delivery",1],["overdue_surveyor",2]]:
		var mission: Dictionary=town.adventures.find_mission(spec[0])
		var point: Vector3=town.adventures.step_position(mission.steps[spec[1]])
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.95)
		var clear: bool=town.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
		var route: PackedVector3Array=town.life.find_route(Vector3(-90,.1,103),point)
		var reachable: bool=not route.is_empty() and Vector2(route[-1].x-point.x,route[-1].z-point.z).length()<1.5
		if not clear or not reachable:failures.append(String(spec[0])+" objective needs a clear reachable anchor")
		print("MISSION_ANCHOR_REVIEW id=",spec[0]," position=",point," clear=",clear," reachable=",reachable)

func check_night_homes() -> void:
	town.day_night.set_enabled(false);town.day_night.set_night(true)
	var old_scale:=Engine.time_scale;Engine.time_scale=3
	var seconds:=0.0
	for frame in range(10000):
		await physics_frame
		seconds+=town.get_physics_process_delta_time()
		if frame%300==0:
			var pending: int=town.day_night.residents_heading_home()
			print("WORLD_NIGHT_PROGRESS seconds=",seconds," pending=",pending)
			if pending==0:break
		if seconds>=480:break
	Engine.time_scale=old_scale
	var sleepers:=0
	for person in town.life.people:
		if person.guard_shift=="night":continue
		if person.posture=="sleeping":
			sleepers+=1
		else:
			failures.append(person.person_name+" must sleep at home")
			print("WORLD_NIGHT_AWAKE name=",person.person_name," stage=",person.night_stage," position=",person.position," path=",person.night_index,"/",person.night_path.size()," door=",person.home_door," bed=",person.assigned_bed)
	print("WORLD_NIGHT_REVIEW_COMPLETE failures=",failures," sleepers=",sleepers," seconds=",seconds)

func sample(label: String,seconds: float) -> void:
	var frames: Array[float]=[]
	var physics:=0.0
	var draws:=0.0
	var finish:=Time.get_ticks_msec()+int(seconds*1000)
	var previous:=Time.get_ticks_usec()
	while Time.get_ticks_msec()<finish:
		await process_frame
		var now:=Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		previous=now
		physics+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var total:=0.0
	for frame in frames:total+=frame
	frames.sort()
	var result: Dictionary={"scene":label,"fps":frames.size()*1000.0/maxf(total,1),"p95_ms":frames[int((frames.size()-1)*.95)],"max_ms":frames[-1],"physics_ms":physics/frames.size(),"draws":draws/frames.size(),"memory_mb":OS.get_static_memory_usage()/1048576.0,"texture_mb":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0}
	results.append(result)
	print("LAG_SAMPLE ",JSON.stringify(result))
