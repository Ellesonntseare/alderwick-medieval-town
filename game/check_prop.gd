extends SceneTree
func _initialize() -> void:
 print("PROP_START")
 var resource=load("res://assets/furniture/Chandelier.gltf")
 print("PROP_LOADED ",resource)
 var node=resource.instantiate()
 print("PROP_INSTANTIATED ",node)
 node.free()
 quit()
