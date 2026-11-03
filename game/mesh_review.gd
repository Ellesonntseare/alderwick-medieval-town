extends SceneTree
func _initialize() -> void:
 var model=load("res://characters/viking.glb").instantiate()
 for mesh in model.find_children("*","MeshInstance3D",true,false):print("VIKING_MESH ",mesh.name," path=",model.get_path_to(mesh)," bounds=",mesh.get_aabb())
 model.free()
 quit()
