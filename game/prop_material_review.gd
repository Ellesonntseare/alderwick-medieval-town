extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var factory: Node3D=load("res://town.gd").new()
	var errors: Array[String]=[]
	for asset in ["Carrot","FarmCrate_Carrot"]:
		var stage := Node3D.new()
		root.add_child(stage)
		var instance: Node3D=factory.detailed_prop(asset,stage,Vector3.ZERO,Vector3.ONE,false)
		for mesh: MeshInstance3D in instance.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				var colors: PackedColorArray=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				print("PROP_MATERIAL asset=",asset," surface=",surface," material=",material.resource_name," vertex_albedo=",material.vertex_color_use_as_albedo," colors=",colors.size()," first=",colors[0] if not colors.is_empty() else Color.WHITE)
				if not colors.is_empty() and not material.vertex_color_use_as_albedo:errors.append(asset+" lost vertex colours")
		stage.queue_free()
	factory.free()
	print("PROP_MATERIAL_REVIEW_COMPLETE failures=",errors)
	quit(0 if errors.is_empty() else 1)
