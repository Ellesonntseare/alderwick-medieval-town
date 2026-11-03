extends Node

var town: Node3D
var clock := 0.0
var elapsed := 0.0
var lines: Dictionary={}
var meals := 0
var tavern_visits := 0
var breaks_taken := 0
var friendships_made := 0
var paused := false

func _ready() -> void:
	town=get_parent()
	# Open-air resting places are built before the street grid is sampled.
	for point: Vector3 in [Vector3(14,0,19),Vector3(17,0,19),Vector3(-18,0,4),Vector3(-20,0,4),Vector3(-89,0,101),Vector3(-89,0,104),Vector3(124,0,111),Vector3(127,0,111)]:
		town.interior_stool(town.jobs,point)
		var seat: Node3D=town.jobs.get_child(town.jobs.get_child_count()-1)
		seat.add_to_group("public_seats")

func bind() -> void:
	for person in town.life.people:
		person.set_meta("next_break",18.0+posmod(person.person_name.hash(),55))
		person.set_meta("next_tavern",35.0+posmod(person.person_name.hash(),90))

func _process(delta: float) -> void:
	if paused or not town.life.navigation_ready:return
	elapsed+=delta
	clock+=delta
	if clock<0.8:return
	var step := clock
	clock=0
	for person in town.life.people:
		if person.posture=="sleeping":continue
		person.hunger=minf(2,person.hunger+step/45.0)
		if town.day_night.night or not available(person):continue
		if not person.guard_label.is_empty():
			if person.hunger>=1 and person.food>0:
				person.routine={"kind":"eat","timer":4.0,"at_post":true}
				person.activity="Eating a packed meal at the watch"
			continue
		if not person.stall_name.is_empty():
			if person.hunger>=1.2 and town.economy.buy_food(person,person):
				town.economy.eat(person)
				meals+=1
			continue
		if person.indoor_house:
			if person.hunger>1:
				person.food+=1
				town.economy.eat(person)
				person.activity="Taking a meal break indoors"
				person.wait_time=person.decision_rng.randf_range(5,9)
			continue
		if person.carry_kind!="":continue
		if not person.job.is_empty() and person.job.get("stage") not in ["start","break"]:continue
		if person.hunger>=0.9:
			if person.food>0 and begin_break(person,true):continue
			if begin_shopping(person):continue
		if elapsed>float(person.get_meta("next_tavern",1000)) and person.get_meta("district")=="city":
			if begin_tavern(person):continue
		if elapsed>float(person.get_meta("next_break",1000)):begin_break(person)

func available(person: CharacterBody3D) -> bool:
	return person.routine.is_empty() and not person.talking and not person.social_partner and not person.meeting_partner and not person.night_schedule and person.posture=="standing" and person.getting_up<=0

func shopping_point(seller: CharacterBody3D,rank: int) -> Vector3:
	var forward := Vector3(sin(seller.stall_facing),0,cos(seller.stall_facing))
	return seller.stall_anchor+forward*(2.5+rank*1.15)

func begin_shopping(person: CharacterBody3D) -> bool:
	var district: String=person.get_meta("district")
	var choice := posmod(person.person_name.hash()+int(person.get_meta("shopping_turn",0)),4)
	var seller: CharacterBody3D=town.economy.seller_for(district,choice)
	if not seller or not town.economy.open_for_trade(seller) or person.coins<2 or town.economy.market_for(seller).stock<1:return false
	if not lines.has(seller):lines[seller]=[]
	var line: Array=lines[seller]
	if line.size()>=3:return false
	for other in line:
		if other.style==person.style:return false
	var goal := shopping_point(seller,line.size())
	var route: PackedVector3Array=town.life.route_to_point(person,goal)
	if route.is_empty():return false
	line.append(person)
	person.routine={"kind":"shopping","seller":seller,"stage":"walking","timer":0.0,"timeout":45.0,"rank":line.size()-1}
	person.path=route
	person.path_index=0
	person.activity="Going to buy vegetables"
	person.set_meta("shopping_turn",int(person.get_meta("shopping_turn",0))+1)
	return true

func reserve_seat(person: CharacterBody3D) -> Node3D:
	var best: Node3D=null
	var distance := 45.0
	for seat: Node3D in get_tree().get_nodes_in_group("public_seats"):
		if seat.has_meta("occupant"):continue
		var same := false
		for neighbour in town.life.people:
			if neighbour!=person and neighbour.style==person.style and neighbour.position.distance_to(seat.global_position)<7:same=true;break
		if same:continue
		var gap: float=person.position.distance_to(seat.global_position)
		if gap<distance:
			best=seat
			distance=gap
	if best:best.set_meta("occupant",person.person_name)
	return best

func begin_break(person: CharacterBody3D,eating := false) -> bool:
	var seat := reserve_seat(person)
	if not seat:
		if eating:
			person.routine={"kind":"eat","timer":4.0}
			person.activity="Eating fresh vegetables"
			return true
		person.set_meta("next_break",elapsed+10)
		return false
	var target: Vector3=seat.global_position+seat.global_basis*Vector3(0,-0.48,-0.8)
	var route: PackedVector3Array=town.life.route_to_point(person,target)
	if route.is_empty():
		seat.remove_meta("occupant")
		person.set_meta("next_break",elapsed+10)
		return false
	person.routine={"kind":"rest_walk","seat":seat,"eating":eating,"timer":0.0,"timeout":35.0}
	person.path=route
	person.path_index=0
	person.activity="Taking lunch to a seat" if eating else "Walking to a quiet resting place"
	return true

