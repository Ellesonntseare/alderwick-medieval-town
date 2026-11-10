extends SceneTree

class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass
	func _unhandled_input(_event: InputEvent) -> void:pass

var failures: Array[String]=[]
var checks:=0

func _initialize() -> void:run.call_deferred()

func check_pose(person: Node,rig: Skeleton3D,phase: String) -> void:
	checks+=1
	var torso:=rig.get_bone_global_pose(rig.find_bone("Chest")).origin-rig.get_bone_global_pose(rig.find_bone("Hips")).origin
	if phase=="holding" and (person.carry_hand_error>.16 or rad_to_deg(torso.angle_to(Vector3.UP))>25):failures.append(person.style+" holding grip/torso")
	for side in ["L","R"]:
		for pair in [["UpperLeg.","LowerLeg."],["LowerLeg.","Foot."]]:
			var a:=rig.find_bone(pair[0]+side);var b:=rig.find_bone(pair[1]+side)
			var rest:=rig.get_bone_global_rest(a).origin.distance_to(rig.get_bone_global_rest(b).origin)
			var posed:=rig.get_bone_global_pose(a).origin.distance_to(rig.get_bone_global_pose(b).origin)
			if absf(rest-posed)>.015:failures.append(person.style+" "+phase+" leg stretching")

func run() -> void:
	root.size=Vector2i(360,400);root.set_disable_input(true)
	var stage:=Town.new();root.add_child(stage)
	var life: Node=load("res://village_life.gd").new();life.town=stage;life.navigation_ready=true
	var light:=DirectionalLight3D.new();stage.add_child(light);light.rotation_degrees=Vector3(-25,-30,0)
	var fill:=DirectionalLight3D.new();stage.add_child(fill);fill.rotation_degrees=Vector3(-20,150,0);fill.light_energy=.8
	var camera:=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.65;camera.position=Vector3(2,1.5,-4);camera.look_at(Vector3(0,.95,0))
	var layer:=CanvasLayer.new();stage.add_child(layer);var caption:=Label.new();layer.add_child(caption)
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://player_skins.json"))
	var sheet:=Image.create_empty(1080,400*catalog.size(),false,Image.FORMAT_RGBA8)
	for index in range(catalog.size()):
		var person: CharacterBody3D=load("res://villager.gd").new();person.life=life;person.style=catalog[index].id;person.person_name="Action review "+person.style;stage.add_child(person);person.set_physics_process(false);person.visual.rotation.y=PI
		person.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var rig: Skeleton3D=person.visual.find_children("*","Skeleton3D",true,false)[0]
		var feet:=rig.get_node("AttachedFeet") as SkeletonModifier3D
		person.set_physics_process(true);person.set_carry("supplies");person.set_physics_process(false)
		if not person.prop_action.active:failures.append(person.style+" pickup did not start")
		for frame in range(8):person.tick_prop_action(.05);person.animator.advance(.05)
		if not person.carry_kind.is_empty():failures.append(person.style+" pickup attached before contact")
		caption.text=person.style+" · reaching"
		await feet.modification_processed
		check_pose(person,rig,"pickup")
		await RenderingServer.frame_post_draw
		sheet.blit_rect(root.get_texture().get_image(),Rect2i(0,0,360,400),Vector2i(0,index*400))
		for frame in range(22):person.tick_prop_action(.05);person.animator.advance(.05)
		person.animate("Walk")
		for far in [false,true]:
			person.set_meta("performance_far",far)
			for frame in range(8):person.animator.advance(.08);await process_frame
			await feet.modification_processed
			check_pose(person,rig,"holding")
		if person.carry_kind!="supplies" or not is_instance_valid(person.carry_root):failures.append(person.style+" pickup did not attach")
		caption.text=person.style+" · holding"
		await RenderingServer.frame_post_draw
		sheet.blit_rect(root.get_texture().get_image(),Rect2i(0,0,360,400),Vector2i(360,index*400))
		person.set_physics_process(true);person.set_carry("");person.set_physics_process(false)
		for frame in range(10):person.tick_prop_action(.05);person.animator.advance(.05)
		if person.carry_kind!="supplies":failures.append(person.style+" put-down detached before contact")
		caption.text=person.style+" · placing"
		await feet.modification_processed
		check_pose(person,rig,"place")
		await RenderingServer.frame_post_draw
		sheet.blit_rect(root.get_texture().get_image(),Rect2i(0,0,360,400),Vector2i(720,index*400))
		for frame in range(20):person.tick_prop_action(.05);person.animator.advance(.05)
		if not person.carry_kind.is_empty() or is_instance_valid(person.carry_root):failures.append(person.style+" put-down did not detach")
		# A night interruption must not delay the actual home route or attach
		# a load whose contact frame has not happened.
		person.set_physics_process(true);person.set_carry("supplies");person.set_physics_process(false)
		person.night_schedule=true;person.tick_prop_action(.2)
		if person.prop_action.active or not person.carry_kind.is_empty():failures.append(person.style+" night interruption")
		person.queue_free();await process_frame
	if DisplayServer.get_name()!="headless":
		sheet.save_png("res://../review/prop-action-rigs.png")
		sheet.get_region(Rect2i(0,0,1080,mini(sheet.get_height(),1600))).save_png("res://../review/prop-action-rigs-close.png")
	life.free()
	print("PROP_ACTION_RIG_REVIEW_COMPLETE failures=",failures," models=",catalog.size()," pose_checks=",checks)
	quit(0 if failures.is_empty() else 1)
