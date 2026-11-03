extends Node

var town: Node3D
var households: Array=[]
var membership: Dictionary={}
var groups: Dictionary={}
var bound:=false
var clock:=0.0

func _ready() -> void:
	town=get_parent()
	households=JSON.parse_string(FileAccess.get_file_as_string("res://households.json")).households

func bind() -> void:
	var houses: Array=[]
	for house in get_tree().get_nodes_in_group("enterable_houses"):
		if house.get_meta("player_owned",false) or house.get_meta("family_excluded",false):continue
		if town.life.house_capacity(house)>=2:houses.append(house)
	for family in households:
		family["residents"]=[]
		for person in town.life.people:
			if family.members.has(person.person_name):family.residents.append(person)
	var assignments:=match_homes(houses)
	for family in households:
		var members: Array=family.residents
		if members.is_empty():continue
		var best: Node3D=assignments.get(family.id)
		if not best:
			push_error("No family home for "+family.title)
			continue
		var beds: Array=[]
		for child in best.get_children():
			if child.is_in_group("beds"):beds.append(child)
		if beds.size()<members.size():
			# A family bunk preserves the existing clear floor route in small
			# houses, rather than narrowing the room with another floor bed.
			var lower: Marker3D=beds[0]
			var frame:=Node3D.new();best.add_child(frame)
			frame.transform=lower.transform
			frame.position+=lower.basis*Vector3(0,.55,.85)
			town.detailed_prop("Bed_Twin1",frame,Vector3.ZERO,Vector3(1.2,.35,2.05),true)
			for side in [-1.0,1.0]:
				for end in [-1.0,1.0]:town.box(frame,Vector3(.07,1.2,.07),Vector3(side*.58,-.3,end*.98),Color("624b34"),false)
			var bed:=Marker3D.new();bed.transform=lower.transform;bed.position.y+=1.15
			best.add_child(bed);bed.add_to_group("beds");beds.append(bed)
		for index in range(members.size()):
			var person: Node=members[index]
			membership[person.person_name]={"id":family.id,"title":family.title,"role":family.members[person.person_name],"members":family.members,"home":best,"bed":beds[index]}
			beds[index].set_meta("resident_owner",person.person_name)
			person.set_meta("household",family.id)
			person.home=String(best.get_meta("display_name",best.name))
		family["house"]=best
		family["residents"]=members
	bound=true
	print("HOUSEHOLDS_BOUND families=",households.size()," residents=",membership.size())

func match_homes(houses: Array) -> Dictionary:
	# Minimum-cost matching avoids assigning the final family a distant leftover
	# house. Indoor workers keep their workplace home; the castle family keeps
	# the requested castle. Each household receives a separate home.
	var count:=households.size();var available:=houses.size()
	if available<count:push_error("Not enough family houses");return {}
	var costs: Array=[]
	for family in households:
		var row: Array=[]
		for house in houses:
			var cost:=0.0
			for person in family.residents:
				cost+=person.position.distance_to(house.global_position)
				if person.indoor_house and person.indoor_house!=house:cost+=1000000
			if family.has("preferred_home"):
				if String(house.name).to_lower().replace(" ","").contains(String(family.preferred_home).to_lower().replace(" ","")):cost-=100000
				else:cost+=100000
			row.append(cost)
		costs.append(row)
	var u: Array=[];u.resize(count+1);u.fill(0.0)
	var v: Array=[];v.resize(available+1);v.fill(0.0)
	var p: Array=[];p.resize(available+1);p.fill(0)
	var way: Array=[];way.resize(available+1);way.fill(0)
	for index in range(1,count+1):
		p[0]=index
		var current:=0
		var minimum: Array=[];minimum.resize(available+1);minimum.fill(INF)
		var used: Array=[];used.resize(available+1);used.fill(false)
		while true:
			used[current]=true
			var i: int=p[current]
			var delta:=INF;var next:=0
			for j in range(1,available+1):
				if used[j]:continue
				var value: float=costs[i-1][j-1]-u[i]-v[j]
				if value<minimum[j]:minimum[j]=value;way[j]=current
				if minimum[j]<delta:delta=minimum[j];next=j
			for j in range(available+1):
				if used[j]:u[p[j]]+=delta;v[j]-=delta
				else:minimum[j]-=delta
			current=next
			if p[current]==0:break
		while true:
			var previous: int=way[current]
			p[current]=p[previous];current=previous
			if current==0:break
	var result: Dictionary={}
	for j in range(1,available+1):
		if p[j]>0:result[households[int(p[j])-1].id]=houses[j-1]
	return result

