extends Node

const NEEDS := ["hunger","energy","hygiene","comfort","fun","social"]
const SKILLS := ["Cooking","Farming","Carpentry","Smithing","Trading","Archery"]
const TRAITS := ["Sociable","Reserved","Patient","Industrious","Generous","Tidy","Playful","Cautious","Curious"]
var town: Node3D
var states: Dictionary={}
var people: Dictionary={}
var enabled := true
var bound := false
var testing := false
var elapsed := 0.0
var day := 1
var was_night := false
var tick_clock := 0.0
var save_clock := 0.0
var save_path := "user://character-life.json"
var save_writer=preload("res://background_json_save.gd").new()
var view: Node
var activity: Dictionary={}
var wash_owner: CharacterBody3D
var enabled_toggle: CheckBox
var home_visits: Dictionary={}

func _ready() -> void:
	town=get_parent()
	testing=town.economy.testing()
	if testing:save_path="user://review-character-life.json"
	view=load("res://life_panel.gd").new();add_child(view);view.build(self)
	enabled_toggle=CheckBox.new();enabled_toggle.text="Needs & moods";enabled_toggle.button_pressed=true
	enabled_toggle.toggled.connect(set_needs_enabled)
	town.menu_body.add_child(enabled_toggle)
	bind.call_deferred()

func defaults(name: String,role := "") -> Dictionary:
	var code := posmod(name.hash(),100000)
	var traits: Array=[TRAITS[code%TRAITS.size()],TRAITS[(code+3)%TRAITS.size()]]
	if name in ["Ollie","Theo"]:traits=["Playful","Curious"]
	if name=="Duncan":traits=["Sociable","Generous"]
	if name=="Ivor":traits=["Curious","Reserved"]
	if name=="Roslin":traits=["Generous","Patient"]
	if name=="Fenn":traits=["Patient","Cautious"]
	if name=="You":traits=["Curious","Sociable"]
	var skills: Dictionary={}
	for skill in SKILLS:skills[skill]=0.0
	var main := "Carpentry" if role in ["Carpenter","Young apprentice"] else "Smithing" if role=="Blacksmith" else "Farming" if role in ["Farmer","Herbalist"] else "Cooking" if role in ["Baker","Innkeeper","Brewer"] else "Trading" if role in ["Merchant","Supply courier","Forester"] else "Archery" if role=="Range keeper" else ""
	if not main.is_empty() and name!="You" and name!="Theo":skills[main]=float(pow(3+code%3,2)*12)
	return {"traits":traits,"needs":{"hunger":85.0,"energy":85.0+code%15,"hygiene":95.0,"comfort":80.0,"fun":75.0,"social":65.0},"skills":skills,"mood":"Content","feeling":"","feeling_until":0.0,"conversation_day":0,"next_action":0.0,"romance_day":0}

func bind() -> void:
	while not town.life.navigation_ready:await get_tree().process_frame
	states["You"]=defaults("You")
	for person in town.life.people:
		people[person.person_name]=person
		states[person.person_name]=defaults(person.person_name,person.occupation)
		person.set_meta("base_sociability",person.sociability)
	if not testing and FileAccess.file_exists(save_path):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if saved is Dictionary:
			enabled=bool(saved.get("enabled",true));enabled_toggle.set_pressed_no_signal(enabled)
			day=maxi(1,int(saved.get("day",1)));elapsed=maxf(0,float(saved.get("elapsed",0)))
			for name in saved.get("states",{}):
				if not states.has(name):continue
				var record: Dictionary=saved.states[name]
				for key in ["traits","needs","skills","conversation_day","romance_day"]:
					if record.has(key):states[name][key]=record[key]
				if people.has(name):people[name].friendships=record.get("friendships",{})
	bound=true
	view.refresh_people()
	print("CHARACTER_LIFE_READY residents=",people.size()," needs=6 skills=6 personalities=true shared_relationship_store=true")

