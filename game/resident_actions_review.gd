extends SceneTree

class Day extends Node:
	var night := false
class Life extends Node:
	var town: Node3D
	var navigation_ready := true
	var people: Array[CharacterBody3D]=[]
	var traffic: Node
	var allow_route := true
	func route_to_point(_person: Node,point: Vector3,_avoid := false) -> PackedVector3Array:
		return PackedVector3Array([point]) if allow_route else PackedVector3Array()
	func find_route(_from: Vector3,to: Vector3,_person: Node=null) -> PackedVector3Array:return PackedVector3Array([to])
class Jobs extends Node3D:
	var events: Array[Dictionary]=[]
	func record(person: Node,kind: String,text: String) -> void:events.append({"who":person.person_name,"kind":kind,"text":text})
	func plan(_person: Node) -> void:pass
class SkillLife extends Node:
	var bound := false
	var gains: Dictionary={}
	func gain_skill(person: String,skill: String,amount: float) -> void:gains[person+skill]=float(gains.get(person+skill,0))+amount
	func work_duration(_person: Node,_skill: String) -> float:return .8
class Routines extends Node:
	var town: Node3D
	var actions: Node3D
	var elapsed:=0.0
	func available(person: Node) -> bool:return person.routine.is_empty() and not person.talking and not person.social_partner and not person.meeting_partner and not person.night_schedule and person.posture=="standing" and person.getting_up<=0
	func cancel(person: Node) -> void:actions.cleanup(person);person.routine={}
class Town extends Node3D:
	var day_night: Node
	var life: Node
	var routines: Node
	var jobs: Node3D
	var character_life: Node
	var asset_loader: Node3D
	func detailed_prop(asset: String,parent: Node3D,pos: Vector3,size: Vector3,solid: bool) -> Node3D:
		return asset_loader.detailed_prop(asset,parent,pos,size,solid)
	func box(parent: Node3D,size: Vector3,point: Vector3,color: Color,_solid := false) -> MeshInstance3D:
		var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;visual.mesh=mesh;visual.position=point
		var mat:=StandardMaterial3D.new();mat.albedo_color=color;visual.material_override=mat;parent.add_child(visual);return visual
class Animal extends Node3D:
	var species := "Sheep"

var town: Town
var actions: Node3D
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
	else:print("RESIDENT_ACTION_PASS ",message)

func resident(person_name: String,occupation: String,point: Vector3,style := "worker") -> CharacterBody3D:
	var person: CharacterBody3D=load("res://villager.gd").new()
	person.person_name=person_name;person.occupation=occupation;person.style=style;person.position=point
	person.route.assign([point,point+Vector3(2,0,0),point+Vector3(0,0,2)])
	# Use the actual animation/skeleton/tool attachment, without the heavy town.
	person.life=town.life;town.add_child(person);person.set_physics_process(false);person.set_meta("district","city");town.life.people.append(person)
	return person

