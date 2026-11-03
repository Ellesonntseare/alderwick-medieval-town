extends Node

var town: Node3D
var failures: Array[String]=[]

func _ready() -> void:
	town=get_parent()
	run.call_deferred()

func check(value: bool,message: String) -> void:
	if value:return
	failures.append(message)
	push_error(message)

func horizontal(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func run() -> void:
	while not town.life.navigation_ready or get_tree().get_nodes_in_group("animals").size()<9:await get_tree().physics_frame
	town.day_night.set_enabled(false)
	town.speech.set_enabled(false)
	town.player.enabled=false
	town.player.position=Vector3(0,0.1,60)
	var life: Node=town.life
	if "--inspect-castle-route" in OS.get_cmdline_user_args():
		var person: CharacterBody3D=life.people[42]
		var room: Node3D=town.expansion.rooms[1]
		var bed: Node3D=life.reserve_bed(person,room)
		var target: Vector3=life.bedside_position(person,bed)
		var route: PackedVector3Array=life.indoor_route(person,room,Vector3(115,0.24,80.1),target)
		print("CASTLE_FOCUSED_ROUTE nodes=",route.size()," target=",target)
		var shape := CapsuleShape3D.new()
		shape.radius=0.36
		shape.height=1.7
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape=shape
		query.collision_mask=1
		query.exclude=[town.player.get_rid(),person.get_rid()]
		for z in [80,78,76,74,72,70,68,66,64,62,60]:
			query.transform=Transform3D(Basis.IDENTITY,Vector3(114.8,1.3,z))
			var hits := town.get_world_3d().direct_space_state.intersect_shape(query,5)
			var labels: Array[String]=[]
			for hit in hits:labels.append(str(hit.collider.get_path()))
			print("CASTLE_CORRIDOR_SAMPLE z=",z," hits=",labels)
		get_tree().quit()
		return
	for frame in range(60):await get_tree().physics_frame
	check(life.people.size()==45,"Town must retain exactly 45 residents")
	var shield_count := 0
	for person in life.people:
		if person.style in ["knight","viking"]:
			shield_count+=1
			check(not person.guard_label.is_empty() and person.job.get("kind")=="guard","Every shield-bearing resident must have a fixed guard job")
	check(shield_count==13,"All thirteen shield-bearing characters must be used")
	var starts: Dictionary={}
	for guard in town.jobs.guards:starts[guard]=guard.guard_post
	var carry_seen := 0
	var pose_updates := 0
	var max_hand_error := 0.0
	for frame in range(7200):
		await get_tree().physics_frame
		if frame%300!=0:continue
		for guard in town.jobs.guards:check(horizontal(guard.position,starts[guard])<0.18,"Day guard must remain at their post: "+guard.person_name)
		for person in life.people:
			if not person.carry_kind.is_empty():
				carry_seen+=1
				pose_updates+=person.carry_pose_updates
				max_hand_error=maxf(max_hand_error,person.carry_hand_error)
		print("JOBS_DAY_PROGRESS ",frame/60,"s farm_deliveries=",town.jobs.deliveries," furniture=",town.jobs.furniture_made," supply_runs=",town.jobs.supplies_delivered)
	check(town.jobs.deliveries>=3,"Farmers must actually deliver produce to market")
	check(town.jobs.furniture_made>=4,"Carpenters must produce visible finished furniture")
	check(town.jobs.supplies_delivered>=3,"Couriers must complete supply deliveries")
	check(carry_seen>5 and pose_updates>0 and max_hand_error<0.2,"Carrying must show loaded crates with both hands following them")
	var stock := 0
	for market in town.jobs.markets.values():stock+=int(market.stock)
	check(stock==town.jobs.deliveries,"Visible market stock must match completed farmer deliveries")
	var memory_checked := false
	for person in life.people:
		if not person.recent_events.is_empty():
			var answer: String=person.speak("Your work")
			check(answer.contains(person.recent_events[-1].text),"Dialogue must refer to completed events from this resident's own day")
			memory_checked=true
			break
	check(memory_checked,"At least one completed job must be remembered")
	print("JOBS_RESULTS farm=",town.jobs.deliveries," furniture=",town.jobs.furniture_made," supplies=",town.jobs.supplies_delivered," carrying_samples=",carry_seen," hand_error=",max_hand_error," guard_posts=",town.jobs.guards.size())
	for person in life.people:
		if not person.job.is_empty() and person.job.kind!="guard" and person.job.get("completed",0)==0:print("JOB_PENDING ",person.person_name," job=",person.job," at=",person.position," path=",person.path_index,"/",person.path.size())
	town.day_night.set_enabled(true)
	town.day_night.phase=0.8
	town.day_night.apply_time()
	town.day_night.enabled=false
	var sleeping := 0
	for frame in range(5400):
		await get_tree().physics_frame
		if frame%300!=0:continue
		sleeping=0
		for person in life.people:
			if person.posture=="sleeping":sleeping+=1
		print("JOBS_NIGHT_PROGRESS ",frame/60,"s sleepers=",sleeping," queue_crossings=",life.traffic.crossings," largest_queue=",life.traffic.max_queue)
		if sleeping==45:break
	check(sleeping==45,"Every resident, including all guards, must reach a bed at night")
	if sleeping!=45:
		for person in life.people:
			if person.posture!="sleeping":print("NIGHT_PENDING ",person.person_name," stage=",person.night_stage," at=",person.position," goal=",person.night_path[person.night_index] if person.night_index<person.night_path.size() else Vector3.ZERO)
	town.day_night.set_enabled(false)
	var returned := 0
	for frame in range(5400):
		await get_tree().physics_frame
		if frame%300!=0:continue
		returned=0
		for guard in town.jobs.guards:
			if not guard.night_schedule and horizontal(guard.position,guard.guard_post)<0.25:returned+=1
		print("GUARDS_MORNING_PROGRESS ",frame/60,"s posted=",returned,"/",town.jobs.guards.size())
		if frame==1200 or frame==1800:
			for guard in town.jobs.guards:
				if guard.night_schedule or horizontal(guard.position,guard.guard_post)>0.25:print("GUARD_COMMUTE ",guard.person_name," stage=",guard.night_stage," at=",guard.position," remaining=",horizontal(guard.position,guard.guard_post))
		if returned==town.jobs.guards.size():break
	check(returned==town.jobs.guards.size(),"All guards must return to their fixed posts in the morning")
	if returned!=town.jobs.guards.size():
		for guard in town.jobs.guards:
			if guard.night_schedule or horizontal(guard.position,guard.guard_post)>0.25:print("GUARD_PENDING ",guard.person_name," stage=",guard.night_stage," at=",guard.position," post=",guard.guard_post)
		for person in life.people:
			if person.night_schedule:print("EXIT_PENDING ",person.person_name," stage=",person.night_stage," at=",person.position," goal=",person.night_path[person.night_index] if person.night_index<person.night_path.size() else Vector3.ZERO)
	town.player.position=Vector3(0,0.1,23)
	town.set_view(1)
	town.update_camera()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	print("ACTIVITY_REVIEW_COMPLETE failures=",failures)
	if "--review-activities-live" not in OS.get_cmdline_user_args():get_tree().quit(0 if failures.is_empty() else 1)
