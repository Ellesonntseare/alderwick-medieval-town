extends SceneTree

class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass

var failures: Array[String] = []

func _initialize() -> void:run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:failures.append(message);push_error(message)

func run() -> void:
	var town := Town.new();root.add_child(town)
	var house := Node3D.new();town.add_child(house);house.add_to_group("enterable_houses")
	house.set_meta("build_id", "existing:batch-review")
	var room := Node3D.new();house.add_child(room)
	var roof := Node3D.new();roof.name = "Roof";house.add_child(roof)
	var editor := Node3D.new();editor.set_meta("build_id", "placed:review");house.add_child(editor)
	var door := Node3D.new();door.add_to_group("doors");house.add_child(door)
	var assets := ["Table_Large", "Table_Plate", "Mug", "Stool", "Bookcase_2", "Chandelier"]
	var expected: Array[MeshInstance3D] = []
	var opaque: Array[MeshInstance3D] = []
	var before := 0
	for index in range(assets.size()):
		for copy in range(2):
			var asset: Node3D = town.detailed_prop(assets[index], room, Vector3(4 + copy * 2.0, 0, 4 + index * 1.5), Vector3.ONE, true)
			for mesh: MeshInstance3D in asset.find_children("*", "MeshInstance3D", true, false):
				expected.append(mesh);before += mesh.mesh.get_surface_count()
				var can_batch := true
				for surface in range(mesh.mesh.get_surface_count()):
					var material := mesh.get_active_material(surface)
					if material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:can_batch = false
				if can_batch:opaque.append(mesh)
	var excluded: Array[MeshInstance3D] = []
	for owner in [roof, editor, door]:
		for copy in range(2):
			var prop: Node3D = town.detailed_prop("Stool", owner, Vector3(copy, 0, 0), Vector3.ONE, false)
			for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):excluded.append(mesh)
	var collisions := room.find_children("*", "CollisionShape3D", true, false)
	var seat := Marker3D.new();seat.add_to_group("seats");room.add_child(seat)
	var batcher = load("res://static_decoration_batches.gd").new();batcher.build(town)
	check(batcher.source_count == opaque.size(), "Every duplicated opaque real furniture mesh batches")
	var after := 0
	for batch: MultiMeshInstance3D in batcher.batches:
		after += batch.multimesh.mesh.get_surface_count()
		check(batch.get_parent() == room, "Interior furniture retains its room owner")
		check(batch.multimesh.instance_count == 2, "Each real furniture pair keeps both copies")
	for source in expected:
		if source in opaque:check(not source.visible and source.has_meta("performance_batched"), "Opaque furniture rendered once")
		else:
			check(source.visible and not source.has_meta("performance_batched"), "Transparent furniture retains individual sorting")
			after += source.mesh.get_surface_count()
	check(after < before, "Actual asset surface draws decrease")
	for source in excluded:check(source.visible and not source.has_meta("performance_batched"), "Door roof and editable furniture stay separate")
	for collision in collisions:check(is_instance_valid(collision) and collision.shape != null and room.is_ancestor_of(collision), "Furniture collision retained")
	check(is_instance_valid(seat) and seat.is_in_group("seats"), "Seat interaction marker preserved")
	house.position = Vector3(50, 0, -20);room.hide()
	for batch in batcher.batches:check(not batch.is_visible_in_tree(), "Moved house retains independently hidden room")
	print("STATIC_FURNITURE_REVIEW_COMPLETE failures=", failures, " assets=", assets.size(), " source_meshes=", expected.size(), " surface_draws=", before, "->", after, " collisions=", collisions.size())
	quit(0 if failures.is_empty() else 1)
