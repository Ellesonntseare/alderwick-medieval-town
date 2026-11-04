extends SceneTree

class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass
	func _unhandled_input(_event: InputEvent) -> void:pass
class Roads extends Node3D:
	func road(_points: Array,_width: float) -> void:pass

var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func load_nearby(district: Node3D) -> void:
	district.update_stream(0,150)
	var deadline:=Time.get_ticks_msec()+60000
	while district.loading and Time.get_ticks_msec()<deadline:
		await process_frame;district.update_stream(0,150)
	check(is_instance_valid(district.visual),"Visual district loads when approached")

func run() -> void:
	root.size=Vector2i(1280,720)
	var town:=Town.new();root.add_child(town)
	town.player=CharacterBody3D.new();town.add_child(town.player)
	town.expansion=Roads.new();town.add_child(town.expansion)
	var ground:=MeshInstance3D.new();ground.name="SharedGround";ground.material_override=StandardMaterial3D.new();town.add_child(ground)
	var district: Node3D=load("res://neighbouring_town.gd").new();town.add_child(district);district.set_process(false)
	check(district.visual==null and not district.loading,"Initial district contains collision without loading visual scene")
	var collision_count:=district.find_children("*","CollisionShape3D",true,false).size()
	check(collision_count>=607 and district.doors.size()==10,"All building collision and ten doors are retained")
	check(district.distance_to_district(Vector3(0,0,410))==0,"Distance is measured from district bounds")
	await load_nearby(district)
	check(district.door_visuals.size()==10,"Each visible door attaches to its working hinge")
	var door: Node3D=district.doors[0]
	door.toggle(Vector3.ZERO)
	for frame in range(35):await physics_frame
	var angle: float=door.rotation.y
	district.update_stream(1000,150);await process_frame
	check(district.visual==null and district.door_visuals.is_empty(),"Distant visual instances are freed")
	check(district.find_children("*","CollisionShape3D",true,false).size()==collision_count,"Unload preserves collision and navigation geometry")
	await load_nearby(district)
	check(door.is_open and is_equal_approx(door.rotation.y,angle),"Reload preserves an open door")
	district.unload_visual()
	print("INDUSTRIAL_STREAM_REVIEW_COMPLETE failures=",failures," retained_colliders=",collision_count)
	quit(0 if failures.is_empty() else 1)
