extends SkeletonModifier3D

var resident: Node3D

func rotate_joint(skeleton: Skeleton3D,index: int,current: Vector3,target: Vector3) -> void:
	if current.length()<0.001 or target.length()<0.001:return
	var pose := skeleton.get_bone_global_pose(index)
	pose.basis=Basis(Quaternion(current.normalized(),target.normalized()))*pose.basis
	skeleton.set_bone_global_pose(index,pose)

func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(resident) or resident.carry_kind.is_empty() or resident.posture!="standing":return
	if resident.get_meta("performance_far",false):return
	var skeleton := get_skeleton()
	resident.carry_pose_updates+=1
	resident.carry_hand_error=0.0
	for side in ["L","R"]:
		var upper := skeleton.find_bone("UpperArm."+side)
		var lower := skeleton.find_bone("LowerArm."+side)
		var wrist := skeleton.find_bone("Wrist."+side)
		if upper<0 or lower<0 or wrist<0:continue
		var shoulder: Vector3=skeleton.get_bone_global_pose(upper).origin
		var elbow: Vector3=skeleton.get_bone_global_pose(lower).origin
		var hand: Vector3=skeleton.get_bone_global_pose(wrist).origin
		var sign := 1.0 if side=="L" else -1.0
		var target: Vector3=skeleton.to_local(resident.visual.to_global(Vector3(sign*0.27,1.06,0.32)))
		var first := shoulder.distance_to(elbow)
		var second := elbow.distance_to(hand)
		if first<0.01 or second<0.01:continue
		var reach := clampf(shoulder.distance_to(target),absf(first-second)+0.01,first+second-0.01)
		var axis := (target-shoulder).normalized()
		var along := (first*first-second*second+reach*reach)/(2*reach)
		var outward := Vector3(sign,-0.2,0.05)
		outward=(outward-axis*outward.dot(axis)).normalized()
		var bend := shoulder+axis*along+outward*sqrt(maxf(0,first*first-along*along))
		rotate_joint(skeleton,upper,elbow-shoulder,bend-shoulder)
		elbow=skeleton.get_bone_global_pose(lower).origin
		hand=skeleton.get_bone_global_pose(wrist).origin
		rotate_joint(skeleton,lower,hand-elbow,shoulder+axis*reach-elbow)
		resident.carry_hand_error=maxf(resident.carry_hand_error,skeleton.get_bone_global_pose(wrist).origin.distance_to(target))
