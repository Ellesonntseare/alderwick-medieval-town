extends SceneTree
const Cache=preload("res://prepared_motion_cache.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var model: Node3D=load("res://characters/worker.glb").instantiate();root.add_child(model)
	var animator: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
	var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
	var source:=animator.get_animation("Walk")
	var snapshot:=Cache.snapshot(source)
	var path:=String(source.track_get_path(0).get_concatenated_names())
	var id:=Cache.key("test-rig","walk-cache-review",source,{})
	Cache.save(id,source)
	var restored:=Cache.restore(id,rig,path)
	assert(restored and restored.get_track_count()==source.get_track_count())
	for track in range(source.get_track_count()):
		assert(restored.track_get_path(track)==source.track_get_path(track))
		assert(restored.track_get_key_count(track)==source.track_get_key_count(track))
		for sample in range(31):
			var time:=source.length*sample/30.0
			match source.track_get_type(track):
				Animation.TYPE_POSITION_3D:assert(source.position_track_interpolate(track,time).is_equal_approx(restored.position_track_interpolate(track,time)))
				Animation.TYPE_ROTATION_3D:assert(source.rotation_track_interpolate(track,time).is_equal_approx(restored.rotation_track_interpolate(track,time)))
				Animation.TYPE_SCALE_3D:assert(source.scale_track_interpolate(track,time).is_equal_approx(restored.scale_track_interpolate(track,time)))
	assert(Cache.restore(id,rig,"wrong/rig/path")==null)
	var invalid:=snapshot.duplicate(true);invalid.tracks[0].type=Animation.TYPE_METHOD
	assert(Cache.decode(invalid,rig,path)==null)
	invalid=snapshot.duplicate(true);invalid.tracks[0].keys[2]=NAN
	assert(Cache.decode(invalid,rig,path)==null)
	var first:=id
	Cache.select_rig("review-batched-rig")
	var rig_file: String=Cache.current_rig
	Cache.save(id,source);Cache.finish_rig()
	Cache.select_rig("review-batched-rig")
	assert(Cache.restore(id,rig,path)!=null)
	Cache.finish_rig()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Cache.ROOT+rig_file+"-rig.cache"))
	Cache.source_keys.clear()
	var changed:=source.duplicate() as Animation
	changed.position_track_insert_key(0,.01,Vector3(0,2,0))
	assert(Cache.key("test-rig","walk-cache-review",changed,{})!=first)
	Cache.source_keys.clear()
	assert(Cache.key("changed-rest-rig","walk-cache-review",source,{})!=first)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Cache.ROOT+id+".cache"))
	print("PREPARED_MOTION_CACHE_REVIEW_COMPLETE real_walk_curve_equivalent=true wrong_rig_rejected=true method_tracks_rejected=true nonfinite_keys_rejected=true changed_source_invalidates=true changed_rig_invalidates=true")
	quit()
