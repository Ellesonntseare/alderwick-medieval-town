extends RefCounted

static func batch(root: Node3D) -> void:
	var groups: Dictionary={}
	var original_count := 0
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		var local: Transform3D=root.global_transform.affine_inverse()*mesh.global_transform
		var key := str(mesh.mesh.get_instance_id())+":"+str(floori(local.origin.x/24))+":"+str(floori(local.origin.z/24))
		if not groups.has(key):
			var resource := mesh.mesh.duplicate() as ArrayMesh
			for surface in range(resource.get_surface_count()):resource.surface_set_material(surface,mesh.get_active_material(surface))
			groups[key]={"mesh":resource,"transforms":[]}
		groups[key].transforms.append(local)
		original_count+=1
	for child in root.get_children():
		root.remove_child(child)
		child.free()
	for data in groups.values():
		var instance := MultiMeshInstance3D.new()
		var multimesh := MultiMesh.new()
		multimesh.transform_format=MultiMesh.TRANSFORM_3D
		multimesh.mesh=data.mesh
		multimesh.instance_count=data.transforms.size()
		for index in range(data.transforms.size()):multimesh.set_instance_transform(index,data.transforms[index])
		instance.multimesh=multimesh
		root.add_child(instance)
	print("PAVING_RENDER_BATCHES meshes=",original_count," batches=",groups.size())
