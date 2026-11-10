extends CharacterBody3D

const Phone=preload("res://mobile_runtime.gd")

var camera: Camera3D
var enabled := false
var bob := 0.0
var third_camera: Camera3D
var arm: SpringArm3D
var avatar: Node3D
var animator: AnimationPlayer
var view_mode := 0
var jump_active := false
var jump_requested := false
var resting := ""
var rest_anchor: Node3D
var stand_transform := Transform3D.IDENTITY
var stand_visual := Transform3D.IDENTITY
var rest_elapsed := 0.0
var getting_up := 0.0
var rest_tween: Tween
var standing_avatar := Transform3D.IDENTITY
var skin_id := "medieval"
var body_shape: CollisionShape3D
var appearance_height := 1.0
var sprinting := false
var tired_breath := 0.0

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	body_shape=shape
	camera = Camera3D.new()
	camera.position.y = 1.65
	camera.fov = 76
	camera.far = 700
	add_child(camera)
	collision_mask = 7
	arm = SpringArm3D.new()
	arm.position.y = 1.55
	arm.rotation.x = -0.24
	arm.spring_length = 4.0
	var camera_clearance := SphereShape3D.new()
	camera_clearance.radius=0.24
	arm.shape=camera_clearance
	arm.margin=0.18
	arm.collision_mask = 1
	arm.add_excluded_object(get_rid())
	add_child(arm)
	third_camera = Camera3D.new()
	third_camera.fov = 68
	third_camera.far = 700
	third_camera.near=0.05
	arm.add_child(third_camera)
	var saved_skin := "medieval"
	if FileAccess.file_exists("user://player-appearance.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string("user://player-appearance.json"))
		if saved is Dictionary:saved_skin=String(saved.get("skin","medieval"))
	if not set_skin(saved_skin,false):set_skin("medieval",false)

func set_skin(id: String,persist := true) -> bool:
	var path := "res://characters/"+id+".glb"
	if not ResourceLoader.exists(path):return false
	var candidate: Node3D=load(path).instantiate()
	if candidate.find_children("*","Skeleton3D",true,false).is_empty():candidate.free();return false
	if not resting.is_empty():stand_from_furniture(true)
	if rest_tween and rest_tween.is_running():rest_tween.kill()
	if avatar:remove_child(avatar);avatar.queue_free()
	avatar=candidate
	add_child(avatar)
	avatar.rotation.y=PI
	var fitter: CharacterBody3D=load("res://villager.gd").new()
	fitter.style=id
	fitter.person_name=id
	fitter.visual=avatar
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://player_skins.json"))
	for skin in catalog:
		if skin.id==id:fitter.person_name=String(skin.portrait);break
	fitter.apply_appearance()
	fitter.mount_rigid_equipment()
	appearance_height=fitter.appearance_height
	var capsule:=body_shape.shape as CapsuleShape3D
	capsule.radius=0.32*minf(fitter.appearance_build,1.0)
	capsule.height=1.8*appearance_height
	body_shape.position.y=capsule.height*0.5
	camera.position.y=1.65*appearance_height
	arm.position.y=1.55*appearance_height
	fitter.free()
	standing_avatar=avatar.transform
	avatar.visible=view_mode==2
	animator=find_animation(avatar)
	if animator:
		var source_library := animator.get_animation_library("")
		var library := AnimationLibrary.new()
		for clip_name in source_library.get_animation_list():
			var clip := source_library.get_animation(clip_name).duplicate() as Animation
			clip.loop_mode = Animation.LOOP_LINEAR
			library.add_animation(clip_name,clip)
		animator.remove_animation_library("")
		animator.add_animation_library("",library)
		preload("res://motion_library.gd").attach(avatar,animator,true)
		var standing_name := "BasicIdle" if id=="erika_archer" else "Idle"
		var standing: Animation = animator.get_animation(standing_name).duplicate()
		standing.loop_mode = Animation.LOOP_LINEAR
		if animator.has_animation("PlayerIdle"):animator.get_animation_library("").remove_animation("PlayerIdle")
		animator.get_animation_library("").add_animation("PlayerIdle",standing)
		install_tired_idle()
		animator.play("PlayerIdle" if animator.has_animation("PlayerIdle") else "Idle")
	var skeleton: Skeleton3D = avatar.find_children("*","Skeleton3D",true,false)[0]
	var attached := preload("res://feet_attachment.gd").new()
	attached.name = "AttachedFeet"
	attached.model = avatar
	skeleton.add_child(attached)
	var grounding := SkeletonModifier3D.new()
	grounding.set_script(load("res://foot_grounding.gd"))
	grounding.name="GroundedFeet"
	grounding.resident=self
	grounding.model=avatar
	skeleton.add_child(grounding)
	skin_id=id
	if persist:
		var file:=FileAccess.open("user://player-appearance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"skin":id}))
	return true

func find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := find_animation(child)
		if found: return found
	return null

func set_view(mode: int) -> void:
	view_mode = mode
	enabled = mode != 1
	camera.current = mode == 0
	third_camera.current = mode == 2
	avatar.visible = mode == 2
	if resting.is_empty() and getting_up<=0:
		if rest_tween and rest_tween.is_running():rest_tween.kill()
		avatar.transform=standing_avatar

func _unhandled_input(event: InputEvent) -> void:
	if enabled and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_SPACE:jump_requested=true
	if enabled and not Phone.enabled() and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.0025
		if view_mode == 0: camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0025, -1.35, 1.35)
		else: arm.rotation.x = clampf(arm.rotation.x - event.relative.y * 0.0025, -0.9, 0.2)
	if enabled and not Phone.enabled() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	sprinting = false
	if not enabled or get_parent().get_meta("world_loading", false):
		return
	if getting_up>0:
		getting_up-=delta
		velocity=Vector3(0,-2,0)
		move_and_slide()
		return
	if not resting.is_empty():
		rest_elapsed+=delta
		if resting=="sitting" and animator.current_animation!="SitIdle" and not animator.is_playing():animator.play("SitIdle",0.15)
		return
	avatar.transform=standing_avatar
	var physical=get_parent().get("physical_gameplay")
	if physical and physical.climbing:
		physical.move_climber(delta);return
	if physical and (physical.busy>0 or physical.gesture>0):
		velocity=Vector3(0,-2,0);move_and_slide();return
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.z -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.z += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
	if Phone.enabled():direction+=Vector3(Phone.move_axis.x,0,Phone.move_axis.y)
	direction = basis * direction.normalized()
	var speed := 6.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 3.5
	if Phone.enabled() and Phone.running:speed=6.5
	if physical:
		if physical.winded:speed=minf(speed,3.5)
		if physical.carried or physical.pushing:speed=minf(speed,2.2)
		if physical.crouching:speed=1.7
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 22)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 22)
	if not is_on_floor(): velocity.y -= 22 * delta
	elif jump_requested:
		velocity.y = 6
		jump_active=true
		if animator.has_animation("RunnerJump"):animator.play("RunnerJump",0.08,1.5)
	jump_requested=false
	move_with_steps(delta)
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	sprinting = speed > 4.0 and direction.length_squared() > .01 and horizontal_speed > 4.0 and not (physical and physical.mounted)
	var idle := direction.length_squared() < .01
	var tired: bool = idle and horizontal_speed < .25 and is_on_floor() and physical and physical.winded and not (physical.carried or physical.pushing or physical.mounted or physical.crouching)
	if animator:
		if jump_active and is_on_floor():jump_active=false
		if not jump_active:
			var clip := "Walk"
			if idle:
				clip = "TiredIdle" if tired and animator.has_animation("TiredIdle") else "PlayerIdle"
			elif speed > 4:
				clip = "RunnerRun" if animator.has_animation("RunnerRun") else "Run"
			if animator.current_animation != clip:animator.play(clip,.2)
	if is_on_floor() and not idle:bob += delta * speed * 2
	tired_breath = move_toward(tired_breath, 1.0 if tired else 0.0, delta * 4.0)
	var breath := tired_breath * (-.065 + sin(Time.get_ticks_msec() * .004) * .012)
	camera.position.y = (1.65 + breath)*appearance_height + sin(bob)*.025
	if physical and physical.crouching:camera.position.y=appearance_height
	if physical and physical.mounted:
		camera.position.y=2.5
		avatar.position.y+=.9
	if position.y < -150: position = Vector3(0, 2, 23)