func save_state(background:=false) -> void:
	var trace:=preload("res://frame_costs.gd").begin()
	save_state_traced(background)
	preload("res://frame_costs.gd").finish("character_life.save_state",trace,"")

func save_state_traced(background:=false) -> void:
	if testing or not bound:return
	for name in people:states[name]["friendships"]=people[name].friendships
	save_writer.save(save_path,{"version":1,"enabled":enabled,"day":day,"elapsed":elapsed,"states":states},background)

func state(name: String) -> Dictionary:
	if not states.has(name):states[name]=defaults(name)
	return states[name]

func need(name: String,id: String) -> float:
	return clampf(float(state(name).needs.get(id,100)),0,100)

func change_need(name: String,id: String,amount: float) -> void:
	state(name).needs[id]=clampf(need(name,id)+amount,0,100)

func skill_level(name: String,skill: String) -> int:
	return mini(10,floori(sqrt(maxf(0,float(state(name).skills.get(skill,0)))/12.0)))

func gain_skill(name: String,skill: String,amount: float) -> void:
	if skill not in SKILLS or amount<=0:return
	state(name).skills[skill]=minf(1200,float(state(name).skills.get(skill,0))+amount)

func work_duration(person: Node,skill: String) -> float:
	var temperament := .94 if "Industrious" in state(person.person_name).traits else 1.0
	return clampf(temperament*(1.20 if enabled and need(person.person_name,"energy")<25 else 1.0)/(1+.06*skill_level(person.person_name,skill)),.62,1.25)

func walking_pace(person: Node) -> float:
	var pace := .92 if "Cautious" in state(person.person_name).traits else 1.0
	if enabled and need(person.person_name,"energy")<25:pace*=.85
	return pace

func set_needs_enabled(value: bool) -> void:
	enabled=value
	if not value:
		for person in people.values():
			person.remove_meta("mood_label")
			if person.get_meta("need_nap",false):
				person.set_meta("need_nap",false)
				if person.posture=="sleeping" and not town.day_night.night:person.leave_home()
	save_state()

func worked(person: Node,kind: String) -> void:
	var skill: String={"crafted":"Carpentry","delivery":"Farming","supply":"Trading","cook":"Cooking","lesson":"Archery"}.get(kind,"")
	if skill.is_empty():return
	gain_skill(person.person_name,skill,6)
	feel(person.person_name,"Proud",20)

func feel(name: String,mood: String,seconds: float) -> void:
	state(name).feeling=mood;state(name).feeling_until=elapsed+seconds

func mood(name: String) -> String:
	if not enabled:return "Content"
	if need(name,"energy")<22:return "Exhausted"
	if need(name,"hunger")<25:return "Hungry"
	if need(name,"hygiene")<25 or need(name,"comfort")<20:return "Uncomfortable"
	if need(name,"social")<25:return "Lonely"
	if need(name,"fun")<25:return "Bored"
	var data := state(name)
	if float(data.feeling_until)>elapsed and not String(data.feeling).is_empty():return data.feeling
	if need(name,"energy")>80 and need(name,"fun")>80 and need(name,"social")>75:return "Cheerful"
	return "Content"

func _process(delta: float) -> void:
	var trace:=preload("res://frame_costs.gd").begin()
	_process_traced(delta)
	preload("res://frame_costs.gd").finish("character_life._process",trace,"")

func _process_traced(delta: float) -> void:
	if not bound:return
	elapsed+=delta
	if town.day_night.night!=was_night:
		if was_night:day+=1
		was_night=town.day_night.night
	update_activity(delta)
	tick_visits(delta)
	tick_clock+=delta;save_clock+=delta
	if tick_clock>=1:
		var step := tick_clock;tick_clock=0
		if enabled:
			update_player(step)
			for name in people:update_person(people[name],step)
		if view.visible():view.refresh()
	if save_clock>=15:save_clock=0;save_state(true)

