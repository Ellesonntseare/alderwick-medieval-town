extends SceneTree

func _initialize() -> void:run.call_deferred()
func run() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://downloaded/neighbour_town/layout.json"))
	var leaves: Dictionary={}
	for leaf in data.doors:leaves[leaf.name]=true
	var source: Node3D=load("res://downloaded/neighbour_town/industrial_town.glb").instantiate();root.add_child(source)
	var output:=Node3D.new();output.name="IndustrialCollision"
	var body:=StaticBody3D.new();output.add_child(body);body.owner=output
	var count:=0
	for mesh: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		var relative: Transform3D=source.global_transform.affine_inverse()*mesh.global_transform
		if leaves.has(String(mesh.name)):
			var bounds: AABB=relative*mesh.get_aabb()
			var across_x: bool=bounds.size.x>=bounds.size.z
			var hinge:=Vector3(bounds.position.x,bounds.position.y,bounds.get_center().z) if across_x else Vector3(bounds.get_center().x,bounds.position.y,bounds.position.z)
			var marker:=Marker3D.new();marker.name=mesh.name;output.add_child(marker);marker.owner=output
			marker.transform=Transform3D(Basis(Vector3.UP,0 if across_x else -PI/2),hinge)
			marker.set_meta("door_size",Vector3(maxf(bounds.size.x,bounds.size.z),bounds.size.y,clampf(minf(bounds.size.x,bounds.size.z),.08,.35)))
			continue
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape();shape.transform=relative
		body.add_child(shape);shape.owner=output;count+=1
	var packed:=PackedScene.new();assert(packed.pack(output)==OK)
	assert(ResourceSaver.save(packed,"res://downloaded/neighbour_town/collision.scn",ResourceSaver.FLAG_COMPRESS)==OK)
	print("INDUSTRIAL_COLLISION_BAKED shapes=",count," doors=",output.get_child_count()-1)
	output.free();source.queue_free();quit()
