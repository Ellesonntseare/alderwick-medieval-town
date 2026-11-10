extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:failures.append(message);push_error(message)
func run() -> void:
	root.size=Vector2i(1280,800);root.set_disable_input(true)
	create_timer(160,true,false,true).timeout.connect(func():push_error("Workshop review timed out");quit(1))
	var town: Node3D=load("res://town.tscn").instantiate();root.add_child(town)
	town.set_process(false);town.set_process_input(false);town.set_process_unhandled_input(false)
	while not town.get("session"):await process_frame
	town.session.save_path="user://review-workshop-world-session.json"
	while not town.session.restored or not town.session.systems_ready():await process_frame
	town.interface_ui.close();paused=false
	town.day_night.set_enabled(false)
	if town.home_district.inside:town.home_district.leave_home()
	town.set_view(2);town.player.position=Vector3(-24,.1,37.8)
	await physics_frame
	town.adventures.inventory={"Timber":12,"Metal fittings":4}
	town.interface_ui.open_page("Belongings")
	check(town.inventory_ui.grid.get_child_count()>=2,"Belongings opens with real inventory cards")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../review/workshop-belongings.png")
	check(town.crafting.begin("Supply crate"),"Start the real recipe from the bench")
	await create_timer(7.2).timeout
	check(town.inventory_ui.amount("Supply crate")==1 and town.inventory_ui.amount("Timber")==8,"Workshop produces a crate after consuming its inputs")
	var residents: Dictionary={}
	for person in town.life.people:residents[person.person_name]=person
	var sven: CharacterBody3D=residents.Sven
	town.adventures.progress.castle_store={"status":"active","step":1}
	town.player.position=sven.position+Vector3(0,0,1.5)
	town.life.open_dialog(sven,false);town.adventures.refresh_conversation_action()
	check(town.adventures.conversation_action.visible and not town.adventures.conversation_action.disabled,"Sven has a visible parcel action")
	town.adventures.conversation_action.pressed.emit()
	await create_timer(3.5).timeout
	check(town.adventures.progress.castle_store.status=="complete" and town.inventory_ui.amount("Supply crate")==0,"Animated hand-over consumes the crate at contact")
	town.life.close_dialog()
	town.adventures.meet("Sven");check(town.adventures.progress.castle_tools.status=="offered","Finishing the first castle task unlocks the next")
	var projects:=town.find_child("DistrictProjects",true,false)
	if projects:check(projects.sites.castle_store.finished.visible,"Completed castle project swaps in the new crate")
	town.player.position=Vector3(8,.12,12)
	town.player.velocity=Vector3.ZERO
	await physics_frame
	check(town.session.flush_and_save()==OK,"Coordinated session saved")
	var saved: Dictionary=town.session.Store.load_valid(town.session.save_path)
	check(not saved.is_empty() and saved.adventures.progress.castle_store.status=="complete","Saved session contains completed workshop delivery")
	if not saved.is_empty():
		var coins: int=town.economy.player_coins
		town.economy.player_coins=0
		check(town.session.apply_snapshot(saved) and town.economy.player_coins==coins,"World session restores the saved wallet without another reward")
	if DisplayServer.get_name()!="headless":
		var minimap: Node=town.town_map.minimap
		var reused:=false
		for attempt in range(3):
			town.player.position=Vector3(8,.12,12)
			await create_timer(1).timeout
			town.player.position=Vector3(58,.12,12)
			await create_timer(1).timeout
			var before: int=minimap.captures
			var hits: int=minimap.tiles.hits
			var revision: int=town.town_map.scenery_cache.revision
			town.player.position=Vector3(8,.12,12)
			await create_timer(1).timeout
			print("WORKSHOP_MAP_REVISIT captures_before=",before," captures_after=",minimap.captures," revision_before=",revision," revision_after=",town.town_map.scenery_cache.revision," new_hits=",minimap.tiles.hits-hits)
			for change in town.town_map.scenery_cache.recent_invalidations:
				if int(change.revision)>revision:print("WORKSHOP_MAP_CHANGE ",change)
			if before>=2 and minimap.captures==before and minimap.tiles.hits>hits:reused=true;break
		check(reused,"Returning to an unchanged map tile reuses its capture")
		var house:=town.get_node("Willow House") as Node3D
		var map_image: Image=minimap.picture.texture.get_image()
		var offset: Vector3=house.global_position-minimap.anchor
		var pixel:=Vector2i((Vector2(offset.x,offset.z)/180+Vector2(.5,.5))*Vector2(map_image.get_size()))
		var roof_pixels:=0
		for x in range(pixel.x-4,pixel.x+5):
			for y in range(pixel.y-4,pixel.y+5):
				if not Rect2i(Vector2i.ZERO,map_image.get_size()).has_point(Vector2i(x,y)):continue
				var color:=map_image.get_pixel(x,y)
				if color.r>color.g*1.2 and color.r>color.b*1.3:roof_pixels+=1
		print("WORKSHOP_MAP_ROOF_PIXELS count=",roof_pixels)
		check(roof_pixels>=16,"The cached walking map shows Willow House's roof")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../review/workshop-minimap.png")
	# Use the home floor collision for placement and verify the saved object is
	# reconstructed only once even if the same snapshot is reapplied.
	town.home_district.enter_home()
	await physics_frame
	var home: Node3D=town.home_district.interior
	var placed:=false
	town.inventory_ui.change("Crafted stool",1)
	for offset: Vector3 in [Vector3(2.6,.1,3.8),Vector3(2,.1,1),Vector3(.8,.1,2.5),Vector3(4.0,.1,3.5)]:
		town.player.position=home.to_global(offset)
		if town.crafting.place("Crafted stool"):placed=true;break
	check(placed and town.inventory_ui.amount("Crafted stool")==0,"Crafted stool can be placed on the actual home floor")
	var craft_state: Dictionary=town.crafting.snapshot()
	town.crafting.restore(craft_state);town.crafting.restore(craft_state)
	var count:=0
	for child in home.get_children():
		if child.has_meta("crafted_id"):count+=1
	check(count==1,"Reloading placement retains exactly one physical stool")
	print("WORKSHOP_WORLD_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
