extends SceneTree

const Motions=preload("res://motion_library.gd")
const STYLES=["adventurer","armoured_assassin","bruce","cult_archer","emlyn","erika_archer","female_peasant","female_ranger","knight","male_peasant","male_ranger","medieval_woman","medieval","mercenary","night_hunter","robed_scholar","runner_child","runner_youth","saxon","viking","witch","worker"]
var failures: Array[String]=[]
var results: Array=[]
var sheets: Dictionary={}
var caption: Label

func _initialize() -> void:run.call_deferred()

func run() -> void:
	# Load only locomotion templates, not the world or other action packs.
	if "--pose-images" in OS.get_cmdline_user_args():setup_capture()
	var baseline: Node3D=load("res://characters/worker.glb").instantiate()
	cache_source(baseline,["Idle","Walk","Run"])
	baseline.free()
	var source: Node3D=load("res://characters/runner_motion.glb").instantiate()
	var source_rig: Skeleton3D=source.find_children("*","Skeleton3D",true,false)[0]
	var source_player: AnimationPlayer=source.find_children("*","AnimationPlayer",true,false)[0]
	var rests: Dictionary={};var parents: Dictionary={}
	for bone in range(source_rig.get_bone_count()):
		var name:=source_rig.get_bone_name(bone)
		rests[name]=source_rig.get_bone_rest(bone)
		parents[name]=source_rig.get_bone_name(source_rig.get_bone_parent(bone)) if source_rig.get_bone_parent(bone)>=0 else ""
	for name in ["RunnerRun","RunnerJump"]:
		Motions.cached[name]=source_player.get_animation(name)
		Motions.action_rests[name]=rests;Motions.action_parents[name]=parents
		Motions.erika_baseline[name]=true
	var tile:=0
	for style in STYLES:
		var model: Node3D=load("res://characters/"+style+".glb").instantiate()
		root.add_child(model)
		var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
		var animator: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
		var library:=animator.get_animation_library("").duplicate() as AnimationLibrary
		animator.remove_animation_library("");animator.add_animation_library("",library)
		var target_path:=String(animator.get_node(animator.root_node).get_path_to(rig))
		for name in ["RunnerRun","RunnerJump"]:
			var raw: Animation=Motions.cached[name].duplicate()
			for track in range(raw.get_track_count()-1,-1,-1):
				var path:=raw.track_get_path(track)
				if path.get_subname_count()>0 and rig.find_bone(String(path.get_subname(0)))>=0:
					raw.track_set_path(track,NodePath(target_path+":"+String(path.get_subname(0))))
				else:raw.remove_track(track)
			library.add_animation(name+"Raw",raw)
			# Reproduce older player setup: a raw clip already exists by this name.
			library.add_animation(name,raw)
		Motions.attach(model,animator)
		for name in ["RunnerRun","RunnerJump"]:
			if animator.get_animation(name)==animator.get_animation(name+"Raw"):
				failures.append(style+" retained unfitted "+name)
		var attachment: SkeletonModifier3D=load("res://feet_attachment.gd").new()
		attachment.model=model;rig.add_child(attachment)
		for clip in ["Walk","Run","RunnerRunRaw","RunnerJumpRaw","RunnerRun","RunnerJump"]:
			if not animator.has_animation(clip):continue
			var metrics:=measure(rig,animator,clip,attachment,not clip.ends_with("Raw"))
			metrics.style=style;metrics.clip=clip;results.append(metrics)
			print("LOCOMOTION_RIG ",JSON.stringify(metrics))
			if not clip.ends_with("Raw"):
				if metrics.ankle_gap>.015:failures.append(style+" "+clip+" ankle detached")
				if metrics.thigh_stretch>.015:failures.append(style+" "+clip+" thigh stretched")
				if metrics.shin_stretch>.015:failures.append(style+" "+clip+" shin stretched")
		var blend_error:=measure_blends(rig,animator,attachment)
		if blend_error>.015:failures.append(style+" blended ankle detached")
		print("LOCOMOTION_BLEND style=",style," ankle_gap=",blend_error)
		if not sheets.is_empty():await capture_poses(style,tile,animator,attachment)
		tile+=1
		model.free()
		# Completed resources stay cached just as in the real game.
	source.free()
	for name in sheets:sheets[name].save_png("res://../review/locomotion-"+name+".png")
	var output:=FileAccess.open("res://../review/locomotion-rig-results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"results":results,"failures":failures},"\t"))
	print("LOCOMOTION_RIG_REVIEW_COMPLETE models=",STYLES.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func measure(rig: Skeleton3D,animator: AnimationPlayer,clip: String,attachment: SkeletonModifier3D,correct: bool) -> Dictionary:
	var ankle_gap:=0.0;var thigh_stretch:=0.0;var shin_stretch:=0.0
	var samples:=61
	animator.stop();rig.reset_bone_poses()
	animator.play(clip,0)
	for sample in range(samples):
		animator.seek(animator.get_animation(clip).length*float(sample)/(samples-1),true)
		animator.advance(0);rig.force_update_all_bone_transforms()
		if correct:attachment._process_modification_with_delta(0)
		for side in ["L","R"]:
			var thigh:=rig.find_bone("UpperLeg."+side);var shin:=rig.find_bone("LowerLeg."+side);var foot:=rig.find_bone("Foot."+side)
			if thigh<0 or shin<0 or foot<0:continue
			var rest_thigh:=rig.get_bone_global_rest(thigh);var rest_shin:=rig.get_bone_global_rest(shin);var rest_foot:=rig.get_bone_global_rest(foot)
			var pose_thigh:=rig.get_bone_global_pose(thigh);var pose_shin:=rig.get_bone_global_pose(shin);var pose_foot:=rig.get_bone_global_pose(foot)
			var rest_offset: Vector3=rest_shin.affine_inverse()*rest_foot.origin
			ankle_gap=maxf(ankle_gap,(pose_shin*rest_offset).distance_to(pose_foot.origin))
			var thigh_length:=rest_thigh.origin.distance_to(rest_shin.origin)
			var shin_length:=rest_shin.origin.distance_to(rest_foot.origin)
			thigh_stretch=maxf(thigh_stretch,absf(pose_thigh.origin.distance_to(pose_shin.origin)/maxf(thigh_length,.001)-1))
			shin_stretch=maxf(shin_stretch,absf(pose_shin.origin.distance_to(pose_foot.origin)/maxf(shin_length,.001)-1))
	return {"samples":samples,"ankle_gap":ankle_gap,"thigh_stretch":thigh_stretch,"shin_stretch":shin_stretch}

func cache_source(model: Node3D,names: Array) -> void:
	var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
	var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
	var rests: Dictionary={};var parents: Dictionary={}
	for bone in range(rig.get_bone_count()):
		var name:=rig.get_bone_name(bone)
		rests[name]=rig.get_bone_rest(bone)
		parents[name]=rig.get_bone_name(rig.get_bone_parent(bone)) if rig.get_bone_parent(bone)>=0 else ""
	for name in names:
		Motions.cached[name]=player.get_animation(name)
		Motions.action_rests[name]=rests;Motions.action_parents[name]=parents
		Motions.erika_baseline[name]=true

func measure_blends(rig: Skeleton3D,animator: AnimationPlayer,attachment: SkeletonModifier3D) -> float:
	var gap:=0.0
	animator.play("Walk",0);animator.advance(.15)
	for clip in ["RunnerRun","RunnerJump","Walk"]:
		animator.play(clip,.3)
		for frame in range(31):
			animator.advance(.01)
			attachment._process_modification_with_delta(.01)
			for index in range(attachment.feet.size()):
				var ankle: Vector3=rig.get_bone_global_pose(attachment.legs[index])*attachment.offsets[index]
				gap=maxf(gap,ankle.distance_to(rig.get_bone_global_pose(attachment.feet[index]).origin))
	return gap

func setup_capture() -> void:
	root.size=Vector2i(240,320)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("33434e"))
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.65
	root.add_child(environment)
	for direction in [Vector3(-35,-28,0),Vector3(-25,146,0)]:
		var light:=DirectionalLight3D.new();light.rotation_degrees=direction;light.light_energy=.8
		root.add_child(light)
	var camera:=Camera3D.new();root.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.5
	camera.position=Vector3(2.0,1.4,4);camera.look_at(Vector3(0,.95,0));camera.current=true
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	caption=Label.new();canvas.add_child(caption);caption.position=Vector2(5,295)
	caption.add_theme_font_size_override("font_size",15)
	for name in ["walk","takeoff","apex"]:sheets[name]=Image.create_empty(1200,1600,false,Image.FORMAT_RGBA8)

func capture_poses(style: String,tile: int,animator: AnimationPlayer,attachment: SkeletonModifier3D) -> void:
	caption.text=style
	for name in sheets:
		var clip: String="Walk" if name=="walk" else "RunnerJump"
		animator.stop();attachment.get_skeleton().reset_bone_poses();animator.play(clip,0)
		animator.seek(animator.get_animation(clip).length*(.25 if name=="walk" else .15 if name=="takeoff" else .5),true)
		animator.advance(0);animator.pause()
		await process_frame
		await RenderingServer.frame_post_draw
		var frame:=root.get_texture().get_image();frame.convert(Image.FORMAT_RGBA8)
		sheets[name].blit_rect(frame,Rect2i(0,0,240,320),Vector2i(tile%5*240,tile/5*320))
