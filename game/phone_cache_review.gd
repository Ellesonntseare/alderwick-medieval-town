extends SceneTree
const Cache=preload("res://phone_navigation_cache.gd")
const TEST_PATH="user://review-phone-navigation.cache"
class Life extends Node:
	const NAV_REGION=Rect2i(-1,-1,2,2)
	var automated:=false
	var grid:=AStarGrid2D.new()
	var floor_heights: Dictionary={}
	var street_cells: Dictionary={}
func _initialize() -> void:
	var life:=Life.new();life.grid.region=life.NAV_REGION;life.grid.update()
	for x in [-1,0]:
		for z in [-1,0]:life.floor_heights[Vector2i(x,z)]=float(x+z)
	life.grid.set_point_solid(Vector2i(-1,0),true);life.street_cells[Vector2i(0,0)]=true
	Cache.save(life,TEST_PATH)
	life.floor_heights.clear();life.street_cells.clear();life.grid.set_point_solid(Vector2i(-1,0),false)
	assert(Cache.restore(life,TEST_PATH))
	assert(life.floor_heights.size()==4 and life.street_cells.has(Vector2i(0,0)) and life.grid.is_point_solid(Vector2i(-1,0)))
	var version=ProjectSettings.get_setting("application/config/version",null)
	ProjectSettings.set_setting("application/config/version","changed-review-version")
	assert(not Cache.restore(life,TEST_PATH))
	ProjectSettings.set_setting("application/config/version",version)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH));life.free()
	print("PHONE_CACHE_REVIEW_COMPLETE restore=true geometry_version_invalidates=true")
	quit()
