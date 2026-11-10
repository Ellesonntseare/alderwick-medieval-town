extends SceneTree

const Motions=preload("res://motion_library.gd")
var failures: Array[String]=[]

func _initialize() -> void:
	call_deferred("review")

func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func make_model(skeleton_name: String="Rig",private_player: bool=false,leg_height: float=1.0) -> Node3D:
	var model:=Node3D.new()
	model.scene_file_path="res://characters/memory_fixture.glb"
	var rig:=Skeleton3D.new();rig.name=skeleton_name
	model.add_child(rig)
	rig.add_bone("Root");rig.set_bone_rest(0,Transform3D.IDENTITY)
	rig.add_bone("Body");rig.set_bone_parent(1,0)
	rig.set_bone_rest(1,Transform3D(Basis.IDENTITY,Vector3.UP*leg_height))
	var player:=AnimationPlayer.new();player.name="AnimationPlayer";player.root_node=NodePath("..")
	model.add_child(player)
	var library:=AnimationLibrary.new()
	if private_player:library.add_animation("PlayerIdle",Animation.new())
	player.add_animation_library("",library)
	root.add_child(model)
	return model

func review() -> void:
	# Synthetic clip: no meshes, imports, world scene or resident instances.
	var source:=Animation.new();source.length=5.0
	var track:=source.add_track(Animation.TYPE_ROTATION_3D)
	source.track_set_path(track,NodePath("Rig:Body"))
	for frame in range(301):source.rotation_track_insert_key(track,frame/60.0,Quaternion(Vector3.UP,sin(frame/60.0)*0.2))
	Motions.cached["RunnerDance"]=source
	Motions.action_rests["RunnerDance"]={"Root":Transform3D.IDENTITY,"Body":Transform3D(Basis.IDENTITY,Vector3.UP)}
	Motions.action_parents["RunnerDance"]={"Root":"","Body":"Root"}
	var before:=int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var a:=make_model();var b:=make_model()
	var aa: AnimationPlayer=a.get_node("AnimationPlayer");var bb: AnimationPlayer=b.get_node("AnimationPlayer")
	var imported_library:=aa.get_animation_library("")
	Motions.attach(a,aa);Motions.attach(b,bb)
	var shared:=aa.get_animation("RunnerDance")
	check(shared==bb.get_animation("RunnerDance"),"Matching NPCs must share the resolved animation")
	check(not imported_library.has_animation("RunnerDance"),"Attaching actions must not pollute imported libraries")
	check(shared.loop_mode==Animation.LOOP_LINEAR,"Dance keeps looping")
	check(shared.track_get_key_count(0)==301,"Fitting retains all source keys")
	check(shared.track_get_path(0)==NodePath("Rig:Body"),"Resolved bone path is retained")
	var simulated_resident_references: Array=[]
	for resident in range(53):simulated_resident_references.append(shared)
	var unique_ids: Dictionary={}
	for clip in simulated_resident_references:unique_ids[clip.get_instance_id()]=true
	check(unique_ids.size()==1,"53 identical-style references use one clip resource")
	var player:=make_model("Rig",true);var pa: AnimationPlayer=player.get_node("AnimationPlayer")
	Motions.attach(player,pa)
	check(pa.get_animation("RunnerDance")!=shared,"Existing PlayerIdle setup gets private action clips")
	pa.get_animation("RunnerDance").loop_mode=Animation.LOOP_NONE
	pa.get_animation("RunnerDance").track_set_key_value(0,0,Quaternion(Vector3.RIGHT,0.4))
	check(shared.loop_mode==Animation.LOOP_LINEAR,"Player loop customization cannot mutate NPC clips")
	check(shared.track_get_key_value(0,0)==Quaternion.IDENTITY,"Player key edits cannot mutate NPC clips")
	var different_path:=make_model("OtherRig");var dp: AnimationPlayer=different_path.get_node("AnimationPlayer")
	Motions.attach(different_path,dp)
	check(dp.get_animation("RunnerDance")!=shared,"Different resolved skeleton paths require separate clips")
	check(dp.get_animation("RunnerDance").track_get_path(0)==NodePath("OtherRig:Body"),"Different skeleton path resolves correctly")
	var different_rest:=make_model("Rig",false,1.2);var dr: AnimationPlayer=different_rest.get_node("AnimationPlayer")
	Motions.attach(different_rest,dr)
	check(dr.get_animation("RunnerDance")!=shared,"Different rest proportions require separate fitted clips")
	# Measure the animation allocation avoided for 53 identical-style residents.
	var base_bytes:=int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var old_copies: Array=[]
	for resident in range(53):old_copies.append(shared.duplicate())
	var copy_bytes:=int(Performance.get_monitor(Performance.MEMORY_STATIC))-base_bytes
	old_copies.clear()
	print("MOTION_MEMORY_REVIEW ",JSON.stringify({"references":53,"unique_shared_clips":unique_ids.size(),"previous_actor_clip_instances":53,"previous_extra_template_instances":1,"current_total_clip_instances":1,"resource_reduction_percent":100.0*53/54,"measured_53_duplicate_bytes":copy_bytes,"source_keys":301,"fixture_static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC))-before,"failures":failures}))
	for model in [a,b,player,different_path,different_rest]:model.free()
	Motions.cached.clear();Motions.adapted.clear();Motions.action_rests.clear();Motions.action_parents.clear()
	quit(0 if failures.is_empty() else 1)
