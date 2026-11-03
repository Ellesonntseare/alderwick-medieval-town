extends Node

var town: Node3D

func _ready() -> void:
	town=get_parent()
	run.call_deferred()

func capture(file: String,point: Vector3,offset: Vector3) -> void:
	town.overview.position=point+offset
	town.overview.look_at(point+Vector3.UP*1.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../"+file)

func run() -> void:
	while not town.life.navigation_ready or get_tree().get_nodes_in_group("animals").size()<9:await get_tree().physics_frame
	town.get_viewport().gui_disable_input=true
	town.day_night.set_enabled(false)
	town.set_view(1)
	town.player.enabled=false
	var guard: CharacterBody3D=town.jobs.guards[0]
	await capture("town-guard-watch.png",guard.position,Vector3(3.6,2.6,4.5))
	var farmer: CharacterBody3D
	for frame in range(2400):
		await get_tree().physics_frame
		for person in town.life.people:
			if person.carry_kind=="carrots":farmer=person;break
		if farmer:break
	if farmer:
		await get_tree().create_timer(0.6).timeout
		town.player.position=farmer.position+Vector3(0,0.2,6)
		await capture("town-farmer-delivery.png",farmer.position,farmer.visual.global_basis*Vector3(3.4,2.4,4.2))
	for person in town.life.people:
		if person.carry_kind=="supplies":
			await get_tree().create_timer(0.4).timeout
			await capture("town-supply-run.png",person.position,person.visual.global_basis*Vector3(3.4,2.4,4.2))
			break
	for frame in range(1200):
		await get_tree().physics_frame
		var worker: CharacterBody3D
		for person in town.life.people:
			if person.job.get("stage")=="crafting":worker=person;break
		if worker:
			await get_tree().create_timer(0.8).timeout
			await capture("town-carpenter-at-work.png",worker.position,worker.visual.global_basis*Vector3(3.5,3.0,4.8))
			break
	var started := Time.get_ticks_msec()
	while not town.speech.available and Time.get_ticks_msec()-started<20000:await get_tree().process_frame
	if town.speech.available:
		town.player.position=guard.position+Vector3(0,0.2,4)
		town.life.open_dialog(guard)
		started=Time.get_ticks_msec()
		var voice: AudioStreamPlayer3D=town.speech.configure(guard)
		while not voice.playing and Time.get_ticks_msec()-started<30000:await get_tree().process_frame
		if voice.playing:
			print("NEURAL_DIALOGUE_PLAYBACK_OK profile=",town.speech.profile(guard)," duration=",voice.stream.get_length()," max_distance=",voice.max_distance)
			await capture("town-voiced-guard-dialogue.png",guard.position,Vector3(3.5,2.3,4.5))
			var duration: float=minf(voice.stream.get_length(),8.0)
			await get_tree().create_timer(duration).timeout
		else:push_error("Character voice did not begin playback")
		town.life.close_dialog()
	else:push_error("Local character voice service did not become available")
	town.player.position=Vector3(0,0.2,23)
	town.set_view(1)
	town.update_camera()
	town.get_viewport().gui_disable_input=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	print("WORK_PREVIEW_READY population=",town.life.people.size()," fixed_guards=",town.jobs.guards.size()," produce_deliveries=",town.jobs.deliveries," furniture=",town.jobs.furniture_made," supplies=",town.jobs.supplies_delivered," voices_ready=",town.speech.available)
