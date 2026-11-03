extends SceneTree
class FixtureTown extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass
	func _unhandled_input(_event: InputEvent) -> void:pass
	func set_view(mode: int) -> void:player.set_view(mode)
class Economy extends Node:
	func testing() -> bool:return true
class Home extends Node:
	var house: Node3D
	func register_house(value: Node3D) -> bool:house=value;return true
class Life extends Node:
	var active: Node
class Adventures extends Node:
	func stop_work() -> void:pass
var failed: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
	if not value:failed.append(message);push_error(message)
	else:print("HOME_PASS ",message)
func run() -> void:
	root.size=Vector2i(1280,800)
	var town:=FixtureTown.new();root.add_child(town)
	town.world()
	town.player=load("res://player.gd").new();town.add_child(town.player)
	town.economy=Economy.new();town.add_child(town.economy)
	town.player_home=Home.new();town.add_child(town.player_home)
	town.life=Life.new();town.add_child(town.life)
	town.adventures=Adventures.new();town.add_child(town.adventures)
	var district: Node3D=load("res://player_home_district.gd").new();town.add_child(district)
	for frame in range(5):await physics_frame
	check(district.ready_for_spawn,"Home is ready")
	check(district.interior.get_meta("family_excluded") and district.exterior.get_meta("player_owned"),"Both home spaces are reserved for player")
	check(district.clear_capsule(district.safe_spawn()),"Indoor starting capsule is clear")
	district.enter_home()
	check(district.inside and not district.exterior.visible,"Exterior hidden during indoor play")
	check(town.player.camera.current,"Game starts in first person inside the selected interior")
	for frame in range(90):await physics_frame
	check(town.player.is_on_floor() and absf(town.player.position.y+80)<.2,"Actual player lands safely on interior floor")
	town.player.set_physics_process(false)
	town.player.position=district.room_origin+Vector3(6.7,.1,5.1)
	for frame in range(130):
		town.player.velocity=Vector3(0,-2,-3)
		town.player.move_with_steps(1.0/60)
		await physics_frame
	check(town.player.position.y>district.room_origin.y+2.4,"Player walks up the stairs to the bedroom gallery")
	print("HOME_STAIRS_END ",town.player.position)
	town.player.position=district.safe_spawn();town.player.set_physics_process(true)
	var before: Vector3=town.player.position
	check(town.player.use_furniture(district.seats[0],"sitting"),"Player can use a sofa in the chosen interior")
	for frame in range(90):await physics_frame
	check(town.player.resting=="sitting","Sitting posture stays active")
	town.player.stand_from_furniture(true)
	check(town.player.resting.is_empty() and town.player.position.distance_to(before)<.2,"Getting up restores the safe position")
	town.player.position=district.room_origin+Vector3(.8,2.7,-4.5)
	check(town.player.use_furniture(district.bed,"sleeping"),"Player can sleep in their own bed")
	for frame in range(30):await physics_frame
	check(town.player.resting=="sleeping" and district.bed.get_meta("occupant")=="player","Bed is reserved while player sleeps")
	town.player.stand_from_furniture(true)
	check(not district.bed.has_meta("occupant"),"Getting out frees the bed")
	town.player.position=before
	if DisplayServer.get_name()!="headless":
		for frame in range(6):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../town-player-home-inside.png")
	check(district.clear_capsule(district.porch),"Outside arrival capsule is clear")
	district.leave_home()
	check(not district.inside and district.exterior.visible and not district.interior.visible,"Leaving restores outside house and hides interior")
	district.enter_home()
	check(district.inside and town.player.position.distance_to(district.spawn)<6,"Re-entry returns player to interior")
	print("PLAYER_HOME_DISTRICT_REVIEW_COMPLETE failures=",failed)
	quit(0 if failed.is_empty() else 1)
