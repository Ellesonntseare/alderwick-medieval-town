extends SceneTree

var town: Node3D
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
	else:print("FEATURE_PASS ",message)
func person(name: String) -> CharacterBody3D:
	for resident in town.life.people:
		if resident.person_name==name:return resident
	return null
func run() -> void:
	Engine.max_fps=60
	town=load("res://town.tscn").instantiate();root.add_child(town)
	while not town.life.navigation_ready or town.discoveries.sites.size()<3:await physics_frame
	town.speech.set_enabled(false);town.day_night.set_enabled(false)
	town.events.set_process(false);town.routines.set_process(false);town.life.set_process(false)
	for resident in town.life.people:resident.set_physics_process(false)
	for animal in get_nodes_in_group("animals"):animal.set_physics_process(false)
	check(town.life.people.size()==53,"All 53 residents remain present")
	var events: Node=town.events;events.records.clear();events.knowledge.clear()
	var ada:=person("Ada");var corvin:=person("Corvin");var greta:=person("Greta")
	events.publish("test_fact","A labelled crate was returned.",["Ada"],Vector3(5000,0,5000))
	check(events.knowledge.has("Ada") and not events.knowledge.has("Greta"),"An unwitnessed event is not known by the whole town")
	events.share(ada,corvin)
	check(events.knowledge.Corvin.test_fact.contains("Ada"),"News retains the person who passed it on")
	events.publish("test_fact","Wrong replacement",[],Vector3.ZERO)
	check(events.records.test_fact.text=="A labelled crate was returned.","Events are idempotent")
	check(events.context(greta).known_town_events.is_empty(),"A distant resident cannot claim this news")
	events.save_state()
	var saved=JSON.parse_string(FileAccess.get_file_as_string(events.save_path))
	check(saved.knowledge.Corvin.has("test_fact"),"Event knowledge is saved")
	# Inspect an actual clue nearby, then verify distance checks and story progress.
	var discovery: Node=town.discoveries;discovery.found.clear()
	var site: Dictionary=discovery.sites[0]
	town.adventures.progress.missing_delivery={"status":"active","step":0}
	town.player.position=Vector3(5000,0,5000)
	check(not discovery.discover(site),"Clues cannot be collected remotely")
	town.player.position=site.point+Vector3(0,.1,.8)
	check(discovery.discover(site),"An actual nearby delivery slip can be examined")
	check(town.adventures.progress.missing_delivery.step==1,"A real clue reveals the next investigation step")
	check(discovery.context(corvin).size()==1 and discovery.context(greta).is_empty(),"Only relevant residents receive clue context")
	check(town.adventures.progress.missing_delivery.status=="active","Reading evidence does not complete its mission")
	# Test a genuine roof, and clear weather restoration with the cycle disabled.
	var weather: Node3D=town.weather
	weather.set_weather("Rain");weather._process(.5)
	check(weather.current=="Rain" and town.day_night.sun.light_energy<=.22,"Rain changes the lighting")
	weather.set_weather("Clear");weather._process(.5)
	check(town.day_night.sun.light_energy>.6,"Clear weather restores daylight with the clock disabled")
	var sheep: Node=null
	for animal in get_nodes_in_group("animals"):
		if animal.species=="Sheep":sheep=animal;break
	check(sheep!=null and sheep.weather_shelter and weather.covered(sheep.home),"Farm sheep have a real roof over their rain shelter")
	weather.set_weather("Rain");sheep.choose_target()
	check(sheep.target.distance_to(sheep.home)<1.5,"Rain sends farm animals back to their shelter")
	weather.set_weather("Clear")
	# Prepare two actual relatives on reachable, unobstructed positions.
	var family: Dictionary=town.families.households[0]
	var a: CharacterBody3D=family.residents[0];var b: CharacterBody3D=family.residents[1]
	var original_a: Vector3=a.position;var original_b: Vector3=b.position
	for member in [a,b]:
		member.routine={};member.social_partner=null;member.meeting_partner=null;member.night_schedule=false;member.social_cooldown=0;member.posture="standing";member.job={};member.carry_kind="";member.guard_label="";member.stall_name="";member.indoor_house=null;member.getting_up=0
	a.position=Vector3(0,.02,20);b.position=Vector3(1.6,.02,20)
	await physics_frame
	check(events.family_activity(family),"A pair of relatives can start a shared family break")
	check(a.social_partner==b and b.social_partner==a,"The family break has two actual participants")
	if a.social_partner:a.end_social()
	a.position=original_a;b.position=original_b
	# The player home must remain unassigned until a suitable house is supplied.
	check(town.player_home.house==null,"No substitute house is assigned to the player")
	check(not town.player_home.register_house(family.house),"A resident family's home cannot be taken")
	var own:=Node3D.new();town.add_child(own);own.add_to_group("enterable_houses");own.position=Vector3(500,0,500)
	check(town.player_home.register_house(own),"An unoccupied reviewed house can be registered")
	town.player.position=own.position
	town.adventures.inventory["Test keepsake"]=2
	check(town.player_home.transfer("Test keepsake",1,true) and town.adventures.inventory["Test keepsake"]==1,"Home storage removes the deposited item from the carried inventory")
	check(town.player_home.transfer("Test keepsake",1,false) and town.adventures.inventory["Test keepsake"]==2,"Stored belongings can be withdrawn without duplication")
	check(not town.player_home.transfer("Test keepsake",3,true),"Storage cannot create items")
	print("LIVING_WORLD_FEATURES_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
