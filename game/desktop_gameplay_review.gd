extends SceneTree

var failures: Array[String] = []
var stage := ""
var profile := ""
var town: Node3D

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pc-stage="):stage = argument.trim_prefix("--pc-stage=")
		if argument.begins_with("--pc-profile="):profile = argument.trim_prefix("--pc-profile=")
	if stage not in ["play", "resume", "night"] or not profile.is_valid_identifier():
		push_error("Pass --pc-stage=play|resume|night and an isolated --pc-profile=identifier");quit(1);return
	var name := "Alderwick-review/" + profile
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", name)
	var user_path := ProjectSettings.globalize_path("user://")
	if not user_path.ends_with("/" + name + "/") or DirAccess.make_dir_recursive_absolute(user_path) != OK:
		push_error("Failed to isolate the test profile");quit(1);return
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:print("PC_GAMEPLAY_PASS ", label)
	else:failures.append(label);push_error(label)

func press_button(parent: Node, title: String) -> bool:
	for button: Button in parent.find_children("*", "Button", true, false):
		if button.text == title:
			button.pressed.emit()
			return true
	return false

func key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code;event.keycode = code;event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code);key(code, false)
	Input.flush_buffered_events()
	await process_frame;await process_frame

func ticks(count: int) -> void:
	for index in range(count):await physics_frame

