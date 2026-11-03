extends SkeletonModifier3D

var resident: CharacterBody3D
var model: Node3D
var feet: Dictionary={}
var initialized := false
var offset := 0.0
var contact_error := 0.0
var corrections := 0
var performance_clock:=0.0

func initialize(skeleton: Skeleton3D) -> void:
	initialized=true
	for side in ["L","R"]:
		var bone := skeleton.find_bone("Foot."+side)
		if bone<0:continue
		var candidates: Array[Vector3]=[]
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			if not mesh.skin or not mesh.visible:continue
			var binding := -1
			for bind in range(mesh.skin.get_bind_count()):
				if mesh.skin.get_bind_bone(bind)==bone or mesh.skin.get_bind_name(bind)==skeleton.get_bone_name(bone):binding=bind;break
			if binding<0:continue
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var bones=arrays[Mesh.ARRAY_BONES]
				var weights=arrays[Mesh.ARRAY_WEIGHTS]
				if bones==null or weights==null:continue
				var stride: int=bones.size()/maxi(1,vertices.size())
				for index in range(vertices.size()):
					for slot in range(stride):
						if bones[index*stride+slot]==binding and weights[index*stride+slot]>0.45:
							candidates.append(mesh.skin.get_bind_pose(binding)*vertices[index])
		if candidates.is_empty():continue
		var rest := skeleton.get_bone_global_rest(bone)
		candidates.sort_custom(func(a: Vector3,b: Vector3):return (rest*a).y<(rest*b).y)
		var sole: Array[Vector3]=[]
		var lowest: float=(rest*candidates[0]).y
		for point in candidates:
			if (rest*point).y>lowest+0.018:break
			sole.append(point)
		feet[bone]=sole

func _process_modification_with_delta(delta: float) -> void:
	if not is_instance_valid(resident) or not is_instance_valid(model):return
	if resident.get_meta("performance_far",false):return
	performance_clock+=delta
	if performance_clock<.033:return
	delta=performance_clock;performance_clock=0
	if resident.get("posture") in ["sleeping","sitting"] or resident.get("getting_up")>0:return
	if resident.get("jump_active")==true or resident.get("resting") in ["sleeping","sitting"]:return
	var skeleton := get_skeleton()
	if not initialized:initialize(skeleton)
	if feet.is_empty():return
	var minimum := INF
	var space := resident.get_world_3d().direct_space_state
	for bone in feet:
		var pose: Transform3D=skeleton.global_transform*skeleton.get_bone_global_pose(bone)
		var sole_y := INF
		var centre := Vector3.ZERO
		for point: Vector3 in feet[bone]:
			var world := pose*point
			sole_y=minf(sole_y,world.y)
			centre+=world
		centre/=feet[bone].size()
		var ray := PhysicsRayQueryParameters3D.create(Vector3(centre.x,resident.global_position.y+0.48,centre.z),Vector3(centre.x,resident.global_position.y-0.9,centre.z),1)
		ray.exclude=[resident.get_rid()]
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y<0.6:continue
		minimum=minf(minimum,sole_y-float(hit.position.y))
	if not is_finite(minimum):return
	# Shift the visual, preserving the animated legs, physical capsule and
	# equipment. The lower sole follows the actual floor rather than a guessed Y.
	var previous_y := model.position.y
	var target := clampf(previous_y-minimum+0.008,-0.55,0.3)
	offset=target if absf(target-previous_y)>0.06 else lerpf(previous_y,target,1.0-exp(-delta*45.0))
	model.position.y=offset
	contact_error=minimum+offset-previous_y
	corrections+=1
