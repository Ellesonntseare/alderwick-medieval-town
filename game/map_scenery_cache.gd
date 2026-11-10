extends RefCounted

# Static mesh resources are indexed once. Live actors never enter this world.
# Proxy nodes survive nearby captures; the minimap separately caches pixels.
const CELL_SIZE := 64.0
const INACTIVE_LIMIT := 256
var town: Node3D
var map_root: Node
var scenery: Node3D
var tree: SceneTree
var revision := 0
var initialized := false
var entries: Dictionary = {}
var cells: Dictionary = {}
var large: Dictionary = {}
var pending: Dictionary = {}
var resources: Dictionary = {}
var transient_roots: Dictionary = {}
var builder_state: Array = []
var dirty_resources: Dictionary = {}
var area_revisions: Dictionary = {}
var global_revision := 0
var trace_invalidations := "--review-map-changes" in OS.get_cmdline_user_args()
var recent_invalidations: Array[Dictionary] = []
var scans := 0
var proxy_creations := 0
var proxy_reuses := 0
var serial := 0

func bind(owner: Node3D, map_node: Node, target: Node3D) -> void:
	town = owner;map_root = map_node;scenery = target;tree = town.get_tree()
	tree.node_added.connect(node_added);tree.node_removed.connect(node_removed)

func dispose() -> void:
	if tree and tree.node_added.is_connected(node_added):tree.node_added.disconnect(node_added)
	if tree and tree.node_removed.is_connected(node_removed):tree.node_removed.disconnect(node_removed)
	for id in entries:
		var source: Node3D = entries[id].source.get_ref()
		var callback := visibility_changed.bind(id)
		if is_instance_valid(source) and source.visibility_changed.is_connected(callback):source.visibility_changed.disconnect(callback)
	for id in resources:
		var resource: Resource = resources[id].get_ref()
		var callback := resource_changed.bind(id)
		if resource and resource.changed.is_connected(callback):resource.changed.disconnect(callback)
	clear_view();entries.clear();cells.clear();large.clear();pending.clear();resources.clear()

func eligible(node: Node) -> bool:
	if not (node is MeshInstance3D or node is MultiMeshInstance3D):return false
	if not town.is_ancestor_of(node) or map_root.is_ancestor_of(node):return false
	var current := node
	while current and current != town:
		if current is PhysicsBody3D and not current is StaticBody3D:return false
		if current is Skeleton3D or transient_roots.has(current.get_instance_id()):return false
		if current.has_meta("future_trade_item") or current.has_meta("physical_id") or current.has_meta("held_by") or current.is_in_group("market_produce"):return false
		var script: Script = current.get_script()
		if script and script.resource_path.get_file() in ["archery_school.gd", "sky_birds.gd", "resident_actions.gd"]:return false
		current = current.get_parent()
	return not (node is MeshInstance3D and node.skin)

func node_added(node: Node) -> void:
	# Inspect metadata after the complete gameplay object is attached.
	if (node is MeshInstance3D or node is MultiMeshInstance3D) and town.is_ancestor_of(node) and not map_root.is_ancestor_of(node):
		pending[node.get_instance_id()] = weakref(node)

func node_removed(node: Node) -> void:
	var id := node.get_instance_id()
	pending.erase(id)
	if not entries.has(id):return
	var callback := visibility_changed.bind(id)
	if node.visibility_changed.is_connected(callback):node.visibility_changed.disconnect(callback)
	if entries[id].visible:invalidate(entries[id].bounds, "removed", node)
	remove_cells(id)
	var proxy: Node = entries[id].proxy
	if is_instance_valid(proxy):proxy.hide();proxy.queue_free()
	entries.erase(id)

func visibility_changed(id: int) -> void:
	if not entries.has(id):return
	var record: Dictionary = entries[id]
	var source: Node3D = record.source.get_ref()
	if not is_instance_valid(source):return
	var shown := source.is_visible_in_tree()
	if record.visible == shown:return
	record.visible = shown
	invalidate(record.bounds, "shown" if shown else "hidden", source)

