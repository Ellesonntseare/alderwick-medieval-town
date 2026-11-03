extends SceneTree

const EXPECTED := {"Gareth":"saxon","Duncan":"bruce","Selene":"armoured_assassin","Ivor":"robed_scholar","Roslin":"medieval_woman","Fenn":"cult_archer","Ollie":"runner_child","Theo":"runner_youth"}
const WARDROBE := {"Finn":"male_peasant","Wren":"female_peasant","Kael":"male_ranger","Elowen":"female_ranger"}
var failures: Array[String]=[]
var town: Node3D

func _initialize() -> void:run.call_deferred()

func check(ok: bool,message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	town=load("res://town.tscn").instantiate()
	root.add_child(town)
	while not town.life.navigation_ready:await physics_frame
	town.speech.set_enabled(false)
	town.day_night.set_enabled(false)
	town.player.position=Vector3(0,0.1,23)
	check(town.life.people.size()==53,"53 residents including the original 45")
	var stories=JSON.parse_string(FileAccess.get_file_as_string("res://character_stories.json"))
	var cast: Dictionary={}
	for person in stories.characters:cast[person.name]=person
	check(cast.size()==53,"53 distinct character backgrounds")
	var added: Array[CharacterBody3D]=[]
	var feet_samples: Dictionary={}
	var feet_error: Dictionary={}
	for person in town.life.people:
		check(cast.has(person.person_name),person.person_name+" needs a background")
		if WARDROBE.has(person.person_name):check(person.style==WARDROBE[person.person_name],person.person_name+" wears the approved outfit")
		if not EXPECTED.has(person.person_name):continue
		added.append(person)
		check(person.style==EXPECTED[person.person_name],person.person_name+" uses the approved model")
		check(person.animator!=null,person.person_name+" needs an animator")
		for clip in ["Idle","Walk","Run","SitEnter","SitIdle","SitExit","SleepExit","WorkTable","WorkHarvest"]:
			check(person.animator.has_animation(clip),person.person_name+" missing "+clip)
		var capsule: CapsuleShape3D=person.find_children("*","CollisionShape3D",false,false)[0].shape
		check(is_equal_approx(capsule.height,1.7*person.appearance_height),person.person_name+" capsule fits model")
		if person.is_child:
			check(person.appearance_height<0.9,person.person_name+" has child proportions")
			check(not town.routines.begin_tavern(person),person.person_name+" has age-appropriate routines")
		feet_samples[person.person_name]=0
		feet_error[person.person_name]=0.0
		print("NEW_RESIDENT_READY ",person.person_name," style=",person.style," height=",1.8*person.appearance_height," role=",person.occupation," job=",person.job.get("kind","independent")," home=",person.home)
	check(added.size()==8,"All eight new residents are present")
	for frame in range(2400):
		await physics_frame
		if frame%120!=0:continue
		for person in added:
			if person.posture!="standing" or person.getting_up>0 or person.night_schedule:continue
			var grounding: SkeletonModifier3D=person.visual.find_child("GroundedFeet",true,false)
			if grounding.corrections<5:continue
			feet_samples[person.person_name]+=1
			feet_error[person.person_name]=maxf(feet_error[person.person_name],absf(grounding.contact_error))
	for person in added:
		print("NEW_RESIDENT_DAY ",person.person_name," travelled=",person.travelled," posture=",person.posture," foot_samples=",feet_samples[person.person_name]," foot_error=",feet_error[person.person_name]," stage=",person.night_stage)
		if person.person_name=="Selene":continue
		check(feet_samples[person.person_name]>0 and feet_error[person.person_name]<0.16,person.person_name+" feet follow the floor")
		if person.person_name not in ["Gareth","Ivor"]:check(person.travelled>1.0,person.person_name+" moves through the town")
	check(town.jobs.night_guards.size()==4,"Selene joins a separate night watch")
	check(town.life.walking_routes!=null and town.life.walking_routes.paved.size()>500,"Actual rendered streets are registered for walking")
	for person in added:
		print("RESIDENT_WALKING_POLICY ",person.person_name," policy=",person.walking_policy," remaining_path=",person.path.size()-person.path_index)
	if "--day-only" in OS.get_cmdline_user_args():
		print("NEW_RESIDENTS_DAY_REVIEW_COMPLETE failures=",failures)
		quit(0 if failures.is_empty() else 1)
		return
	town.day_night.set_enabled(true)
	town.day_night.phase=0.85
	town.day_night.apply_time()
	town.day_night.enabled=false
	for frame in range(7200):
		await physics_frame
		if frame%600==0:
			var sleeping := 0
			for person in added:
				if person.posture=="sleeping":sleeping+=1
			print("NEW_RESIDENT_NIGHT_PROGRESS seconds=",frame/60," asleep=",sleeping,"/7")
			if sleeping==7:break
	for person in added:
		print("NEW_RESIDENT_NIGHT ",person.person_name," posture=",person.posture," stage=",person.night_stage," pos=",person.position," next=",person.night_path[person.night_index] if person.night_index<person.night_path.size() else Vector3.ZERO)
		if person.person_name=="Selene":check(not person.night_schedule and person.position.distance_to(person.guard_post)<0.3,"Selene covers the bridge at night")
		else:check(person.posture=="sleeping",person.person_name+" reaches a bed at night")
	print("NEW_RESIDENTS_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
