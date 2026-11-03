extends SceneTree

class FixtureTown extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass
	func _unhandled_input(_event: InputEvent) -> void:pass
	func set_view(mode: int) -> void:view_mode=mode
class Life extends Node:
	var active: Node
	var navigation_ready:=false
	var people: Array=[]
class Adventures extends Node:
	var journal:=PanelContainer.new()
	func stop_work() -> void:pass
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func mouse_button(point: Vector2,pressed: bool) -> void:
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
func mouse_move(point: Vector2,relative: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=relative;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)

func run() -> void:
	root.size=Vector2i(1280,800)
	var town:=FixtureTown.new();root.add_child(town)
	town.menu_body=VBoxContainer.new();town.add_child(town.menu_body)
	town.life=Life.new();town.add_child(town.life)
	town.adventures=Adventures.new();town.adventures.journal.hide();town.add_child(town.adventures)
	town.economy=load("res://town_economy.gd").new();town.economy.town=town
	town.music=AudioStreamPlayer.new();town.add_child(town.music)
	town.player=CharacterBody3D.new();town.add_child(town.player);town.player.position=Vector3(50,0,50)
	town.box(town,Vector3(150,1,150),Vector3(0,-.55,0),Color("718054"),true)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-35,0);town.add_child(sun)
	town.well(Vector3(-10,0,0))
	var builder=load("res://town_builder.gd").new()
	# Isolate this fixture from the player's saved layout.
	builder.save_path="user://builder-fixture-review.json"
	town.builder=builder;town.add_child(builder)
	builder.save_path="user://builder-fixture-review.json"
	builder.apply_records({});builder.undo_stack.clear();builder.redo_stack.clear()
	builder.toggle();builder.category="Furniture";builder.fill_palette()
	builder.camera_target=Vector3(6,0,0);builder.camera_zoom=30;builder.update_camera()
	for frame in range(3):await physics_frame
	for frame in range(4):await process_frame
	var button: Control=builder.palette.get_child(0)
	var start:=button.get_global_rect().get_center()
	var end: Vector2=builder.camera.unproject_position(Vector3(10,0,0))
	mouse_move(start,Vector2.ZERO);mouse_button(start,true)
	await process_frame
	mouse_move(start+Vector2(18,0),Vector2(18,0));await process_frame
	mouse_move(end,end-start);await process_frame
	mouse_button(end,false)
	for frame in range(6):await process_frame
	if DisplayServer.get_name()!="headless":check(builder.records.size()==1,"Native GUI drag-and-drop creates a placed object")
	if builder.records.is_empty():await builder.place("table",Vector3(10,0,0))
	if builder.records.is_empty():check(false,"Direct placement must succeed on clear ground");quit(1);return
	var id: String=builder.records.keys()[0]
	var position: Vector3=builder.nodes[id].position
	check(not await builder.place("table",position),"Overlapping placement is rejected")
	builder.undo();check(builder.records.is_empty(),"Undo removes the placed object")
	builder.redo();check(builder.records.size()==1,"Redo restores it")
	check(await builder.place("bed",Vector3(14,0,0)),"A functional bed can be placed")
	check(not get_nodes_in_group("beds").is_empty(),"Placed beds expose a usable interaction anchor")
	check(await builder.place("path",Vector3(3,0,-8)),"A walkable path section can be placed")
	check(builder.nodes[builder.selected].get_child(0).has_meta("walking_lane"),"The path exposes walking-lane metadata for NPC routes")
	builder.save_layout()
	var expected: Dictionary=builder.records.duplicate(true)
	for key in builder.nodes.keys():
		if not builder.originals.has(key):builder.nodes[key].free();builder.nodes.erase(key)
	builder.records.clear();builder.load_layout()
	check(builder.records==expected,"The editable layout reloads without altering source models")
	check(await builder.place("cottage",Vector3(-4,0,-15)),"A furnished building can be placed")
	builder.camera_target=Vector3(1,0,-5);builder.camera_zoom=31;builder.update_camera()
	check(get_nodes_in_group("doors").size()>0,"Placed houses have working door nodes")
	check(get_nodes_in_group("enterable_houses").size()>0,"Placed houses are physical enterable buildings")
	builder.hint.text="Drag buildings and furniture into the world. Layout, undo and placement checks verified."
	for frame in range(5):await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../town-build-mode.png")
	await builder.finish()
	check(town.process_mode!=Node.PROCESS_MODE_DISABLED,"Leaving build mode resumes the simulation")
	var well: MeshInstance3D=town.find_children("WellWater","MeshInstance3D",true,false)[0]
	check(well.mesh is CylinderMesh and well.position.y>.4,"The well contains visible circular water")
	town.economy.free();town.adventures.journal.free()
	print("BUILDER_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
