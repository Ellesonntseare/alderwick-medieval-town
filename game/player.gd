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

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
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
	camera.position.y=1.65*fitter.appearance_height
	fitter.free()
	standing_avatar=avatar.transform
	avatar.visible=view_mode==2
	animator=find_animation(avatar)
	if animator:
		var library:=animator.get_animation_library("").duplicate() as AnimationLibrary
		animator.remove_animation_library("")
		animator.add_animation_library("",library)
		for clip in animator.get_animation_list():animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
		load_runner_motion()
		load_neutral_stance()
		preload("res://motion_library.gd").attach(avatar,animator)
		animator.play("PlayerIdle" if animator.has_animation("PlayerIdle") else "Idle")
	var grounding := SkeletonModifier3D.new()
	grounding.set_script(load("res://foot_grounding.gd"))
	grounding.name="GroundedFeet"
	grounding.resident=self
	grounding.model=avatar
	avatar.find_children("*","Skeleton3D",true,false)[0].add_child(grounding)
	skin_id=id
	if persist:
		var file:=FileAccess.open("user://player-appearance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"skin":id}))
	return true

func load_neutral_stance() -> void:
	var resource := load("res://characters/neutral_motion.glb") as PackedScene
	if not resource:return
	var source := resource.instantiate()
	var source_animator := find_animation(source)
	var skeletons := avatar.find_children("*","Skeleton3D",true,false)
	if source_animator and source_animator.has_animation("Idle_Neutral") and not skeletons.is_empty():
		var clip: Animation=source_animator.get_animation("Idle_Neutral").duplicate()
		var root := animator.get_node(animator.root_node)
		var target_path := String(root.get_path_to(skeletons[0]))
		for track in range(clip.get_track_count()):
			var path := clip.track_get_path(track)
			if path.get_subname_count()>0:clip.track_set_path(track,NodePath(target_path+":"+String(path.get_subname(0))))
		clip.loop_mode=Animation.LOOP_LINEAR
		animator.get_animation_library("").add_animation("PlayerIdle",clip)
		animator.play("PlayerIdle")
	source.free()

func load_runner_motion() -> void:
	var source_scene := load("res://characters/runner_motion.glb") as PackedScene
	if not source_scene:return
	var source := source_scene.instantiate()
	var source_player := find_animation(source)
	var skeletons := avatar.find_children("*","Skeleton3D",true,false)
	if source_player and not skeletons.is_empty():
		var root := animator.get_node(animator.root_node)
		var target_path := String(root.get_path_to(skeletons[0]))
		var library := animator.get_animation_library("")
		for clip_name in ["RunnerRun","RunnerJump"]:
			if not source_player.has_animation(clip_name):continue
			var clip := source_player.get_animation(clip_name).duplicate() as Animation
			clip.loop_mode=Animation.LOOP_LINEAR if clip_name=="RunnerRun" else Animation.LOOP_NONE
			for track in range(clip.get_track_count()):
				var path := clip.track_get_path(track)
				if path.get_subname_count()>0:clip.track_set_path(track,NodePath(target_path+":"+String(path.get_subname(0))))
			library.add_animation(clip_name,clip)
	source.free()

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
	if not enabled:
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
		if physical.stamina<8:speed=minf(speed,3.5)
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
	if animator:
		if jump_active and is_on_floor():jump_active=false
		if not jump_active:
			var clip := ("PlayerIdle" if animator.has_animation("PlayerIdle") else "Idle") if direction.length()<0.1 else ("RunnerRun" if speed>4 and animator.has_animation("RunnerRun") else "Run" if speed>4 else "Walk")
			if animator.current_animation != clip: animator.play(clip,0.2)
	if is_on_floor() and direction.length() > 0.1: bob += delta * speed * 2
	camera.position.y = 1.65 + sin(bob) * 0.025
	if physical and physical.crouching:camera.position.y=1.0
	if physical and physical.mounted:
		camera.position.y=2.5
		avatar.position.y+=.9
	if position.y < -150: position = Vector3(0, 2, 23)

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
		avatar.global_position=anchor.global_position-Vector3(0,1.03,0)
		animator.play("SitEnter",0.1)
		camera.position.y=0.82
		arm.position.y=0.75
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
	camera.position.y=1.65
	camera.rotation.x=0
	arm.position.y=1.55
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

