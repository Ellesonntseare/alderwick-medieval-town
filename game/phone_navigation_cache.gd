extends RefCounted

static func key() -> String:
	return str(ProjectSettings.get_setting("application/config/version","development"))+FileAccess.get_file_as_string("user://town-layout.json").sha256_text() if FileAccess.file_exists("user://town-layout.json") else str(ProjectSettings.get_setting("application/config/version","development"))+"default"

static func restore(life: Node,path: String="user://phone-navigation.cache") -> bool:
	if life.automated or not FileAccess.file_exists(path):return false
	var file:=FileAccess.open_compressed(path,FileAccess.READ,FileAccess.COMPRESSION_ZSTD)
	if not file:return false
	var data=file.get_var(false)
	if not data is Dictionary or data.get("key")!=key() or data.get("region")!=life.NAV_REGION:return false
	var area: int=life.NAV_REGION.size.x*life.NAV_REGION.size.y
	if not data.get("floor") is Dictionary or data.floor.size()!=area or not data.get("streets") is Dictionary or not data.get("solid") is PackedByteArray or data.solid.size()!=area:return false
	life.floor_heights=data.floor;life.street_cells=data.streets
	var index:=0
	for x in range(life.NAV_REGION.position.x,life.NAV_REGION.end.x):
		for z in range(life.NAV_REGION.position.y,life.NAV_REGION.end.y):
			life.grid.set_point_solid(Vector2i(x,z),data.solid[index]!=0);index+=1
	print("PHONE_NAVIGATION_CACHE_RESTORED")
	return true

static func save(life: Node,path: String="user://phone-navigation.cache") -> void:
	if life.automated:return
	var solids:=PackedByteArray()
	for x in range(life.NAV_REGION.position.x,life.NAV_REGION.end.x):
		for z in range(life.NAV_REGION.position.y,life.NAV_REGION.end.y):solids.append(1 if life.grid.is_point_solid(Vector2i(x,z)) else 0)
	var file:=FileAccess.open_compressed(path,FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
	if file:file.store_var({"key":key(),"region":life.NAV_REGION,"floor":life.floor_heights,"streets":life.street_cells,"solid":solids})
