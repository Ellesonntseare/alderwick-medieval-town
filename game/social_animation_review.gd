extends SceneTree

const Motions=preload("res://motion_library.gd")
const STYLES=["adventurer","armoured_assassin","bruce","cult_archer","emlyn","erika_archer","female_peasant","female_ranger","knight","male_peasant","male_ranger","medieval_woman","medieval","mercenary","night_hunter","robed_scholar","runner_child","runner_youth","saxon","viking","witch","worker"]
const REMAINING_CLIPS=["CarryingTurn","CarryingIdle","ShoveReaction","DrunkWalkBackwards","Singing","Praying"]
var clips: Array = ["JazzDance","HeadShakeNo"]
var failures: Array[String]=[]
var results: Array=[]
var sheets: Dictionary={}
var caption: Label

func _initialize() -> void:run.call_deferred()

func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func run() -> void:
	if "--remaining-actions" in OS.get_cmdline_user_args():clips=REMAINING_CLIPS
	if "--pose-images" in OS.get_cmdline_user_args():setup_capture()
	var tile:=0
	for style in STYLES:
		var model: Node3D=load("res://characters/"+style+".glb").instantiate();root.add_child(model)
		var animator: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
		var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
		Motions.attach(model,animator)
		var attachment:=preload("res://feet_attachment.gd").new();attachment.model=model;rig.add_child(attachment)
		for clip in clips:review_clip(style,rig,animator,attachment,clip,"resident")
		if not sheets.is_empty():await capture_poses(style,tile,animator,attachment)
		tile+=1;model.free()
	var player: CharacterBody3D=load("res://player.gd").new();root.add_child(player)
	player.set_physics_process(false);player.enabled=false;player.set_view(2)
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://player_skins.json"))
	for skin in catalog:
		check(player.set_skin(skin.id,false),String(skin.id)+" skin loads")
		var rig: Skeleton3D=player.avatar.find_children("*","Skeleton3D",true,false)[0]
		var attachment: SkeletonModifier3D=rig.get_node("AttachedFeet")
		for clip in clips:review_clip(skin.id,rig,player.animator,attachment,clip,"player")
	player.free()
	for name in sheets:sheets[name].save_png("res://../review/social-"+name+".png")
	var report_path := "res://../review/remaining-animation-rig-results.json" if clips==REMAINING_CLIPS else "res://../review/social-animation-rig-results.json"
	var output:=FileAccess.open(report_path,FileAccess.WRITE)
	output.store_string(JSON.stringify({"results":results,"failures":failures},"\t"))
	print("SOCIAL_ANIMATION_REVIEW_COMPLETE models=",STYLES.size()," player_skins=",catalog.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func review_clip(style: String,rig: Skeleton3D,animator: AnimationPlayer,attachment: SkeletonModifier3D,clip: String,kind: String) -> void:
	check(animator.has_animation(clip),kind+style+" missing "+clip)
	if not animator.has_animation(clip):return
	var animation:=animator.get_animation(clip)
	check(animation.loop_mode==(Animation.LOOP_LINEAR if clip=="JazzDance" else Animation.LOOP_NONE),style+clip+" loop policy")
	var foot_error:=0.0;var thigh_error:=0.0;var shin_error:=0.0;var arm_error:=0.0;var forearm_error:=0.0;var motion:=0.0;var floor_error:=0.0
	var first_head:=Quaternion.IDENTITY;var first_hand:=Vector3.ZERO;var first_shin:=Quaternion.IDENTITY
	var head:=rig.find_bone("Head");var hand:=rig.find_bone("Wrist.R")
	animator.stop();rig.reset_bone_poses();animator.play(clip,0)
	for sample in range(61):
		animator.seek(animation.length*sample/60.0,true);animator.advance(0)
		attachment._process_modification_with_delta(0)
		var head_pose:=rig.get_bone_global_pose(head)
		var hand_pose:=rig.get_bone_global_pose(hand)
		var shin_rotation:=rig.get_bone_global_pose(rig.find_bone("LowerLeg.L")).basis.orthonormalized().get_rotation_quaternion()
		if sample==0:
			first_head=head_pose.basis.orthonormalized().get_rotation_quaternion()
			first_hand=hand_pose.origin
			first_shin=shin_rotation
		motion=maxf(motion,first_head.angle_to(head_pose.basis.orthonormalized().get_rotation_quaternion()) if clip=="HeadShakeNo" else first_hand.distance_to(hand_pose.origin))
		if clip in REMAINING_CLIPS:
			motion=maxf(motion,first_shin.angle_to(shin_rotation))
			motion=maxf(motion,first_head.angle_to(head_pose.basis.orthonormalized().get_rotation_quaternion()))
		check(head_pose.is_finite() and hand_pose.is_finite(),style+clip+" finite pose")
		var minimum:=INF;var rest_minimum:=INF
		for side in ["L","R"]:
			var thigh:=rig.find_bone("UpperLeg."+side);var shin:=rig.find_bone("LowerLeg."+side);var foot:=rig.find_bone("Foot."+side)
			var rt:=rig.get_bone_global_rest(thigh);var rs:=rig.get_bone_global_rest(shin);var rf:=rig.get_bone_global_rest(foot)
			var pt:=rig.get_bone_global_pose(thigh);var ps:=rig.get_bone_global_pose(shin);var pf:=rig.get_bone_global_pose(foot)
			foot_error=maxf(foot_error,(ps*(rs.affine_inverse()*rf.origin)).distance_to(pf.origin))
			thigh_error=maxf(thigh_error,absf(pt.origin.distance_to(ps.origin)/rt.origin.distance_to(rs.origin)-1))
			shin_error=maxf(shin_error,absf(ps.origin.distance_to(pf.origin)/rs.origin.distance_to(rf.origin)-1))
			minimum=minf(minimum,pf.origin.y);rest_minimum=minf(rest_minimum,rf.origin.y)
			var upper_arm:=rig.find_bone("UpperArm."+side);var lower_arm:=rig.find_bone("LowerArm."+side);var wrist:=rig.find_bone("Wrist."+side)
			var rest_arm:=rig.get_bone_global_rest(upper_arm);var rest_elbow:=rig.get_bone_global_rest(lower_arm);var rest_wrist:=rig.get_bone_global_rest(wrist)
			var posed_arm:=rig.get_bone_global_pose(upper_arm);var posed_elbow:=rig.get_bone_global_pose(lower_arm);var posed_wrist:=rig.get_bone_global_pose(wrist)
			arm_error=maxf(arm_error,absf(posed_arm.origin.distance_to(posed_elbow.origin)/rest_arm.origin.distance_to(rest_elbow.origin)-1))
			forearm_error=maxf(forearm_error,absf(posed_elbow.origin.distance_to(posed_wrist.origin)/rest_elbow.origin.distance_to(rest_wrist.origin)-1))
		if clip=="Praying":
			var poses: Dictionary={}
			for bone in range(rig.get_bone_count()):poses[bone]=rig.get_bone_global_pose(bone)
			floor_error=maxf(floor_error,absf(Motions.prayer_support_height(rig,poses)))
		else:
			floor_error=maxf(floor_error,absf(minimum-rest_minimum))
	check(foot_error<.001,kind+style+clip+" foot attachment")
	check(thigh_error<.005 and shin_error<.005,kind+style+clip+" leg lengths")
	check(arm_error<.005 and forearm_error<.005,kind+style+clip+" arm lengths")
	check(motion>.03,kind+style+clip+" contains the expected motion")
	check(floor_error<.035,kind+style+clip+" remains grounded")
	var result: Dictionary={"kind":kind,"style":style,"clip":clip,"length":animation.length,"ankle_gap_m":foot_error,"thigh_relative_error":thigh_error,"shin_relative_error":shin_error,"upper_arm_relative_error":arm_error,"forearm_relative_error":forearm_error,"motion":motion,"ground_error_m":floor_error}
	results.append(result);print("SOCIAL_ANIMATION_RIG ",JSON.stringify(result))

func setup_capture() -> void:
	root.size=Vector2i(240,320);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("33434e"))
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7;root.add_child(environment)
	for direction in [Vector3(-35,-28,0),Vector3(-25,146,0)]:
		var light:=DirectionalLight3D.new();light.rotation_degrees=direction;light.light_energy=.8;root.add_child(light)
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.4;camera.position=Vector3(2,1.4,4);camera.look_at(Vector3(0,.95,0))
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	caption=Label.new();canvas.add_child(caption);caption.position=Vector2(5,295);caption.add_theme_font_size_override("font_size",15)
	for name in clips:sheets[name]=Image.create_empty(1200,1600,false,Image.FORMAT_RGBA8)

func capture_poses(style: String,tile: int,animator: AnimationPlayer,attachment: SkeletonModifier3D) -> void:
	caption.text=style
	for clip in sheets:
		animator.stop();attachment.get_skeleton().reset_bone_poses();animator.play(clip,0)
		animator.seek(animator.get_animation(clip).length*.4,true);animator.advance(0);animator.pause()
		await process_frame;await RenderingServer.frame_post_draw
		var frame:=root.get_texture().get_image();frame.convert(Image.FORMAT_RGBA8)
		sheets[clip].blit_rect(frame,Rect2i(0,0,240,320),Vector2i(tile%5*240,tile/5*320))
