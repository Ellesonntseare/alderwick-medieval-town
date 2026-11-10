extends Node3D

# Owned by TownRoutines so editor pauses and night cancellation use the same
# lifecycle as shopping/resting. No separate navigation or resident copies.
var town: Node3D
var elapsed := 0.0
var work: Dictionary={}
var reservations: Dictionary={}
var completed := {"baking":0,"smithing":0,"water":0,"sweep":0,"tend":0,"training":0,"garden":0}
var school: Node3D
var water_stock := 0

func _ready() -> void:
	town=get_parent().town
	school=preload("res://archery_school.gd").new()
	add_child(school)

func box(parent: Node3D,size: Vector3,point: Vector3,color: Color) -> MeshInstance3D:
	return town.box(parent,size,point,color,false)

func clip(person: CharacterBody3D,preferred: String,fallback: String) -> String:
	return preferred if person.animator and person.animator.has_animation(preferred) else fallback

func eligible(person: CharacterBody3D) -> bool:
	if town.day_night.night or not town.routines.available(person):return false
	if person.indoor_house or (person.is_child and person.person_name!="Theo") or not person.guard_label.is_empty() or not person.stall_name.is_empty() or not person.carry_kind.is_empty():return false
	if not person.job.is_empty() and person.job.get("stage","") not in ["start","break"]:return false
	return true

func consider(person: CharacterBody3D,clock: float) -> bool:
	if clock<float(person.get_meta("next_visible_action",20+posmod(person.person_name.hash(),35))):return false
	person.set_meta("next_visible_action",clock+35+posmod(person.person_name.hash(),30))
	if school.pupils.has(person) and clock>=float(person.get_meta("next_archery",0)):
		if school.begin(person):return true
	if not eligible(person):return false
	var choice := posmod(person.person_name.hash()+int(person.get_meta("visible_action_turn",0)),3)
	var kind: String="garden" if person.occupation=="Herbalist" else "tend" if person.occupation in ["Stable keeper","Farmer"] else ["water","sweep","tend"][choice]
	return begin(person,kind)

func begin(person: CharacterBody3D,kind: String) -> bool:
	if kind=="training":return school.begin(person)
	if not eligible(person) or kind not in ["water","sweep","tend","training","garden"]:return false
	if person.is_child and kind!="training":return false
	var chores:=0
	for reservation in reservations:
		if not String(reservation).begins_with("training:"):chores+=1
	if chores>=4:return false
	var target := person.position
	var animal: Node3D=null
	if kind=="water":
		if person.get_meta("district","")!="city":return false
		target=Vector3(0,person.position.y,2.5)
	elif kind=="garden":
		if person.get_meta("district","")!="city":return false
		target=Vector3(-30+posmod(person.person_name.hash(),3),person.position.y,36)
	elif kind=="tend":
		var nearest := 30.0
		for candidate: Node3D in get_tree().get_nodes_in_group("animals"):
			if candidate.get("species") not in ["Cow","Horse","Pig","Sheep","Pug"]:continue
			var gap := person.position.distance_to(candidate.global_position)
			if gap<nearest:animal=candidate;nearest=gap
		if not animal:return false
		target=animal.global_position+Vector3(1.7,0,0)
	# Herbalists can walk from the practice field across the city to the garden.
	# Reachability is still certified by the real route, rather than a 60 m
	# radius that rejected Roslin's lane just across the town square.
	if person.position.distance_to(target)>(100 if kind=="garden" else 60 if kind=="training" else 40):return false
	var key := kind+":"+(str(animal.get_instance_id()) if animal else str(Vector2i(roundi(target.x/3),roundi(target.z/3))))
	if reservations.has(key):return false
	var route: PackedVector3Array=town.life.route_to_point(person,target)
	if route.is_empty() or route[-1].distance_to(target)>1.25:return false
	reservations[key]=person
	person.routine={"kind":"resident_action","action":kind,"stage":"walking","timer":0.0,"timeout":50.0,"key":key,"target":target,"animal":animal,"props":null}
	person.path=route;person.path_index=0
	person.activity={"water":"Fetching water from the well","sweep":"Tidying the street","tend":"Taking feed to the animals","training":"Walking to the practice ground","garden":"Walking to tend the community garden"}[kind]
	person.set_meta("visible_action_turn",int(person.get_meta("visible_action_turn",0))+1)
	clear_work(person)
	return true

