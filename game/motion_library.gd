extends RefCounted

static var cached: Dictionary={}
static var action_rests: Dictionary={}
static var action_parents: Dictionary={}
static var adapted: Dictionary={}
static var erika_baseline: Dictionary={}
const FITTED_LOCOMOTION=["RunnerRun","RunnerJump"]
const REMAINING_ACTIONS=["CarryingTurn","CarryingIdle","ShoveReaction","DrunkWalkBackwards","Singing","Praying"]
const DENSE_GROUNDED_ACTIONS=["JazzDance","HeadShakeNo","CarryingTurn","CarryingIdle","ShoveReaction","DrunkWalkBackwards","Singing","Praying"]
const NEW_ACTIONS=["RunnerRoll","RunnerDance","RunnerWorking","RunnerPunch","SitPoint","PickFruit","DrawSword","DrawArrow","AimOverdraw","Examine","ShieldIdle","ShieldKick","Defeated","DigPlant","ActionToIdle","WaveGesture","WheelbarrowWalk","FemaleWalk","ActionPose","DrunkIdle","SittingPose","ShieldBlock","ShieldBlockHold","ShieldSlash","PullPlant","BoxIdle","BoxWalk","PickUp","WorkDevice","BasicLeftStrafeWalking","BasicRightStrafeWalking","BasicIdle","BasicJump","BasicWalking","BasicRightTurn90","BasicLeftTurn90","JazzDance","HeadShakeNo"]

# NPCs share completed clips; player clips stay private for stance/loop edits.
# The optional flag also supports other callers that need to mutate animations.
static func attach(model: Node3D,animator: AnimationPlayer,private_clips: bool=false) -> void:
	if not animator:return
	if cached.is_empty():
		for asset in ["worker","runner_motion","daily_motion","runner_actions","runner_extra_actions","equipment_actions","farming_actions","basic_locomotion","social_actions","remaining_actions"]:
			var packed:=load("res://characters/"+asset+".glb") as PackedScene
			if not packed:continue
			var source:=packed.instantiate()
			var players:=source.find_children("*","AnimationPlayer",true,false)
			var rigs:=source.find_children("*","Skeleton3D",true,false)
			if not players.is_empty() and not rigs.is_empty():
				var rig: Skeleton3D=rigs[0]
				var rest: Dictionary={};var parents: Dictionary={}
				for i in range(rig.get_bone_count()):
					rest[rig.get_bone_name(i)]=rig.get_bone_rest(i)
					parents[rig.get_bone_name(i)]=rig.get_bone_name(rig.get_bone_parent(i)) if rig.get_bone_parent(i)>=0 else ""
				for name in players[0].get_animation_list():
					if asset in ["worker","runner_motion"]:erika_baseline[name]=true
					else:erika_baseline.erase(name)
					# Imported resources are immutable templates, so keep their references.
					cached[name]=players[0].get_animation(String(name))
					action_rests[name]=rest
					action_parents[name]=parents
			source.free()
	var skeletons := model.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty():return
	var rig: Skeleton3D=skeletons[0]
	var root := animator.get_node(animator.root_node)
	var path := String(root.get_path_to(rig))
	var library := animator.get_animation_library("").duplicate() as AnimationLibrary
	animator.remove_animation_library("")
	animator.add_animation_library("",library)
	var erika:=model.scene_file_path.ends_with("/erika_archer.glb")
	# Existing player setup installs PlayerIdle before calling this method.
	# Keep that caller compatible without relying on a particular node name.
	private_clips=private_clips or library.has_animation("PlayerIdle")
	var rest_signature: Array=[]
	for bone in range(rig.get_bone_count()):
		rest_signature.append([rig.get_bone_name(bone),rig.get_bone_parent(bone),rig.get_bone_rest(bone)])
	var rig_key: String=model.scene_file_path+":"+path+":"+str(hash(rest_signature))
	preload("res://prepared_motion_cache.gd").select_rig(rig_key)
	for name in cached:
		if erika_baseline.has(name) and not erika and name not in FITTED_LOCOMOTION:continue
		if library.has_animation(name):
			if not ((erika and erika_baseline.has(name)) or name in FITTED_LOCOMOTION):continue
			library.remove_animation(name)
		var key: String=rig_key+":"+String(name)
		var disk_key:=""
		if not adapted.has(key):
			disk_key=preload("res://prepared_motion_cache.gd").key(rig_key,name,cached[name],action_rests.get(name,{}))
			var prepared: Animation=preload("res://prepared_motion_cache.gd").restore(disk_key,rig,path)
			if prepared:adapted[key]=prepared
		if not adapted.has(key):
			var fitted := cached[name].duplicate() as Animation
			if name in NEW_ACTIONS or name in REMAINING_ACTIONS or name in FITTED_LOCOMOTION or erika:
				fitted=fit_action(fitted,rig,action_rests.get(name,{}),action_parents.get(name,{}),name)
			fitted.loop_mode=Animation.LOOP_LINEAR if name in ["SitIdle","WorkTable","WorkHarvest","RunnerDance","RunnerWorking","PickFruit","ShieldIdle","ShieldBlockHold","DigPlant","WheelbarrowWalk","FemaleWalk","DrunkIdle","Idle","Walk","Run","PlayerIdle","RunnerRun","BoxIdle","BoxWalk","WorkDevice","BasicLeftStrafeWalking","BasicRightStrafeWalking","BasicIdle","BasicWalking","JazzDance"] else Animation.LOOP_NONE
			for track in range(fitted.get_track_count()-1,-1,-1):
				var original := fitted.track_get_path(track)
				if original.get_subname_count()>0 and rig.find_bone(String(original.get_subname(0)))>=0:
					fitted.track_set_path(track,NodePath(path+":"+String(original.get_subname(0))))
				else:fitted.remove_track(track)
			adapted[key]=fitted
			preload("res://prepared_motion_cache.gd").save(disk_key,fitted)
		var clip: Animation=adapted[key].duplicate() if private_clips else adapted[key]
		library.add_animation(name,clip)
	preload("res://prepared_motion_cache.gd").finish_rig()
	if erika and library.has_animation("Idle") and not library.has_animation("PlayerIdle"):
		library.add_animation("PlayerIdle",library.get_animation("Idle"))