func run() -> void:
	root.size = Vector2i(1280, 800)
	create_timer(190, true, false, true).timeout.connect(func():push_error("Desktop gameplay review timed out");quit(1))
	var boot: Control = load("res://town_boot.tscn").instantiate()
	root.add_child(boot);current_scene = boot
	var title := "Enter town" if stage == "play" else "Continue town"
	check(boot.skin_buttons.size() == 22, "Title shows all 22 character appearances")
	if stage == "play":boot.skin_buttons.runner_child.pressed.emit()
	check(boot.selected_skin == "runner_child", "Selected appearance survives title and restart")
	if not press_button(boot.main_column, title):check(false, title + " button is available");quit(1);return
	await scene_changed
	town = current_scene
	check(is_instance_valid(town.loading_screen), "Joining shows the desktop loading screen")
	while not town.session or not town.session.restored or town.loading_screen:await process_frame
	check(town.session.ready_for_use and town.player.skin_id == "runner_child", "Normal entry loads the selected character")
	match stage:
		"play":await play()
		"resume":await resume()
		"night":await cycle_through_night()
	print("PC_GAMEPLAY_REVIEW_COMPLETE stage=", stage, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func play() -> void:
	await ticks(20)
	var player: CharacterBody3D = town.player
	var home: Node3D = town.home_district
	check(home.inside and player.is_on_floor() and town.player_home.house == home.interior, "New player starts on the floor inside their own home")
	check(town.view_mode == 0 and player.camera.current and player.enabled, "New player starts with first-person controls")
	await check_stamina()
	check(town.life.people.size() == 53, "Live world has the 53 Alderwick residents")
	await tap(KEY_TAB)
	check(town.view_mode == 1 and not player.enabled, "Tab switches to free overhead view")
	var focus: Vector3 = town.overview_focus
	key(KEY_D);await ticks(12);key(KEY_D, false)
	check(town.overview_focus.distance_to(focus) > 1, "Overhead responds to movement keys")
	await tap(KEY_TAB)
	check(town.view_mode == 2 and player.third_camera.current, "Tab switches to third person")
	var standing_y := player.position.y
	await tap(KEY_SPACE)
	var highest := player.position.y
	for index in range(36):await physics_frame;highest = maxf(highest, player.position.y)
	check(highest - standing_y > .5 and player.is_on_floor(), "Space jumps and lands on the actual home floor")
	for spec in [[home.seats[0], "sitting"], [home.bed, "sleeping"]]:
		var furniture: Node3D = spec[0]
		player.position = furniture.global_position - Vector3(0, .5, .8)
		await ticks(4)
		check(player.use_furniture(furniture, spec[1]), "Player uses home furniture: " + spec[1])
		await tap(KEY_E)
		check(player.resting.is_empty() and not furniture.has_meta("occupant"), "Use key gets up and frees the " + spec[1] + " spot")
		await ticks(45)
	town.set_view(0)
	player.position = home.exit_point + Vector3.FORWARD * 1.25
	aim_at(home.exit_point + Vector3.UP * .85)
	home.transferred_at = 0
	await ticks(4);await tap(KEY_E)
	check(not home.inside and player.position.distance_to(home.porch) < .75, "Use key exits through the actual home doorway")
	var door: Node3D
	for child in town.get_node("Bramble Bakery").get_children():
		if child.is_in_group("doors"):door = child;break
	if door:
		player.position = door.get_closed_transform() * Vector3(.55, .1, -1.4)
		aim_at(door.get_closed_transform() * Vector3(door.width / 2, door.height / 2, 0))
		await ticks(12)
		if door.is_open:door.toggle(player.position)
		await tap(KEY_E)
		check(door.is_open, "Use key opens a real town door")
	else:check(false, "Bakery door exists")
	await tap(KEY_K)
	check(town.town_map.opened and not player.enabled, "Map shortcut opens the journal map and stops walking")
	await tap(KEY_ESCAPE)
	check(not town.town_map.opened and player.enabled, "Closing the map restores movement")
	home.enter_home()
	await tap(KEY_K)
	var traveled := travel_to("Forest trail")
	await ticks(12)
	check(traveled and not home.inside and home.exterior.visible and not home.interior.visible and not town.town_map.opened and player.enabled and player.global_position.distance_to(Vector3(0,0,120)) < 1, "Travel from home restores the exterior and lands on the forest road")
	var before_run := player.global_position
	key(KEY_SHIFT);key(KEY_W)
	await ticks(14)
	check(player.global_position.distance_to(before_run) > 1 and player.animator.current_animation in ["RunnerRun", "Run"], "Shift runs along the connected forest road")
	check(player.sprinting and town.physical_gameplay.stamina < 100, "Moving at sprint speed consumes stamina")
	key(KEY_W, false);key(KEY_SHIFT, false)
	var merchant: Node = town.economy.seller_for("city")
	if merchant:
		player.position = merchant.global_position + Vector3(0, .03, 1.6)
		var initial_coins: int = town.economy.player_coins
		var initial_food: int = town.economy.player_food
		check(town.economy.buy_food(merchant) and town.economy.player_coins < initial_coins and town.economy.player_food == initial_food + 1, "A real market purchase exchanges coins for food")
	else:check(false, "Town square has a seller")
	var ada: Node
	for resident in town.life.people:
		if resident.person_name == "Ada":ada = resident;break
	if ada:
		player.position = ada.global_position + Vector3(0, .03, 1.5)
		town.life.open_dialog(ada, false)
		check(town.adventures.conversation_action.visible and not town.adventures.conversation_action.disabled, "Nearby resident panel offers a story action")
		town.adventures.conversation_action.pressed.emit()
		check(town.adventures.progress.missing_delivery.status == "active", "Resident action accepts Ada's actual mission")
		town.life.close_dialog()
	else:check(false, "Ada is present")
	town.challenges.start("archery")
	town.physical_gameplay.score = town.challenges.baseline + 1
	check(town.challenges.active == "archery", "Archery contract starts alongside a story mission")
	# A grounded carry checkpoint exercises the serialized object identity.
	player.position = Vector3(8, .04, 12)
	player.rotation.y = .4
	await ticks(4)
	var crate: Node3D = town.physical_gameplay.find_object("physical/vegetable_delivery_crate")
	check(is_instance_valid(crate) and town.physical_gameplay.restore_carried(crate), "Physical crate attached before saving")
	await tap(KEY_ESCAPE)
	check(paused and town.interface_ui.pause_panel.visible, "Escape opens pause menu and pauses the town")
	check(press_button(town.interface_ui.pause_panel, "Save game"), "Pause menu has a Save game button")
	check(town.session.last_error == OK and FileAccess.file_exists(town.session.save_path), "Save button writes a complete session")
	check(press_button(town.interface_ui.pause_panel, "Return to title"), "Return to title saves and transitions")
	await scene_changed
	check(not paused and press_button_exists(current_scene.main_column, "Continue town"), "Title offers Continue after saving")

func aim_at(point: Vector3) -> void:
	var player: CharacterBody3D = town.player
	var direction: Vector3 = point - player.camera.global_position
	player.rotation.y = atan2(-direction.x, -direction.z)
	player.camera.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())

func check_stamina() -> void:
	var player: CharacterBody3D = town.player
	var physical: Node3D = town.physical_gameplay
	town.set_view(2)
	player.sprinting = true
	physical.update_stamina(10.0)
	check(is_equal_approx(physical.stamina, 45.0) and not physical.winded, "Ten seconds of sprinting leaves 45 stamina")
	physical.update_stamina(7.0)
	check(physical.winded and physical.stamina < 8, "A longer sprint makes the player winded")
	await ticks(6)
	check(player.animator.current_animation == "TiredIdle" and player.tired_breath > 0, "A winded player plays the tired animation at rest")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../review/player-tired-idle.png")
	key(KEY_W);key(KEY_SHIFT)
	await ticks(6)
	check(not player.sprinting and player.animator.current_animation == "Walk" and physical.winded, "Movement interrupts tired idle and allows walking while winded")
	key(KEY_W, false);key(KEY_SHIFT, false)
	await ticks(72)
	check(not physical.winded and player.animator.current_animation == "PlayerIdle", "Recovery clears the tired pose and restores sprint availability")
	physical.stamina = 100
	town.home_district.enter_home()
	await ticks(6)

