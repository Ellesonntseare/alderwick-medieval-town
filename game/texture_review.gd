extends SceneTree
func _initialize() -> void:
 for path in ["res://downloaded/fortress_Image_15.png","res://downloaded/medieval_house_Image_16.png","res://assets/furniture/T_Page_Noise.png"]:
  var texture=load(path) as Texture2D
  assert(texture and texture.get_width()<=1024 and texture.get_height()<=1024)
  print("TEXTURE_MEMORY_LIMIT_OK ",path," ",texture.get_width(),"x",texture.get_height())
 quit()
