extends SkeletonModifier3D

var anchor: Node3D
var arm_bone := -1
var rest := Transform3D.IDENTITY
var grip := Vector3.ZERO
var clearance := .08
var animator: AnimationPlayer

func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(anchor) or arm_bone < 0:return
	var arm := get_skeleton().get_bone_global_pose(arm_bone)
	var current := arm * rest
	var normal := current.basis.z.normalized()
	var forward := Vector3(normal.x,0,absf(normal.z))
	if animator and animator.current_animation.begins_with("Shield"):forward=Vector3.BACK
	if forward.length_squared() < .0625:forward=Vector3.BACK
	forward=forward.normalized()
	var facing := Basis(Vector3.UP.cross(forward),Vector3.UP,forward)
	anchor.basis=arm.basis.inverse()*facing
	anchor.position=arm.affine_inverse()*(arm*grip+forward*clearance)
