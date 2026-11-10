extends SceneTree

var preview_camera: Camera3D
var sheet: Image
var pose_label: Label

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var stage:=Node3D.new()
	root.add_child(stage)
	var ground:=StaticBody3D.new()
	stage.add_child(ground)
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(20,1,20)
	collider.shape=shape
	collider.position.y= -0.5
	ground.add_child(collider)
	var player: CharacterBody3D=load("res://player.gd").new()
	stage.add_child(player)
	player.set_view(2)
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://player_skins.json"))
	if "--pose-images" in OS.get_cmdline_user_args():
		root.size = Vector2i(240,300)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		RenderingServer.set_default_clear_color(Color("566372"))
		var light := DirectionalLight3D.new()
		stage.add_child(light)
		light.rotation_degrees = Vector3(-35,-28,0)
		var fill := DirectionalLight3D.new()
		stage.add_child(fill)
		fill.rotation_degrees = Vector3(-25,146,0)
		fill.light_energy = .65
		preview_camera = Camera3D.new()
		stage.add_child(preview_camera)
		preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		preview_camera.size = 2.5
		preview_camera.position = Vector3(2.2,1.55,-3.6)
		preview_camera.look_at(Vector3(0,.95,0))
		preview_camera.current = true
		preview_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var captions := CanvasLayer.new()
		stage.add_child(captions)
		pose_label = Label.new()
		captions.add_child(pose_label)
		pose_label.position = Vector2(6,6)
		pose_label.add_theme_font_size_override("font_size",14)
		sheet = Image.create_empty(1440,catalog.size()*300,false,Image.FORMAT_RGBA8)
	var failures:Array[String]=[]
	var seen:Dictionary={}
	for skin in catalog:
		if seen.has(skin.base):failures.append("Duplicate base model "+skin.base)
		seen[skin.base]=true
		if not player.set_skin(skin.id,false):failures.append("Skin cannot load "+skin.id);continue
		if "--basic-idle" in OS.get_cmdline_user_args():
			var idle_library: AnimationLibrary=player.animator.get_animation_library("")
			idle_library.remove_animation("PlayerIdle")
			idle_library.add_animation("PlayerIdle",player.animator.get_animation("BasicIdle"))
		for clip in ["PlayerIdle","Walk","RunnerRun","RunnerJump","SitEnter","SitIdle","SleepExit"]:
			if not player.animator.has_animation(clip):failures.append(skin.id+" missing "+clip)
		var rig: Skeleton3D = player.avatar.find_children("*","Skeleton3D",true,false)[0]
		var attachment: SkeletonModifier3D = rig.get_node("AttachedFeet")
		player.enabled = false
		for clip_name in ["PlayerIdle","Walk","RunnerRun","RunnerJump"]:
			if not player.animator.has_animation(clip_name):continue
			var clip: Animation = player.animator.get_animation(clip_name)
			player.animator.play(clip_name,0)
			var worst_error := 0.0
			var first_shin := Quaternion.IDENTITY
			var shin_swing := 0.0
			for sample in range(31):
				await process_frame
				player.animator.play(clip_name,0)
				player.animator.seek(clip.length * sample / 30.0,true)
				player.animator.pause()
				await attachment.modification_processed
				var rotation := rig.get_bone_global_pose(rig.find_bone("LowerLeg.L")).basis.orthonormalized().get_rotation_quaternion()
				if sample == 0:first_shin = rotation
				shin_swing = maxf(shin_swing,rotation.angle_to(first_shin))
				for side in ["L","R"]:
					var shin := rig.find_bone("LowerLeg."+side)
					var foot := rig.find_bone("Foot."+side)
					if shin < 0 or foot < 0:
						failures.append(skin.id+" missing a lower leg or foot")
						break
					var rest_offset := rig.get_bone_global_rest(shin).affine_inverse() * rig.get_bone_global_rest(foot).origin
					var expected := rig.get_bone_global_pose(shin) * rest_offset
					var actual := rig.get_bone_global_pose(foot).origin
					worst_error = maxf(worst_error,(rig.global_basis * (expected-actual)).length())
			print("PLAYER_ANKLE ",skin.id," ",clip_name," maximum_error_m=",worst_error)
			if worst_error > .001:failures.append("%s %s ankle drift %.3f m" % [skin.id,clip_name,worst_error])
			if clip_name != "PlayerIdle" and shin_swing < .05:failures.append(skin.id+" no visible shin movement in "+clip_name)
		if sheet:
			player.enabled = false
			player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			player.position = Vector3.ZERO
			player.avatar.transform = player.standing_avatar
			player.avatar.find_child("GroundedFeet",true,false).active = false
			for column in range(6):
				await process_frame
				var clip_name: String = ["PlayerIdle","Walk","RunnerRun","RunnerJump","RunnerJump","RunnerJump"][column]
				pose_label.text = skin.id+" · "+["Standing","Walk","Run","Jump start","Jump middle","Jump end"][column]
				player.animator.play(clip_name,0)
				player.animator.seek(player.animator.current_animation_length * [.25,.25,.25,.15,.5,.85][column],true)
				player.animator.pause()
				await attachment.modification_processed
				await RenderingServer.frame_post_draw
				var frame := root.get_texture().get_image()
				frame.convert(Image.FORMAT_RGBA8)
				frame.resize(240,300)
				sheet.blit_rect(frame,Rect2i(0,0,240,300),Vector2i(column*240,(seen.size()-1)*300))
			player.avatar.find_child("GroundedFeet",true,false).active = true
		player.enabled = true
		player.position=Vector3(0,0.1,0)
		player.velocity=Vector3.ZERO
		for frame in range(15):await physics_frame
		player.jump_requested=true
		var base:float=player.position.y
		var highest:=base
		for frame in range(90):
			await physics_frame
			highest=maxf(highest,player.position.y)
		if highest-base<0.5 or not player.is_on_floor():failures.append(skin.id+" jump/landing failed")
		if skin.id in ["runner_child","runner_youth"]:
			if player.body_shape.shape.height>=1.6 or player.camera.position.y>=1.5:
				failures.append(skin.id+" must use a shorter capsule and camera")
		var seat:=Marker3D.new()
		stage.add_child(seat)
		seat.position=Vector3(0,.55,1)
		for posture in ["sitting","sleeping"]:
			if not player.use_furniture(seat,posture) or player.resting!=posture:
				failures.append(skin.id+" failed to use furniture: "+posture)
			player.stand_from_furniture(true)
			if seat.has_meta("occupant") or not is_equal_approx(player.camera.position.y,1.65*player.appearance_height):
				failures.append(skin.id+" failed to restore standing camera and release furniture")
		seat.queue_free()
		print("PLAYER_SKIN_CHECK id=",skin.id," clips=",player.animator.get_animation_list().size()," jump_rise=",highest-base," landed=",player.is_on_floor())
	print("PLAYER_SKINS_REVIEW_COMPLETE failures=",failures," unique_bases=",seen.size())
	if sheet:sheet.save_png(ProjectSettings.globalize_path("res://../review/player-gait-and-jump.png"))
	quit(0 if failures.is_empty() else 1)
