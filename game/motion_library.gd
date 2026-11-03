extends RefCounted

static var cached: Dictionary={}

static func attach(model: Node3D,animator: AnimationPlayer) -> void:
	if not animator:return
	if cached.is_empty():
		var source := (load("res://characters/daily_motion.glb") as PackedScene).instantiate()
		var players := source.find_children("*","AnimationPlayer",true,false)
		if not players.is_empty():
			for name in players[0].get_animation_list():cached[name]=players[0].get_animation(name).duplicate()
		source.free()
	var skeletons := model.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty():return
	var root := animator.get_node(animator.root_node)
	var path := String(root.get_path_to(skeletons[0]))
	var library := animator.get_animation_library("")
	for name in cached:
		if library.has_animation(name):continue
		var clip := cached[name].duplicate() as Animation
		clip.loop_mode=Animation.LOOP_LINEAR if name in ["SitIdle","WorkTable","WorkHarvest"] else Animation.LOOP_NONE
		for track in range(clip.get_track_count()):
			var original := clip.track_get_path(track)
			if original.get_subname_count()>0:clip.track_set_path(track,NodePath(path+":"+String(original.get_subname(0))))
		library.add_animation(name,clip)