static func fit_action(clip: Animation,rig: Skeleton3D,rests: Dictionary,parents: Dictionary,clip_name: String) -> Animation:
	var original:=clip.duplicate() as Animation
	var named_tracks: Dictionary={}
	var tracks: Dictionary={}
	for track in range(clip.get_track_count()-1,-1,-1):
		var path:=clip.track_get_path(track)
		if path.get_subname_count()==0:continue
		var name:=String(path.get_subname(0));var bone:=rig.find_bone(name)
		if bone<0 or not rests.has(name):continue
		if not named_tracks.has(name):named_tracks[name]={}
		named_tracks[name][clip.track_get_type(track)]=track
		var source: Transform3D=rests[name];var target:=rig.get_bone_rest(bone)
		if not tracks.has(bone):tracks[bone]={}
		tracks[bone][clip.track_get_type(track)]=track
		for index in range(clip.track_get_key_count(track)):
			match clip.track_get_type(track):
				Animation.TYPE_POSITION_3D:
					var value: Vector3=clip.track_get_key_value(track,index)
					var ratio: float=target.origin.length()/source.origin.length() if source.origin.length()>.001 else 1.0
					clip.track_set_key_value(track,index,target.origin+(value-source.origin)*ratio)
				Animation.TYPE_ROTATION_3D:
					var value: Quaternion=clip.track_get_key_value(track,index)
					clip.track_set_key_value(track,index,(target.basis.get_rotation_quaternion()*source.basis.get_rotation_quaternion().inverse()*value).normalized())
				Animation.TYPE_SCALE_3D:clip.track_set_key_value(track,index,target.basis.get_scale())
	var rest_globals: Dictionary={};var frames: Dictionary={}
	for bone in tracks:
		if not tracks[bone].has(Animation.TYPE_ROTATION_3D):continue
		var track: int=tracks[bone][Animation.TYPE_ROTATION_3D]
		for index in range(clip.track_get_key_count(track)):
			var time:=clip.track_get_key_time(track,index)
			if not frames.has(time):frames[time]={"source":{},"target":{}}
			var posed:=retarget_pose(original,clip,rig,tracks,named_tracks,rests,parents,bone,time,frames[time],rest_globals)
			var parent:=rig.get_bone_parent(bone)
			var local: Basis=retarget_pose(original,clip,rig,tracks,named_tracks,rests,parents,parent,time,frames[time],rest_globals).basis.inverse()*posed.basis if parent>=0 else posed.basis
			clip.track_set_key_value(track,index,local.orthonormalized().get_rotation_quaternion())
	for side in ["L","R"]:
		var foot:=rig.find_bone("Foot."+side);var leg:=rig.find_bone("LowerLeg."+side)
		if foot<0 or leg<0 or not tracks.has(foot) or not tracks[foot].has(Animation.TYPE_POSITION_3D):continue
		var track: int=tracks[foot][Animation.TYPE_POSITION_3D]
		var offset: Vector3=rig.get_bone_global_rest(leg).affine_inverse()*rig.get_bone_global_rest(foot).origin
		for index in range(clip.track_get_key_count(track)):
			var time:=clip.track_get_key_time(track,index);var poses: Dictionary={}
			var ankle: Vector3=pose_at(clip,rig,tracks,leg,time,poses)*offset
			var parent:=rig.get_bone_parent(foot)
			var local: Vector3=pose_at(clip,rig,tracks,parent,time,poses).affine_inverse()*ankle if parent>=0 else ankle
			clip.track_set_key_value(track,index,local)
	if clip_name in DENSE_GROUNDED_ACTIONS or clip_name in ["Idle","Walk","Run","RunnerRun","DigPlant","RunnerWorking","ShieldIdle","ShieldKick","ShieldBlock","ShieldBlockHold","ShieldSlash","ActionPose","PullPlant","BoxIdle","BoxWalk","PickUp","WorkDevice","BasicLeftStrafeWalking","BasicRightStrafeWalking","BasicIdle","BasicWalking","BasicRightTurn90","BasicLeftTurn90"]:
		ground_action(clip,rig,tracks,clip_name in DENSE_GROUNDED_ACTIONS,clip_name=="Praying")
	return clip

