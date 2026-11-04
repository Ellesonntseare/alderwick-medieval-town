extends SceneTree
class Player extends CharacterBody3D:
	var enabled:=true
class Life extends Node:
	var navigation_ready:=true
	var active: Node
	var people: Array=[]
class Builder extends Node:
	var active:=false
class Home extends Node3D:
	var inside:=false
	var porch:=Vector3(14,0,27)
	var exit_point:=Vector3(2,-80,5)
class Adventures extends Node:
	var progress={"review":{"status":"active","step":0}}
	var definitions=[{"id":"review","title":"Find the workbench","steps":[{"position":[20,0,-10],"text":"Go to the workbench and repair the wagon"}]}]
	var visitor: Node
	func find_mission(_id: String) -> Dictionary:return definitions[0]
	func step_position(step: Dictionary) -> Vector3:return Vector3(step.position[0],step.position[1],step.position[2])
class Challenges extends Node:
	var active:=""
	func objective() -> Dictionary:return {}
class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass
	func _unhandled_input(_event: InputEvent) -> void:pass
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,900)
	var town:=Town.new();root.add_child(town)
	town.player=Player.new();town.add_child(town.player);town.player.position=Vector3(0,0,12)
	town.life=Life.new();town.add_child(town.life)
	town.builder=Builder.new();town.add_child(town.builder)
	town.home_district=Home.new();town.add_child(town.home_district)
	town.adventures=Adventures.new();town.add_child(town.adventures)
	town.challenges=Challenges.new();town.add_child(town.challenges)
	town.menu_body=VBoxContainer.new();town.add_child(town.menu_body)
	town.world()
	if "--world-map" in OS.get_cmdline_user_args():
		town.rng.seed=41729
		town.town()
		town.expansion=load("res://native_districts.gd").new();town.add_child(town.expansion)
		town.chateaux=load("res://chateau_districts.gd").new();town.add_child(town.chateaux)
		var industrial: Node3D=load("res://neighbouring_town.gd").new();town.add_child(industrial)
		var forest: Node3D=load("res://forest_districts.gd").new();town.add_child(forest)
	else:
		for spec in [["Market house",Vector3(-14,0,20)],["Willow House",Vector3(14,0,27)],["Workyard",Vector3(20,0,-10)]]:town.building(spec[0],spec[1],6,8,1,0)
		for x in [-5,5]:town.box(town,Vector3(3,.04,110),Vector3(x,.03,0),Color("a48e67"),false)
	var map: CanvasLayer=load("res://town_map.gd").new();town.town_map=map;town.add_child(map)
	for frame in range(30):await physics_frame
	map.open();assert(map.opened and not town.player.enabled)
	if "--world-map" in OS.get_cmdline_user_args():map.whole_town()
	assert(map.tracked=="review" and map.objective().point==Vector3(20,0,-10))
	if DisplayServer.get_name()!="headless":
		while map.refresh_pending:await process_frame
		for frame in range(4):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../town-map-review.png")
		if "--world-map" in OS.get_cmdline_user_args():
			map.center=Vector3.ZERO;map.zoom=180;map.request_render()
			while map.refresh_pending:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../town-map-detail.png")
	var old_zoom: float=map.zoom
	map.zoom_in();assert(map.zoom<old_zoom)
	map.close();assert(town.player.enabled and not map.opened)
	print("TOWN_MAP_REVIEW_COMPLETE objective=true map_pause_restore=true zoom=true")
	quit()