func tick(person: CharacterBody3D,delta: float) -> bool:
	if person.routine.get("kind","")!="resident_action":return false
	var action: Dictionary=person.routine
	if town.day_night.night or person.night_schedule:
		town.routines.cancel(person);return false
	if action.stage=="walking":
		if not person.follow_path(delta,1.4):return true
		if person.position.distance_to(action.target)>1.5:
			town.routines.cancel(person);person.plan();return false
		action.stage="working"
		if action.action not in ["garden","training"]:action.props=make_tool(person,String(action.action))
	person.rest(delta)
	var kind: String=action.action
	if kind=="tend":
		if not is_instance_valid(action.animal) or person.position.distance_to(action.animal.global_position)>5:
			town.routines.cancel(person);person.plan();return false
		var facing: Vector3=action.animal.global_position-person.position
		person.visual.rotation.y=lerp_angle(person.visual.rotation.y,atan2(facing.x,facing.z),delta*5)
	elif kind=="water":person.visual.rotation.y=atan2(-person.position.x,-person.position.z)
	if kind=="training":school.tick(person,delta)
	elif kind=="garden":person.animate(clip(person,"DigPlant","WorkHarvest"))
	else:person.animate("WorkHarvest" if kind=="tend" else "WorkTable")
	person.activity={"water":"Drawing a bucket of water","sweep":"Sweeping the street","tend":"Putting out fresh animal feed","training":"Practising at the training ground","garden":"Tending seedlings in the community garden"}[kind]
	action.timer+=delta
	if is_instance_valid(action.props) and kind=="sweep":action.props.rotation.z=sin(float(action.timer)*5)*.22
	if action.timer<(24 if kind=="training" else 6):return true
	completed[kind]+=1
	var memory := ""
	match kind:
		"water":water_stock=mini(20,water_stock+1);memory="I brought a fresh bucket of water from the well."
		"sweep":memory="I swept the street and cleared up outside the houses."
		"tend":
			action.animal.set_meta("resident_fed_by",person.person_name)
			action.animal.set_meta("resident_fed_at",Time.get_ticks_msec())
			memory="I put out fresh feed for the "+String(action.animal.species).to_lower()+"."
		"training":
			memory="I finished a practice session at the training ground."
			if town.character_life:town.character_life.gain_skill(person.person_name,"Archery",2)
		"garden":
			memory="I tended the seedlings in the community garden."
			if town.character_life:town.character_life.gain_skill(person.person_name,"Farming",2)
	town.jobs.record(person,"daily_activity",memory)
	cleanup(person)
	person.routine={}
	person.wait_time=1.5
	person.plan()
	return true

func cleanup(person: CharacterBody3D) -> void:
	var action: Dictionary=person.routine
	if action.get("kind","")!="resident_action":return
	if action.get("action")=="training":school.cleanup(person)
	var props: Node3D=action.get("props")
	if is_instance_valid(props):props.queue_free()
	var key: String=action.get("key","")
	if reservations.get(key)==person:reservations.erase(key)

