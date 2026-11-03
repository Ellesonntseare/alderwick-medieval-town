extends SceneTree
var town: Node3D
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800)
	town=load("res://town.tscn").instantiate();root.add_child(town)
	while not town.life.navigation_ready:await process_frame
	town.speech.set_enabled(false)
	town.player.position=Vector3(0,.1,23);town.set_view(2)
	Engine.max_fps=60
	for frame in range(240):await process_frame
	print("PERFORMANCE_REVIEW_COMPLETE fps=",Engine.get_frames_per_second()," resident_count=",town.life.people.size())
	if "--performance-leave-open" in OS.get_cmdline_user_args():
		Engine.max_fps=45
		return
	quit()