func update_player(step: float) -> void:
	var resting: String=town.player.resting
	change_need("You","hunger",-.14*step)
	change_need("You","energy",(2.8 if resting=="sleeping" else .6 if resting=="sitting" else -.22 if town.player.velocity.length()>4 else -.14)*step)
	change_need("You","hygiene",-.05*step)
	change_need("You","comfort",(.4 if not resting.is_empty() else -.025)*step)
	change_need("You","social",(.9 if town.life.active else -.045)*step)
	change_need("You","fun",(.25 if town.life.active or town.player.velocity.length()>1 else -.04)*step)
	state("You").mood=mood("You")

func update_person(person: CharacterBody3D,step: float) -> void:
	var name: String=person.person_name
	var sleeping: bool=person.posture=="sleeping"
	var seated: bool=person.posture=="sitting"
	var social: bool=person.talking or person.social_partner!=null
	state(name).needs.hunger=clampf(100-person.hunger*50,0,100)
	change_need(name,"energy",(2.8 if sleeping else .65 if seated else -.18)*step)
	change_need(name,"hygiene",(.12 if sleeping else -.07 if person.occupation=="Farmer" else -.045)*step)
	change_need(name,"comfort",(.5 if sleeping or seated else .06 if person.indoor_house else -.02)*step)
	change_need(name,"social",(1.0 if social else -.04)*step)
	change_need(name,"fun",(.5 if social else .2 if person.is_child and person.travelled>1 else -.05)*step)
	state(name).mood=mood(name)
	person.set_meta("mood_label",state(name).mood)
	var sociability: float=float(person.get_meta("base_sociability",.5))
	if "Sociable" in state(name).traits:sociability*=1.25
	if "Reserved" in state(name).traits:sociability*=.75
	if need(name,"social")<40:sociability+=.15
	person.sociability=clampf(sociability,.1,.95)
	if sleeping:
		if person.get_meta("need_nap",false) and need(name,"energy")>85 and not town.day_night.night:
			person.set_meta("need_nap",false);person.leave_home()
		return
	if elapsed<float(state(name).next_action) or not town.routines.available(person):return
	if person.is_child or not person.guard_label.is_empty() or not person.stall_name.is_empty():return
	if person.indoor_house:
		if person.occupation in ["Baker","Innkeeper","Brewer"] and person.food>=2 and person.food<4 and person.hunger<.8:
			person.food-=2;person.food+=3;gain_skill(name,"Cooking",3);feel(name,"Proud",20)
			person.activity="Preparing food for the household";state(name).next_action=elapsed+90
		elif person.occupation=="Blacksmith":gain_skill(name,"Smithing",2);state(name).next_action=elapsed+60
		return
	if not person.job.is_empty() and person.job.get("stage") not in ["start","break"]:return
	state(name).next_action=elapsed+8
	if need(name,"hygiene")<28 and start_washing(person):return
	if need(name,"energy")<15:
		person.set_meta("need_nap",true);town.life.assign_home(person);state(name).next_action=elapsed+50
	elif need(name,"energy")<35 or need(name,"comfort")<30:
		if town.routines.begin_break(person):state(name).next_action=elapsed+30

func start_washing(person: CharacterBody3D) -> bool:
	if is_instance_valid(wash_owner) and wash_owner.routine.get("kind","")=="life_wash":return false
	var goal := Vector3(2.6,.01,-.2)
	if person.position.distance_to(goal)>60:return false
	var path: PackedVector3Array=town.life.route_to_point(person,goal)
	if path.is_empty():return false
	wash_owner=person;person.path=path;person.path_index=0
	person.routine={"kind":"life_wash","timer":4.0,"timeout":55.0}
	person.activity="Going to wash at the well"
	state(person.person_name).next_action=elapsed+60
	return true

