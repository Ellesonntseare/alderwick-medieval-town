extends SceneTree

class Builder extends Node:
	var nodes: Dictionary = {}
class Town extends Node3D:
	var builder: Node
	var physical_gameplay: Node3D
	var cooking: Node
	var jobs: Node
	var industrial_workforce: Node
	func box(parent: Node3D, size: Vector3, point: Vector3, _color: Color, _solid: bool) -> MeshInstance3D:
		var result := MeshInstance3D.new()
		result.mesh = BoxMesh.new();result.mesh.size = size;result.position = point;parent.add_child(result)
		return result
class Routines extends Node:
	var town: Node3D
class Cooking extends Node3D:
	var crop_visual: Node3D
	var herb_visual: Node3D
class Jobs extends Node3D:
	var markets: Dictionary = {}
	var benches: Array = []
class Industrial extends Node3D:
	var workers: Dictionary = {}

var failures: Array[String] = []
func _initialize() -> void:run.call_deferred()
func check(value: bool, label: String) -> void:
	if not value:failures.append(label);push_error(label)
func mesh(parent: Node3D, point: Vector3) -> MeshInstance3D:
	var result := MeshInstance3D.new();parent.add_child(result);result.mesh = BoxMesh.new();result.position = point
	result.material_override = StandardMaterial3D.new()
	return result
func visible_proxies(cache: RefCounted) -> int:
	var result := 0
	for record in cache.entries.values():
		if is_instance_valid(record.proxy) and record.proxy.visible:result += 1
	return result
