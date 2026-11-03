extends Node

var town: Node3D

func _ready() -> void:
	town=get_parent()
	run.call_deferred()

func capture(file: String,point: Vector3,offset: Vector3) -> void:
	town.overview.position=point+offset
	town.overview.look_at(point+Vector3.UP*0.9)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../"+file)

func run() -> void:
	while not town.life.navigation_ready or get_tree().get_nodes_in_group("animals").size()<9:await get_tree().physics_frame
	town.get_viewport().gui_disable_input=true
	town.day_night.set_enabled(false)
	town.set_view(1)
	town.player.enabled=false
	var farmer: CharacterBody3D
	for frame in range(1800):
		await get_tree().physics_frame
		for person in town.life.people:
			if person.carry_kind=="carrots":farmer=person;break
		if farmer:break
	if farmer:
		await get_tree().create_timer(0.5).timeout
		await capture("town-grounded-farmer.png",farmer.position,farmer.visual.global_basis*Vector3(3,2,4.1))
	town.toggle_menu()
	await capture("town-market-collapsed.png",Vector3(-1,0,6),Vector3(17,15,21))
	var dog: CharacterBody3D
	for animal in get_tree().get_nodes_in_group("animals"):
		if animal.species=="Pug":dog=animal
	if dog:
		await capture("town-small-dog-roaming.png",dog.position,Vector3(1.6,1.1,2.2))
		print("DOG_NATIVE_PREVIEW travelled=",dog.travelled," height=",dog.desired_height," state=",dog.state)
	town.day_night.set_enabled(true)
	town.day_night.phase=0.85
	town.day_night.apply_time()
	town.day_night.enabled=false
	await get_tree().create_timer(6).timeout
	await capture("town-warm-night.png",Vector3(-6,0,10),Vector3(22,11,27))
	print("ATMOSPHERE_NATIVE_REVIEW glow=",town.atmosphere.night_glow," visible_lights=",town.atmosphere.enabled_lights," window_panes=",town.atmosphere.windows.size())
	town.day_night.set_enabled(false)
	if town.menu_collapsed:town.toggle_menu()
	var seller: CharacterBody3D=town.economy.seller_for("city")
	# The trade panel is usable immediately, even while the separate chat
	# model is still loading. This preview never changes the player's money.
	await capture("town-market-daylight.png",Vector3(0,0,5),Vector3(18,16,25))
	town.player.position=Vector3(0,0.15,23)
	town.set_view(1)
	town.update_camera()
	town.player.enabled=false
	town.get_viewport().gui_disable_input=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	print("TOWN_LIFE_PREVIEW_READY population=",town.life.people.size()," purse=",town.economy.player_coins," music_playing=",town.music.playing," night_watch=",town.jobs.night_guards.size()," renders=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," fps=",Engine.get_frames_per_second())
	if "--capture-town-life" in OS.get_cmdline_user_args():get_tree().quit()
