extends SceneTree
const Cache=preload("res://phone_navigation_cache.gd")
const Fixture=preload("res://phone_cache_review.gd")
const PATH="user://navigation-integrity-review.cache"
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var town:=Node3D.new();root.add_child(town)
	var body:=StaticBody3D.new();town.add_child(body)
	var collider:=CollisionShape3D.new();body.add_child(collider)
	var shape:=BoxShape3D.new();shape.size=Vector3(4,1,5);collider.shape=shape
	var geometry:=Cache.geometry_key(town)
	assert(not geometry.is_empty() and geometry==Cache.geometry_key(town))
	collider.shape=shape.duplicate();assert(geometry==Cache.geometry_key(town))
	body.position.x=2;assert(geometry!=Cache.geometry_key(town));body.position.x=0
	collider.shape.size.x=8;assert(geometry!=Cache.geometry_key(town));collider.shape=shape
	var life:=Fixture.Life.new();life.grid.region=life.NAV_REGION;life.grid.update()
	for x in [-1,0]:
		for z in [-1,0]:life.floor_heights[Vector2i(x,z)]=.2
	life.street_cells[Vector2i(0,0)]=true
	life.grid.set_point_solid(Vector2i(-1,0),true)
	Cache.save(life,PATH,geometry)
	assert(Cache.restore(life,PATH,geometry))
	assert(not Cache.restore(life,PATH,"changed collision mesh"))
	var reader:=FileAccess.open_compressed(PATH,FileAccess.READ,FileAccess.COMPRESSION_ZSTD)
	var data: Dictionary=reader.get_var(false);reader.close()
	data.floor.erase(Vector2i(0,0));data.floor[Vector2i(99,99)]=.2
	var writer:=FileAccess.open_compressed(PATH,FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD);writer.store_var(data);writer.close()
	assert(not Cache.restore(life,PATH,geometry))
	assert(life.floor_heights.has(Vector2i(0,0)) and not life.floor_heights.has(Vector2i(99,99)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH));life.free()
	print("NAVIGATION_INTEGRITY_REVIEW_COMPLETE stable_geometry=true moved_building_invalidates=true resized_shape_invalidates=true changed_mesh_invalidates=true corrupt_coordinates_rejected=true prior_grid_preserved=true")
	quit()
