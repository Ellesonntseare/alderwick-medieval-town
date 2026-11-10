extends SceneTree
var sources: Array[MeshInstance3D]=[]
var cube:=BoxMesh.new()
var material:=StandardMaterial3D.new()
func _initialize() -> void:run.call_deferred()
func source(parent: Node3D,x: float,asset_name:="Prop_Crate") -> MeshInstance3D:
	var asset:=Node3D.new();parent.add_child(asset);asset.set_meta("static_asset",asset_name);asset.position.x=x
	var mesh:=MeshInstance3D.new();asset.add_child(mesh);mesh.mesh=cube;mesh.material_override=material;sources.append(mesh);return mesh
func run() -> void:
	var town:=Node3D.new();root.add_child(town)
	for x in [1.0,3.0,5.0,80.0,82.0]:source(town,x)
	var door:=Node3D.new();town.add_child(door);door.add_to_group("doors")
	var door_mesh:=source(door,0)
	var editor:=Node3D.new();town.add_child(editor);editor.set_meta("build_id","review")
	var editor_mesh:=source(editor,0)
	var house:=Node3D.new();town.add_child(house);house.add_to_group("enterable_houses");house.set_meta("build_id","existing:review")
	source(house,1);source(house,2)
	var batches=load("res://static_decoration_batches.gd").new();batches.build(town)
	assert(batches.source_count==7 and batches.batches.size()==3)
	assert(door_mesh.visible and editor_mesh.visible)
	for batch in batches.batches:
		assert(batch.multimesh.mesh.surface_get_material(0)==material)
		assert(batch.multimesh.mesh!=cube)
		if DisplayServer.get_name()!="headless":
			assert(batch.get_aabb().size.x<17)
			for index in range(batch.multimesh.instance_count):
				var point: Vector3=(batch.global_transform*batch.multimesh.get_instance_transform(index)).origin
				assert(point.x in [1.0,2.0,3.0,5.0,80.0,82.0])
	house.position=Vector3(12,0,9);house.hide()
	for batch in batches.batches:
		if batch.get_parent()==house:
			assert(not batch.is_visible_in_tree())
			if DisplayServer.get_name()!="headless":assert((batch.global_transform*batch.multimesh.get_instance_transform(0)).origin.z==9)
	batches.apply_quality(0)
	for batch in batches.batches:assert(batch.visibility_range_end==65)
	# The expanded furniture list stays within the same interior visibility owner.
	house.show()
	var room:=Node3D.new();house.add_child(room)
	var roof:=Node3D.new();roof.name="Roof";house.add_child(roof)
	for asset in ["Table_Large","Table_Plate","Mug","Stool","Bookcase_2","Chandelier"]:
		source(room,1,asset);source(room,2,asset)
		var roof_mesh:=source(roof,0,asset)
		assert(roof_mesh.visible)
	var furniture=load("res://static_decoration_batches.gd").new();furniture.build(town)
	assert(furniture.source_count==12 and furniture.batches.size()==1)
	room.hide()
	assert(not furniture.batches[0].is_visible_in_tree())
	room.position=Vector3(7,0,3)
	assert(furniture.batches[0].global_position.is_equal_approx(Vector3(20,0,12)))
	assert(not door_mesh.has_meta("performance_batched") and not editor_mesh.has_meta("performance_batched"))
	print("STATIC_DECORATION_REVIEW_COMPLETE sources=7 draws=3 furniture_sources=12 furniture_draws=1 owner_moves=true doors_roofs_editor_preserved=true materials_preserved=true")
	quit()
