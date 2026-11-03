extends SceneTree
class Life extends Node:
	var navigation_ready:=false
class Town extends Node3D:
	var menu_body:=VBoxContainer.new()
	var life:=Life.new()
	var view_mode:=0
	var builder: Node
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var town:=Town.new();root.add_child(town);town.add_child(town.menu_body);town.add_child(town.life)
	var performance=load("res://town_performance.gd").new()
	performance.save_path="user://review-graphics-settings.json";town.add_child(performance)
	assert(performance.mode.item_count==4)
	performance.choose_quality(0)
	assert(is_equal_approx(root.scaling_3d_scale,.6) and Engine.physics_ticks_per_second==30)
	performance.choose_quality(3)
	assert(is_equal_approx(root.scaling_3d_scale,1.0) and Engine.physics_ticks_per_second==60)
	var saved=JSON.parse_string(FileAccess.get_file_as_string(performance.save_path))
	assert(saved.quality==3)
	performance.choose_quality(1,false)
	assert(is_equal_approx(root.scaling_3d_scale,.8))
	print("GRAPHICS_SETTINGS_REVIEW_COMPLETE presets=4 saved=true native_ultra=true balanced=true")
	quit()
