extends SceneTree
func _initialize() -> void:
 var scene=load("res://downloaded/fortress.glb").instantiate()
 for mesh in scene.find_children("*","MeshInstance3D",true,false):
  for surface in range(mesh.mesh.get_surface_count()):
   var material=mesh.get_active_material(surface)
   if material is StandardMaterial3D and material.albedo_texture:
    var tex=material.albedo_texture
    print("ACTUAL_MAP_TEXTURE ",tex.get_class()," ",tex.resource_path," ",tex.get_width(),"x",tex.get_height())
 scene.free()
 quit()