func press_button_exists(parent: Node, title: String) -> bool:
	for button: Button in parent.find_children("*", "Button", true, false):
		if button.text == title:return true
	return false

func travel_to(title: String) -> bool:
	var page: Control = town.interface_ui.page_nodes["Map"]
	for selector: OptionButton in page.find_children("*", "OptionButton", true, false):
		for index in range(selector.item_count):
			if selector.get_item_text(index) == title:
				selector.item_selected.emit(index)
				return true
	return false

func resume() -> void:
	check(town.home_district.inside and town.player.position.distance_to(town.home_district.safe_spawn()) < .35, "Continue starts inside the player’s home after restoring an outdoor save")
	check(town.view_mode == 0 and town.player.enabled and town.player.camera.current, "Continue starts with a playable first-person camera")
	check(town.adventures.progress.missing_delivery.status == "active" and town.economy.player_food == 1, "Continue restores the active mission and market purchase")
	check(town.challenges.active == "archery" and town.physical_gameplay.score - town.challenges.baseline == 1 and town.challenges.remaining > 0, "Continue restores the challenge timer and scored hit")
	check(is_instance_valid(town.physical_gameplay.carried) and town.physical_gameplay.object_id(town.physical_gameplay.carried) == "physical/vegetable_delivery_crate", "Continue restores the same carried object")
	await tap(KEY_ESCAPE)
	check(paused and town.interface_ui.pause_panel.visible, "Pause works after restart")
	await tap(KEY_ESCAPE)
	check(not paused and town.player.enabled, "Resume releases pause and restores controls")
	if DisplayServer.get_name() != "headless":
		while not town.town_map.minimap.captured:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../review/pc-gameplay-resumed.png")
	var crate: Node3D = town.physical_gameplay.carried
	if is_instance_valid(crate):
		town.home_district.set_inside(false)
		var player: CharacterBody3D = town.player
		var landing := Vector3.INF
		for mark: Vector3 in [Vector3(5,.04,4.5), Vector3(9,.04,1), Vector3(6,.04,2.5)]:
			player.position = mark;player.rotation.y = 0
			await ticks(6)
			landing = town.physical_gameplay.place_destination()
			if landing.distance_to(Vector3(8,0,4)) < 5:break
		check(landing.distance_to(Vector3(8,0,4)) < 5, "Found clear ground in the market delivery zone")
		var coins: int = town.economy.player_coins
		await tap(KEY_E)
		if town.physical_gameplay.panel.visible:
			check(press_button(town.physical_gameplay.panel, "Place on ground"), "Carried crate offers a real put-down action when a recipient is nearby")
		check(town.physical_gameplay.object_action.active, "The valid drop starts the contact animation")
		await ticks(90)
		check(town.physical_gameplay.carried == null and not crate.has_meta("vegetables") and town.economy.player_coins == coins + 8, "Delivery transfers the cargo and pays once at contact")
		var stock: int = town.jobs.markets.city.stock
		var checkpoint: Dictionary = town.session.snapshot()
		# Simulate the default cargo metadata on an object constructed by restart.
		crate.set_meta("vegetables", 4)
		check(town.session.apply_snapshot(checkpoint) and not crate.has_meta("vegetables"), "Continue clears cargo from an already delivered crate")
		crate.set_meta("vegetables", 4)
		town.physical_gameplay.restore_carried(crate)
		town.physical_gameplay.commit_place(crate, Vector3(8,.04,4))
		check(town.economy.player_coins == coins + 8 and town.jobs.markets.city.stock == stock, "Delivery ledger prevents duplicate pay and stock")

func cycle_through_night() -> void:
	town.session.autosave_seconds = INF
	var day: Node = town.day_night
	day.cycle_seconds = 60
	day.toggle.button_pressed = true
	check(day.enabled and day.night, "World setting starts the one-minute preview at dusk")
	Engine.time_scale = 3
	var elapsed := 0.0
	var next_report := 60.0
	var most_sleeping := 0
	while day.night and elapsed < 390:
		await physics_frame
		elapsed += town.get_physics_process_delta_time()
		most_sleeping = maxi(most_sleeping, 71 - day.residents_heading_home())
		if elapsed >= next_report:
			print("PC_GAMEPLAY_NIGHT_PROGRESS seconds=", elapsed, " asleep=", most_sleeping)
			next_report += 60
	Engine.time_scale = 1
	check(most_sleeping == 71, "All 71 off-duty residents reach beds during the preview")
	var watch := 0
	for resident in town.life.people:
		if resident.guard_shift == "night":watch += 1
	check(watch == 4, "Four residents are assigned to the night watch")
	check(not day.night, "The preview resumes daylight after residents get home")
	day.toggle.button_pressed = false
	check(not day.enabled and not day.night and is_equal_approx(day.phase, .5), "Turning the cycle off restores permanent daylight")
