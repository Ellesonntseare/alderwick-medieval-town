extends SkeletonModifier3D

var resident: Node3D
var carrier: Node3D
var model: Node3D
var physical: Node3D
var grip_weight:=1.0

func rotate_joint(skeleton: Skeleton3D,index: int,current: Vector3,target: Vector3) -> void:
	if current.length()<0.001 or target.length()<0.001:return
	var pose := skeleton.get_bone_global_pose(index)
	pose.basis=pose.basis.slerp(Basis(Quaternion(current.normalized(),target.normalized()))*pose.basis,grip_weight)
	skeleton.set_bone_global_pose(index,pose)

func _process_modification_with_delta(_delta: float) -> void:
	var appearance: Node3D
	var payload: Node3D
	if is_instance_valid(resident):
		if (resident.carry_kind.is_empty() and not is_instance_valid(resident.received_object)) or resident.posture!="standing":return
		appearance=resident.visual;grip_weight=1
		payload=resident.carry_root if is_instance_valid(resident.carry_root) else resident.received_object
	elif is_instance_valid(carrier) and is_instance_valid(physical) and is_instance_valid(physical.holding_payload()):
		if not String(carrier.get("resting")).is_empty():return
		appearance=model;grip_weight=physical.hand_grip_weight()
		payload=physical.holding_payload()
	else:return
	# Visible carriers still need their holding pose when distant animation is
	# sampled at a lower rate, including workers viewed from overhead.
	if not is_instance_valid(appearance) or not appearance.is_visible_in_tree() or grip_weight<=.001:return
	var skeleton := get_skeleton()
	if is_instance_valid(resident):resident.carry_pose_updates+=1;resident.carry_hand_error=0.0
	else:physical.player_carry_pose_updates+=1;physical.player_hand_error=0.0
	for side in ["L","R"]:
		var upper := skeleton.find_bone("UpperArm."+side)
		var lower := skeleton.find_bone("LowerArm."+side)
		var wrist := skeleton.find_bone("Wrist."+side)
		if upper<0 or lower<0 or wrist<0:continue
		var shoulder: Vector3=skeleton.get_bone_global_pose(upper).origin
		var elbow: Vector3=skeleton.get_bone_global_pose(lower).origin
		var hand: Vector3=skeleton.get_bone_global_pose(wrist).origin
		var sign := 1.0 if side=="L" else -1.0
		# Grip the rear of each side at waist height. A lower, further-forward
		# target exceeds the arm reach of the shorter original town rigs.
		var grip_point:=Vector3(sign*.30,1.12,.25)
		if is_instance_valid(payload):grip_point+=appearance.to_local(payload.global_position)-Vector3(0,.96,.4)
		var target:=skeleton.to_local(appearance.to_global(grip_point))
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
		# The wrist position alone leaves the hand pointing down with the
		# walking forearm. Orient the palm toward the box and fingers along it.
		var middle:=skeleton.find_bone("Middle2."+side)
		var index:=skeleton.find_bone("Index2."+side)
		var pinky:=skeleton.find_bone("Pinky2."+side)
		if middle>=0 and index>=0 and pinky>=0:
			var wrist_pose:=skeleton.get_bone_global_pose(wrist)
			var forward: Vector3=(skeleton.get_bone_global_pose(middle).origin-wrist_pose.origin).normalized()
			var across: Vector3=skeleton.get_bone_global_pose(index).origin-skeleton.get_bone_global_pose(pinky).origin
			var palm: Vector3=forward.cross(across).normalized()*sign
			if forward.length_squared()>.9 and palm.length_squared()>.9:
				var source:=Basis(forward,palm,forward.cross(palm)).orthonormalized()
				var hold_forward: Vector3=skeleton.global_basis.inverse()*appearance.global_basis*Vector3.BACK
				var hold_palm: Vector3=skeleton.global_basis.inverse()*appearance.global_basis*Vector3(-sign,0,0)
				var grip:=Basis(hold_forward,hold_palm,hold_forward.cross(hold_palm)).orthonormalized()
				wrist_pose.basis=wrist_pose.basis.slerp(grip*source.inverse()*wrist_pose.basis,grip_weight)
				skeleton.set_bone_global_pose(wrist,wrist_pose)
		var error:=skeleton.get_bone_global_pose(wrist).origin.distance_to(target)
		if is_instance_valid(resident):resident.carry_hand_error=maxf(resident.carry_hand_error,error)
		else:physical.player_hand_error=maxf(physical.player_hand_error,error)
