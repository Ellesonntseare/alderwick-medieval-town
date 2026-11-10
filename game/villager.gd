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
var dialogue_was_speaking := false
var visits := 0
var travelled := 0.0
var activity := "Enjoying the town"
var visual: Node3D
var animator: AnimationPlayer
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
var watch_shield_anchor: Node3D
var watch_shield_rest := Basis.IDENTITY
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
var received_object: Node3D
var prop_action:=preload("res://prop_action.gd").new()
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
var simulation_elapsed := 0.0
var rest_ground_check := 0.0
var rest_ground_position := Vector3.INF
var movement_step_probes := 0
var movement_rest_skips := 0

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
			if clip in ["Idle","Walk","Run","Interact","Wave","WorkTable","WorkHarvest","SitIdle"]:animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		animate("Idle")
	var skeleton := visual.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var attached_feet:=preload("res://feet_attachment.gd").new()
	attached_feet.model=visual
	attached_feet.name="AttachedFeet"
	skeleton.add_child(attached_feet)
	var grounding := SkeletonModifier3D.new()
	grounding.name="GroundedFeet"
	grounding.set_script(load("res://foot_grounding.gd"))
	grounding.resident=self
	grounding.model=visual
	skeleton.add_child(grounding)
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
	if prop_action.active and clip!=prop_action.clip:return
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
	if life.town.routines:life.town.routines.actions.clear_work(self)
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
	# Stationary residents retain floor contact; periodically recheck for removed
	# support. Moving platforms and displaced bodies always run physics normally.
	rest_ground_check-=delta
	if is_on_floor() and get_platform_velocity().length_squared()<.0001 and position.distance_squared_to(rest_ground_position)<.000004 and rest_ground_check>0:
		velocity=Vector3.ZERO;movement_rest_skips+=1;return
	velocity=Vector3(0,-2,0)
	move_with_steps(delta)
	rest_ground_position=position
	rest_ground_check=.2+float(posmod(person_name.hash(),7))*.01

func _physics_process(delta: float) -> void:
	simulation_elapsed+=delta
	if simulation_elapsed<float(get_meta("simulation_interval",0.0)):return
	delta=simulation_elapsed
	simulation_elapsed=0.0
	social_cooldown=maxf(0,social_cooldown-delta)
	if tick_prop_action(delta):rest(delta);return
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
			# A paired, quiet exchange still has body language while generated
			# dialogue is postponed. Never gesture at an absent partner.
			var gesture: String="HeadShakeNo" if not social_speaking and social_elapsed>2 and social_elapsed<5 and person_name.hash()%2==0 and animator and animator.has_animation("HeadShakeNo") else "Interact" if social_speaking else "Idle"
			animate(gesture)
			var camera := get_viewport().get_camera_3d()
			bubble.visible=social_speaking and posture!="sleeping" and camera!=null and camera.global_position.distance_to(global_position)<15 and has_conversation_partner()
			if social_time<=0:end_social()
			return
	if meeting_partner and not talking:
		process_meeting(delta)
		return
	if talking:
		var speech: Node=life.town.get("speech")
		var speaking: bool=speech!=null and speech.busy(self)
		if posture=="sitting":
			if speaking and not dialogue_was_speaking:
				animate(conversation_animation(true))
			elif animator and animator.current_animation not in ["SitEnter","SitPoint"]:
				animate("SitIdle")
		else:
			rest(delta)
			if work_timer==0:
				animate("WaveGesture" if animator and animator.has_animation("WaveGesture") else "Wave")
			elif work_timer>=1.5:
				animate(conversation_animation(speaking))
		dialogue_was_speaking=speaking
		work_timer += delta
		return
	dialogue_was_speaking=false
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
		if destination==0 and not route_unavailable and life.town.routines:life.town.routines.actions.work_tick(self,delta)
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
	if occupation=="Village child" and not indoor_house and animator and animator.has_animation("RunnerDance"):
		return "RunnerDance"
	if occupation=="Farmer":return "WorkHarvest"
	if occupation in ["Baker","Blacksmith","Brewer","Carpenter","Weaver","Herbalist","Merchant","Town clerk","Archivist","Castle caretaker"]:return "WorkTable"
	return "Interact"