func tick_routine(person: CharacterBody3D,delta: float) -> bool:
	if person.routine.get("kind","")=="home_invitation":
		person.follow_path(delta,1.5)
		return true
	if person.routine.get("kind","")!="life_wash":return false
	if not person.follow_path(delta,1.4):return true
	person.rest(delta);person.animate("Interact");person.activity="Washing at the well"
	person.routine.timer-=delta
	if person.routine.timer<=0:
		change_need(person.person_name,"hygiene",100);change_need(person.person_name,"comfort",12)
		feel(person.person_name,"Refreshed",25);person.routine={};wash_owner=null;person.plan()
	return true

func ate(person: Node=null) -> void:
	var name: String=person.person_name if person else "You"
	if person:state(name).needs.hunger=100
	else:change_need(name,"hunger",32)
	change_need(name,"comfort",5)

func shared_meal(a: Node,b: Node) -> void:
	for person in [a,b]:change_need(person.person_name,"social",15);change_need(person.person_name,"fun",10);feel(person.person_name,"Happy",30)
	town.routines.befriend(a,b)

func conversed(person: Node) -> void:
	var name: String=person.person_name
	change_need("You","social",15);change_need(name,"social",15)
	if int(state(name).conversation_day)==day:return
	state(name).conversation_day=day
	town.adventures.remember(name,"life_conversation_"+str(day),"We spent time talking together.",1)

func relationship_status(name: String) -> String:
	var data: Dictionary=town.adventures.relationship(name)
	if int(data.get("romance",0))>=8:return "Mutual romantic interest"
	var trust: int=int(data.trust)
	return "Close friend" if trust>=16 else "Friend" if trust>=8 else "Getting acquainted" if trust>0 else "Strained" if trust<0 else "New acquaintance"

func reputation() -> int:
	var score := 0
	for data in town.adventures.relationships.values():score+=int(data.get("trust",0))
	return clampi(roundi(score/5.0),-50,50)

func context(person: Node) -> Dictionary:
	var name: String=person.person_name
	var skills: Dictionary={}
	for skill in SKILLS:
		if skill_level(name,skill)>0:skills[skill]=skill_level(name,skill)
	return {"personality_traits":state(name).traits,"current_mood":mood(name),"own_needs":state(name).needs,"skills_out_of_10":skills,"relationship_with_visitor":relationship_status(name),"instruction":"Let personality and current feelings affect your tone naturally. Do not recite meters or statistics unless asked. Only physical game actions can give items, change money, finish a lesson or prepare food."}

func give_food(name: String) -> bool:
	if not people.has(name) or town.player.position.distance_to(people[name].position)>4:return false
	var person: Node=people[name]
	var gift: String=town.cooking.take_gift()
	if gift.is_empty():return false
	person.food+=1
	var data: Dictionary=town.adventures.relationship(name)
	data["gifts"]=int(data.get("gifts",0))+1
	town.adventures.remember(name,"meal_gift_"+str(data.gifts),"The visitor gave me a portion of "+gift.to_lower()+".",3)
	change_need(name,"social",8);feel(name,"Grateful",35)
	return true

func committed(person: Node) -> bool:
	var family: Dictionary=town.families.context(person.person_name)
	var role: String=String(family.get("your_family_role","")).to_lower()
	if "partner" in role:return true
	if role=="parent":
		var parents := 0
		for value in family.get("family_members",{}).values():
			if String(value).to_lower().begins_with("parent"):parents+=1
		return parents>=2
	return false

