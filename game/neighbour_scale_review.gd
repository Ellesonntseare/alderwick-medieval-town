extends SceneTree

class TestTown extends "res://town.gd":
	func _ready() -> void:pass
	func _input(_event: InputEvent) -> void:pass
class Roads extends "res://native_districts.gd":
	func _ready() -> void:town=get_parent()
class Entrances extends Node3D:
	var entrances: Array=[]
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func run() -> void:
	root.size=Vector2i(1280,800)
	var town := TestTown.new();root.add_child(town)
	var ground: MeshInstance3D=town.box(town,Vector3(1000,30,1000),Vector3(0,-15.05,0),Color("667447"),true);ground.name="SharedGround"
	town.expansion=Roads.new();town.add_child(town.expansion)
	town.chateaux=Entrances.new();town.add_child(town.chateaux)
	var next: Node3D=load("res://neighbouring_town.gd").new();town.add_child(next)
	town.player=load("res://player.gd").new();town.add_child(town.player);town.player.enabled=false;town.player.set_physics_process(false)
	town.overview=Camera3D.new();town.add_child(town.overview);town.overview.current=true;town.overview.far=1000
	town.interface()
	for index in range(20):
		var button := Button.new();button.text="Review menu entry "+str(index);town.menu_body.add_child(button)
	for frame in range(8):await process_frame
	town.fit_menu()
	check(town.menu_panel.get_rect().end.y<=800,"The expanded menu remains within the window")
	check(town.menu_scroll.get_v_scroll_bar().max_value>town.menu_scroll.size.y,"Additional controls remain reachable by scrolling")
	town.toggle_menu()
	for frame in range(3):await process_frame
	check(town.menu_panel.size.y<100 and not town.menu_body.visible,"The menu still collapses")
	var human_door: Node3D
	for door in next.doors:
		check(door.height>=1.85 and door.height<=2.7,"All native doors have human clearance")
		check(door.width>=.85,"Native door width fits a character")
		if String(door.get_meta("source_leaf","")).begins_with("door_Soft_Wood"):human_door=door
		check(door.toggle(door.global_position+Vector3(0,0,-3)),"Native leaf opens")
	await create_timer(.55).timeout
	for door in next.doors:check(door.is_open and door.collider.disabled,"Native door collision releases when open")
	check(human_door!=null,"The separate hideout house is scaled to a human door")
	if human_door:
		var closed: Transform3D=human_door.get_closed_transform()
		town.player.position=closed*Vector3(human_door.width/2,0,-1)
		var probe := town.player.global_transform;probe.origin.y+=.12
		var forward := closed.basis*Vector3(0,0,2)
		check(not town.player.test_move(probe,forward),"The player capsule can cross the fitted house doorway")
		var light := DirectionalLight3D.new();town.add_child(light);light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=.8
		var environment := WorldEnvironment.new();town.add_child(environment);environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.7;environment.environment.ambient_light_color=Color.WHITE
		town.overview.position=closed*Vector3(3.0,2.2,-6)
		town.overview.look_at(human_door.global_position+Vector3(0,1.3,0));town.overview.current=true
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../neighbour-human-scale-preview.png")
	print("NEIGHBOUR_SCALE_REVIEW_COMPLETE failures=",failures," doors=",next.doors.size()," house_door=",human_door.height if human_door else 0)
	quit(0 if failures.is_empty() else 1)
