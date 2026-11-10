extends "res://performance_review.gd"

func run() -> void:
	var launch_started:=Time.get_ticks_msec()
	root.size=Vector2i(1280,800)
	root.set_disable_input(true)
	create_timer(360,true,false,true).timeout.connect(func():push_error("Performance review timed out");quit(1))
	town=load("res://town.tscn").instantiate()
	root.add_child(town)
	town.set_process(false)
	town.set_process_input(false)
	town.set_process_unhandled_input(false)
	while not town.life.navigation_ready:await process_frame
	while not town.interface_ui.ready_for_use or not town.home_district.ready_for_spawn:await process_frame
	print("CURRENT_STARTUP_READY elapsed_ms=",Time.get_ticks_msec()-launch_started)
	print("MOTION_CACHE_STATUS hits=",preload("res://prepared_motion_cache.gd").hits," misses=",preload("res://prepared_motion_cache.gd").misses)
	if "--startup-only" in OS.get_cmdline_user_args():quit();return
	town.interface_ui.close()
	paused=false
	if town.home_district.inside:town.home_district.leave_home()
	town.day_night.set_enabled(false)
	var settings: Node
	for child in town.get_children():
		if child.get_script()==load("res://town_performance.gd"):settings=child;break
	while settings.actors.is_empty():await process_frame
	settings.choose_quality(0,false)
	town.player.position=Vector3(0,.1,23)
	town.player.rotation.y=0
	town.set_view(2)
	town.player.enabled=false
	await create_timer(4).timeout
	preload("res://frame_costs.gd").reset()
	await sample("square_third_person_no_ai",15)
	await screenshot("optimized-square")
	town.set_view(1)
	town.overview_focus=Vector3(35,0,43)
	town.distance=26
	town.update_camera()
	await create_timer(3).timeout
	await sample("archery_overhead_no_ai",15)
	await screenshot("optimized-archery")
	await check_offline_world()
	preload("res://frame_costs.gd").enabled=false
	var file:=FileAccess.open("res://../review/current-no-ai-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"quality":"Performance","window":"1280x800","residents":town.life.people.size(),"results":results,"trace":preload("res://frame_costs.gd").report()},"\t"))
	print("CURRENT_PERFORMANCE_COMPLETE failures=",failures," ai_disabled=",not preload("res://dialogue_features.gd").ENABLED)
	quit(0 if failures.is_empty() else 1)

func screenshot(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../review/"+label+".png")

func check_offline_world() -> void:
	var people: Dictionary={}
	for person in town.life.people:people[person.person_name]=person
	town.adventures.progress.missing_delivery={"status":"offered","step":0}
	var ada: CharacterBody3D=people.Ada
	town.player.position=ada.position+Vector3(0,0,1.8)
	town.life.open_dialog(ada,false)
	town.adventures.refresh_conversation_action()
	if not town.adventures.conversation_action.visible:failures.append("Offline mission acceptance button missing")
	town.adventures.conversation_action.pressed.emit()
	if town.adventures.progress.missing_delivery.status!="active":failures.append("Offline mission was not accepted through the resident panel")
	town.life.close_dialog()
	var corvin: CharacterBody3D=people.Corvin
	town.player.position=corvin.position+Vector3(0,0,1.8)
	town.life.open_dialog(corvin,false)
	town.adventures.refresh_conversation_action()
	town.adventures.conversation_action.pressed.emit()
	if int(town.adventures.progress.missing_delivery.step)!=1 or town.life.entry.visible:failures.append("Offline clue action or disabled chat input regressed")
	await screenshot("offline-mission-in-town")
	town.life.close_dialog()
	for tier in range(3):
		town.challenges.completions.delivery=tier
		var spec: Dictionary=town.challenges.contract("delivery")
		var route: PackedVector3Array=town.life.find_route(Vector3(-32,.1,37),spec.destination)
		if route.is_empty() or route[-1].distance_to(spec.destination)>3:failures.append("Delivery destination is unreachable: "+spec.destination_name)
	print("OFFLINE_WORLD_ACTIONS_REVIEW_COMPLETE mission_button=true clue_button=true chat_hidden=",not town.life.entry.visible," failures=",failures)
