extends RefCounted

const FORMAT:=3

static func key(geometry: String="") -> String:
	var layout:=FileAccess.get_file_as_string("user://town-layout.json") if FileAccess.file_exists("user://town-layout.json") else "default"
	return str([FORMAT,ProjectSettings.get_setting("application/config/version","development"),layout.sha256_text(),FileAccess.get_file_as_string("res://village_life.gd").sha256_text(),geometry]).sha256_text()

static func geometry_key(town: Node3D) -> String:
	# Hash actual collision geometry and transforms, not transient object IDs or
	# visual materials. A moved building or changed mesh invalidates the cache.
	var shapes: Dictionary={}
	var records: Array[String]=[]
	for collider: CollisionShape3D in town.find_children("*","CollisionShape3D",true,false):
		var body:=collider.get_parent() as CollisionObject3D
		if not body or body is CharacterBody3D or (body.collision_layer&1)==0 or collider.disabled or not collider.shape:continue
		var shape:=collider.shape
		if not shapes.has(shape.get_instance_id()):
			var data: Variant
			if shape is BoxShape3D:data=shape.size
			elif shape is CapsuleShape3D or shape is CylinderShape3D:data=[shape.radius,shape.height]
			elif shape is SphereShape3D:data=shape.radius
			elif shape is ConcavePolygonShape3D:data=hash(shape.get_faces())
			elif shape is ConvexPolygonShape3D:data=hash(shape.points)
			elif shape is WorldBoundaryShape3D:data=shape.plane
			else:return ""
			shapes[shape.get_instance_id()]=str([shape.get_class(),data])
		records.append(str([shapes[shape.get_instance_id()],collider.global_transform]))
	records.sort()
	return str(records).sha256_text()

static func restore(life: Node,path: String="user://phone-navigation.cache",geometry: String="") -> bool:
	if life.automated and "--review-cache-enabled" not in OS.get_cmdline_user_args():return false
	if not FileAccess.file_exists(path):return false
	var file:=FileAccess.open_compressed(path,FileAccess.READ,FileAccess.COMPRESSION_ZSTD)
	if not file:return false
	var data=file.get_var(false)
	if not data is Dictionary or data.get("key")!=key(geometry) or data.get("region")!=life.NAV_REGION:return false
	var area: int=life.NAV_REGION.size.x*life.NAV_REGION.size.y
	if not data.get("floor") is Dictionary or data.floor.size()!=area or not data.get("streets") is Dictionary or not data.get("solid") is PackedByteArray or data.solid.size()!=area:return false
	# Validate before mutating navigation, including the complete coordinate set.
	for x in range(life.NAV_REGION.position.x,life.NAV_REGION.end.x):
		for z in range(life.NAV_REGION.position.y,life.NAV_REGION.end.y):
			var value: Variant=data.floor.get(Vector2i(x,z))
			if not (value is float or value is int) or not is_finite(float(value)):return false
	for cell in data.streets:
		if not cell is Vector2i or not life.NAV_REGION.has_point(cell):return false
	for solid: int in data.solid:
		if solid>1:return false
	life.floor_heights=data.floor;life.street_cells=data.streets
	var index:=0
	for x in range(life.NAV_REGION.position.x,life.NAV_REGION.end.x):
		for z in range(life.NAV_REGION.position.y,life.NAV_REGION.end.y):
			life.grid.set_point_solid(Vector2i(x,z),data.solid[index]!=0);index+=1
	print("NAVIGATION_CACHE_RESTORED cells=",area," path=",path)
	return true

static func save(life: Node,path: String="user://phone-navigation.cache",geometry: String="") -> void:
	if life.automated and "--review-cache-enabled" not in OS.get_cmdline_user_args():return
	var solids:=PackedByteArray()
	for x in range(life.NAV_REGION.position.x,life.NAV_REGION.end.x):
		for z in range(life.NAV_REGION.position.y,life.NAV_REGION.end.y):solids.append(1 if life.grid.is_point_solid(Vector2i(x,z)) else 0)
	var temporary:=path+".pending"
	var file:=FileAccess.open_compressed(temporary,FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
	if not file:return
	file.store_var({"key":key(geometry),"region":life.NAV_REGION,"floor":life.floor_heights,"streets":life.street_cells,"solid":solids})
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))!=OK:push_warning("Walking cache could not be saved; it will be rebuilt on the next launch.")