func run() -> void:
	town=Town.new();root.add_child(town)
	town.asset_loader=load("res://town.gd").new()
	town.day_night=Day.new();town.add_child(town.day_night)
	town.life=Life.new();town.life.town=town;town.add_child(town.life)
	town.jobs=Jobs.new();town.add_child(town.jobs)
	town.character_life=SkillLife.new();town.add_child(town.character_life)
	town.routines=Routines.new();town.routines.town=town;town.add_child(town.routines)
	actions=load("res://resident_actions.gd").new();town.routines.actions=actions;town.routines.add_child(actions)
	var floor:=StaticBody3D.new();town.add_child(floor);var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(100,1,100);collision.shape=shape;collision.position.y=-.5;floor.add_child(collision)
	var baker:=resident("Fixture Baker","Baker",Vector3(4,.03,0))
	var smith:=resident("Fixture Smith","Blacksmith",Vector3(8,.03,0))
	var keeper:=resident("Fixture Keeper","Range keeper",Vector3(0,.03,2.5))
	var animal:=Animal.new();town.add_child(animal);animal.position=Vector3(-1.7,.03,2.5);animal.add_to_group("animals")
	await physics_frame
	check(baker.animator.has_animation("WorkTable"),"Actual resident receives daily work animations")
	for iteration in range(6):actions.work_tick(baker,8);actions.work_tick(smith,8)
	check(baker.food==4 and actions.completed.baking==4,"Bread production creates real food and stops at four displayed loaves")
	baker.food-=1;actions.work_tick(baker,.1)
	check(actions.work[baker].output==3 and not actions.work[baker].station.has_node("Loaf3"),"Eating removes a displayed loaf on the next work update")
	actions.work_tick(baker,8)
	check(baker.food==4 and actions.work[baker].output==4,"Baker replenishes a consumed loaf without growing the display indefinitely")
	check(actions.completed.smithing==4 and town.character_life.gains["Fixture SmithSmithing"]==8,"Smith repairs four displayed tools and gains bounded skill")
	check(is_instance_valid(actions.work[smith].tool) and actions.work[smith].tool.get_parent() is BoneAttachment3D,"Held work tool follows the actual resident hand bone")
	check(actions.work[smith].station.get_child_count()==9,"Finished metal tools rest on a supported work table")
	actions.clear_work(smith);await process_frame
	check(not is_instance_valid(actions.work[smith].tool),"Interrupting work releases the held tool")
	keeper.guard_label="test gate"
	check(not actions.begin(keeper,"sweep"),"Posted guards cannot leave to perform a chore")
	keeper.guard_label="";keeper.job={"kind":"supply","stage":"delivering"}
	check(not actions.begin(keeper,"water"),"A resident delivering supplies cannot abandon the job for a chore")
	keeper.job={}
	keeper.is_child=true;check(not actions.begin(keeper,"training"),"Adult chore selection preserves child schedules");keeper.is_child=false
	town.life.allow_route=false
	check(not actions.begin(keeper,"water") and keeper.routine.is_empty(),"Unreachable chore is rejected without teleporting or reserving a station")
	town.life.allow_route=true
	check(actions.begin(keeper,"water"),"Water collection uses an ordinary resident route")
	check(keeper.position==Vector3(0,.03,2.5) and keeper.path.size()==1,"Starting an errand preserves the body position and installs a path")
	actions.tick(keeper,6)
	check(actions.water_stock==1 and keeper.routine.is_empty() and actions.reservations.is_empty(),"Water errand completes once and releases its reservation")
	check(not actions.tick(keeper,6) and actions.water_stock==1,"Finished water errand cannot award duplicate stock")
	check(actions.begin(keeper,"sweep"),"Street sweeping can begin between work shifts")
	actions.tick(keeper,1)
	var tool: Node3D=keeper.routine.props
	town.routines.cancel(keeper);await process_frame
	check(not is_instance_valid(tool) and actions.reservations.is_empty() and actions.completed.sweep==0,"Cancelling a chore removes the broom and releases its reservation without a result")
	check(actions.begin(keeper,"tend"),"Nearby animal feeding uses the animal's actual position")
	actions.tick(keeper,6)
	check(animal.get_meta("resident_fed_by","")==keeper.person_name and actions.completed.tend==1,"Completed animal care records the actual keeper on the animal")
	actions.school.pupils.append(keeper);keeper.set_meta("archery_slot",0)
	check(actions.begin(keeper,"training"),"Range keeper may practise between scheduled duties")
	town.day_night.night=true
	actions.tick(keeper,1)
	check(keeper.routine.is_empty() and actions.reservations.is_empty() and actions.completed.training==0,"Night immediately cancels a chore so the existing home schedule can take over")
	town.day_night.night=false
	check(actions.begin(keeper,"training"),"Training can restart the next day")
	keeper.position=keeper.routine.target;keeper.path=PackedVector3Array()
	actions.tick(keeper,24)
	check(actions.completed.training==1 and town.character_life.gains["Fixture KeeperArchery"]==2,"Finished practice records a real skill gain")
	var seat:=Marker3D.new();town.add_child(seat);seat.position=Vector3(4,.55,2)
	baker.sit_at(seat)
	check(baker.conversation_animation(true) in ["SitIdle","SitPoint"] and baker.posture=="sitting" and seat.get_meta("occupant")==baker.person_name,"Seated conversation selects a seated clip and preserves chair ownership")
	check(not baker.animator.has_animation("RunnerPunch") or baker.animator.get_animation("RunnerPunch").loop_mode==Animation.LOOP_NONE,"Resident initialization preserves one-shot punch policy")
	var guard_jobs: Node=load("res://town_jobs.gd").new()
	keeper.style="erika_archer";keeper.occupation="Guard"
	check(guard_jobs.is_guard_role(keeper,"west"),"Elsa's new archer appearance preserves her western guard assignment")
	keeper.occupation="Range keeper"
	check(not guard_jobs.is_guard_role(keeper,"west"),"Archer appearance alone does not turn a range keeper into a posted guard")
	keeper.style="cult_archer"
	check(actions.begin(keeper,"training"),"An equipped range keeper can start bow practice")
	keeper.position=keeper.routine.target;keeper.path=PackedVector3Array()
	actions.tick(keeper,.1)
	check(keeper.animator.current_animation=="DrawArrow","Bow practice starts with the certified draw clip")
	keeper.routine.timer=1.1;actions.tick(keeper,.1)
	check(keeper.animator.current_animation=="AimOverdraw","Bow practice follows with the certified aim clip")
	town.routines.cancel(keeper)
	var gardener:=resident("Garden Helper","Herbalist",Vector3(-29,.03,36))
	check(actions.begin(gardener,"garden"),"Herbalist can route to the community garden")
	gardener.position=gardener.routine.target;gardener.path=PackedVector3Array()
	actions.tick(gardener,6)
	check(actions.completed.garden==1 and town.character_life.gains["Garden HelperFarming"]==2,"Garden tending completes a task and awards farming experience")
	var guard := resident("Fixture Knight","Guard",Vector3(12,.03,0),"knight")
	guard.guard_post=guard.position
	guard.guard_label="the gate"
	guard.job={"kind":"guard","stage":"posted","watch_elapsed":8.0}
	guard_jobs.town=town
	guard_jobs.tick(guard,.1)
	check(guard.animator.current_animation=="ShieldIdle" and guard.position==guard.guard_post,"Equipped guard uses the shield stance without leaving their post")
	guard.job.watch_elapsed=0.0
	guard_jobs.tick(guard,.1)
	check(guard.animator.current_animation=="Examine","Guard checks their gear while posted")
	guard.job.watch_elapsed=6.0
	guard_jobs.tick(guard,.1)
	check(guard.animator.current_animation=="ShieldBlock","Guard raises the shield during a short drill")
	guard.job.watch_elapsed=6.7
	guard_jobs.tick(guard,.1)
	check(guard.animator.current_animation=="ShieldBlockHold" and guard.position==guard.guard_post,"Guard holds the block at their post")
	guard.equipment_nodes.clear()
	guard_jobs.tick(guard,.1)
	check(guard.animator.current_animation=="Idle","Unequipped guard skips the shield and gear poses")
	var elsa := resident("Elsa","Guard",Vector3(16,.03,0),"erika_archer")
	elsa.guard_post=elsa.position
	elsa.guard_label="the western crofts"
	elsa.job={"kind":"guard","stage":"posted","watch_elapsed":6.7}
	guard_jobs.tick(elsa,.1)
	check(elsa.equipment_nodes.size()==1 and elsa.equipment_nodes[0].bone_name=="LowerArm.L" and elsa.animator.current_animation=="ShieldBlockHold","Elsa's corrected skin carries a shield on the correct arm and uses it on duty")
	var farm := resident("Fixture Grower","Farmer",Vector3(-4,.03,0))
	farm.job={"kind":"farm","stage":"to_source","district":"city","target":farm.position,"completed":0}
	guard_jobs.tick(farm,.1)
	check(farm.job.stage=="planting","The farm routine starts planting at the field")
	guard_jobs.tick(farm,.1)
	check(farm.animator.current_animation=="DigPlant","The field task plays the digging and planting clip")
	farm.job.timer=0.0
	guard_jobs.tick(farm,.1)
	check(farm.job.stage=="harvesting" and is_equal_approx(farm.job.timer,4.0),"Planting returns to the harvest timer with the resident's skill applied")
	check(farm.animator.assigned_animation=="PullPlant" and farm.animator.get_animation("PullPlant").loop_mode==Animation.LOOP_NONE,"Farmers play a single pull-plant clip when harvesting")
	farm.job.timer=2.0
	farm.animate("WaveGesture")
	guard_jobs.tick(farm,.1)
	check(farm.animator.assigned_animation=="PullPlant" and farm.animator.current_animation_position>2.0,"Interrupted harvest resumes partway through the same task")
	farm.job.timer=0.0
	guard_jobs.life=town.life
	guard_jobs.markets.city={"point":Vector3(-2,.03,0)}
	guard_jobs.tick(farm,.1)
	check(farm.job.stage=="delivering" and farm.carry_kind=="carrots" and is_instance_valid(farm.carry_root),"Finished harvesting loads one actual carrot crate and sets a delivery route")
	farm.animate("Idle")
	check(farm.animator.assigned_animation=="Idle","A waiting crate carrier remains upright")
	farm.move_direction(Vector3.RIGHT,1.45,.016)
	check(farm.animator.assigned_animation=="Walk","A moving crate carrier uses the resident's normal leg cycle")
	var carrier_rig: Skeleton3D=farm.visual.find_children("*","Skeleton3D",true,false)[0]
	var foot:=carrier_rig.find_bone("Foot.L")
	var before:=farm.position
	var extent:=AABB()
	for frame in range(60):
		await physics_frame
		farm.move_direction(Vector3.RIGHT,1.45,1.0/60)
		var point:=carrier_rig.get_bone_global_pose(foot).origin
		extent=AABB(point,Vector3.ZERO) if frame==0 else extent.expand(point)
	print("CARRY_WALK_SAMPLE body_distance=",farm.position.distance_to(before)," foot_extent=",extent.size," animation_time=",farm.animator.current_animation_position)
	check(farm.position.distance_to(before)>.2 and extent.size.y>.03 and extent.size.z>.10,"The carrier advances with visible lifting and stepping of the foot")
	check(farm.carry_pose_updates>0 and farm.carry_hand_error<.25,"Hand placement continues to hold the crate during the stride")
	farm.set_carry("")
	farm.move_direction(Vector3.RIGHT,1.45,.016)
	check(farm.animator.assigned_animation=="Walk","Putting down the crate restores the ordinary walk")
	guard_jobs.free()
	if "--capture" in OS.get_cmdline_user_args():
		root.size=Vector2i(1280,800)
		var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("8da7b6");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.65;town.add_child(environment)
		var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-30,0);sun.light_energy=1.2;town.add_child(sun)
		town.box(town,Vector3(30,.04,30),Vector3(4,-.02,0),Color("8a916a"))
		var camera:=Camera3D.new();town.add_child(camera);camera.position=Vector3(11,5,10);camera.look_at(Vector3(4,1.1,1));camera.current=true
		baker.stand_up(true);baker.visual.rotation=Vector3.ZERO;baker.animate("WorkTable");baker.animator.advance(.5)
		smith.animate("WorkTable");smith.animator.advance(.5);actions.work_tick(smith,.1)
		for frame in range(12):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../resident-actions-preview.png")
		camera.position=Vector3(9.8,2.5,3.3);camera.look_at(Vector3(8,1,.35))
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../resident-smith-tool-preview.png")
		camera.position=Vector3(5.8,2.5,3.3);camera.look_at(Vector3(4,1,.35))
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../resident-baker-work-preview.png")
		guard.animate("ShieldBlockHold")
		guard.animator.play("ShieldBlockHold",0)
		guard.animator.seek(.7,true)
		guard.animator.advance(0)
		camera.position=guard.position+Vector3(1.8,2.1,3.1)
		camera.look_at(guard.position+Vector3.UP*.85)
		for frame in range(6):await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../resident-guard-block-preview.png")
		farm.animate("DigPlant")
		farm.animator.seek(2.4,true)
		camera.position=farm.position+Vector3(1.8,2.1,3.1)
		camera.look_at(farm.position+Vector3.UP*.65)
		for frame in range(6):await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../resident-farm-planting-preview.png")
		elsa.animator.seek(.7,true)
		camera.position=elsa.position+Vector3(1.3,1.65,3)
		camera.look_at(elsa.position+Vector3.UP*.9)
		for frame in range(6):await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../resident-elsa-shield-preview.png")
	town.asset_loader.free()
	print("RESIDENT_ACTION_REVIEW_COMPLETE failures=",failures," completed=",actions.completed," remembered=",town.jobs.events.size())
	quit(0 if failures.is_empty() else 1)