func install_tired_idle() -> void:
	if not animator.has_animation("Defeated"):return
	var source := animator.get_animation("Defeated")
	var standing := animator.get_animation("PlayerIdle")
	var breathing := Animation.new()
	breathing.length = .8
	breathing.loop_mode = Animation.LOOP_PINGPONG
	# Use the fitted torso movement on top of a grounded standing pose.
	for track in range(standing.get_track_count()):
		var type := standing.track_get_type(track)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:continue
		if not standing.track_is_enabled(track) or standing.track_get_key_count(track) == 0:continue
		var path := standing.track_get_path(track)
		var target := breathing.add_track(type)
		breathing.track_set_path(target, path)
		var lean_track := -1
		if type == Animation.TYPE_ROTATION_3D and path.get_subname_count() == 1:
			if path.get_subname(0) in [&"Abdomen", &"Torso", &"Chest", &"Neck", &"Head"]:
				lean_track = source.find_track(path, type)
		for frame in range(5):
			var time := frame * .2
			match type:
				Animation.TYPE_POSITION_3D:breathing.position_track_insert_key(target, time, standing.position_track_interpolate(track, time))
				Animation.TYPE_ROTATION_3D:
					var pose := standing.rotation_track_interpolate(track, time)
					if lean_track >= 0:
						pose = pose.slerp(source.rotation_track_interpolate(lean_track, 1.75 + frame * .075), .85)
					breathing.rotation_track_insert_key(target, time, pose)
				Animation.TYPE_SCALE_3D:breathing.scale_track_insert_key(target, time, standing.scale_track_interpolate(track, time))
	animator.get_animation_library("").add_animation("TiredIdle", breathing)

