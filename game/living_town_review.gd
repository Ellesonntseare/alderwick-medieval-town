extends SceneTree

var failures: Array[String]=[]
var town: Node3D
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func run() -> void:
	town=load("res://town.tscn").instantiate();root.add_child(town)
	while not town.life.navigation_ready or get_nodes_in_group("animals").size()<13 or not town.adventures.visitor:await physics_frame
	town.speech.set_enabled(false);town.day_night.set_enabled(false)
	check(town.life.people.size()==53,"All 53 residents remain present")
	check(town.families.membership.size()==53,"Every resident has a household")
	check(town.families.households.size()==24,"24 distinct households are assigned")
	var beds: Dictionary={}
	for person in town.life.people:
		var data: Dictionary=town.families.membership[person.person_name]
		check(not beds.has(data.bed),person.person_name+" has a unique permanent bed")
		beds[data.bed]=true
		check(data.bed.get_parent()==data.home,person.person_name+" bed belongs to shared family home")
	check(town.life.walking_routes.paved.size()>500,"Movement policies read the rendered paving")
	var origins: Dictionary={}
	for bird in get_nodes_in_group("sky_birds"):origins[bird]=bird.position
	for animal in get_nodes_in_group("animals"):
		check(animal.can_walk and animal.animator.has_animation(animal.walk_clip),animal.name+" has a real skeletal walk clip")
	for frame in range(2400):await physics_frame
	for person in town.life.people:
		if person.person_name in ["Ollie","Theo","Duncan","Roslin","Fenn"]:
			print("LIVING_TOWN_DAY name=",person.person_name," travelled=",person.travelled," policy=",person.walking_policy)
			if person.travelled<1:print("RESIDENT_STUCK_STATE name=",person.person_name," pos=",person.position," activity=",person.activity," route=",person.path," wait=",person.wait_time," routine=",person.routine," blocked=",person.blocked_steps)
			check(person.travelled>1,person.person_name+" continues to roam or work")
	var moved:=0
	for animal in get_nodes_in_group("animals"):
		print("FARM_ANIMAL_REVIEW name=",animal.name," walked=",animal.travelled," position=",animal.position," clip=",animal.animator.current_animation)
		if animal.travelled>.5:moved+=1
		if animal.pasture.has_area():check(animal.pasture.has_point(Vector2(animal.position.x,animal.position.z)),animal.name+" stays in the farm pasture")
	check(moved>=10,"Most farm animals walk rather than remaining static")
	for bird in origins:check(bird.travelled>20 and bird.position.y>12,"Birds fly above the districts")
	town.day_night.set_night(true)
	var assembled: Dictionary={}
	for frame in range(7200):
		await physics_frame
		if frame%60==0:
			for id in town.families.groups:
				var group: Dictionary=town.families.groups[id]
				var close:=true
				for person in group.members:
					if person.position.distance_to(group.meet)>4:close=false
				if close:assembled[id]=true
		if frame in [1800,3600,7199]:
			var missing: Array=[]
			for person in town.life.people:
				if person.guard_shift!="night" and person.posture!="sleeping":missing.append(person.person_name+":"+person.night_stage+":"+str(person.position))
			print("FAMILY_NIGHT_PROGRESS seconds=",frame/60," missing=",missing)
			if missing.is_empty():break
	var asleep:=0
	for person in town.life.people:
		if person.guard_shift=="night":check(person.posture!="sleeping",person.person_name+" works the night-watch exception");continue
		if person.posture=="sleeping":asleep+=1
		check(person.posture=="sleeping",person.person_name+" reaches a bed at night")
		if person.assigned_bed:check(person.assigned_bed==town.families.membership[person.person_name].bed,person.person_name+" sleeps in their family home")
	check(assembled.size()>0,"Families physically gather before walking home")
	check(town.adventures.visitor.posture=="sleeping","The visiting surveyor rests at night too")
	print("LIVING_TOWN_REVIEW_COMPLETE sleepers=",asleep," assembled_families=",assembled.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
