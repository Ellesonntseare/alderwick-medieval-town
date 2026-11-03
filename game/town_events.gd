extends Node

var town: Node3D
var records: Dictionary={}
var knowledge: Dictionary={}
var clock:=0.0
var elapsed:=0.0
var family_clock:=0.0
var family_turn:=0
var save_path:="user://town-events.json"

func _ready() -> void:
	town=get_parent()
	if town.economy.testing():save_path="user://review-town-events.json"
	if FileAccess.file_exists(save_path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if data is Dictionary:records=data.get("events",{});knowledge=data.get("knowledge",{})

func save_state() -> void:
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"events":records,"knowledge":knowledge}))

func publish(id: String,text: String,witnesses: Array,point: Vector3) -> void:
	if records.has(id):return
	records[id]={"id":id,"text":text,"position":[point.x,point.y,point.z]}
	for name in witnesses:learn(String(name),id,"I was directly involved.")
	if town.life.navigation_ready:
		for person in town.life.people:
			if person.position.distance_to(point)<9 and visible_between(person.position,point):learn(person.person_name,id,"I witnessed this nearby.")
	save_state()

func learn(name: String,id: String,source: String) -> bool:
	if not records.has(id):return false
	if not knowledge.has(name):knowledge[name]={}
	if knowledge[name].has(id):return false
	knowledge[name][id]=source
	return true

func visible_between(a: Vector3,b: Vector3) -> bool:
	return town.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a+Vector3.UP,b+Vector3.UP,1)).is_empty()

func share(a: Node,b: Node) -> void:
	for id in knowledge.get(a.person_name,{}):
		if learn(b.person_name,id,"Told to me by "+a.person_name):break

func context(person: Node) -> Dictionary:
	var known: Array=[]
	for id in knowledge.get(person.person_name,{}):
		if records.has(id):known.append({"fact":records[id].text,"source":knowledge[person.person_name][id]})
	var nearby: Array=[]
	for other in town.life.people:
		if other!=person and nearby.size()<4 and person.position.distance_to(other.position)<6 and visible_between(person.position,other.position):nearby.append({"name":other.person_name,"activity":other.activity})
	return {"known_town_events":known.slice(-8),"visible_neighbours":nearby,"weather":town.weather.current,"indoors":town.weather.covered(person.position),"instruction":"Use these facts naturally when relevant. Distinguish what you witnessed from what you were told. Do not recite your schedule or invent completed events."}

func eligible(person: Node) -> bool:
	return town.routines.available(person) and person.guard_label.is_empty() and person.stall_name.is_empty() and not person.indoor_house and person.carry_kind.is_empty() and (person.job.is_empty() or person.job.get("stage") in ["start","break"])

func family_memory(a: Node,b: Node) -> void:
	var meal: bool=a.food>0 and b.food>0 and (a.hunger>.4 or b.hunger>.4)
	if meal:town.economy.eat(a);town.economy.eat(b)
	if town.character_life:town.character_life.shared_meal(a,b)
	for member in [a,b]:
		var relative: Node=b if member==a else a
		member.recent_events.append({"kind":"family","text":("I shared a packed meal with " if meal else "I took a family break with ")+relative.person_name+"."})
		if member.recent_events.size()>12:member.recent_events.pop_front()

func family_activity(family: Dictionary) -> bool:
	var members: Array=family.residents
	for a in members:
		if not eligible(a):continue
		for b in members:
			if b==a or not eligible(b) or a.position.distance_to(b.position)>28:continue
			if a.position.distance_to(b.position)<2.3:
				if town.life.start_meetup(a,b,12):
					family_memory(a,b)
					return true
			else:
				var direction: Vector3=(a.position-b.position).normalized()
				var route: PackedVector3Array=town.life.route_to_point(a,b.position+direction*1.6)
				if route.is_empty():continue
				a.path=route;a.path_index=0
				a.routine={"kind":"family_visit","relative":b,"timeout":25.0,"timer":0.0}
				b.routine={"kind":"family_wait","relative":a,"timeout":25.0,"timer":0.0}
				a.activity="Going to spend a break with "+b.person_name
				b.activity="Waiting for "+a.person_name
				return true
	return false

func tick_routine(person: CharacterBody3D,delta: float) -> bool:
	var routine: Dictionary=person.routine
	if routine.get("kind","") not in ["family_visit","family_wait","rain_shelter"]:return false
	if town.day_night.night or (routine.kind!="rain_shelter" and town.weather.current=="Rain"):
		town.routines.cancel(person);person.plan();return false
	if routine.kind=="rain_shelter":
		if town.weather.current!="Rain":town.routines.cancel(person);person.plan();return false
		if person.follow_path(delta,1.5):person.rest(delta);person.animate("Idle");person.activity="Waiting under cover for the rain to ease"
		return true
	var relative: Node=routine.relative
	if not is_instance_valid(relative) or relative.talking or relative.night_schedule:
		town.routines.cancel(person);person.plan();return false
	if routine.kind=="family_wait":person.rest(delta);person.animate("Idle");return true
	if person.position.distance_to(relative.position)>1.9:
		if person.follow_path(delta,1.4):town.routines.cancel(person);person.plan()
		return true
	town.routines.cancel(person);town.routines.cancel(relative)
	if town.life.start_meetup(person,relative,12):
		family_memory(person,relative)
	return true

func _process(delta: float) -> void:
	if not town.life.navigation_ready:return
	clock+=delta;elapsed+=delta;family_clock+=delta
	if clock>=4:
		clock=0
		for district in town.jobs.markets:
			var market: Dictionary=town.jobs.markets[district]
			if int(market.stock)==0:
				for seller in town.life.people:
					if not seller.stall_name.is_empty() and town.economy.market_for(seller)==market:
						publish("stock_empty_"+String(district),seller.person_name+" ran out of vegetables at the "+String(district)+" market. Deliveries are needed to refill the stall.",[seller.person_name],seller.position);break
		for chat in town.life.chats.values():
			# News passes only in an actual, nearby, unobstructed conversation.
			if chat.index>=1 and chat.a.position.distance_to(chat.b.position)<2.5 and visible_between(chat.a.position,chat.b.position):share(chat.a,chat.b);share(chat.b,chat.a)
		save_state()
	if family_clock>18 and town.families.bound and not town.day_night.night and town.weather.current!="Rain":
		family_clock=0
		for attempt in range(town.families.households.size()):
			var family: Dictionary=town.families.households[family_turn%town.families.households.size()]
			family_turn+=1
			if family_activity(family):break