func make_tool(person: CharacterBody3D,kind: String) -> Node3D:
	var tool := Node3D.new()
	tool.name="ResidentTool_"+kind
	var skeletons: Array=person.visual.find_children("*","Skeleton3D",true,false)
	if not skeletons.is_empty() and skeletons[0].find_bone("Wrist.R")>=0:
		var mount := BoneAttachment3D.new()
		mount.bone_name="Wrist.R";skeletons[0].add_child(mount);mount.add_child(tool)
		# Free the mount with its tool to avoid retaining empty attachments.
		tool.tree_exited.connect(func():if is_instance_valid(mount) and not mount.is_queued_for_deletion():mount.queue_free())
	else:
		person.visual.add_child(tool);tool.position=Vector3(.25,.9,.4)
	if kind in ["smithing","carpentry"]:
		box(tool,Vector3(.035,.3,.035),Vector3(0,-.08,0),Color("765231"))
		box(tool,Vector3(.19,.08,.075),Vector3(0,.09,0),Color("6d7378"))
	elif kind=="sweep":
		box(tool,Vector3(.035,1.2,.035),Vector3(0,-.4,0),Color("85633e"))
		box(tool,Vector3(.27,.17,.1),Vector3(0,-1.02,0),Color("b4a16a"))
	elif kind!="training":
		var pail := MeshInstance3D.new();var mesh := CylinderMesh.new()
		mesh.top_radius=.15;mesh.bottom_radius=.11;mesh.height=.24;mesh.radial_segments=12
		pail.mesh=mesh;pail.position.y=-.12;tool.add_child(pail)
		var material := StandardMaterial3D.new();material.albedo_color=Color("8b6745");pail.material_override=material
		box(tool,Vector3(.27,.025,.025),Vector3(0,.04,0),Color("4f5053"))
	return tool

func work_tick(person: CharacterBody3D,delta: float) -> void:
	var kind := "baking" if person.occupation=="Baker" else "smithing" if person.occupation=="Blacksmith" else "carpentry" if person.occupation=="Carpenter" else ""
	if kind.is_empty():return
	if not work.has(person):
		var station := Node3D.new();station.name=person.person_name+"WorkResults";add_child(station)
		station.global_position=person.global_position
		station.rotation.y=person.visual.global_rotation.y
		if kind in ["baking","smithing"]:
			box(station,Vector3(.8,.07,.45),Vector3(0,.86,.65),Color("765438"))
			for x in [-.33,.33]:
				for z in [.49,.81]:box(station,Vector3(.06,.83,.06),Vector3(x,.415,z),Color("67472f"))
		work[person]={"timer":0.0,"kind":kind,"tool":null,"station":station,"output":0,"active_at":0}
	var state: Dictionary=work[person]
	if kind=="baking":
		while state.output>person.food:
			var loaf: Node=state.station.get_node_or_null("Loaf"+str(state.output-1))
			if loaf:state.station.remove_child(loaf);loaf.queue_free()
			state.output-=1
	state.active_at=Time.get_ticks_msec()
	if not is_instance_valid(state.tool):state.tool=make_tool(person,kind)
	state.timer+=delta
	if state.timer<8:return
	state.timer=0.0
	# Existing carpentry jobs own their finished furniture and wages.
	if kind=="carpentry":return
	if state.output>=4:return
	var slot: int=state.output
	if kind=="baking":
		# A bounded tray of bread is also real food for the baker's meals.
		if person.food>=4:return
		var loaf := MeshInstance3D.new();var mesh := SphereMesh.new();mesh.radius=.1;mesh.height=.15
		loaf.name="Loaf"+str(slot)
		loaf.mesh=mesh;loaf.scale=Vector3(1.45,.6,1)
		loaf.position=Vector3((slot%2-.5)*.3,.95,.55+float(slot/2)*.16);state.station.add_child(loaf)
		var mat := StandardMaterial3D.new();mat.albedo_color=Color("c68a45");loaf.material_override=mat
		person.food+=1
		completed.baking+=1
		town.jobs.record(person,"cook","I baked a fresh loaf of bread at the bakery.")
	else:
		box(state.station,Vector3(.3,.04,.1),Vector3(-.2+float(slot%2)*.4,.91,.55+float(slot/2)*.15),Color("92999b"))
		completed.smithing+=1
		town.jobs.record(person,"smithing","I finished repairing a metal tool at the forge.")
		if town.character_life:town.character_life.gain_skill(person.person_name,"Smithing",2)
	state.output+=1

func clear_work(person: CharacterBody3D) -> void:
	if not work.has(person):return
	var tool: Node3D=work[person].tool
	if is_instance_valid(tool):tool.queue_free()
	work[person].tool=null

func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed<.25:return
	elapsed=0
	for person in work:
		if not is_instance_valid(person):continue
		if Time.get_ticks_msec()-int(work[person].active_at)>300 or person.talking or person.night_schedule or person.posture!="standing":clear_work(person)