func romantic_interest(name: String) -> String:
	if not people.has(name):return "Choose a resident."
	var person: Node=people[name]
	if person.is_child or town.player.skin_id in ["runner_child","runner_youth"]:return "Friendship is available for this character."
	if town.player.position.distance_to(person.position)>4:return "Stand near them to speak in person."
	if committed(person):return person.person_name+" is already in a committed relationship."
	var data: Dictionary=town.adventures.relationship(name)
	if int(state(name).romance_day)==day:return "Give them time before asking again."
	state(name).romance_day=day
	if int(data.trust)<10:return "They would like to know you better first."
	if "Reserved" in state(name).traits and int(data.trust)<16:return "They enjoy your company but are not ready for romance."
	data["romance"]=mini(20,int(data.get("romance",0))+8)
	town.adventures.remember(name,"romantic_interest_"+str(day),"We expressed mutual romantic interest.",1)
	feel(name,"Happy",40);town.adventures.save_state()
	return "The interest is mutual. Keep spending time together."

func argue(name: String) -> bool:
	if not people.has(name) or town.player.position.distance_to(people[name].position)>4:return false
	var person: Node=people[name]
	var data: Dictionary=town.adventures.relationship(name)
	data["arguments"]=int(data.get("arguments",0))+1
	town.adventures.remember(name,"argument_"+str(data.arguments),"The visitor chose to argue with me.",-4)
	feel(name,"Upset",45);person.social_cooldown=maxf(person.social_cooldown,15)
	if town.events:town.events.publish("player_argument_"+name+"_"+str(data.arguments),"The visitor argued with "+name+".",[name],person.position)
	return true

func apologize(name: String) -> bool:
	if not people.has(name) or town.player.position.distance_to(people[name].position)>4:return false
	var data: Dictionary=town.adventures.relationship(name)
	if int(data.trust)>=0 or int(data.get("apology_day",0))==day:return false
	data["apology_day"]=day
	town.adventures.remember(name,"apology_"+str(day),"The visitor apologized for our disagreement.",2)
	feel(name,"Thoughtful",20)
	return true

func invite_home(name: String) -> bool:
	if not people.has(name) or not is_instance_valid(town.player_home.house):return false
	var person: CharacterBody3D=people[name]
	if person.is_child or person.posture!="standing" or person.night_schedule or person.talking or not person.guard_label.is_empty() or not person.carry_kind.is_empty():return false
	if int(town.adventures.relationship(name).trust)<8 or town.day_night.night:return false
	var house: Node3D=town.player_home.house
	var district: Node=town.get("home_district")
	if district and district.has_method("enter_visitor"):
		if person.indoor_house or home_visits.has(person):return false
		var route: PackedVector3Array=town.life.route_to_point(person,district.porch)
		if route.is_empty():return false
		if not person.routine.is_empty():town.routines.cancel(person)
		if person.meeting_partner:town.life.cancel_meeting(person)
		if person.social_partner:person.end_social()
		person.path=route;person.path_index=0
		person.routine={"kind":"home_invitation","timeout":240.0}
		home_visits[person]={"stage":"walking","time":0.0,"district":district,"route":person.route.duplicate(),"indoor_points":person.indoor_points.duplicate(),"destination":person.destination}
		person.activity="Walking to your home for a visit"
		return true
	var seat: Node3D=null;var door: Node3D=null
	for candidate in get_tree().get_nodes_in_group("seats"):
		if house.is_ancestor_of(candidate) and not candidate.has_meta("occupant"):seat=candidate;break
	for candidate in get_tree().get_nodes_in_group("doors"):
		if house.is_ancestor_of(candidate):door=candidate;break
	if not seat or not door:return false
	var path: PackedVector3Array=town.life.route_to_door(person,door)
	if path.is_empty():return false
	if not person.routine.is_empty():town.routines.cancel(person)
	seat.set_meta("occupant",name)
	person.head_home(door,path);person.day_visit=true;person.visit_seat=seat
	person.set_meta("home_guest",true);person.set_meta("visit_room",house);person.set_meta("visit_label","your home")
	person.activity="Coming to visit your home"
	return true

