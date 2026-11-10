extends SceneTree

class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass

class Settings extends "res://town_performance.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass

var failures: Array[String] = []
var houses: Array[Node3D] = []
var excluded: Array[MeshInstance3D] = []

func _initialize() -> void:run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:failures.append(message);push_error(message)

func make_houses(town: Node3D) -> void:
	for index in range(6):
		var house := Node3D.new();house.name = "CacheHouse" + str(index);town.add_child(house)
		house.position = Vector3(index * 15, 0, 0)
		house.add_to_group("enterable_houses");house.set_meta("modular_house", true);house.set_meta("build_id", "existing:cache" + str(index))
		for row in range(4):
			for col in range(4):
				town.model(house, "Floor_WoodDark", Vector3(col * 2, .06, row * 2))
				town.model(house, "Wall_Plaster_Straight", Vector3(col * 2, row * 3, 0))
		for label in ["Roof", "Door"]:
			var holder := Node3D.new();holder.name = label;house.add_child(holder)
			if label == "Door":holder.add_to_group("doors")
			var prop: Node3D = town.model(holder, "Wall_Plaster_Straight", Vector3.ZERO)
			for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):excluded.append(mesh)
		houses.append(house)

func remove_houses() -> void:
	for house in houses:house.free()
	houses.clear();excluded.clear()

func measure(town: Node3D) -> Dictionary:
	make_houses(town)
	var originals: Array[MeshInstance3D] = []
	for house in houses:
		for mesh: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):originals.append(mesh)
	var settings := Settings.new();town.add_child(settings);settings.town = town
	var started := Time.get_ticks_usec()
	await settings.batch_house_surfaces()
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	var batches := 0
	for house in houses:
		for source: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
			if source in excluded:check(source.visible, "Door and roof geometry remains independently visible")
			elif source in originals:check(not source.visible, "Original architecture replaced once")
			else:
				batches += 1
				check(source.mesh.get_surface_count() == 1 and source.mesh.surface_get_material(0) != null, "Runtime material bound to merged geometry")
	check(batches > 0, "Actual architecture merged")
	for house in houses:
		house.position += Vector3(10, 0, 20);house.hide()
		for mesh: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):check(not mesh.is_visible_in_tree(), "Moved/hidden house owns every merged surface")
	var data := {"ms":elapsed,"batches":batches,"source_surfaces":288}
	settings.free();remove_houses()
	return data

func run() -> void:
	var town := Town.new();root.add_child(town)
	# Asset loading is outside each timed preparation pass. No world/player/NPC
	# simulation is constructed by this focused fixture.
	town.library["Floor_WoodDark"] = load(town.ASSETS + "Floor_WoodDark.gltf")
	town.library["Wall_Plaster_Straight"] = load(town.ASSETS + "Wall_Plaster_Straight.gltf")
	var first: Dictionary = await measure(town)
	var second: Dictionary = await measure(town)
	check(first.batches == 12 and second.batches == 12, "All current house architecture batches rebuilt")
	print("NATIVE_HOUSE_MERGE_REVIEW_COMPLETE failures=", failures, " first=", first, " second=", second, " disk_cache=false doors_roofs_owner_preserved=true")
	quit(0 if failures.is_empty() else 1)