func run() -> void:
	var town := Town.new();root.add_child(town);town.builder = Builder.new();town.add_child(town.builder)
	town.physical_gameplay = Node3D.new();town.add_child(town.physical_gameplay)
	town.cooking = Cooking.new();town.add_child(town.cooking)
	town.cooking.crop_visual = Node3D.new();town.cooking.add_child(town.cooking.crop_visual)
	town.cooking.herb_visual = Node3D.new();town.cooking.add_child(town.cooking.herb_visual)
	town.jobs = Jobs.new();town.add_child(town.jobs)
	town.industrial_workforce = Industrial.new();town.add_child(town.industrial_workforce)
	var market := Node3D.new();town.jobs.add_child(market);town.jobs.markets.city = {"root":market}
	var bench := Node3D.new();town.jobs.add_child(bench);town.jobs.benches.append({"output":bench})
	var output := Node3D.new();town.industrial_workforce.add_child(output);town.industrial_workforce.workers.Ada = {"output":output}
	var routines := Routines.new();routines.town = town;town.add_child(routines)
	var actions: Node3D = load("res://resident_actions.gd").new();routines.add_child(actions);actions.set_process(false)
	var tray := Node3D.new();actions.add_child(tray)
	var map := Node3D.new();town.add_child(map)
	var scenery := Node3D.new();map.add_child(scenery)
	var cache = load("res://map_scenery_cache.gd").new();cache.bind(town, map, scenery)
	var house := Node3D.new();town.add_child(house);town.builder.nodes.house = house
	var roof := mesh(house, Vector3(1, 2, 1));roof.name = "Roof"
	var road := mesh(town, Vector3(4, 0, 4));road.mesh.size = Vector3(1, .05, 9);road.visibility_range_end = 17
	var actor := CharacterBody3D.new();town.add_child(actor);mesh(actor, Vector3(2, 0, 2))
	var batch := MultiMeshInstance3D.new();town.add_child(batch);batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D;batch.multimesh.mesh = BoxMesh.new();batch.multimesh.instance_count = 2
	batch.multimesh.custom_aabb = AABB(Vector3.ZERO, Vector3(10, 1, 10))
	var area := Rect2(-Vector2.ONE * 10, Vector2.ONE * 30)
	var crate := Node3D.new();town.physical_gameplay.add_child(crate);crate.set_meta("physical_id", "review-crate")
	var crate_mesh := mesh(crate, Vector3.ZERO)
	var crops := mesh(town.cooking.crop_visual, Vector3.ZERO)
	var herbs := mesh(town.cooking.herb_visual, Vector3.ZERO)
	mesh(market, Vector3.ZERO);mesh(bench, Vector3.ZERO);mesh(output, Vector3.ZERO)
	cache.show_area(area)
	check(cache.scans == 1 and cache.entries.size() == 3 and visible_proxies(cache) == 3, "Index contains exact scenery including road, roof and MultiMesh, excludes player")
	var creations: int = cache.proxy_creations;var revision: int = cache.revision
	cache.show_area(area)
	check(cache.scans == 1 and cache.proxy_creations == creations and cache.proxy_reuses == 3, "Repeated capture reuses proxies with no town scan")
	check(cache.revision == revision and road.visibility_range_end == 17, "Capturing never alters walking-view culling or static revision")
	crate.reparent(actor);crate.set_meta("held_by", "Ada");crate.reparent(town.physical_gameplay)
	crops.hide();herbs.show();town.cooking.crop_visual.scale *= 1.2
	var new_stock := mesh(market, Vector3.ONE);new_stock.free()
	mesh(bench, Vector3.ONE);mesh(output, Vector3.ONE)
	var loaf := mesh(tray, Vector3.ONE);loaf.name = "Loaf0"
	cache.poll_changes()
	check(cache.revision == revision and not cache.entries.has(crate_mesh.get_instance_id()), "Carried props, crops, market supplies and station output cannot invalidate tiles")
	check(not cache.entries.has(loaf.get_instance_id()), "Resident baking and smithing result meshes are excluded")
	var record: Dictionary = cache.entries[roof.get_instance_id()]
	check(record.proxy.mesh == roof.mesh and record.proxy.material_override == roof.material_override, "Actual geometry and materials retained")
	house.position = Vector3(180, 0, 0);cache.poll_changes()
	check(cache.revision > revision, "Builder move invalidates captured sections")
	cache.show_area(area);check(visible_proxies(cache) == 2, "Moved house leaves former map section")
	cache.show_area(Rect2(Vector2(170, -10), Vector2.ONE * 30))
	check(visible_proxies(cache) == 1 and record.proxy.global_position == roof.global_position, "Moved house enters new section at current transform")
	revision = cache.revision;house.hide();cache.poll_changes()
	check(cache.revision > revision, "Inherited roof visibility invalidates cache")
	cache.show_area(Rect2(Vector2(170, -10), Vector2.ONE * 30));check(visible_proxies(cache) == 0, "Hidden house stays hidden")
	house.show();revision = cache.revision
	var nearby_version: int = cache.area_revision(area)
	var streamed := mesh(town, Vector3(180, 0, 5));cache.poll_changes()
	check(cache.revision > revision, "New streamed scenery invalidates sections")
	check(cache.area_revision(area) == nearby_version, "Distant district streaming leaves town tile valid")
	cache.show_area(Rect2(Vector2(170, -10), Vector2.ONE * 30));check(visible_proxies(cache) == 2, "Streamed scenery appears")
	revision = cache.revision;streamed.free();cache.poll_changes()
	check(cache.revision > revision, "Removed streamed scenery invalidates sections")
	var moved_parent := Node3D.new();town.add_child(moved_parent)
	roof.reparent(moved_parent);cache.poll_changes()
	check(cache.entries.has(roof.get_instance_id()), "Reparented scenery reindexes without duplicate observers")
	roof.mesh.size = Vector3(40, 2, 2);revision = cache.revision;cache.poll_changes()
	check(cache.dirty_resources.is_empty() and cache.entries[roof.get_instance_id()].bounds.size.x > 39, "Changed geometry updates spatial bounds")
	var tiles = load("res://minimap_tile_cache.gd").new()
	var picture := ImageTexture.new()
	var city: Vector2i = Vector2i.ZERO
	var district := Vector2i(8, 0)
	var city_version: int = cache.area_revision(tiles.area(city))
	tiles.store(city, picture, city_version)
	var district_picture := ImageTexture.new()
	tiles.store(district, district_picture, cache.area_revision(tiles.area(district)))
	var site := Node3D.new();town.add_child(site)
	var unfinished := mesh(site, Vector3(381, 0, 0));var finished := mesh(site, Vector3(384, 0, 0));finished.hide();cache.poll_changes()
	var district_version: int = cache.area_revision(tiles.area(district))
	tiles.store(district, district_picture, district_version)
	unfinished.hide();finished.show();cache.poll_changes()
	check(cache.area_revision(tiles.area(district)) > district_version and tiles.find(district, cache.area_revision(tiles.area(district))) == null, "Completed fixed site invalidates affected tile")
	check(tiles.find(city, cache.area_revision(tiles.area(city))) == picture, "Revisited unchanged section reuses captured pixels after remote change")
	site.free();cache.poll_changes()
	check(tiles.key(Vector3(20, 0, 20)) == Vector2i.ZERO and tiles.key(Vector3(26, 0, 0)) == Vector2i(1, 0), "Sections use stable snapped anchors")
	for index in range(20):tiles.store(Vector2i(index, 0), ImageTexture.new(), cache.revision)
	check(tiles.tiles.size() == tiles.LIMIT and tiles.find(Vector2i.ZERO, cache.revision) == null, "Captured texture memory bounded by LRU")
	check(tiles.find(Vector2i(19, 0), cache.revision + 1) == null and tiles.tiles.size() == tiles.LIMIT - 1, "Scenery change invalidates only affected pixels")
	cache.clear_view();check(cache.entries.size() == 3 and cache.scans == 1, "Closing full map frees proxies while preserving scenery index")
	cache.dispose();check(not node_added.is_connected(cache.node_added), "Cache releases scene-tree observers")
	# Compile the real map/minimap path as part of the focused check.
	check(load("res://town_map.gd") != null and load("res://walking_minimap.gd") != null, "Integrated map scripts compile")
	print("MINIMAP_CACHE_REVIEW_COMPLETE failures=", failures, " scans=", cache.scans, " proxy_creations=", creations, " tile_limit=", tiles.LIMIT)
	quit(0 if failures.is_empty() else 1)