func tick_visits(delta: float) -> void:
	for person in home_visits.keys():
		if not is_instance_valid(person):home_visits.erase(person);continue
		var visit: Dictionary=home_visits[person]
		visit.time+=delta
		if person.night_schedule or visit.time>240 or (visit.stage=="inside" and visit.time>45 and not person.talking):
			if visit.stage=="inside":
				person.stand_up()
				person.route.assign(visit.route);person.indoor_points.assign(visit.indoor_points);person.destination=visit.destination
				visit.district.exit_visitor(person)
			elif person.routine.get("kind","")=="home_invitation":person.routine={};person.plan()
			home_visits.erase(person)
			continue
		if visit.stage=="walking" and person.position.distance_to(visit.district.porch)<3.5:
			if visit.district.enter_visitor(person):
				visit.stage="inside";visit.time=0
				person.routine={};person.wait_time=10
				person.indoor_points.assign([person.position,person.position+Vector3(-.5,0,0),person.position+Vector3(0,0,-.5)])
				person.route.assign(person.indoor_points);person.destination=0
				for seat in visit.district.seats:
					if seat.global_position.y>visit.district.room_origin.y+1 or seat.has_meta("occupant"):continue
					person.sit_at(seat);person.wait_time=18;break
				feel(person.person_name,"Welcome",40)

func begin_activity(kind: String,seconds: float,extra: Dictionary={}) -> bool:
	if not activity.is_empty() or not town.player.resting.is_empty():return false
	activity=extra.duplicate();activity["kind"]=kind;activity["timer"]=seconds;activity["total"]=seconds;activity["origin"]=town.player.position
	activity["previous_enabled"]=town.player.enabled
	town.player.enabled=false;town.player.velocity=Vector3.ZERO
	var clip := "WorkHarvest" if kind=="plant" else "WorkTable"
	if kind=="plant" and town.player.animator.has_animation("DigPlant"):clip="DigPlant"
	if kind=="cook" and town.player.animator.has_animation("RunnerWorking"):clip="RunnerWorking"
	if town.player.animator.has_animation(clip):town.player.animator.play(clip,.15)
	return true

func update_activity(delta: float) -> void:
	if activity.is_empty():return
	if town.player.position.distance_to(activity.origin)>1.5:cancel_activity();return
	activity.timer-=delta
	if activity.timer>0:return
	var done := activity.duplicate()
	activity={};town.player.enabled=done.previous_enabled
	if done.kind=="wash":change_need("You","hygiene",100);change_need("You","comfort",12);feel("You","Refreshed",30)
	elif done.kind=="cook":town.cooking.finish_recipe(done.recipe)
	elif done.kind=="plant":town.cooking.finish_planting()
	elif done.kind=="lesson":
		gain_skill("You",done.skill,10);change_need("You","fun",10)
		if people.has(done.teacher):people[done.teacher].talking=done.was_talking
		feel("You","Inspired",35)
	view.refresh()

func cancel_activity() -> void:
	if activity.is_empty():return
	town.player.enabled=activity.previous_enabled
	if activity.kind=="lesson" and people.has(activity.teacher):people[activity.teacher].talking=activity.was_talking
	activity={}

func lesson(name: String,skill: String) -> bool:
	if not people.has(name) or skill not in SKILLS or skill_level(name,skill)<3:return false
	var person: Node=people[name]
	if person.is_child or skill_level("You",skill)>=skill_level(name,skill) or int(town.adventures.relationship(name).trust)<5:return false
	if person.position.distance_to(town.player.position)>4 or person.posture!="standing" or person.night_schedule:return false
	if not person.guard_label.is_empty():return false
	if person.social_partner:person.end_social()
	if person.meeting_partner:town.life.cancel_meeting(person)
	if not person.routine.is_empty():town.routines.cancel(person)
	if not begin_activity("lesson",8,{"teacher":name,"skill":skill,"was_talking":person.talking}):return false
	person.talking=true;person.activity="Sharing a short "+skill.to_lower()+" lesson"
	return true

func _exit_tree() -> void:
	save_state()
	save_writer.shutdown()