func conversation_animation(speaking: bool) -> String:
	if posture=="sitting":
		if speaking and animator and animator.has_animation("SitPoint"):return "SitPoint"
		return "SitIdle"
	return "Interact" if speaking else "Idle"

func move_direction(direction: Vector3,pace: float,delta: float) -> void:
	if life and life.get("town") and life.town.get("character_life")!=null and life.town.character_life.bound:pace*=life.town.character_life.walking_pace(self)
	var desired: Vector3=life.traffic.steer(self,direction,pace,delta) if life and life.traffic else direction*pace
	velocity=Vector3(desired.x,-2,desired.z)
	move_with_steps(delta)
	if desired.length()>0.05:
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(desired.x,desired.z),delta*8)
		# Use the resident's regular gait while the hand modifier holds the crate.
		# This preserves the resident's visible stride at delivery speed.
		var running := carry_kind.is_empty() and pace>2.2
		animate("Run" if running else "Walk")
		animator.speed_scale=clampf(desired.length()/(4.5 if running else 1.45),0.55,1.7)
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
		if stuck_time>1.4 and (not life.walking_routes or life.walking_routes.claim_replan()):
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

func prop_action_busy() -> bool:return prop_action.active

func tick_prop_action(delta: float) -> bool:
	if not prop_action.active:return false
	if night_schedule or posture!="standing" or (talking and prop_action.kind!="handover"):prop_action.cancel();return false
	prop_action.tick(delta)
	if prop_action.active and is_instance_valid(carry_root) and prop_action.kind in ["pickup","place"]:
		var fraction:=clampf((prop_action.ratio()-prop_action.contact)/(1-prop_action.contact),0,1) if prop_action.kind=="pickup" else clampf(1-prop_action.ratio()/prop_action.contact,0,1)
		carry_root.position=Vector3(0,.18,.45).lerp(Vector3(0,.96,.4),fraction)
	return prop_action.active

func finish_prop_action() -> void:
	if is_instance_valid(carry_root):carry_root.position=Vector3(0,.96,.4)
	if animator and animator.has_animation("Idle"):animator.speed_scale=1;animator.play("Idle",.18)

func begin_prop_gesture() -> bool:
	if prop_action.active:return false
	return prop_action.begin(animator,"handover",func():return true,finish_prop_action)

func set_carry(kind: String,animated:=true) -> void:
	if not prop_action.active and carry_kind==kind and (kind.is_empty() or is_instance_valid(carry_root)):return
	prop_action.cancel()
	if carry_kind==kind and (kind.is_empty() or is_instance_valid(carry_root)):return
	if animated and is_physics_processing() and life and life.get("navigation_ready")==true and posture=="standing" and not night_schedule:
		if prop_action.begin(animator,"place" if kind.is_empty() else "pickup",func():apply_carry(kind);return true,finish_prop_action):
			return
	apply_carry(kind)

func apply_carry(kind: String) -> void:
	carry_kind=kind
	if carry_root:carry_root.queue_free();carry_root=null
	if kind.is_empty():return
	carry_root=Node3D.new()
	visual.add_child(carry_root)
	carry_root.name="CarriedGoods"
	carry_root.position=Vector3(0,0.96,0.40)
	life.town.detailed_prop("FarmCrate_Carrot" if kind=="carrots" else "Crate_Wooden",carry_root,Vector3.ZERO,Vector3(0.55,0.3,0.36),false)
	ensure_carry_modifier()

