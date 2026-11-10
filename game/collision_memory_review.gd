extends SceneTree

class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var town:=Town.new();root.add_child(town)
	var mesh:=BoxMesh.new()
	var instances: Array[MeshInstance3D]=[]
	for index in range(3):
		var instance:=MeshInstance3D.new();instance.mesh=mesh
		town.add_child(instance);instance.position.x=index*3
		town.collisions(instance,index==2);instances.append(instance)
	var a: CollisionShape3D=instances[0].get_child(0).get_child(0)
	var b: CollisionShape3D=instances[1].get_child(0).get_child(0)
	var c: CollisionShape3D=instances[2].get_child(0).get_child(0)
	assert(a.shape==b.shape and a.shape!=c.shape)
	assert(not a.shape.backface_collision and c.shape.backface_collision)
	assert(instances[0].get_child(0).global_position==Vector3.ZERO)
	assert(instances[1].get_child(0).global_position==Vector3(3,0,0))
	print("COLLISION_MEMORY_REVIEW_COMPLETE shared_mesh_collision=true backface_isolated=true placed_bodies=true")
	quit()
