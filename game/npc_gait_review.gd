extends SceneTree

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var styles: Dictionary={}
	for record in JSON.parse_string(FileAccess.get_file_as_string("res://player_skins.json")):
		styles[record.id]=true
	for style in ["worker","knight","witch","viking","medieval","mercenary","adventurer","night_hunter","emlyn","saxon","bruce","armoured_assassin","robed_scholar","medieval_woman","cult_archer","runner_child","runner_youth","male_peasant","female_peasant","male_ranger","female_ranger","erika_archer"]:
		styles[style]=true
	var report: Array=[]
	for style in styles:
		var packed: PackedScene=load("res://characters/"+style+".glb")
		var model:=packed.instantiate();root.add_child(model)
		var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
		var animator: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
		for clip in ["Walk","Run"]:
			if not animator.has_animation(clip):continue
			var maximum_foot_gap:=0.0
			var maximum_length_error:=0.0
			var length:=animator.get_animation(clip).length
			for sample in range(31):
				animator.play(clip,0);animator.seek(length*sample/31,true);animator.advance(0)
				for side in ["L","R"]:
					var upper:=rig.find_bone("UpperLeg."+side)
					var lower:=rig.find_bone("LowerLeg."+side)
					var foot:=rig.find_bone("Foot."+side)
					if mini(upper,mini(lower,foot))<0:continue
					var rest_offset:=rig.get_bone_global_rest(lower).affine_inverse()*rig.get_bone_global_rest(foot).origin
					var ankle: Vector3=rig.get_bone_global_pose(lower)*rest_offset
					maximum_foot_gap=maxf(maximum_foot_gap,ankle.distance_to(rig.get_bone_global_pose(foot).origin))
					var rest_length:=rig.get_bone_global_rest(upper).origin.distance_to(rig.get_bone_global_rest(lower).origin)
					var actual_length:=rig.get_bone_global_pose(upper).origin.distance_to(rig.get_bone_global_pose(lower).origin)
					maximum_length_error=maxf(maximum_length_error,absf(actual_length-rest_length))
			var item: Dictionary={"style":style,"clip":clip,"foot_gap_m":maximum_foot_gap,"leg_length_error_m":maximum_length_error}
			report.append(item);print("NPC_GAIT_SAMPLE ",JSON.stringify(item))
		model.free()
	var file:=FileAccess.open("res://../npc-gait-review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("NPC_GAIT_REVIEW_COMPLETE samples=",report.size())
	quit()