func ensure_carry_modifier() -> void:
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
	prop_action.cancel();apply_carry("")
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
	var night_speed := minf(2.0,speed*1.15)
	if day_visit:night_speed=1.65
	if night_stage in ["to_bed","exit_walk","exit_approach","visit_walk"]:night_speed=1.6
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
	for child in get_children():
		if child is CollisionShape3D:child.set_deferred("disabled",true)

func set_equipment_visible(value: bool) -> void:
	for equipment in equipment_nodes:equipment.visible=value
	var equipment: Array=[]
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		for part in equipment:
			if String(mesh.name).begins_with(part):mesh.visible=value

func mount_rigid_equipment() -> void:
	if style=="erika_archer" and occupation=="Guard" and life:
		mount_watch_shield()
		return
	var shields: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		var label := String(mesh.name).to_lower()
		if label.contains("shield") or (style=="knight" and label.begins_with("polysurface55")):
			shields.append(mesh)
		elif style in ["saxon","cult_archer","bruce","armoured_assassin"] and (label.contains("sword") or label.contains("bow") or label.contains("arrow") or label.contains("equipment")):
			equipment_nodes.append(mesh)
	if not shields.is_empty():mount_carried_shield(shields,"L")
	if style!="knight":return
	var skeleton := visual.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		if not String(mesh.name).begins_with("polySurface56"):continue
		var mount := BoneAttachment3D.new()
		mount.name="EquipmentSpear"
		mount.bone_name="Chest"
		skeleton.add_child(mount)
		var rigid := MeshInstance3D.new()
		rigid.mesh=mesh.mesh
		mount.add_child(rigid)
		rigid.skeleton=NodePath("")
		var relative := skeleton.global_transform.affine_inverse()*mesh.global_transform
		var centre := relative*mesh.get_aabb().get_center()
		var chest := skeleton.get_bone_global_rest(skeleton.find_bone("Chest"))
		relative.origin += Vector3(-.16,1.05,-.19)-centre
		rigid.transform=chest.affine_inverse()*relative
		mesh.visible=false
		equipment_nodes.append(mount)

func mount_carried_shield(meshes: Array[MeshInstance3D],side: String) -> void:
	var skeleton := visual.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var arm := skeleton.find_bone("LowerArm."+side)
	var wrist := skeleton.find_bone("Wrist."+side)
	if arm<0 or wrist<0:return
	var bounds := AABB()
	var transforms: Array[Transform3D] = []
	for index in range(meshes.size()):
		var relative := skeleton.global_transform.affine_inverse()*meshes[index].global_transform
		transforms.append(relative)
		var box := relative*meshes[index].get_aabb()
		bounds=box if index==0 else bounds.merge(box)
	var forearm := skeleton.get_bone_global_rest(arm)
	var hand := skeleton.get_bone_global_rest(wrist).origin
	# The rear surface rests against the forearm; the hand sits behind the centre.
	var centre := forearm.origin.lerp(hand,.85)
	centre.z += .055+bounds.size.z*.5
	var mount := BoneAttachment3D.new()
	mount.name="EquipmentShield"
	mount.bone_name="LowerArm."+side
	skeleton.add_child(mount)
	var anchor := Node3D.new()
	mount.add_child(anchor)
	anchor.transform=forearm.affine_inverse()*Transform3D(Basis.IDENTITY,centre)
	watch_shield_anchor=anchor
	watch_shield_rest=anchor.basis
	var brace := preload("res://shield_attachment.gd").new()
	brace.anchor=anchor
	brace.arm_bone=arm
	brace.rest=anchor.transform
	brace.animator=find_animator(visual)
	brace.grip=forearm.affine_inverse()*(hand+forearm.basis.y.normalized()*.04)
	brace.clearance=.11+bounds.size.z*.5
	if style=="viking":brace.clearance=.22
	skeleton.add_child(brace)
	for index in range(meshes.size()):
		var source := meshes[index]
		var rigid := MeshInstance3D.new()
		rigid.mesh=source.mesh
		rigid.material_override=source.material_override
		for surface in range(source.mesh.get_surface_count()):
			rigid.set_surface_override_material(surface,source.get_surface_override_material(surface))
		rigid.skeleton=NodePath("")
		anchor.add_child(rigid)
		rigid.transform=Transform3D(Basis.IDENTITY,-bounds.get_center())*transforms[index]
		if style=="viking":rigid.transform=Transform3D(Basis(Vector3.UP,PI),Vector3.ZERO)*rigid.transform
		source.visible=false
	equipment_nodes.append(mount)