static func ground_action(clip: Animation,rig: Skeleton3D,tracks: Dictionary,dense_keys: bool=false,kneeling: bool=false) -> void:
	var root:=rig.find_bone("Root")
	var left:=rig.find_bone("Foot.L")
	var right:=rig.find_bone("Foot.R")
	if root<0 or left<0 or right<0:return
	var track: int=tracks.get(root,{}).get(Animation.TYPE_POSITION_3D,-1)
	if track<0 and dense_keys:
		track=clip.add_track(Animation.TYPE_POSITION_3D)
		var rig_path:=String(clip.track_get_path(0)).get_slice(":",0)
		clip.track_set_path(track,NodePath(rig_path+":"+rig.get_bone_name(root)))
		clip.position_track_insert_key(track,0,rig.get_bone_rest(root).origin)
		clip.position_track_insert_key(track,clip.length,rig.get_bone_rest(root).origin)
		if not tracks.has(root):tracks[root]={}
		tracks[root][Animation.TYPE_POSITION_3D]=track
	if track<0:return
	if dense_keys:
		# glTF drops constant root keys, but a dance still needs a ground offset
		# at each leg pose. Restore that sampling before computing the offsets.
		var times: Dictionary={}
		for source_track in range(clip.get_track_count()):
			if clip.track_get_type(source_track) not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:continue
			for index in range(clip.track_get_key_count(source_track)):
				var time:=clip.track_get_key_time(source_track,index)
				times[time]=clip.position_track_interpolate(track,time)
		for index in range(clip.track_get_key_count(track)-1,-1,-1):clip.track_remove_key(track,index)
		var ordered:=times.keys();ordered.sort()
		for time in ordered:clip.position_track_insert_key(track,time,times[time])
	var ankle_rest:=minf(rig.get_bone_global_rest(left).origin.y,rig.get_bone_global_rest(right).origin.y)
	var values: Array[Vector3]=[]
	for index in range(clip.track_get_key_count(track)):
		var time:=clip.track_get_key_time(track,index)
		var poses: Dictionary={}
		var ankle:=minf(pose_at(clip,rig,tracks,left,time,poses).origin.y,pose_at(clip,rig,tracks,right,time,poses).origin.y)
		var origin: Vector3=clip.track_get_key_value(track,index)
		var support_y:=ankle-ankle_rest
		if kneeling:
			for side in ["L","R"]:
				pose_at(clip,rig,tracks,rig.find_bone("LowerLeg."+side),time,poses)
			support_y=prayer_support_height(rig,poses)
		var correction:=Vector3.DOWN*support_y
		var parent:=rig.get_bone_parent(root)
		if parent>=0:correction=pose_at(clip,rig,tracks,parent,time,poses).basis.inverse()*correction
		values.append(origin+correction)
	for index in range(values.size()):
		clip.track_set_key_value(track,index,values[index])