func resource_changed(id: int) -> void:dirty_resources[id] = true

func cell_for(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))

func invalidate(area: Rect2, reason: String, source: Node) -> void:
	revision += 1
	if trace_invalidations:
		var path := str(source.get_path()) if source.is_inside_tree() else str(source.name)
		recent_invalidations.append({"revision":revision,"reason":reason,"source":path,"area":area})
		if recent_invalidations.size() > 32:recent_invalidations.pop_front()
	var start := cell_for(area.position)
	var end := cell_for(area.end)
	if (end.x - start.x + 1) * (end.y - start.y + 1) > 64:
		global_revision = revision;area_revisions.clear();return
	for x in range(start.x, end.x + 1):
		for y in range(start.y, end.y + 1):area_revisions[Vector2i(x, y)] = revision

func area_revision(area: Rect2) -> int:
	var version := global_revision
	var start := cell_for(area.position)
	var end := cell_for(area.end)
	for x in range(start.x, end.x + 1):
		for y in range(start.y, end.y + 1):version = maxi(version, area_revisions.get(Vector2i(x, y), 0))
	return version

func exclude(node: Variant) -> void:
	if node is Node and is_instance_valid(node):transient_roots[node.get_instance_id()] = true

func refresh_exclusions() -> void:
	transient_roots.clear()
	for property in [&"physical_gameplay", &"weather", &"discoveries"]:
		exclude(town.get(property) if property in town else null)
	if &"cooking" in town and is_instance_valid(town.cooking):
		exclude(town.cooking.crop_visual);exclude(town.cooking.herb_visual)
	if &"jobs" in town and is_instance_valid(town.jobs):
		for market in town.jobs.markets.values():exclude(market.get("root"))
		for bench in town.jobs.benches:exclude(bench.get("output"))
	if &"industrial_workforce" in town and is_instance_valid(town.industrial_workforce):
		for worker in town.industrial_workforce.workers.values():exclude(worker.get("output"))
	if &"adventures" in town and is_instance_valid(town.adventures) and &"markers" in town.adventures:
		for marker in town.adventures.markers.values():exclude(marker)
	# Sven's output lives under his workshop building, away from the jobs tree.
	for child in town.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with("/town_places.gd"):exclude(child.output)

func poll_changes() -> void:
	if not initialized or not pending.is_empty():refresh_exclusions()
	if not initialized:
		initialized = true;scans += 1
		for kind in ["MeshInstance3D", "MultiMeshInstance3D"]:
			for source in town.find_children("*", kind, true, false):
				if eligible(source):pending[source.get_instance_id()] = weakref(source)
	for id in pending.keys():
		var source: Node3D = pending[id].get_ref()
		if is_instance_valid(source) and eligible(source):register(source)
	pending.clear()
	var state: Array = []
	var builder: Node = town.get("builder")
	var nodes: Variant = builder.get("nodes") if is_instance_valid(builder) else null
	if nodes is Dictionary:
		for source in nodes.values():
			if is_instance_valid(source) and source is Node3D:state.append([source.get_instance_id(), source.global_transform, source.visible])
	var builder_changed := state != builder_state
	if builder_changed or not dirty_resources.is_empty():
		builder_state = state
		for id in entries.keys():
			var record: Dictionary = entries[id]
			var source: Node3D = record.source.get_ref()
			if not is_instance_valid(source):continue
			var resource_dirty := dirty_resources.has(record.geometry)
			if resource_dirty or (builder_changed and source.global_transform != record.transform):
				var reason := "geometry changed" if resource_dirty else "moved"
				if record.visible:invalidate(record.bounds, reason + " (previous)", source)
				update_bounds(id)
				if record.visible:invalidate(record.bounds, reason + " (current)", source)
		dirty_resources.clear()