func mount_watch_shield() -> void:
	var source := Node3D.new()
	visual.add_child(source)
	life.town.detailed_prop("Shield_Wooden",source,Vector3.ZERO,Vector3(.48,.58,.10),false)
	var meshes: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):meshes.append(mesh)
	if not meshes.is_empty():mount_carried_shield(meshes,"L")
	source.queue_free()

func stand_up(immediate := false) -> void:
	if posture=="standing":return
	var previous_posture := posture
	posture="standing"
	set_equipment_visible(true)
	if resting_place:resting_place.remove_meta("occupant")
	resting_place=null
	var target_visual := standing_visual
	if posture_tween and posture_tween.is_running():posture_tween.kill()
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
	var before:=global_position
	var grounded:=is_on_floor()
	# Budgeted residents accumulate multiple engine ticks.
	var tick_scale:=maxf(1.0,delta/maxf(get_physics_process_delta_time(),.000001))
	velocity*=tick_scale
	move_and_slide()
	velocity/=tick_scale
	# Clear flat roads need no speculative step probes. Try a step only after
	# the normal collision sweep reports an obstruction and blocks progress.
	var travelled_horizontal:=Vector3(global_position.x-before.x,0,global_position.z-before.z)
	if not grounded or horizontal.length_squared()<.000001 or travelled_horizontal.dot(horizontal.normalized())>=horizontal.length()*.8:return
	var wall:=false
	var floor_only:=get_slide_collision_count()>0
	for index in range(get_slide_collision_count()):
		var hit:=get_slide_collision(index)
		var body:=hit.get_collider() as CollisionObject3D
		if hit.get_normal().y<.98:floor_only=false
		if body and body.collision_layer & 1 and hit.get_normal().y<.98 and hit.get_normal().y>-.1:wall=true
	var remaining:=horizontal-travelled_horizontal
	if not wall:
		if not floor_only:return
		# Imported coplanar floor triangles can exhaust the slide iterations
		# without a wall contact. Retry horizontally just above that floor seam.
		var lifted:=global_transform;lifted.origin.y+=.03
		movement_step_probes+=1
		if test_move(lifted,remaining):
			# A porch edge can report a floor normal as well. Try the ordinary
			# stair-height rise, checking head clearance and the full forward path.
			var porch:=global_transform;porch.origin.y+=.32
			movement_step_probes+=2
			if test_move(lifted,Vector3.UP*.29) or test_move(porch,remaining.normalized()*maxf(.4,remaining.length())):return
			lifted=porch
		global_transform=lifted
		var saved_velocity:=velocity
		var physics_delta:=maxf(get_physics_process_delta_time(),.000001)
		velocity=Vector3(remaining.x/physics_delta,0,remaining.z/physics_delta)
		move_and_slide()
		velocity=saved_velocity
		return
	var raised:=global_transform;raised.origin.y+=.32
	var clearance_start:=global_transform;clearance_start.origin.y+=.03
	movement_step_probes+=2
	if test_move(clearance_start,Vector3.UP*.29) or test_move(raised,remaining.normalized()*maxf(.4,remaining.length())):return
	global_position.y+=.32
	var previous_velocity:=velocity
	var step_delta:=maxf(get_physics_process_delta_time(),.000001)
	velocity=Vector3(remaining.x/step_delta,-2,remaining.z/step_delta)
	move_and_slide()
	velocity=previous_velocity
