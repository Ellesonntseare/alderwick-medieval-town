extends SceneTree
const Fixture=preload("res://town_map_review.gd")
func _initialize() -> void:
	var town:=Fixture.Town.new();root.add_child(town)
	var physical: Node=load("res://physical_gameplay.gd").new();physical.town=town
	var station:=Node3D.new();town.add_child(station)
	var original:=MeshInstance3D.new();station.add_child(original)
	for attempt in range(100):physical.show_work_result(station)
	assert(station.get_child_count()==4 and is_instance_valid(original))
	for child in station.get_children():
		if child!=original:assert(child.get_meta("work_result_visual",false))
	physical.free()
	print("REPEATED_WORK_VISUAL_REVIEW_COMPLETE completed_actions=100 result_meshes=3 original_preserved=true")
	quit()
