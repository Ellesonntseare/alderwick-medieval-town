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
class PerformanceFixture extends "res://town_performance.gd":
	func _ready() -> void:town=get_parent()
	func _process(_delta: float) -> void:pass
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,900)
	var verify_roof_pixels := "--review-roof-pixels" in OS.get_cmdline_user_args()
	var world_map := "--world-map" in OS.get_cmdline_user_args()
	var capture_name := "minimap-town" if world_map else "minimap-house"
	var town:=Town.new();root.add_child(town)
	town.player=Player.new();town.add_child(town.player);town.player.position=Vector3(0,0,12)
	if verify_roof_pixels:town.player.position.x=8
	town.life=Life.new();town.add_child(town.life)
	town.builder=Builder.new();town.add_child(town.builder)
	town.home_district=Home.new();town.add_child(town.home_district)
	town.adventures=Adventures.new();town.add_child(town.adventures)
	town.challenges=Challenges.new();town.add_child(town.challenges)
	town.menu_body=VBoxContainer.new();town.add_child(town.menu_body)
	town.world()
	if world_map:
		town.rng.seed=41729
		town.town()
		town.expansion=load("res://native_districts.gd").new();town.add_child(town.expansion)
		var industrial: Node3D=load("res://neighbouring_town.gd").new();town.add_child(industrial)
		var forest: Node3D=load("res://forest_districts.gd").new();town.add_child(forest)
	else:
		for spec in [["Market house",Vector3(-14,0,20)],["Willow House",Vector3(14,0,27)],["Workyard",Vector3(20,0,-10)]]:town.building(spec[0],spec[1],6,8,1,0)
		for x in [-5,5]:town.box(town,Vector3(3,.04,110),Vector3(x,.03,0),Color("a48e67"),false)
	var map: CanvasLayer=load("res://town_map.gd").new();town.town_map=map;town.add_child(map)
	var sentinel: MeshInstance3D=town.box(town,Vector3(2,2,2),Vector3(5,1,12),Color.WHITE)
	sentinel.visibility_range_end=17
	assert(map.viewport.world_3d!=town.get_world_3d())
	assert(map.minimap.viewport.world_3d==map.viewport.world_3d)
	map.refresh_scenery(Rect2(Vector2(-90,-90),Vector2(180,180)))
	if verify_roof_pixels:
		# The minimap can have proxies by the time the walking renderer collects
		# its objects. Those proxies must retain the map's overhead view range.
		var performance := PerformanceFixture.new();town.add_child(performance)
		await performance.collect()
		map.scenery_cache.poll_changes()
	var house: Node3D=town.get_node("Willow House")
	var roof_count:=0
	for source: MeshInstance3D in house.find_children("*","MeshInstance3D",true,false):
		if not source.get_parent().name.begins_with("Roof_RoundTiles"):continue
		var entry: Dictionary=map.scenery_cache.entries.get(source.get_instance_id(),{})
		var proxy: MeshInstance3D=entry.get("proxy")
		if not is_instance_valid(proxy):continue
		assert(proxy.visible and proxy.mesh==source.mesh and proxy.global_transform.is_equal_approx(source.global_transform))
		if proxy.visibility_range_end != 0:
			push_error("Walking view range leaked to map roof proxy: " + str(proxy.visibility_range_end))
			quit(1);return
		roof_count+=1
	assert(roof_count>0,"Named modular house retains its actual roof mesh in the map world")
	print("MAP_FIXTURE_ROOFS name=",house.name," meshes=",roof_count)
	sentinel.visibility_range_end=17
	for frame in range(30):await physics_frame
	map.open();assert(map.opened and not town.player.enabled)
	if world_map:map.whole_town()
	assert(map.tracked=="review" and map.objective().point==Vector3(20,0,-10))
	if DisplayServer.get_name()!="headless":
		while map.refresh_pending:await process_frame
		assert(is_equal_approx(sentinel.visibility_range_end,17.0))
		assert(map.scenery.get_child_count()>0)
		for frame in range(4):await process_frame
		await RenderingServer.frame_post_draw
		if not verify_roof_pixels:root.get_texture().get_image().save_png("res://../town-map-review.png" if world_map else "res://../town-map-fixture.png")
		if world_map:
			map.center=Vector3.ZERO;map.zoom=180;map.request_render()
			while map.refresh_pending:await process_frame
			await RenderingServer.frame_post_draw
			if not verify_roof_pixels:root.get_texture().get_image().save_png("res://../town-map-detail.png")
	var old_zoom: float=map.zoom
	map.zoom_in();assert(map.zoom<old_zoom)
	map.close();assert(town.player.enabled and not map.opened)
	if DisplayServer.get_name()!="headless":
		for frame in range(5):await process_frame
		while map.minimap.capturing or not map.minimap.captured:await process_frame
		if verify_roof_pixels:
			var captured: Image=map.minimap.picture.texture.get_image()
			captured.save_png("res://../review/"+capture_name+"-roof-fixture.png")
			var pixel: Vector2i=Vector2i(map.minimap.camera.unproject_position(house.global_position + Vector3.UP * 3))
			var red_pixels:=0
			for x in range(pixel.x-4,pixel.x+5):
				for y in range(pixel.y-4,pixel.y+5):
					var color:=captured.get_pixel(x,y)
					if color.r>color.g*1.2 and color.r>color.b*1.3:red_pixels+=1
			print("MINIMAP_FIXTURE_ROOF_PIXELS projected=",pixel," orange_pixels=",red_pixels)
			if red_pixels<16:push_error("Expected Willow House roof silhouette in cached texture");quit(1);return
		town.player.rotation.y=PI/2
		map.minimap._process(.3)
		assert(is_equal_approx(float(map.minimap.map_material.get_shader_parameter("heading")),-PI/2))
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../review/"+capture_name+"-hud-fixture.png" if verify_roof_pixels else "res://../walking-minimap-review.png")
	print("TOWN_MAP_REVIEW_COMPLETE objective=true map_pause_restore=true zoom=true")
	quit()
