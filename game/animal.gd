extends CharacterBody3D

var species := "Cow"
var desired_height := 1.4
var home := Vector3.ZERO
var radius := 7.0
var pace := 0.7
var visual: Node3D
var animator: AnimationPlayer
var target := Vector3.ZERO
var pause := 0.0
var rng := RandomNumberGenerator.new()
var travelled := 0.0
var state := "Resting"
var voice: AudioStreamPlayer3D
var voice_delay := 0.0
var calls := 0
var asset_path:=""
var idle_clip:="Idle"
var walk_clip:="Walk"
var owner_name:=""
var nav_path:=PackedVector3Array()
var nav_index:=0
var target_clock:=0.0
var can_walk:=true
var pasture:=Rect2()
var ground_clock:=0.0
var weather_shelter:=false

func _ready() -> void:
	add_to_group("animals")
	collision_layer=4
	collision_mask=1
	rng.seed=hash(name)
	visual=Node3D.new()
	add_child(visual)
	visual.add_child(load(asset_path if not asset_path.is_empty() else "res://animals/"+species+".glb").instantiate())
	animator=find_animator(visual)
	if animator:
		for clip in animator.get_animation_list():animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
		if not animator.has_animation(idle_clip):
			for clip in animator.get_animation_list():
				if clip!="RESET":idle_clip=clip;break
		can_walk=animator.has_animation(walk_clip)
		animate("Idle")
		animator.advance(0)
	var bounds := animated_bounds()
	if not animator:can_walk=false
	var size := desired_height/maxf(bounds.size.y,0.1)
	visual.scale=Vector3.ONE*size
	visual.position.y=-bounds.position.y*size
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=clampf(desired_height*0.3,0.10,0.5)
	capsule.height=maxf(desired_height,2*capsule.radius)
	collider.shape=capsule
	collider.position.y=capsule.height/2
	add_child(collider)
	pause=rng.randf_range(1,5)
	target=home
	voice=AudioStreamPlayer3D.new()
	voice.stream=load("res://audio/animals/"+species+".wav")
	voice.position=Vector3(0,desired_height*0.7,0)
	voice.volume_db=-12
	voice.unit_size=7
	voice.max_distance=38
	voice.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.max_polyphony=1
	add_child(voice)
	voice.add_to_group("animal_voices")
	voice_delay=rng.randf_range(4,18)
	print("ANIMAL_SIZE ",species," target=",desired_height," measured=",(visual.global_transform*animated_bounds()).size.y)