func register(source: Node3D) -> void:
	var id := source.get_instance_id()
	var geometry: Resource = source.mesh if source is MeshInstance3D else source.multimesh
	if not geometry:return
	if entries.has(id):return
	var geometry_id := geometry.get_instance_id()
	entries[id] = {"source":weakref(source),"proxy":null,"keys":[],"bounds":Rect2(),"used":0,
		"geometry":geometry_id,"visible":source.is_visible_in_tree(),"transform":source.global_transform}
	source.visibility_changed.connect(visibility_changed.bind(id))
	if not resources.has(geometry_id):
		resources[geometry_id] = weakref(geometry)
		geometry.changed.connect(resource_changed.bind(geometry_id))
	update_bounds(id)
	if entries[id].visible:invalidate(entries[id].bounds, "added", source)

func remove_cells(id: int) -> void:
	large.erase(id)
	for key in entries[id].keys:
		if cells.has(key):
			cells[key].erase(id)
			if cells[key].is_empty():cells.erase(key)
	entries[id].keys = []

func update_bounds(id: int) -> void:
	remove_cells(id)
	var source: Node3D = entries[id].source.get_ref()
	if not is_instance_valid(source):return
	entries[id].transform = source.global_transform
	var box: AABB = source.global_transform * source.get_aabb()
	var area := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z)).grow(.1)
	entries[id].bounds = area
	var start := Vector2i(floori(area.position.x / CELL_SIZE), floori(area.position.y / CELL_SIZE))
	var end := Vector2i(floori(area.end.x / CELL_SIZE), floori(area.end.y / CELL_SIZE))
	if (end.x - start.x + 1) * (end.y - start.y + 1) > 64:large[id] = true;return
	for x in range(start.x, end.x + 1):
		for y in range(start.y, end.y + 1):
			var key := Vector2i(x, y)
			if not cells.has(key):cells[key] = {}
			cells[key][id] = true;entries[id].keys.append(key)

func show_area(area: Rect2) -> void:
	poll_changes();serial += 1
	var candidates := large.duplicate()
	var start := Vector2i(floori(area.position.x / CELL_SIZE), floori(area.position.y / CELL_SIZE))
	var end := Vector2i(floori(area.end.x / CELL_SIZE), floori(area.end.y / CELL_SIZE))
	for x in range(start.x, end.x + 1):
		for y in range(start.y, end.y + 1):
			candidates.merge(cells.get(Vector2i(x, y), {}))
	for id in candidates:
		var record: Dictionary = entries[id]
		var source: Node3D = record.source.get_ref()
		if not is_instance_valid(source) or not source.is_visible_in_tree() or not area.intersects(record.bounds):continue
		var proxy: GeometryInstance3D = record.proxy
		if not is_instance_valid(proxy):
			proxy = MeshInstance3D.new() if source is MeshInstance3D else MultiMeshInstance3D.new()
			scenery.add_child(proxy);record.proxy = proxy;proxy_creations += 1
		else:proxy_reuses += 1
		if proxy is MeshInstance3D:
			proxy.mesh = source.mesh
			for surface in range(source.mesh.get_surface_count()):proxy.set_surface_override_material(surface, source.get_surface_override_material(surface))
		else:proxy.multimesh = source.multimesh
		proxy.transform = source.global_transform;proxy.material_override = source.material_override
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proxy.visible = true;record.used = serial
	var inactive: Array = []
	for id in entries:
		var record: Dictionary = entries[id]
		if is_instance_valid(record.proxy) and record.used != serial:
			record.proxy.hide();inactive.append(id)
	inactive.sort_custom(func(a: int, b: int):return entries[a].used < entries[b].used)
	for index in range(maxi(0, inactive.size() - INACTIVE_LIMIT)):
		var record: Dictionary = entries[inactive[index]]
		record.proxy.queue_free();record.proxy = null

func clear_view() -> void:
	for record in entries.values():
		if is_instance_valid(record.proxy):record.proxy.hide();record.proxy.queue_free()
		record.proxy = null
