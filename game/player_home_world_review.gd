extends SceneTree
var failed: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	Engine.max_fps=60
	var town: Node3D=load("res://town.tscn").instantiate();root.add_child(town)
	while not town.life.navigation_ready or not town.home_district.ready_for_spawn:await physics_frame
	var home: Node3D=town.home_district
	home.enter_home()
	for frame in range(90):await physics_frame
	if not town.player.is_on_floor() or not home.inside:failed.append("Indoor startup does not settle on floor")
	if town.player_home.house!=home.interior:failed.append("Home storage not registered to interior")
	for family in town.families.households:
		if family.get("house") in [home.interior,home.exterior]:failed.append("NPC family claimed home")
	if town.life.people.size()!=53:failed.append("Resident count changed")
	if not home.clear_capsule(home.porch):failed.append("Outdoor doorway arrival blocked in actual town")
	print("PLAYER_HOME_WORLD_REVIEW_COMPLETE failures=",failed," residents=",town.life.people.size()," spawn=",town.player.position)
	quit(0 if failed.is_empty() else 1)
