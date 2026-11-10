extends SceneTree
var failures: Array[String]=[]
var town: Node3D
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
	else:print("JOURNAL_PASS ",label)
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	for frame in range(3):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../review/journal-"+label+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	town=load("res://town.tscn").instantiate();root.add_child(town)
	while not town.interface_ui or not town.interface_ui.ready_for_use:await process_frame
	town.speech.enabled=false;town.day_night.set_enabled(false)
	while not town.home_district.ready_for_spawn:await process_frame
	if town.home_district.inside:town.home_district.leave_home()
	town.player.position=Vector3(0,.1,23);town.set_view(1);town.distance=35;town.update_camera()
	var ui: Node=town.interface_ui
	check(not town.menu_panel.visible and town.menu_collapsed,"Old sidebar is absent")
	check(ui.pages.get_tab_count()==5,"One journal contains five pages")
	check(town.view_selector.get_parent().get_parent()==ui.camera_panel,"View selector moved to camera popup")
	check(not town.economy.wallet_label.visible and not town.economy.eat_button.visible,"Wallet and food controls leave the gameplay HUD")
	await capture("gameplay")
	ui.open_page("Map")
	check(ui.book.visible and town.town_map.opened and not town.player.enabled,"Minimap destination opens integrated map and disables movement")
	await capture("map")
	ui.open_page("My Life")
	check(not town.town_map.opened and town.character_life.view.visible(),"Life pages share journal and close map capture")
	check(ui.page_nodes["My Life"].is_ancestor_of(town.character_life.view.tabs),"Existing life controls are embedded")
	await capture("life")
	ui.open_page("Activities")
	check(ui.activities_list.get_child_count()>=3,"Context activities populate the book")
	ui.open_page("Challenges")
	check(ui.page_nodes["Challenges"].is_ancestor_of(town.challenges.message),"Challenges use the existing live controls")
	await capture("challenges")
	ui.open_page("Journal")
	check(ui.page_nodes["Journal"].is_ancestor_of(town.adventures.content),"Missions and belongings use the existing journal data")
	await capture("missions")
	ui.close()
	check(not ui.active and not paused and not town.menu_panel.visible,"Closing journal restores gameplay without revealing sidebar")
	ui.toggle_pause()
	check(paused and ui.pause_panel.visible,"Pause screen pauses the world")
	ui.open_settings()
	check(ui.settings_tabs.get_tab_count()==4 and ui.settings_panel.visible,"Four settings sections replace the long menu")
	check(ui.settings_nodes["World"].get_child_count()>=3,"Weather and day cycle controls relocated")
	check(ui.settings_nodes["Audio & Voices"].get_child_count()>=3,"Voice switches and volume relocated")
	await capture("settings")
	ui.close()
	var minimap: Node=town.town_map.minimap
	minimap.show()
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	minimap._gui_input(click)
	check(ui.active and ui.opened_page=="Map","Minimap click opens journal map")
	ui.close()
	var escape:=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true
	ui._input(escape);check(ui.pause_panel.visible,"Escape opens pause screen")
	ui._input(escape);check(not ui.active and not paused,"Escape returns to town")
	town.set_view(2);ui.open_page("Map")
	var destination: OptionButton
	for child in ui.page_nodes["Map"].get_children():
		if child is OptionButton:destination=child;break
	check(destination!=null,"Travel destinations are on the map page")
	if destination:
		destination.item_selected.emit(1)
		check(not ui.active and town.player.enabled and town.view_mode==2,"Travel closes the book and restores walking")
	ui.open_page("Challenges")
	town.challenges.start("archery")
	# Simulate the same post-start callback installed on the challenge buttons.
	for child in town.challenges.message.get_parent().get_children():
		if child is Button and child.text.begins_with("Archery"):
			child.pressed.emit();break
	check(not ui.active and not town.challenges.active.is_empty(),"Starting a challenge returns to play")
	town.challenges.active=""
	ui.toggle_pause();ui.close();town.builder.toggle()
	check(town.builder.active and not ui.active,"Town design opens its separate editor")
	await town.builder.finish()
	check(not town.builder.active and not town.menu_panel.visible,"Leaving town design keeps the old sidebar hidden")
	if town.festival:
		town.set_view(1);town.overview_focus=town.festival.CENTRE;town.distance=22;town.update_camera()
		var max_members:=0;var max_dancing:=0
		for second in range(60):
			await create_timer(1).timeout
			var dancing:=0;var names: Array=[]
			for person in town.festival.members:
				names.append(person.person_name+":"+String(person.routine.get("stage",""))+":"+str(person.position))
				if person.routine.get("stage")=="dancing":dancing+=1
			max_members=maxi(max_members,town.festival.members.size());max_dancing=maxi(max_dancing,dancing)
			if second%15==0:print("FESTIVAL_WORLD_PROGRESS seconds=",second," members=",town.festival.members.size()," dancing=",dancing," residents=",names)
		print("FESTIVAL_WORLD_RESULT max_members=",max_members," max_dancing=",max_dancing)
		await capture("village-dance")
	print("JOURNAL_INTERFACE_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
