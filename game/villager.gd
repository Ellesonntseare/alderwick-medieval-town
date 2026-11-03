extends CharacterBody3D

var person_name := "Villager"
var occupation := "Resident"
var home := "Alderwick"
var style := "medieval"
var life: Node
var route: Array[Vector3] = []
var destination := 0
var path := PackedVector3Array()
var path_index := 0
var wait_time := 0.0
var talking := false
var visits := 0
var travelled := 0.0
var activity := "Enjoying the town"
var visual: Node3D
var animator: AnimationPlayer
var label: Label3D
var speed := 1.25
var work_timer := 0.0
var social_partner: CharacterBody3D
var meeting_partner: CharacterBody3D
var meeting_path := PackedVector3Array()
var meeting_path_index := 0
var meeting_timeout := 0.0
var meeting_stuck := 0.0
var social_time := 0.0
var social_elapsed := 0.0
var social_cooldown := 0.0
var sociability := 0.5
var conversations := 0
var work_stops := 0
var breaks := 0
var bubble: Label3D
var social_lines: Array[String] = []
var social_turn := -1
var decision_rng := RandomNumberGenerator.new()
var last_move_position := Vector3.ZERO
var stuck_time := 0.0
var blocked_steps := 0
var replans := 0
var progress_clock := 0.0
var progress_origin := Vector3.ZERO
var indoor_house: Node3D
var indoor_points: Array[Vector3]=[]
var indoor_role := ""
var stall_name := ""
var stall_anchor := Vector3.ZERO
var stall_facing := 0.0
var appearance_height := 1.0
var appearance_build := 1.0
var night_schedule := false
var home_door: Node3D
var home_transform := Transform3D.IDENTITY
var night_stage := ""
var night_path := PackedVector3Array()
var night_index := 0
var night_delay := 0.0
var resting_indoors := false
var last_topic := "town"
var dialogue_turns := 0
var posture := "standing"
var standing_visual := Transform3D.IDENTITY
var resting_place: Node3D
var posture_time := 0.0
var getting_up := 0.0
var posture_tween: Tween
var equipment_nodes: Array[Node3D]=[]
var job: Dictionary={}
var guard_post := Vector3.INF
var guard_facing := 0.0
var guard_label := ""
var carry_kind := ""
var carry_root: Node3D
var recent_events: Array[Dictionary]=[]
var heard_events: Array[Dictionary]=[]
var assigned_bed: Node3D
var queue_target := Vector3.INF
var chat_id := 0
var social_speaking := false
var carry_pose_updates := 0
var carry_hand_error := 0.0
var coins := 20
var food := 0
var hunger := 0.0
var friendships: Dictionary={}
var routine: Dictionary={}
var guard_shift := "day"
var day_visit := false
var visit_seat: Node3D
var sleep_after_exit := false
var is_child := false
var walking_policy := "open"
var route_unavailable := false

func _ready() -> void:
	add_to_group("villagers")
	collision_layer = 2
	collision_mask = 3
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	collider.shape = capsule
	collider.position.y = 0.85
	add_child(collider)
	visual = load("res://characters/"+style+".glb").instantiate()
	add_child(visual)
	apply_appearance()
	mount_rigid_equipment()
	capsule.radius=0.3*appearance_build
	capsule.height=1.7*appearance_height
	collider.position.y=capsule.height/2
	animator = find_animator(visual)
	if animator:
		preload("res://motion_library.gd").attach(visual,animator)
		for clip in animator.get_animation_list():
			if clip not in ["SitEnter","SitExit","SleepExit"]:animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		animate("Idle")
	var skeleton := visual.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var grounding := SkeletonModifier3D.new()
	grounding.name="GroundedFeet"
	grounding.set_script(load("res://foot_grounding.gd"))
	grounding.resident=self
	grounding.model=visual
	skeleton.add_child(grounding)
	label = Label3D.new()
	label.text = person_name+" · "+occupation
	label.position.y = 2.05*appearance_height
	label.font_size = 18
	label.pixel_size = 0.0045
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 4
	add_child(label)
	decision_rng.seed=hash(person_name)
	sociability=decision_rng.randf_range(0.3,0.9)
	social_cooldown=decision_rng.randf_range(0,5)
	bubble=Label3D.new()
	bubble.position.y=2.5*appearance_height
	bubble.font_size=19
	bubble.pixel_size=0.0048
	bubble.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	bubble.modulate=Color("ffe7b4")
	bubble.outline_size=4
	bubble.width=270
	add_child(bubble)
	bubble.hide()