func move_with_steps(delta: float) -> void:
	var horizontal := Vector3(velocity.x,0,velocity.z)*delta
	if horizontal.length()>0.001 and is_on_floor() and test_move(global_transform,horizontal):
		var raised := global_transform
		raised.origin.y+=0.38
		# Step up only where both the body and the forward path fit.
		if not test_move(global_transform,Vector3.UP*0.38) and not test_move(raised,horizontal.normalized()*0.4):
			global_position.y+=0.38
	move_and_slide()

func use_furniture(anchor: Node3D,kind: String) -> bool:
	if anchor.has_meta("occupant"):return false
	if not resting.is_empty():stand_from_furniture(true)
	if rest_tween and rest_tween.is_running():rest_tween.kill()
	getting_up=0
	avatar.transform=standing_avatar
	stand_transform=global_transform
	stand_visual=standing_avatar
	rest_anchor=anchor
	anchor.set_meta("occupant","player")
	resting=kind
	rest_elapsed=0
	velocity=Vector3.ZERO
	global_position=anchor.global_position
	rotation.y=anchor.global_rotation.y
	avatar.rotation.y=0
	if kind=="sitting":
		avatar.global_position=anchor.global_position-Vector3(0,1.03*appearance_height,0)
		animator.play("SitEnter",0.1)
		camera.position.y=0.82*appearance_height
		arm.position.y=0.75*appearance_height
	else:
		animator.play("SleepExit")
		animator.advance(0)
		animator.pause()
		var skeleton := avatar.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
		var hips := skeleton.find_bone("Hips")
		var hips_world: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(hips).origin
		avatar.global_position+=anchor.global_position+anchor.get_parent().global_basis*Vector3(0,0.08,0.85)-hips_world
		camera.position.y=0.45
		camera.rotation.x=0.45
		arm.position.y=0.5
	for child in get_children():
		if child is CollisionShape3D:child.set_deferred("disabled",true)
	return true

func stand_from_furniture(immediate := false) -> void:
	if resting.is_empty():return
	var was_sitting := resting=="sitting"
	var current_visual := avatar.global_transform
	if rest_anchor:rest_anchor.remove_meta("occupant")
	rest_anchor=null
	resting=""
	global_transform=stand_transform
	avatar.global_transform=current_visual
	camera.position.y=1.65*appearance_height
	camera.rotation.x=0
	arm.position.y=1.55*appearance_height
	var skeleton := avatar.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	skeleton.reset_bone_poses()
	animator.play("SitExit" if was_sitting else "SleepExit",0.1)
	if rest_tween and rest_tween.is_running():rest_tween.kill()
	if immediate:
		avatar.transform=stand_visual
		getting_up=0
	else:
		getting_up=minf(1.3,animator.current_animation_length)
		rest_tween=create_tween()
		rest_tween.tween_property(avatar,"transform",stand_visual,getting_up).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for child in get_children():
		if child is CollisionShape3D:child.set_deferred("disabled",false)

