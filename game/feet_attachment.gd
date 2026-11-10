extends SkeletonModifier3D

var model: Node3D
var legs: Array[int]=[]
var feet: Array[int]=[]
var offsets: Array[Vector3]=[]
var initialized:=false

func _process_modification_with_delta(_delta: float) -> void:
	if is_instance_valid(model) and not model.is_visible_in_tree():return
	var skeleton:=get_skeleton()
	if not initialized:
		for side in ["L","R"]:
			var leg:=skeleton.find_bone("LowerLeg."+side)
			var foot:=skeleton.find_bone("Foot."+side)
			if leg<0 or foot<0:continue
			legs.append(leg)
			feet.append(foot)
			offsets.append(skeleton.get_bone_global_rest(leg).affine_inverse()*skeleton.get_bone_global_rest(foot).origin)
		initialized=true
	# Foot controllers are independent bones in these rigs. Anchor them to the
	# currently blended shin pose, including between imported animation keys.
	for index in range(feet.size()):
		var pose:=skeleton.get_bone_global_pose(feet[index])
		pose.origin=skeleton.get_bone_global_pose(legs[index])*offsets[index]
		skeleton.set_bone_global_pose(feet[index],pose)