func apply_appearance() -> void:
	var looks := RandomNumberGenerator.new()
	looks.seed=hash(person_name+"-appearance")
	appearance_height=looks.randf_range(0.96,1.04)
	appearance_build=looks.randf_range(0.96,1.08)
	if style=="runner_child":appearance_height=1.34/1.8;appearance_build=appearance_height
	elif style=="runner_youth":appearance_height=1.54/1.8;appearance_build=appearance_height
	if person_name in ["Hugh","Tomas","Nell","Alden"]:appearance_build=looks.randf_range(1.16,1.24)
	visual.scale=Vector3(appearance_build,appearance_height,appearance_build)
	var palette := [Color("697252"),Color("775847"),Color("566977"),Color("826648"),Color("6c556d"),Color("708278")]
	var tint: Color=palette[looks.randi_range(0,palette.size()-1)]
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if not original:continue
			var mat_name := original.resource_name
			if mat_name not in ["LightBrown","LightGreen","Green","Purple","Worker_Vest","Brown_02"]:continue
			var copy := original.duplicate() as StandardMaterial3D
			copy.albedo_color=original.albedo_color.lerp(tint,0.48)
			mesh.set_surface_override_material(surface,copy)

func find_animator(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := find_animator(child)
		if found: return found
	return null

func animate(clip: String) -> void:
	if animator and clip not in ["Walk","Run"]:animator.speed_scale=1.0
	if animator and animator.current_animation != clip and animator.has_animation(clip): animator.play(clip,0.18)

func plan() -> void:
	if life and life.town.jobs and not job.is_empty():
		life.town.jobs.plan(self)
		return
	if route.is_empty(): return
	if indoor_house:
		path=PackedVector3Array([indoor_points[destination]])
	else:
		path=life.find_route(position,route[destination],self)
		if path.is_empty():
			for step in range(1,route.size()):
				var other := (destination+step)%route.size()
				var alternative: PackedVector3Array=life.find_route(position,route[other],self)
				if not alternative.is_empty():destination=other;path=alternative;break
	route_unavailable=path.is_empty()
	path_index = 0
	activity = "Moving around "+indoor_role if indoor_house else "Walking to "+("work" if destination==0 else "the square" if destination==1 else "home")
	if is_child:activity="Looking for a place to play" if destination==0 else "Visiting the town square" if destination==1 else "Walking around the neighbourhood"
	if person_name=="Roslin":activity="Walking to "+["the herb garden","the town market","the western gardens","the castle market"][destination]
	if person_name=="Fenn":activity="Walking to "+["the archery range","the woodland paths","the western village","the eastern crossing"][destination]
	if route_unavailable:activity="Looking for a clear route";wait_time=1.5
	stuck_time=0
	last_move_position=position
	progress_clock=0
	progress_origin=position

func choose_next() -> void:
	# Work is most likely, with independent choices for errands and home breaks.
	var pick := decision_rng.randf()
	var next := 0 if pick<0.5 else 1 if pick<0.83 else 2
	if route.size()>3:next=decision_rng.randi_range(0,route.size()-1)
	if next==destination:next=(destination+decision_rng.randi_range(1,2))%route.size()
	destination=next
	plan()

func begin_social(other: CharacterBody3D,duration: float,lines: Array[String]) -> void:
	social_partner=other
	social_time=duration
	social_elapsed=0
	social_turn=-1
	social_lines=lines
	conversations+=1
	activity="Chatting with "+other.person_name
	velocity=Vector3.ZERO
	wait_time=maxf(wait_time,decision_rng.randf_range(1,3))

func end_social() -> void:
	if life:life.stop_chat(self)
	var other := social_partner
	social_partner=null
	social_time=0
	bubble.hide()
	social_cooldown=decision_rng.randf_range(12,25)
	if other and other.social_partner==self:other.end_social()
	plan()
	activity="Finishing a short break"
	wait_time=decision_rng.randf_range(0.8,2.5)

func reserve_meeting(other: CharacterBody3D,approach: PackedVector3Array) -> void:
	meeting_partner=other
	meeting_path=approach
	meeting_path_index=0
	meeting_timeout=18
	meeting_stuck=0
	velocity=Vector3.ZERO
	activity=("Waiting for " if approach.is_empty() else "Walking over to ")+other.person_name

func process_meeting(delta: float) -> void:
	meeting_timeout-=delta
	if not is_instance_valid(meeting_partner) or meeting_partner.meeting_partner!=self or meeting_partner.talking or meeting_partner.night_schedule or meeting_timeout<=0:
		life.cancel_meeting(self)
		return
	if meeting_path_index>=meeting_path.size():
		rest(delta)
		animate("Idle")
		if meeting_partner.meeting_path_index>=meeting_partner.meeting_path.size():life.finish_meeting(self,meeting_partner)
		return
	var offset: Vector3=meeting_path[meeting_path_index]-position
	offset.y=0
	if offset.length()<0.16:
		meeting_path_index+=1
		rest(delta)
		return
	var direction := offset.normalized()
	var before := position
	move_direction(direction,speed,delta)
	travelled+=position.distance_to(before)
	meeting_stuck=meeting_stuck+delta if position.distance_to(before)<speed*delta*0.2 else 0.0
	if meeting_stuck>1.2:
		life.cancel_meeting(self)
		return
	# Approaching residents face the path. Facing a partner begins only once
	# both have arrived and the actual conversation has started.
	visual.rotation.y=lerp_angle(visual.rotation.y,atan2(direction.x,direction.z),delta*8)
	animate("Walk")

func has_conversation_partner() -> bool:
	if not is_instance_valid(social_partner):return false
	if social_partner.social_partner!=self or social_partner.talking or social_partner.social_time<=0:return false
	if position.distance_to(social_partner.position)>2.4:return false
	var ray := PhysicsRayQueryParameters3D.create(position+Vector3.UP,social_partner.position+Vector3.UP,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func rest(delta: float) -> void:
	if not guard_label.is_empty() and not night_schedule and Vector2(position.x-guard_post.x,position.z-guard_post.z).length()<0.07:
		position=guard_post
		velocity=Vector3.ZERO
		return
	velocity=Vector3(0,-2,0)
	move_with_steps(delta)

func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	label.visible = not talking and posture!="sleeping" and camera != null and camera.global_position.distance_to(global_position)<15
	label.text=person_name+" · "+occupation+"\n"+activity
	if has_meta("mood_label") and String(get_meta("mood_label"))!="Content":label.text+=" · "+String(get_meta("mood_label"))
	social_cooldown=maxf(0,social_cooldown-delta)
	if social_partner and not has_conversation_partner():end_social()
	if not social_partner:bubble.hide()
	if social_partner and not talking:
		if social_partner.talking:
			end_social()
		else:
			social_time-=delta
			social_elapsed+=delta
			rest(delta)
			var facing: Vector3=social_partner.position-position
			visual.rotation.y=lerp_angle(visual.rotation.y,atan2(facing.x,facing.z),delta*6)
			life.tick_chat(self,delta)
			animate("Interact" if social_speaking else "Idle")
			bubble.visible=social_speaking and label.visible and has_conversation_partner()
			if social_time<=0:end_social()
			return
	if meeting_partner and not talking:
		process_meeting(delta)
		return
	if talking:
		rest(delta)
		animate("Wave" if work_timer<1.5 else "Idle")
		work_timer += delta
		return
	if posture=="sleeping":return
	if posture=="sitting":
		posture_time+=delta
		if animator.current_animation!="SitIdle" and not animator.is_playing():animator.play("SitIdle",0.15)
		wait_time-=delta
		if wait_time<=0:
			stand_up()
			if day_visit:finish_day_visit()
			elif not routine.is_empty():life.town.routines.finish(self)
			else:choose_next()
		return
	if getting_up>0:
		getting_up-=delta
		rest(delta)
		return
	if life.town.get("industrial_workforce") and life.town.industrial_workforce.tick(self,delta):return
	if night_schedule:
		process_night(delta)
		return
	if life.town.routines and life.town.routines.tick(self,delta):return
	if not job.is_empty():
		life.town.jobs.tick(self,delta)
		return
	if not stall_name.is_empty():
		rest(delta)
		visual.rotation.y=lerp_angle(visual.rotation.y,stall_facing,delta*5)
		work_timer+=delta
		var arranging := fmod(work_timer,8)<3.5
		animate("WorkTable" if arranging else "Idle")
		activity=("Arranging " if arranging else "Selling ")+stall_name
		return
	if wait_time>0:
		wait_time -= delta
		velocity = Vector3(0,-2,0)
		move_with_steps(delta)
		animate(work_animation() if destination==0 and not route_unavailable else "Idle")
		if wait_time<=0:
			choose_next()
		return
	if path_index>=path.size():
		wait_time = decision_rng.randf_range(8,16) if destination==0 else decision_rng.randf_range(4,8)
		if destination==0:work_stops+=1
		else:breaks+=1
		activity = work_description() if destination==0 else "Taking a break indoors" if indoor_house else "Browsing the market" if destination==1 else "Resting near home"
		if indoor_house and destination!=0:
			for child in indoor_house.get_children():
				if child.is_in_group("seats") and not child.has_meta("occupant"):
					sit_at(child)
					break
		return
	follow_path(delta,speed)

func work_description() -> String:
	match occupation:
		"Village child":return "Playing and visiting family"
		"Young apprentice":return "Learning about the town's crafts"
		"Archivist":return "Sorting the town records"
		"Range keeper":return "Checking the archery range"
		"Supply courier":return "Organising the next supply delivery"
		"Baker":return "Preparing bread"
		"Blacksmith":return "Repairing tools"
		"Herbalist":return "Sorting herbs"
		"Farmer":return "Checking farm supplies"
		"Guard":return "Keeping watch"
		"Merchant":return "Arranging market goods"
		"Carpenter":return "Checking timber"
		"Weaver":return "Working on cloth"
		_:return "Tending to work"

func work_animation() -> String:
	if occupation=="Farmer":return "WorkHarvest"
	if occupation in ["Baker","Blacksmith","Brewer","Carpenter","Weaver","Herbalist","Merchant","Town clerk","Archivist","Castle caretaker"]:return "WorkTable"
	return "Interact"

func move_direction(direction: Vector3,pace: float,delta: float) -> void:
	if life and life.get("town") and life.town.get("character_life")!=null and life.town.character_life.bound:pace*=life.town.character_life.walking_pace(self)
	var desired: Vector3=life.traffic.steer(self,direction,pace,delta) if life and life.traffic else direction*pace
	velocity=Vector3(desired.x,-2,desired.z)
	move_with_steps(delta)
	if desired.length()>0.05:
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(desired.x,desired.z),delta*8)
		animate("Run" if pace>2.2 else "Walk")
		animator.speed_scale=clampf(desired.length()/(4.5 if pace>2.2 else 1.45),0.55,1.7)
	else:animate("Idle")

func follow_path(delta: float,pace: float) -> bool:
	while path_index<path.size():
		var difference: Vector3=path[path_index]-position
		difference.y=0
		if difference.length()<0.18:path_index+=1;continue
		if difference.length()<0.85 and path_index+1<path.size() and can_skip_to(path[path_index+1]):path_index+=1;continue
		var before := position
		move_direction(difference.normalized(),minf(pace,difference.length()/delta),delta)
		travelled+=position.distance_to(before)
		stuck_time=stuck_time+delta if position.distance_to(before)<0.005 else 0.0
		if stuck_time>1.4:
			blocked_steps+=1
			if life.walking_routes:life.walking_routes.avoid(self,path[path_index])
			path=life.route_to_point(self,path[-1],true)
			path_index=0
			stuck_time=0
			replans+=1
			if blocked_steps>=3 and job.is_empty() and not indoor_house and not night_schedule:
				blocked_steps=0
				choose_next()
		elif position.distance_to(before)>0.01:blocked_steps=0
		return false
	rest(delta)
	return true

func can_skip_to(target: Vector3) -> bool:
	var probe := global_transform
	probe.origin.y+=0.30
	var mask := collision_mask
	collision_mask=1
	var blocked := test_move(probe,target+Vector3.UP*0.30-probe.origin)
	collision_mask=mask
	return not blocked

func set_carry(kind: String) -> void:
	carry_kind=kind
	if carry_root:carry_root.queue_free();carry_root=null
	if kind.is_empty():return
	carry_root=Node3D.new()
	visual.add_child(carry_root)
	carry_root.name="CarriedGoods"
	carry_root.position=Vector3(0,0.96,0.40)
	life.town.detailed_prop("FarmCrate_Carrot" if kind=="carrots" else "Crate_Wooden",carry_root,Vector3.ZERO,Vector3(0.55,0.3,0.36),false)
	var skeleton := visual.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	if not skeleton.has_node("CarryHands"):
		var modifier := SkeletonModifier3D.new()
		modifier.set_script(load("res://carry_pose.gd"))
		modifier.name="CarryHands"
		modifier.resident=self
		skeleton.add_child(modifier)

func head_home(door: Node3D,planned := PackedVector3Array()) -> void:
	if planned.is_empty():planned=life.route_to_door(self,door)
	if planned.is_empty():return
	life.traffic.release_door(self)
	life.town.jobs.suspend(self)
	if meeting_partner:life.cancel_meeting(self)
	stand_up()
	if social_partner:end_social()
	night_schedule=true
	sleep_after_exit=false
	home_door=door
	home_transform=door.get_closed_transform()
	resting_indoors=false
	night_stage="approach"
	night_index=0
	night_path=planned
	queue_target=Vector3.INF
	activity="Heading home for the night"

func leave_home() -> void:
	life.traffic.release_door(self)
	stand_up()
	if not night_schedule:return
	if not resting_indoors:
		night_schedule=false
		plan()
		return
	night_stage="waiting_exit"
	resting_indoors=false
	night_delay=0.2
	night_index=0
	night_path=PackedVector3Array()
	queue_target=Vector3.INF
	activity="Starting the day"

func go_to_bed(bed: Node3D) -> void:
	stand_up()
	if meeting_partner:life.cancel_meeting(self)
	if social_partner:end_social()
	life.town.jobs.suspend(self)
	assigned_bed=bed
	night_schedule=true
	resting_indoors=false
	night_delay=0
	sleep_after_exit=false
	night_stage="to_bed"
	night_index=0
	night_path=life.indoor_route(self,bed.get_parent(),position,life.bedside_position(self,bed))
	activity="Going to bed"

func process_night(delta: float) -> void:
	if resting_indoors:
		rest(delta)
		animate("Idle")
		return
	if night_delay>0:
		night_delay-=delta
		rest(delta)
		animate("Idle")
		return
	if night_stage=="waiting_exit":
		var inside: Vector3=home_transform*Vector3(home_door.width/2,0.04,1.6)
		night_path=life.indoor_route(self,home_door.get_parent(),position,inside)
		night_index=0
		night_stage="exit_walk"
		activity="Walking to the door"
	if night_stage=="exit_walk" and position.distance_to(home_door.global_position)<3.2:
		var rank: int=life.traffic.request_door(self,home_door)
		if rank>=0:
			var target: Vector3=life.traffic.queue_position(self,home_door,rank,true)
			if not queue_target.is_finite() or target.distance_to(queue_target)>0.2:
				path=PackedVector3Array([target])
				path_index=0
				queue_target=target
			follow_path(delta,2.0)
			activity="Queuing to leave "+home_door.door_name
			return
		queue_target=Vector3.INF
		night_stage="exit_approach"
		night_path=PackedVector3Array([home_transform*Vector3(home_door.width/2,0.04,1.0)])
		night_index=0
	if night_stage in ["approach","door_approach"] and position.distance_to(home_door.global_position)<3.0:
		var rank: int=life.traffic.request_door(self,home_door)
		if rank>=0:
			var target: Vector3=life.traffic.queue_position(self,home_door,rank)
			if not queue_target.is_finite() or target.distance_to(queue_target)>0.2:
				path=PackedVector3Array([target])
				path_index=0
				queue_target=target
			follow_path(delta,2.0)
			activity="Queuing to enter "+home_door.door_name
			night_stage="approach"
			return
		if night_stage=="approach" or queue_target.is_finite():
			queue_target=Vector3.INF
			night_stage="door_approach"
			night_path=PackedVector3Array([home_transform*Vector3(home_door.width/2,0.04,-1.3)])
			night_index=0
	if night_stage=="finding_home":
		life.assign_home(self)
		return
	if night_index>=night_path.size():
		if night_stage in ["approach","door_approach"]:
			if not home_door.is_open:home_door.toggle(position)
			night_delay=0.6
			night_path=PackedVector3Array([home_transform*Vector3(home_door.width/2,0.04,1.4)])
			night_index=0
			night_stage="entering"
		elif night_stage=="entering":
			life.traffic.release_door(self)
			if day_visit:life.town.routines.arrive_tavern(self)
			elif assigned_bed:go_to_bed(assigned_bed)
		elif night_stage=="visit_walk":
			life.town.routines.seat_tavern(self)
		elif night_stage=="to_bed":
			if assigned_bed and position.distance_to(life.bedside_position(self,assigned_bed))<1.4:
				resting_indoors=true
				sleep_at(assigned_bed)
			else:
				night_path=life.indoor_route(self,assigned_bed.get_parent(),position,life.bedside_position(self,assigned_bed))
				night_index=0
		elif night_stage=="exit_approach":
			if not home_door.is_open:home_door.toggle(position)
			night_delay=0.6
			night_path=PackedVector3Array([home_transform*Vector3(home_door.width/2,0.04,-1.8)])
			night_index=0
			night_stage="leaving"
		elif night_stage=="leaving":
			life.traffic.release_door(self)
			if sleep_after_exit:
				sleep_after_exit=false
				night_schedule=false
				life.assign_home(self)
			elif not stall_name.is_empty():
				night_path=life.find_route(position,stall_anchor)
				night_path.append(stall_anchor)
				night_index=0
				night_stage="returning_stall"
			else:
				night_schedule=false
				wait_time=0
				plan()
		else:
			night_schedule=false
			activity="Selling "+stall_name
		return
	var target: Vector3=night_path[night_index]
	var offset := target-position
	offset.y=0
	if offset.length()<0.2:
		night_index+=1
		return
	if offset.length()<0.85 and night_index+1<night_path.size() and can_skip_to(night_path[night_index+1]):
		night_index+=1
		return
	var direction := offset.normalized()
	var night_speed := 6.5 if life.town.day_night.cycle_seconds<=60 else speed*1.35
	if day_visit:night_speed=1.65
	if night_stage in ["to_bed","exit_walk","exit_approach","visit_walk"]:night_speed=3.5 if life.town.day_night.cycle_seconds<=60 else 2.0
	if day_visit and night_stage=="visit_walk":night_speed=1.6
	var before := position
	move_direction(direction,minf(night_speed,offset.length()/delta),delta)
	travelled+=position.distance_to(before)
	if position.distance_to(before)<0.004:stuck_time+=delta
	else:stuck_time=0
	if stuck_time>1.5:
		if night_stage in ["to_bed","exit_walk","exit_approach","visit_walk"]:
			var room: Node3D=assigned_bed.get_parent() if assigned_bed else home_door.get_parent()
			night_path=life.indoor_route(self,room,position,night_path[-1])
			night_index=0
		elif night_stage in ["approach","door_approach"]:
			night_path=life.route_to_door(self,home_door)
			night_index=0
			night_stage="approach"
		elif night_stage=="returning_stall":
			night_path=life.route_to_point(self,stall_anchor,true)
			night_index=0
		stuck_time=0

func finish_day_visit() -> void:
	stand_up()
	if visit_seat and visit_seat.get_meta("occupant","")==person_name:visit_seat.remove_meta("occupant")
	visit_seat=null
	day_visit=false
	resting_indoors=false
	night_schedule=true
	night_stage="waiting_exit"
	night_delay=0.2
	night_path=PackedVector3Array()
	night_index=0
	activity="Leaving the Copper Stag"

func sit_at(seat: Node3D) -> void:
	if meeting_partner:life.cancel_meeting(self)
	stand_up(true)
	standing_visual=visual.transform
	resting_place=seat
	seat.set_meta("occupant",person_name)
	posture="sitting"
	posture_time=0
	activity="Sitting and resting"
	animator.play("SitEnter",0.1)
	animator.advance(0)
	visual.global_position=seat.global_position-Vector3(0,1.03*appearance_height,0)
	visual.global_rotation=Vector3(0,seat.global_rotation.y,0)
	label.global_position=visual.global_position+Vector3(0,1.9*appearance_height,0)
	for child in get_children():
		if child is CollisionShape3D:child.set_deferred("disabled",true)

func sleep_at(bed: Node3D) -> void:
	if meeting_partner:life.cancel_meeting(self)
	stand_up(true)
	standing_visual=visual.transform
	global_position=life.bedside_position(self,bed)
	posture="sleeping"
	set_equipment_visible(false)
	resting_place=bed
	bed.set_meta("occupant",person_name)
	activity="Sleeping"
	animator.play("SleepExit")
	animator.advance(0)
	animator.pause()
	visual.global_position=bed.global_position
	visual.global_rotation=Vector3(0,bed.global_rotation.y,0)
	var skeleton := visual.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var hips := skeleton.find_bone("Hips")
	if hips>=0:
		var hip_world: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(hips).origin
		var target: Vector3=bed.global_position+bed.global_basis*Vector3(0,0.08,0.85)
		visual.global_position+=target-hip_world
	label.hide()
	for child in get_children():
		if child is CollisionShape3D:child.set_deferred("disabled",true)

func set_equipment_visible(value: bool) -> void:
	for equipment in equipment_nodes:equipment.visible=value
	var equipment: Array=[]
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		for part in equipment:
			if String(mesh.name).begins_with(part):mesh.visible=value

func mount_rigid_equipment() -> void:
	if style in ["saxon","cult_archer","bruce","armoured_assassin"]:
		for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
			if String(mesh.name).to_lower().contains("shield") or String(mesh.name).to_lower().contains("sword") or String(mesh.name).to_lower().contains("bow") or String(mesh.name).to_lower().contains("arrow") or String(mesh.name).to_lower().contains("equipment"):equipment_nodes.append(mesh)
	if style not in ["knight","viking"]:return
	var skeleton := visual.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var pieces := [["polySurface55_lambert7_0","LowerArm.L",Vector3(0.20,0,0.16)],
		["polySurface56_lambert8_0","Chest",Vector3(-0.08,0,-0.12)]]
	if style=="viking":pieces=[["Equipment_Shield","LowerArm.R",Vector3(-0.10,0,0.10)]]
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		for spec in pieces:
			if not String(mesh.name).begins_with(spec[0]):continue
			var bone := skeleton.find_bone(spec[1])
			var mount := BoneAttachment3D.new()
			mount.name="EquipmentShield" if spec[1]=="LowerArm.L" else "EquipmentSpear" if spec[1]=="Chest" else "EquipmentAxe"
			mount.bone_name=spec[1]
			skeleton.add_child(mount)
			var rigid := MeshInstance3D.new()
			rigid.mesh=mesh.mesh
			mount.add_child(rigid)
			rigid.skeleton=NodePath("")
			var relative: Transform3D=skeleton.global_transform.affine_inverse()*mesh.global_transform
			relative.origin+=spec[2]
			rigid.transform=skeleton.get_bone_global_rest(bone).affine_inverse()*relative
			mesh.visible=false
			equipment_nodes.append(mount)

func stand_up(immediate := false) -> void:
	if posture=="standing":return
	var previous_posture := posture
	posture="standing"
	set_equipment_visible(true)
	if resting_place:resting_place.remove_meta("occupant")
	resting_place=null
	var target_visual := standing_visual
	if posture_tween and posture_tween.is_running():posture_tween.kill()
	label.position=Vector3(0,2.05,0)
	var skeletons := visual.find_children("*","Skeleton3D",true,false)
	if not skeletons.is_empty():skeletons[0].reset_bone_poses()
	animator.play("SitExit" if previous_posture=="sitting" else "SleepExit",0.1)
	if immediate:
		visual.transform=target_visual
		getting_up=0
	else:
		getting_up=minf(1.3,animator.current_animation_length)
		posture_tween=create_tween()
		posture_tween.tween_property(visual,"transform",target_visual,getting_up).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for child in get_children():
		if child is CollisionShape3D:child.set_deferred("disabled",false)

func speak(text: String) -> String:
	var question := text.to_lower()
	if "friend" in question or "neighbour" in question:
		var names: Array=friendships.keys()
		return "I have been getting to know "+", ".join(names.slice(0,3))+". We stop to catch up when our work allows it." if not names.is_empty() else "I am still getting to know my neighbours. A few conversations will help."
	if "coin" in question or "money" in question or "wage" in question:
		return "I have "+str(coins)+" coins in my purse. A portion of vegetables costs two coins. Completed jobs earn wages from the town treasury."
	return preload("res://dialogue_catalog.gd").reply(self,text)

func move_with_steps(delta: float) -> void:
	var horizontal := Vector3(velocity.x,0,velocity.z)*delta
	if horizontal.length()>0.001 and is_on_floor() and test_move(global_transform,horizontal):
		var raised := global_transform
		raised.origin.y+=0.32
		if not test_move(global_transform,Vector3.UP*0.32) and not test_move(raised,horizontal.normalized()*0.4):global_position.y+=0.32
	move_and_slide()