static func prayer_support_height(rig: Skeleton3D,poses: Dictionary) -> float:
	# The kneeling pose rests on knees or boot tips as their heights change.
	var support:=INF
	for side in ["L","R"]:
		var foot:=rig.find_bone("Foot."+side)
		var knee:=rig.find_bone("LowerLeg."+side)
		var foot_rest:=rig.get_bone_global_rest(foot)
		var sole_offset:=foot_rest.affine_inverse()*Vector3(foot_rest.origin.x,0,foot_rest.origin.z)
		var knee_radius:=rig.get_bone_global_rest(knee).origin.distance_to(foot_rest.origin)*.16
		var foot_pose: Transform3D=poses[foot]
		var knee_pose: Transform3D=poses[knee]
		support=minf(support,minf((foot_pose*sole_offset).y,knee_pose.origin.y-knee_radius))
	return support

static func source_pose(clip: Animation,tracks: Dictionary,rests: Dictionary,parents: Dictionary,name: String,time: float,cache: Dictionary,rest_only:=false) -> Transform3D:
	if cache.has(name):return cache[name]
	var rest: Transform3D=rests[name];var position:=rest.origin;var rotation:=rest.basis.get_rotation_quaternion()
	var values: Dictionary=tracks.get(name,{})
	if not rest_only:
		if values.has(Animation.TYPE_POSITION_3D):position=clip.position_track_interpolate(values[Animation.TYPE_POSITION_3D],time)
		if values.has(Animation.TYPE_ROTATION_3D):rotation=clip.rotation_track_interpolate(values[Animation.TYPE_ROTATION_3D],time)
	var local:=Transform3D(Basis(rotation).scaled(rest.basis.get_scale()),position)
	var parent: String=parents.get(name,"")
	cache[name]=source_pose(clip,tracks,rests,parents,parent,time,cache,rest_only)*local if not parent.is_empty() else local
	return cache[name]

static func retarget_pose(original: Animation,clip: Animation,rig: Skeleton3D,tracks: Dictionary,named: Dictionary,rests: Dictionary,parents: Dictionary,bone: int,time: float,frames: Dictionary,rest_globals: Dictionary) -> Transform3D:
	if frames.target.has(bone):return frames.target[bone]
	var rest:=rig.get_bone_rest(bone);var parent:=rig.get_bone_parent(bone)
	var parent_pose: Transform3D=retarget_pose(original,clip,rig,tracks,named,rests,parents,parent,time,frames,rest_globals) if parent>=0 else Transform3D.IDENTITY
	var name:=rig.get_bone_name(bone);var rotation: Quaternion=(parent_pose.basis*rest.basis).orthonormalized().get_rotation_quaternion()
	if rests.has(name):
		var src:=source_pose(original,named,rests,parents,name,time,frames.source)
		var src_rest:=source_pose(original,named,rests,parents,name,0,rest_globals,true)
		rotation=(src.basis.orthonormalized().get_rotation_quaternion()*src_rest.basis.orthonormalized().get_rotation_quaternion().inverse()*rig.get_bone_global_rest(bone).basis.orthonormalized().get_rotation_quaternion()).normalized()
	var position:=rest.origin
	if tracks.get(bone,{}).has(Animation.TYPE_POSITION_3D):position=clip.position_track_interpolate(tracks[bone][Animation.TYPE_POSITION_3D],time)
	frames.target[bone]=Transform3D(Basis(rotation).scaled(rig.get_bone_global_rest(bone).basis.get_scale()),parent_pose*position)
	return frames.target[bone]

static func pose_at(clip: Animation,rig: Skeleton3D,tracks: Dictionary,bone: int,time: float,poses: Dictionary) -> Transform3D:
	if poses.has(bone):return poses[bone]
	var rest:=rig.get_bone_rest(bone);var position:=rest.origin;var rotation:=rest.basis.get_rotation_quaternion()
	var values: Dictionary=tracks.get(bone,{})
	if values.has(Animation.TYPE_POSITION_3D):position=clip.position_track_interpolate(values[Animation.TYPE_POSITION_3D],time)
	if values.has(Animation.TYPE_ROTATION_3D):rotation=clip.rotation_track_interpolate(values[Animation.TYPE_ROTATION_3D],time)
	var local:=Transform3D(Basis(rotation).scaled(rest.basis.get_scale()),position)
	var parent:=rig.get_bone_parent(bone)
	poses[bone]=pose_at(clip,rig,tracks,parent,time,poses)*local if parent>=0 else local
	return poses[bone]
