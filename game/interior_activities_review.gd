extends SceneTree

func _initialize() -> void:run.call_deferred()

func run() -> void:
	root.size=Vector2i(1280,720)
	var town: Node3D=load("res://town.tscn").instantiate();root.add_child(town)
	while not town.life.navigation_ready or not town.home_district.ready_for_spawn or not town.character_life.bound:await physics_frame
	var home: Node3D=town.home_district
	home.enter_home()
	for frame in range(4):await physics_frame
	var activities: Node=town.interior_activities
	town.player.position=home.cooking_anchor.global_position
	town.cooking.register_home(home.interior)
	var labels: Array=[]
	for option in activities.available():labels.append(option.label)
	assert(labels.has("Cook a meal") and labels.has("Store or take belongings"))
	activities.open();assert(activities.panel.visible and not town.player.enabled)
	activities.panel.hide();assert(town.player.enabled)
	var seat: Node3D=home.seats[0]
	town.player.position=seat.global_position
	var occupied_before: bool=seat.has_meta("occupant")
	assert(not occupied_before)
	var seated:=false
	for option in activities.available():
		if option.label=="Sit and rest":option.action.call();seated=true;break
	assert(seated and town.player.resting=="sitting")
	for option in activities.available():
		if option.label=="Stand up":option.action.call();break
	assert(town.player.resting.is_empty())
	town.player.position=Vector3(0,0,25)
	for option in activities.available():assert(option.label!="Store or take belongings" and option.label!="Cook a meal")
	print("INTERIOR_ACTIVITIES_REVIEW_COMPLETE kitchen=true storage_proximity=true sit_stand=true modal_restore=true")
	quit()
