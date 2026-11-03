extends SceneTree

func _initialize() -> void:
	var failed: Array[String]=[]
	for file in DirAccess.get_files_at("res://"):
		if not file.ends_with(".gd") or file=="script_parse_review.gd":continue
		var script=load("res://"+file)
		if not script or not script.can_instantiate():failed.append(file)
	print("SCRIPT_PARSE_REVIEW_COMPLETE failures=",failed)
	quit(0 if failed.is_empty() else 1)