func begin_tavern(person: CharacterBody3D) -> bool:
	if person.is_child:return false
	var visiting := 0
	for other in town.life.people:
		if other.day_visit:
			visiting+=1
			if other.style==person.style:return false
	if visiting>=2 or person.coins<3:return false
	var house: Node3D=null
	for candidate: Node3D in get_tree().get_nodes_in_group("enterable_houses"):
		if candidate.name=="The Copper Stag":house=candidate;break
	if not house:return false
	var seat: Node3D=null
	for child: Node in house.get_children():
		if child.is_in_group("seats") and not child.has_meta("occupant"):seat=child;break
	if not seat:return false
	var door: Node3D=null
	for child in house.get_children():
		if child.is_in_group("doors"):door=child;break
	if not door:return false
	var route: PackedVector3Array=town.life.route_to_door(person,door)
	if route.is_empty() or person.position.distance_to(door.global_position)>45:return false
	seat.set_meta("occupant",person.person_name)
	person.head_home(door,route)
	person.day_visit=true
	person.visit_seat=seat
	person.activity="Visiting the Copper Stag for supper"
	person.set_meta("next_tavern",elapsed+90+posmod(person.person_name.hash(),45))
	return true

func arrive_tavern(person: CharacterBody3D) -> void:
	var seat: Node3D=person.visit_seat
	if not is_instance_valid(seat):person.finish_day_visit();return
	var target: Vector3=seat.global_position+seat.global_basis*Vector3(0,-0.48,-0.7)
	person.night_stage="visit_walk"
	person.night_path=town.life.indoor_route(person,seat.get_parent(),person.position,target)
	person.night_index=0
	person.activity="Finding a seat at the Copper Stag"

func seat_tavern(person: CharacterBody3D) -> void:
	if person.get_meta("home_guest",false):
		person.sit_at(person.visit_seat)
		person.wait_time=person.decision_rng.randf_range(12,18)
		person.activity="Visiting your home"
		person.set_meta("home_guest",false)
		if town.character_life:town.character_life.feel(person.person_name,"Welcome",40)
		return
	if person.coins<3:person.finish_day_visit();return
	var innkeeper: CharacterBody3D=null
	for other in town.life.people:
		if other.person_name=="Rowan":innkeeper=other;break
	if innkeeper:
		person.coins-=3
		innkeeper.coins+=3
		town.economy.record("tavern",person.person_name,innkeeper.person_name,3)
	person.hunger=0
	if town.character_life:town.character_life.ate(person)
	person.sit_at(person.visit_seat)
	person.wait_time=person.decision_rng.randf_range(7,12)
	person.activity="Having supper at the Copper Stag"
	tavern_visits+=1
	town.jobs.record(person,"tavern","I stopped at the Copper Stag for supper and a rest.")

func tick(person: CharacterBody3D,delta: float) -> bool:
	if person.routine.is_empty():return false
	var routine: Dictionary=person.routine
	if routine.has("timeout"):
		routine.timeout-=delta
		if routine.timeout<0:cancel(person);person.plan();return false
	if town.events and town.events.tick_routine(person,delta):return true
	if town.character_life and town.character_life.tick_routine(person,delta):return true
	if routine.kind=="shopping":
		var seller: CharacterBody3D=routine.seller
		if not town.economy.open_for_trade(seller):cancel(person);person.plan();return false
		var line: Array=lines.get(seller,[])
		var rank: int=line.find(person)
		if rank<0:cancel(person);return false
		if rank!=int(routine.rank):
			routine.rank=rank
			person.path=town.life.route_to_point(person,shopping_point(seller,rank))
			person.path_index=0
		if not person.follow_path(delta,1.45):return true
		person.visual.rotation.y=atan2(seller.position.x-person.position.x,seller.position.z-person.position.z)
		person.animate("Interact" if rank==0 else "Idle")
		person.activity="Buying vegetables · 2 coins" if rank==0 else "Waiting at the market"
		if rank>0:return true
		routine.timer+=delta
		if routine.timer<2:return true
		var bought: bool=town.economy.buy_food(seller,person)
		line.erase(person)
		person.routine={}
		if bought:
			town.jobs.record(person,"purchase","I bought fresh vegetables from "+seller.person_name+" for two coins.")
			if not begin_break(person,true):person.routine={"kind":"eat","timer":4.0}
		else:person.plan()
		return true
	if routine.kind=="rest_walk":
		if not person.follow_path(delta,1.4):return true
		var eating: bool=routine.eating
		person.sit_at(routine.seat)
		person.wait_time=person.decision_rng.randf_range(5,9)
		person.routine={"kind":"seated","eating":eating}
		person.activity="Eating a fresh meal" if eating else "Taking a quiet break"
		breaks_taken+=1
		return true
	if routine.kind=="eat":
		person.rest(delta)
		person.animate("Idle" if routine.get("at_post",false) else "Interact")
		routine.timer-=delta
		if routine.timer<=0:
			if town.economy.eat(person):meals+=1
			finish(person)
		return true
	return false

func finish(person: CharacterBody3D) -> void:
	if person.routine.get("eating",false):
		if town.economy.eat(person):meals+=1
	person.routine={}
	person.set_meta("next_break",elapsed+45+posmod(person.person_name.hash(),40))
	person.plan()

func cancel(person: CharacterBody3D) -> void:
	for line in lines.values():line.erase(person)
	var seat: Node3D=person.routine.get("seat")
	if seat and seat.get_meta("occupant","")==person.person_name:seat.remove_meta("occupant")
	person.routine={}
	person.stand_up()

func befriend(a: CharacterBody3D,b: CharacterBody3D) -> void:
	if not a.friendships.has(b.person_name):friendships_made+=1
	a.friendships[b.person_name]=mini(20,int(a.friendships.get(b.person_name,0))+1)
	b.friendships[a.person_name]=mini(20,int(b.friendships.get(a.person_name,0))+1)