func context(name: String) -> Dictionary:
	if not membership.has(name):return {}
	var data: Dictionary=membership[name]
	return {"household":data.title,"your_family_role":data.role,"family_members":data.members,"shared_home":String(data.home.name),"evening_routine":"Meet family and walk home together; night-watch members work their assigned shift."}

func start_evening() -> void:
	groups.clear()
	if not bound:return
	for family in households:
		if not family.has("house"):continue
		var mobile: Array=[]
		var centre:=Vector3.ZERO
		for person in family.residents:
			if person.guard_shift=="night" or person.indoor_house or person.talking:continue
			if person.get_meta("industrial_worker",false) and person.position.z>66:continue
			mobile.append(person);centre+=person.position
		if mobile.size()<2:continue
		centre/=mobile.size()
		var cell: Vector2i=town.life.free_cell(centre)
		var meet:=Vector3(cell.x,float(town.life.floor_heights.get(cell,0))+.03,cell.y)
		groups[family.id]={"members":mobile,"meet":meet,"time":0.0,"departed":false}

func send_home(person: CharacterBody3D) -> bool:
	if not bound or not membership.has(person.person_name):return false
	var data: Dictionary=membership[person.person_name]
	if data.bed.has_meta("occupant") and data.bed.get_meta("occupant")!=person.person_name:return false
	var house: Node3D=data.home
	if house.get_meta("player_owned",false) or house.get_meta("family_excluded",false):return false
	for door in house.get_children():
		if not door.is_in_group("doors"):continue
		var route: PackedVector3Array=town.life.route_to_door(person,door)
		if route.is_empty():continue
		if groups.has(data.id) and not groups[data.id].departed:
			var group: Dictionary=groups[data.id]
			var first: PackedVector3Array=town.life.route_to_point(person,group.meet)
			var last: PackedVector3Array=town.life.find_route(group.meet,route[-1])
			if not first.is_empty() and not last.is_empty():
				route=first;route.append_array(last)
		if person.assigned_bed and person.assigned_bed!=data.bed:town.life.release_bed(person)
		data.bed.set_meta("occupant",person.person_name);person.assigned_bed=data.bed
		person.head_home(door,route)
		person.night_delay=0
		return true
	return false

func _process(delta: float) -> void:
	if not bound or not town.day_night.night:return
	clock+=delta
	if clock<.15:return
	var step:=clock;clock=0
	for group in groups.values():
		group.time+=step
		var assembled:=true
		for person in group.members:
			if person.position.distance_to(group.meet)>3.5:assembled=false
		if not group.departed:
			if assembled or group.time>18:group.departed=true
			else:
				for person in group.members:
					if person.position.distance_to(group.meet)<2.5 and person.night_stage=="approach":
						person.night_delay=.25;person.activity="Waiting to walk home with family"
		else:
			# Companions on the shared trunk wait briefly for slower relatives.
			for person in group.members:
				if person.night_stage!="approach" or group.time>45:continue
				var remaining: float=person.position.distance_to(person.home_door.global_position)
				for relative in group.members:
					if relative==person or relative.night_stage!="approach":continue
					if relative.position.distance_to(relative.home_door.global_position)>remaining+4:
						person.night_delay=.25;person.activity="Walking home with family";break
