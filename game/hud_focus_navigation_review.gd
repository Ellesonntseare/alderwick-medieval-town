extends "res://town_map_review.gd"

const Target=preload("res://interaction_target.gd")

class HudPlayer extends Player:
	var resting:=""
	var camera:=Camera3D.new()
	func _ready() -> void:add_child(camera);camera.position.y=1.5;camera.current=true

class HudTown extends Town:
	var camera_updates:=0
	func update_camera() -> void:camera_updates+=1

class HudLife extends Life:
	var traffic: RefCounted
	var grid:=AStarGrid2D.new()
	var hud_target: Dictionary={}
	var hint: Label
	func find_route(from: Vector3,to: Vector3) -> PackedVector3Array:
		var path:=PackedVector3Array()
		for cell in grid.get_id_path(Vector2i(roundi(from.x),roundi(from.z)),Vector2i(roundi(to.x),roundi(to.z))):path.append(Vector3(cell.x,0,cell.y))
		return path

class HudAdventures extends Adventures:
	var work_elapsed:=0.0
	func nearby_task() -> String:return ""

class Directory extends Node:
	func is_open() -> bool:return false

class Interface extends "res://town_interface.gd":
	func _ready() -> void:town=get_parent();ready_for_use=true
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass

class Physical extends Node3D:
	var objects: Array=[]
	var carried: Node3D
	var climbing:=false
	var mounted: Node3D
	var pushing:=false
	var object_action:=preload("res://prop_action.gd").new()
	var panel: PopupPanel

class Person extends CharacterBody3D:
	var person_name:="Ada"
	var occupation:="Vegetable seller"
	var activity:="Arranging vegetables"
	var posture:="standing"
	var appearance_height:=1.0

class HudMap extends "res://town_map.gd":
	func request_render() -> void:pass

var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func click(map: Node,point: Vector2) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point
	event.pressed=true;map.map_input(event)
	event.pressed=false;map.map_input(event)

func run() -> void:
	root.size=Vector2i(1280,800)
	var town:=HudTown.new();root.add_child(town)
	town.player=HudPlayer.new();town.add_child(town.player)
	town.life=HudLife.new();town.add_child(town.life)
	town.life.hint=Label.new();town.life.add_child(town.life.hint)
	town.life.grid.region=Rect2i(-30,-30,61,61);town.life.grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;town.life.grid.update()
	for x in range(-8,9):
		if x!=5:town.life.grid.set_point_solid(Vector2i(x,-5),true)
	town.builder=Builder.new();town.add_child(town.builder)
	town.home_district=Home.new();town.add_child(town.home_district)
	town.adventures=HudAdventures.new();town.add_child(town.adventures)
	town.challenges=Challenges.new();town.add_child(town.challenges)
	town.character_directory=Directory.new();town.add_child(town.character_directory)
	town.menu_body=VBoxContainer.new();town.add_child(town.menu_body)
	var physical:=Physical.new();town.physical_gameplay=physical;town.add_child(physical)
	physical.panel=PopupPanel.new();physical.add_child(physical.panel)
	var ada:=Person.new();town.add_child(ada);ada.position=Vector3(0,0,-3.6);town.life.people.append(ada)
	var door: Node3D=load("res://door.gd").new();door.door_name="Workshop gate";door.position=Vector3(1.4,0,-1.6);town.add_child(door)
	var interface:=Interface.new();town.interface_ui=interface;town.add_child(interface)
	var map:=HudMap.new();town.town_map=map;town.add_child(map)
	await physics_frame
	var target:=Target.resolve(town)
	check(target.kind=="talk" and target.node==ada and target.detail.contains("Vegetable seller"),"Facing Ada selects her over a closer gate off to one side")
	town.life.hud_target=target;interface.update_focus_prompt(.2)
	check(town.life.hint.visible and town.life.hint.text.begins_with("E · Talk to Ada"),"One prompt shows the actual action and resident")
	var wall:=StaticBody3D.new();town.add_child(wall);wall.position=Vector3(0,1,-1.8)
	var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(.9,2,.2);wall.add_child(shape)
	await physics_frame;await physics_frame
	check(Target.resolve(town).kind!="talk","A wall blocks the resident's prompt")
	town.player.camera.look_at(Vector3(1.95,1.17,-1.6))
	target=Target.resolve(town)
	check(target.kind=="door" and target.node==door,"A focused closed gate remains selectable through its own collider")
	Target.perform(town,target);check(door.is_open,"The displayed gate is the object Use actually opens")
	town.player.camera.rotation.y=PI
	town.life.hud_target=Target.resolve(town);interface.update_focus_prompt(.3)
	check(not town.life.hint.visible,"Looking away fades the prompt out")
	interface.active=true;town.life.hud_target=target;interface.update_focus_prompt(.2)
	check(not town.life.hint.visible,"The Journal hides the focus prompt")
	interface.active=false
	map.opened=true;map.texture.size=Vector2(600,600);map.center=Vector3.ZERO;map.zoom=60
	click(map,Vector2(300,200))
	check(map.waypoint.is_equal_approx(Vector3(0,0,-10)) and map.clear_pin.visible,"Clicking the map converts the displayed point to a world waypoint")
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=Vector2(300,200);press.pressed=true;map.map_input(press)
	var drag:=InputEventMouseMotion.new();drag.position=Vector2(352,200);drag.relative=Vector2(52,0);drag.button_mask=MOUSE_BUTTON_MASK_LEFT;map.map_input(drag)
	press.position=drag.position;press.pressed=false;map.map_input(press)
	check(map.waypoint.is_equal_approx(Vector3(0,0,-10)) and not map.center.is_zero_approx(),"Dragging pans without moving the existing waypoint")
	map.opened=false
	map.minimap.refresh_directions()
	check(map.minimap.destination_label.text=="Map waypoint · 10 m","The walking minimap shows the clicked destination and distance")
	check(map.minimap.navigation.path.has(Vector3(5,0,-5)),"Directions go through the open crossing instead of through the blocked row")
	map.tracked="review";map.clear_pin.pressed.emit()
	check(not map.waypoint.is_finite() and map.navigation_objective().name=="Find the workbench","Clearing a pin restores the tracked journal objective")
	town.view_mode=1;town.player.rotation.y=PI/2;town.overview_focus=Vector3(80,0,80)
	map.minimap._process(.3)
	check(map.minimap.locator_mode and map.minimap.back_to_player.visible and map.minimap.map_material.get_shader_parameter("heading")==0,"Overhead is north-up even when the player faces east")
	check(map.minimap.map_offset(town.player.position).length()>100,"The overview locator measures player position independently of camera focus")
	map.minimap.back_to_player.pressed.emit()
	check(town.overview_focus.is_zero_approx() and town.camera_updates==1,"Back to player recentres the camera without moving the character")
	print("HUD_FOCUS_NAVIGATION_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
