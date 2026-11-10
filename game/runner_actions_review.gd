extends SceneTree
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	root.size=Vector2i(1200,800)
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("75858e");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-20,0);stage.add_child(sun)
	var floor_mesh:=MeshInstance3D.new()
	var floor_shape:=PlaneMesh.new();floor_shape.size=Vector2(6,6)
	floor_mesh.mesh=floor_shape
	floor_mesh.position.y=-.02
	stage.add_child(floor_mesh)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(2.8,1.8,4.5);camera.look_at(Vector3(0,.9,0));camera.current=true
	var styles := ["adventurer","armoured_assassin","bruce","cult_archer","emlyn","erika_archer","female_peasant","female_ranger","knight","male_peasant","male_ranger","medieval_woman","medieval","mercenary","night_hunter","robed_scholar","runner_child","runner_youth","saxon","viking","witch","worker"]
	if "--erika-only" in OS.get_cmdline_user_args():styles=["erika_archer"]
	var sheet:=Image.create(960,840,false,Image.FORMAT_RGBA8)
	var tile:=0
	for style in styles:
		var model: Node3D=load("res://characters/"+style+".glb").instantiate();stage.add_child(model)
		var skeleton: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
		var animator: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
		load("res://motion_library.gd").attach(model,animator)
		var clips: Array=load("res://motion_library.gd").NEW_ACTIONS
		if "--farm-only" in OS.get_cmdline_user_args():clips=clips.slice(24)
		for clip in clips:
			check(animator.has_animation(clip),style+" missing "+clip)
			if not animator.has_animation(clip):continue
			var animation:=animator.get_animation(clip)
			var moving:=0.0;var foot_error:=0.0;var lowest:=100.0;var previous:=Vector3.ZERO
			for sample in range(21):
				animator.play(clip,0);animator.seek(animation.length*sample/21,true);animator.advance(0)
				var hand:=skeleton.get_bone_global_pose(skeleton.find_bone("Wrist.R")).origin
				if sample>0:moving+=hand.distance_to(previous)
				previous=hand
				for name in ["Head","Hips","Foot.L","Foot.R"]:
					var pose:=skeleton.get_bone_global_pose(skeleton.find_bone(name))
					check(pose.is_finite(),style+clip+" non-finite pose")
					lowest=minf(lowest,pose.origin.y)
				for side in ["L","R"]:
					var leg:=skeleton.find_bone("LowerLeg."+side);var foot:=skeleton.find_bone("Foot."+side)
					var offset: Vector3=skeleton.get_bone_global_rest(leg).affine_inverse()*skeleton.get_bone_global_rest(foot).origin
					var expected: Vector3=skeleton.get_bone_global_pose(leg)*offset
					foot_error=maxf(foot_error,expected.distance_to(skeleton.get_bone_global_pose(foot).origin))
			print("RUNNER_ACTION_REVIEW style=",style," clip=",clip," seconds=",animation.length," wrist_motion=",moving," foot_error=",foot_error," lowest_bone=",lowest)
			if clip!="ActionPose":check(moving>.02,style+clip+" contains no motion")
			check(foot_error<.04,style+clip+" feet detached from ankles")
			if style=="worker" and DisplayServer.get_name()!="headless":
				animator.play(clip);animator.seek(animation.length*.5,true);animator.advance(0)
				await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../review/"+clip+".png")
		if style=="erika_archer" and DisplayServer.get_name()!="headless":
			var bounds:=AABB()
			var first:=true
			for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
				var box: AABB=model.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
				bounds=box if first else bounds.merge(box)
				first=false
			print("ERIKA_BIND_HEIGHT ",bounds.size.y)
			root.size=Vector2i(512,512);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.15
			camera.position=Vector3(0,1,4);camera.look_at(Vector3(0,.9,0))
			for pose in ["Idle","PlayerIdle","Walk","RunnerRun","RunnerJump","SitIdle","SleepExit","RunnerDance","PickFruit","DrawArrow"]:
				animator.play(pose,0);animator.seek(animator.get_animation(pose).length*.5,true);animator.advance(0)
				await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../review/ErikaArcher-"+pose+".png")
			animator.play("Idle",0);animator.seek(0,true);animator.advance(0)
			var head: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin)
			camera.size=.62;camera.position=head+Vector3(2,.1,2.2);camera.look_at(head+Vector3.UP*.08)
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../review/ErikaArcher-Portrait.png")
		if DisplayServer.get_name()!="headless":
			root.size=Vector2i(160,210)
			camera.projection=Camera3D.PROJECTION_ORTHOGONAL
			camera.size=2.3
			camera.position=Vector3(1.5,1.15,4)
			camera.look_at(Vector3(0,.95,0))
			var pose: String=["PullPlant","BoxWalk","BasicWalking"][tile%3] if "--farm-only" in OS.get_cmdline_user_args() else ["ShieldIdle","DigPlant","DrawArrow"][tile%3]
			animator.play(pose,0)
			animator.seek(animator.get_animation(pose).length*.47,true)
			animator.advance(0)
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered:=root.get_texture().get_image()
			rendered.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(rendered,Rect2i(Vector2i.ZERO,rendered.get_size()),Vector2i(tile%6*160,tile/6*210))
			tile+=1
		model.free()
	if tile>0:sheet.save_png("res://../review/"+("FarmActionRigs.png" if "--farm-only" in OS.get_cmdline_user_args() else "AllActionRigs.png"))
	print("RUNNER_ACTIONS_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