func animated_bounds() -> AABB:
	var result := AABB()
	var first := true
	var inverse := visual.global_transform.affine_inverse()
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		var skeleton: Skeleton3D=mesh.get_node_or_null(mesh.skeleton) as Skeleton3D if not mesh.skeleton.is_empty() else null
		var transforms: Array[Transform3D]=[]
		if skeleton and mesh.skin:
			skeleton.force_update_all_bone_transforms()
			for bind in range(mesh.skin.get_bind_count()):
				var bone := mesh.skin.get_bind_bone(bind)
				if bone<0:bone=skeleton.find_bone(mesh.skin.get_bind_name(bind))
				transforms.append(skeleton.global_transform*skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones=arrays[Mesh.ARRAY_BONES]
			var weights=arrays[Mesh.ARRAY_WEIGHTS]
			var influences: int=bones.size()/vertices.size() if bones!=null and not vertices.is_empty() else 0
			for vertex in range(0,vertices.size(),maxi(1,vertices.size()/1000)):
				var point := mesh.global_transform*vertices[vertex]
				if not transforms.is_empty() and influences>0:
					point=Vector3.ZERO
					for slot in range(influences):
						var index := vertex*influences+slot
						if weights[index]>0:point+=(transforms[bones[index]]*vertices[vertex])*weights[index]
				point=inverse*point
				result=AABB(point,Vector3.ZERO) if first else result.expand(point)
				first=false
	return result

func find_animator(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:return node
	for child in node.get_children():
		var found := find_animator(child)
		if found:return found
	return null

func animate(clip: String) -> void:
	clip=idle_clip if clip=="Idle" else walk_clip if clip=="Walk" else clip
	if animator and animator.has_animation(clip) and animator.current_animation!=clip:animator.play(clip,0.2)

func _physics_process(delta: float) -> void:
	var town := get_parent()
	ground_clock+=delta
	var camera_for_ground:=get_viewport().get_camera_3d()
	if ground_clock>.25 and camera_for_ground and camera_for_ground.global_position.distance_to(position)<30:
		ground_clock=0
		var bounds:=animated_bounds()
		visual.position.y=-bounds.position.y*visual.scale.y
	target_clock+=delta
	if not owner_name.is_empty() and target_clock>2 and can_walk:
		target_clock=0
		choose_target()
	voice_delay-=delta
	if voice_delay<=0:
		voice_delay=rng.randf_range(15,35) if species!="Horse" else rng.randf_range(3,6)
		var active_voices := 0
		for speaker in get_tree().get_nodes_in_group("animal_voices"):
			if speaker.playing:active_voices+=1
		var camera := get_viewport().get_camera_3d()
		if camera and camera.global_position.distance_to(global_position)<38 and active_voices<2 and (species!="Horse" or state=="Roaming") and not town.day_night.night:
			voice.pitch_scale=rng.randf_range(0.94,1.06)
			voice.play()
			calls+=1
	if not can_walk:
		state="Resting for the night" if town.day_night.night else "Grazing" if species in ["Cow","Sheep"] else "Resting in the stable"
		velocity=Vector3(0,-2,0);move_and_slide();return
	if (town.day_night and town.day_night.night) or (weather_shelter and town.weather and town.weather.current=="Rain"):
		if position.distance_to(home)<1.3:
			state="Sheltering from rain" if weather_shelter and town.weather and town.weather.current=="Rain" else "Resting for the night";pause=maxf(pause,1)
		elif target.distance_to(home)>.1:route_to(home);pause=0
	if pause>0:
		pause-=delta
		velocity=Vector3(0,-2,0)
		move_and_slide()
		animate("Idle")
		if pause<=0:choose_target()
		return
	while nav_index<nav_path.size() and Vector2(position.x-nav_path[nav_index].x,position.z-nav_path[nav_index].z).length()<.4:nav_index+=1
	var waypoint: Vector3=nav_path[nav_index] if nav_index<nav_path.size() else target
	var offset := waypoint-position
	offset.y=0
	if offset.length()<0.35:
		pause=rng.randf_range(3,8)
		state="Grazing" if species in ["Cow","Sheep"] else "Resting"
		return
	var direction := offset.normalized()
	var obstacle_probe:=global_transform
	obstacle_probe.origin.y+=.16
	if test_move(obstacle_probe,direction*0.9):
		choose_target()
		pause=0.15 if species=="Pug" else rng.randf_range(0.4,1.0)
		state="Waiting for space"
		return
	for other in get_tree().get_nodes_in_group("animals"):
		if other==self:continue
		if position.distance_to(other.position)<desired_height*0.8 and direction.dot(other.position-position)>0:
			pause=rng.randf_range(0.5,2)
			return
	var previous := position
	velocity=Vector3(direction.x*pace,-2,direction.z*pace)
	move_and_slide()
	travelled+=position.distance_to(previous)
	visual.rotation.y=lerp_angle(visual.rotation.y,atan2(direction.x,direction.z),delta*3)
	state="Roaming"
	animate("Walk")

func choose_target() -> void:
	var town:=get_parent()
	if (town.day_night and town.day_night.night) or (weather_shelter and town.weather and town.weather.current=="Rain"):route_to(home);return
	if not owner_name.is_empty():
		for person in town.life.people:
			if person.person_name==owner_name and not person.indoor_house and not person.night_schedule and person.position.distance_to(home)<45:
				var goal: Vector3=person.position+Vector3(1.7,0,1.7)
				if position.distance_to(goal)>2.0:route_to(goal);pause=0;state="Following "+owner_name;return
	var centre:=home
	if species=="Sheep":
		var count:=1
		for other in get_tree().get_nodes_in_group("animals"):
			if other!=self and other.species=="Sheep" and other.home.distance_to(home)<12:centre+=other.position;count+=1
		centre/=count
	for attempt in range(24):
		var angle := rng.randf_range(0,TAU)
		var distance := rng.randf_range(1,radius)
		var candidate := centre+Vector3(cos(angle)*distance,0,sin(angle)*distance)
		if candidate.distance_to(home)>radius+2:continue
		if pasture.has_area() and not pasture.has_point(Vector2(candidate.x,candidate.z)):continue
		var probe := global_transform
		probe.origin.y+=.16
		if test_move(probe,candidate-position):continue
		route_to(candidate)
		return
	target=position
	pause=0.4

func route_to(goal: Vector3) -> void:
	var town:=get_parent()
	var route: PackedVector3Array=town.life.find_route(position,goal)
	if pasture.has_area():
		for point in route:
			if not pasture.has_point(Vector2(point.x,point.z)):route=PackedVector3Array();break
	if route.is_empty():target=position;nav_path=PackedVector3Array();pause=.5;return
	target=route[-1];nav_path=route;nav_index=0
