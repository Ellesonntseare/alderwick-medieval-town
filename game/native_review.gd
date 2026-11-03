extends Node

var town: Node3D
var failures: Array[String]=[]

func _ready() -> void:
	town=get_parent()
	run.call_deferred()

func check(value: bool,message: String) -> void:
	if value:return
	failures.append(message)
	push_error(message)

func capture(file: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../"+file)

func walk_to(goal: Vector3,frames := 240) -> bool:
	for index in range(frames):
		await get_tree().physics_frame
		var difference: Vector3=goal-town.player.global_position
		difference.y=0
		if difference.length()<0.18:return true
		var direction := difference.normalized()
		town.player.velocity=Vector3(direction.x*3.5,-2,direction.z*3.5)
		town.player.move_with_steps(1.0/60.0)
	return false

func run() -> void:
	while not town.life.navigation_ready or get_tree().get_nodes_in_group("animals").size()<9:await get_tree().physics_frame
	town.get_viewport().gui_disable_input=true
	town.day_night.set_enabled(false)
	town.set_view(1)
	town.player.enabled=false
	check(town.life.people.size()==45,"Town must contain 45 residents")
	check(town.expansion.rooms.size()==14,"Ten imported buildings and four western homes must exist")
	check(town.expansion.portals.is_empty(),"Native buildings must not use separate-room transitions")
	check(get_tree().get_nodes_in_group("beds").size()>=46,"Residents and player need enough available beds")
	for person in town.life.people:person.set_physics_process(false)
	var camera: Camera3D=town.overview
	camera.position=Vector3(235,230,340)
	camera.look_at(Vector3(-40,1,35))
	await capture("native-town-overview.png")
	camera.position=Vector3(-90,80,210)
	camera.look_at(Vector3(-170,2,100))
	await capture("native-western-village.png")
	for index in [0,1,2,7,9]:
		var room: Node3D=town.expansion.rooms[index]
		var depth: float=room.get_meta("depth")
		camera.position=room.to_global(Vector3(0,1.7,-depth*0.25))
		camera.look_at(room.to_global(Vector3(0,1.3,depth*0.20)))
		await capture("native-interior-%02d.png"%index)
	var room_index := 0
	for entrance in town.expansion.entrances:
		var room: Node3D=entrance.room
		check(room.global_position.y>=-0.06 and room.global_position.y<=0.26,"Usable floor must meet the shared earth: "+entrance.label)
		check(entrance.door.height>=2.3 and entrance.door.width>=1.25,"Door must fit an adult: "+entrance.label)
		if not entrance.door.is_open:entrance.door.toggle(entrance.position)
		for frame in range(30):await get_tree().physics_frame
		town.player.stand_from_furniture(true)
		town.player.getting_up=0
		town.player.global_position=entrance.position
		town.player.velocity=Vector3.ZERO
		for frame in range(8):
			await get_tree().physics_frame
			town.player.velocity=Vector3(0,-2,0)
			town.player.move_and_slide()
		var entered: bool=await walk_to(entrance.inside)
		check(entered,"Actual entrance is obstructed: "+entrance.label)
		check(town.player.global_position.y> -0.2,"Player must remain on the shared map: "+entrance.label)
		if not entered:print("NATIVE_ENTRY_BLOCKED ",entrance.label," at=",town.player.position," target=",entrance.inside)
		var shape := CapsuleShape3D.new()
		shape.radius=0.32
		shape.height=1.8
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape=shape
		query.collision_mask=1
		query.exclude=[town.player.get_rid()]
		query.transform=Transform3D(Basis.IDENTITY,room.global_position+Vector3(0,0.92,0))
		check(town.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Room centre must fit a full-height player: "+entrance.label)
		if room.get_meta("kind")=="smithy":
			check(town.expansion.bed_count(room)==0,"The forge must not contain bedroom furniture")
			check(room.is_in_group("smithy_interiors"),"The forge needs smithing equipment")
		print("NATIVE_ENTRY_CHECK ",entrance.label," entered=",entered," player_y=",town.player.position.y)
		room_index+=1
	var hall: Node3D=town.expansion.rooms[2]
	var supported := 0
	for item: Node3D in hall.get_children():
		if not item.has_meta("future_trade_item"):continue
		var bounds: AABB=town.expansion.bounds_in(item,hall)
		check(absf(bounds.position.y-0.86)<0.02,"Trade decoration must rest on a counter")
		supported+=1
	check(supported==37,"All trade decorations need counter support")
	var forge: Node3D=town.expansion.rooms[7]
	var supported_tools := 0
	for item: Node3D in forge.get_children():
		if not item.has_meta("smithy_tool"):continue
		var bounds: AABB=town.expansion.bounds_in(item,forge)
		check(absf(bounds.position.y-0.91)<0.02,"Forge tools must rest on the workbench")
		supported_tools+=1
	check(supported_tools==17,"All forge tools need workbench support")
	for person in town.life.people:person.set_physics_process(true)
	town.set_view(2)
	town.player.enabled=false
	town.player.position=Vector3(0,0.1,23)
	check(town.player.avatar.position.length()<0.01 and town.player.avatar.visible,"Third-person avatar must stay with its body")
	for frame in range(12):await get_tree().physics_frame
	await capture("native-third-person.png")
	town.player.position=Vector3(0,0.1,60)
	town.day_night.set_enabled(true)
	town.day_night.phase=0.8
	town.day_night.apply_time()
	town.day_night.enabled=false
	var sleeping := 0
	for frame in range(3600):
		await get_tree().physics_frame
		if frame%300!=0:continue
		sleeping=0
		for person in town.life.people:
			if person.posture=="sleeping":sleeping+=1
		print("NATIVE_NIGHT_PROGRESS ",frame/60,"s sleepers=",sleeping)
		if sleeping==45:break
	check(sleeping==45,"Every one of the 45 residents must reach a bed")
	if sleeping!=45:
		for person in town.life.people:
			if person.posture!="sleeping":print("NATIVE_NIGHT_PENDING ",person.person_name," stage=",person.night_stage," at=",person.position," target=",person.home_door.global_position if person.home_door else Vector3.ZERO)
	town.day_night.set_enabled(false)
	town.player.position=Vector3(0,0.1,23)
	town.player.getting_up=0
	town.player.velocity=Vector3.ZERO
	town.set_view(1)
	town.update_camera()
	town.get_viewport().gui_disable_input=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	print("NATIVE_REVIEW_COMPLETE failures=",failures," residents=",town.life.people.size()," beds=",get_tree().get_nodes_in_group("beds").size()," supported_items=",supported," supported_tools=",supported_tools)
	if "--review-native-live" not in OS.get_cmdline_user_args():get_tree().quit(0 if failures.is_empty() else 1)
