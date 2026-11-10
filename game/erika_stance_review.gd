extends SceneTree

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var model: Node3D=load("res://characters/erika_archer.glb").instantiate();root.add_child(model)
	var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
	var animator: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
	preload("res://motion_library.gd").attach(model,animator,true)
	var attachment:=preload("res://feet_attachment.gd").new();rig.add_child(attachment)
	var output: Array=[]
	for clip in ["REST","Idle","BasicIdle","Walk","BasicWalking","RunnerJump"]:
		for fraction in [0.0,.25,.5,.75]:
			animator.stop();rig.reset_bone_poses()
			if clip!="REST":
				animator.play(clip,0);animator.seek(animator.get_animation(clip).length*fraction,true);animator.advance(0)
			attachment._process_modification_with_delta(0)
			var head:=rig.get_bone_global_pose(rig.find_bone("Head")).origin
			var hip:=rig.get_bone_global_pose(rig.find_bone("Hips")).origin
			var result: Dictionary={"clip":clip,"fraction":fraction,"head_hip_xz":Vector2(head.x-hip.x,head.z-hip.z)}
			for side in ["L","R"]:
				var thigh:=rig.get_bone_global_pose(rig.find_bone("UpperLeg."+side)).origin
				var knee:=rig.get_bone_global_pose(rig.find_bone("LowerLeg."+side)).origin
				var foot:=rig.get_bone_global_pose(rig.find_bone("Foot."+side)).origin
				var toe:=rig.get_bone_global_pose(rig.find_bone("LeftToeBase" if side=="L" else "RightToeBase")).origin
				var line:=thigh.lerp(foot,(thigh.y-knee.y)/maxf(.001,thigh.y-foot.y))
				var direction: Vector3=toe-foot
				result[side]={"hip":thigh,"knee":knee,"ankle":foot,"knee_bend_deg":rad_to_deg((knee-thigh).angle_to(foot-knee)),"knee_from_hip_ankle_line_xz":Vector2(knee.x-line.x,knee.z-line.z),"toe_direction":direction.normalized()}
			output.append(result);print("ERIKA_STANCE ",JSON.stringify(result))
	var file:=FileAccess.open("res://../review/erika-stance-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"))
	if "--pose-images" in OS.get_cmdline_user_args():await capture_walks(animator,attachment)
	model.free();quit()

func capture_walks(animator: AnimationPlayer,attachment: SkeletonModifier3D) -> void:
	root.size=Vector2i(200,280);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("455365"))
	var light:=DirectionalLight3D.new();root.add_child(light);light.rotation_degrees=Vector3(-30,-30,0)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
	root.add_child(environment)
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.25
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	var label:=Label.new();canvas.add_child(label);label.add_theme_font_size_override("font_size",14)
	var sheet:=Image.create_empty(1600,1120,false,Image.FORMAT_RGBA8)
	for row in range(4):
		var clip: String="Walk" if row%2==0 else "BasicWalking"
		camera.position=Vector3(0,1,4) if row<2 else Vector3(4,1,0)
		camera.look_at(Vector3(0,.95,0))
		for sample in range(8):
			animator.stop();attachment.get_skeleton().reset_bone_poses()
			animator.play(clip,0);animator.seek(animator.get_animation(clip).length*sample/8.0,true);animator.advance(0);animator.pause()
			label.text=clip+" "+str(sample)+(" front" if row<2 else " side")
			await process_frame;await RenderingServer.frame_post_draw
			var frame:=root.get_texture().get_image();frame.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(frame,Rect2i(0,0,200,280),Vector2i(sample*200,row*280))
	sheet.save_png("res://../review/erika-walk-comparison.png")
