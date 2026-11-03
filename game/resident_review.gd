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

func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../"+path)

func horizontal_distance(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func run() -> void:
	while not town.life.navigation_ready or get_tree().get_nodes_in_group("animals").size()<9:await get_tree().physics_frame
	town.get_viewport().gui_disable_input=true
	town.day_night.set_enabled(false)
	town.set_view(1)
	town.player.enabled=false
	town.player.position=Vector3(0,0.1,60)
	var life: Node=town.life
	check(life.people.size()==45,"Population must be 45 residents")
	var styles: Dictionary={}
	var districts: Dictionary={}
	var new_count := 0
	for person in life.people:
		styles[person.style]=int(styles.get(person.style,0))+1
		var district: String=person.get_meta("district")
		districts[district]=int(districts.get(district,0))+1
		if district=="west":check(person.position.x< -80,"Western residents must actually spawn in the western village")
		if district=="castle":check(person.position.x>75,"Castle residents must actually spawn in their outer district")
		if person.style in life.NEW_STYLES:new_count+=1
		check(person.animator.has_animation("Walk") and person.animator.has_animation("Interact") and person.animator.has_animation("WorkTable"),"Residents must retain usable rigs and activity clips")
		person.social_cooldown=999
	check(styles.size()==8 and new_count>=20 and new_count<=25,"Population must mix the original four and newer four fitted character models")
	check(districts.get("city",0)==31 and districts.get("west",0)==8 and districts.get("castle",0)==6,"Residents must be distributed through the city, western village, and castle districts")
	print("RESIDENT_CAST_OK population=",life.people.size()," new_models=",new_count," original_models=",45-new_count," styles=",styles," districts=",districts)
	var a: CharacterBody3D=life.people[4]
	var b: CharacterBody3D=life.people[8]
	var observer: CharacterBody3D=life.people[12]
	a.position=Vector3(0,0.05,24)
	b.position=Vector3(7,0.05,24)
	observer.position=Vector3(0,0.05,32)
	observer.wait_time=999
	observer.destination=0
	observer.visual.rotation.y=0.73
	var observer_yaw: float=observer.visual.rotation.y
	a.visual.rotation.y=0.45
	a.social_cooldown=0
	b.social_cooldown=0
	var b_start: Vector3=b.position
	check(life.invite_meetup(a,b),"Residents several metres apart must be able to arrange a meeting")
	var premature_turn := false
	for frame in range(1080):
		await get_tree().physics_frame
		if a.social_partner==b:break
		if a.meeting_partner and absf(angle_difference(a.visual.rotation.y,0.45))>0.05:premature_turn=true
	check(a.social_partner==b and b.social_partner==a,"Residents must walk together before starting dialogue")
	check(horizontal_distance(b.position,b_start)>2,"An invited resident must physically walk to the partner")
	check(not premature_turn,"A waiting resident must not face a partner before they start talking")
	var a_start: Vector3=a.position
	var conversation_position: Vector3=(a.position+b.position)*0.5
	for frame in range(150):await get_tree().physics_frame
	check(a.social_partner==b and b.social_partner==a,"Conversation partners must stay together for several seconds")
	check(horizontal_distance(a.position,b.position)>=1.05 and horizontal_distance(a.position,b.position)<=1.9,"Conversation partners must stand beside one another with body clearance")
	check(horizontal_distance(a.position,a_start)<0.15,"Talking residents should stand still")
	var facing: Vector3=(b.position-a.position).normalized()
	check(a.visual.global_basis.z.normalized().dot(facing)>0.9 and b.visual.global_basis.z.normalized().dot(-facing)>0.9,"Only the active partners should face one another")
	check(absf(angle_difference(observer.visual.rotation.y,observer_yaw))<0.02,"A non-participant must retain their own facing direction")
	town.overview.position=conversation_position+Vector3(7,4.7,9)
	town.overview.look_at(conversation_position+Vector3(0,1.1,0))
	await capture("residents-45-conversation.png")
	print("RESIDENT_MEETING_OK approached_metres=",horizontal_distance(b.position,b_start)," pair_gap=",horizontal_distance(a.position,b.position)," unrelated_yaw=",observer.visual.rotation.y)
	for frame in range(900):
		await get_tree().physics_frame
		if not a.social_partner and not b.social_partner:break
	check(not a.social_partner and not b.social_partner and a.social_cooldown>0 and b.social_cooldown>0,"Both residents must finish the chat and resume their routines")
	a.position=Vector3(0,0.05,24)
	b.position=Vector3(7,0.05,24)
	a.social_cooldown=0
	b.social_cooldown=0
	check(life.invite_meetup(a,b),"The interruption check needs an approaching pair")
	life.open_dialog(a)
	check(a.talking and not a.meeting_partner and not b.meeting_partner and not b.bubble.visible,"Player dialogue must release an approaching partner without solo speech")
	life.close_dialog()
	town.player.enabled=false
	observer.wait_time=0
	for person in life.people:person.social_cooldown=life.social_rng.randf_range(0,2)
	var events_before: int=life.social_events
	var invitations_before: int=life.meeting_invitations
	var max_pairs := 0
	for frame in range(1800):
		await get_tree().physics_frame
		if frame%60!=0:continue
		var chatting := 0
		for person in life.people:
			if person.social_partner:chatting+=1
		max_pairs=maxi(max_pairs,chatting/2)
	var movers := 0
	for person in life.people:
		if not person.indoor_house and person.stall_name.is_empty() and person.travelled>2:movers+=1
	check(life.social_events-events_before>=3 and life.meeting_invitations-invitations_before>=2 and max_pairs>=2,"Several autonomous meetings must occur without placing people by hand")
	check(movers>=15,"Residents must continue travelling around the city between activities")
	print("RESIDENT_AUTONOMY_OK chats=",life.social_events-events_before," walk_over_invitations=",life.meeting_invitations-invitations_before," max_chatting_pairs=",max_pairs," outdoor_movers=",movers)
	town.day_night.set_enabled(true)
	town.day_night.phase=0.8
	town.day_night.apply_time()
	town.day_night.enabled=false
	for person in life.people:check(not person.meeting_partner and not person.social_partner,"Nightfall must cancel social plans")
	var sleeping := 0
	for frame in range(3600):
		await get_tree().physics_frame
		if frame%300!=0:continue
		sleeping=0
		for person in life.people:
			if person.posture=="sleeping":sleeping+=1
		print("RESIDENT_NIGHT_PROGRESS ",frame/60,"s sleepers=",sleeping)
		if sleeping==45:break
	check(sleeping==45,"All 45 residents must still reach their beds")
	if sleeping!=45:
		for person in life.people:
			if person.posture!="sleeping":print("RESIDENT_PENDING ",person.person_name," stage=",person.night_stage," at=",person.position," next=",person.night_path[person.night_index] if person.night_index<person.night_path.size() else Vector3.ZERO)
	town.day_night.set_enabled(false)
	for frame in range(180):await get_tree().physics_frame
	for person in life.people:check(person.posture!="sleeping","Residents must wake up for the next day")
	town.player.position=Vector3(0,0.1,23)
	town.set_view(1)
	town.update_camera()
	town.get_viewport().gui_disable_input=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	print("RESIDENT_REVIEW_COMPLETE failures=",failures," residents=",life.people.size()," newer_models=",new_count," original_models=",45-new_count)
	if "--review-residents-live" not in OS.get_cmdline_user_args():get_tree().quit(0 if failures.is_empty() else 1)
