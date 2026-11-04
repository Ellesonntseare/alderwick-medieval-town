extends Node

var town: Node3D
var grid := AStarGrid2D.new()
var people: Array[CharacterBody3D] = []
var navigation_ready := false
var floor_heights: Dictionary={}
var street_cells: Dictionary={}
var traffic: RefCounted
var walking_routes: RefCounted
var interior_grids: Dictionary={}
const NAV_REGION := Rect2i(-270,-150,491,351)
const RESIDENT_COUNT := 53
const NEW_STYLES := ["knight","mercenary","night_hunter","viking","emlyn"]
var nearest: CharacterBody3D
var nearest_door: Node3D
var nearest_furniture: Node3D
var talk_button: Button
var active: CharacterBody3D
var dialog: PanelContainer
var heading: Label
var transcript: RichTextLabel
var entry: TextEdit
var ai: Node
var hint: Label
var visits: Dictionary = {}
var previous_music := -34.0
var heartbeat := 0.0
var automated := false
var social_clock := 0.0
var social_rng := RandomNumberGenerator.new()
var social_events := 0
var social_limit := 5
var meeting_invitations := 0
var chats: Dictionary={}
var next_chat_id := 1
var trade_row: HBoxContainer
var trade_status: Label
const CELL := 1.0

func _ready() -> void:
	town = get_parent()
	traffic=preload("res://street_traffic.gd").new()
	traffic.life=self
	social_rng.randomize()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture") or argument.begins_with("--validate") or argument.begins_with("--review"):automated=true
	if automated:
		seed(5117)
		social_rng.seed=39328
	if not automated and FileAccess.file_exists("user://villager-visits.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("user://villager-visits.json"))
		if data is Dictionary: visits=data
	ai=Node.new()
	ai.set_script(load("res://town_dialogue.gd"))
	add_child(ai)
	make_interface()
	setup.call_deferred()

func setup() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	grid.region=NAV_REGION
	grid.cell_size=Vector2(CELL,CELL)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var shape := CapsuleShape3D.new()
	shape.radius=0.44
	shape.height=1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=1
	query.exclude=[town.player.get_rid()]
	var space := town.get_world_3d().direct_space_state
	for x in range(NAV_REGION.position.x,NAV_REGION.end.x):
		for z in range(NAV_REGION.position.y,NAV_REGION.end.y):
			var cell := Vector2i(x,z)
			var height := navigation_floor(Vector3(x,0,z),space)
			floor_heights[cell]=height
			query.transform=Transform3D(Basis.IDENTITY,Vector3(x,height+0.86,z))
			var blocked := height>2.0 or not space.intersect_shape(query,1).is_empty()
			if absf(x-64)<4 and abs(z)<74 and abs(z)>1.5 and abs(z-48)>1.5:blocked=true
			grid.set_point_solid(cell,blocked)
		if (x-NAV_REGION.position.x)%25==0:await get_tree().process_frame
	var blocked_edges: Array[Vector2i]=[]
	for x in range(NAV_REGION.position.x,NAV_REGION.end.x):
		for z in range(NAV_REGION.position.y,NAV_REGION.end.y):
			var cell := Vector2i(x,z)
			if grid.is_point_solid(cell):continue
			for offset in [Vector2i.RIGHT,Vector2i.DOWN]:
				var next: Vector2i=cell+offset
				if not grid.is_in_boundsv(next) or grid.is_point_solid(next):continue
				var height: float=(floor_heights[cell]+floor_heights[next])*0.5
				query.transform.origin=Vector3(x+offset.x*0.5,height+0.86,z+offset.y*0.5)
				if absf(floor_heights[cell]-floor_heights[next])>0.38 or not space.intersect_shape(query,1).is_empty():
					blocked_edges.append(cell)
					blocked_edges.append(next)
		if (x-NAV_REGION.position.x)%25==0:await get_tree().process_frame
	for cell in blocked_edges:grid.set_point_solid(cell,true)
	# Keep new residents and destinations on the public street network.
	# Tiny clear pockets behind scenery must not become spawn/route endpoints.
	var seed := free_cell(Vector3(0,0,10))
	var queue: Array[Vector2i]=[seed]
	street_cells[seed]=true
	var cursor := 0
	while cursor<queue.size():
		var cell: Vector2i=queue[cursor]
		cursor+=1
		for offset: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var next := cell+offset
			if not grid.is_in_boundsv(next) or grid.is_point_solid(next) or street_cells.has(next):continue
			street_cells[next]=true
			queue.append(next)
		if cursor%8000==0:await get_tree().process_frame
	print("NAVIGATION_STREETS_READY connected_cells=",street_cells.size())
	walking_routes=preload("res://walking_routes.gd").new()
	walking_routes.build(self)
	var residents := [
		["Mara","Baker","Willow House","worker",Vector3(20,0,10),Vector3(8,0,4),Vector3(14,0,22)],
		["Bram","Blacksmith","Hearth House","mercenary",Vector3(20,0,-10),Vector3(8,0,-4),Vector3(-14,0,22)],
		["Elowen","Herbalist","North Cottage","witch",Vector3(-10,0,-10),Vector3(-8,0,-4),Vector3(-18,0,-22)],
		["Rowan","Innkeeper","the Copper Stag","mercenary",Vector3(-10,0,10),Vector3(-8,0,4),Vector3(-34,0,18)],
		["Edric","Guard","the gatehouse","knight",Vector3(8,0,54),Vector3(4,0,4),Vector3(44,0,44)],
		["Tomas","Farmer","the outer farm","worker",Vector3(-48,0,-30),Vector3(-4,0,-8),Vector3(-48,0,36)],
		["Nell","Merchant","Weaver's House","viking",Vector3(-6,0,6),Vector3(4,0,18),Vector3(-30,0,18)],
		["Agnes","Weaver","Weaver's House","witch",Vector3(-30,0,18),Vector3(-6,0,-6),Vector3(-14,0,22)],
		["Finn","Carpenter","Orchard Cottage","worker",Vector3(30,0,18),Vector3(6,0,-6),Vector3(18,0,-22)],
		["Hugh","Brewer","Brew House","mercenary",Vector3(-30,0,-18),Vector3(-6,0,6),Vector3(-48,0,18)],
		["Sera","Miller","the riverside mill","viking",Vector3(54,0,-10),Vector3(6,0,6),Vector3(48,0,36)],
		["Wren","Herbalist","North Cottage","witch",Vector3(-10,0,-10),Vector3(-4,0,8),Vector3(-18,0,-22)],
		["Oswin","Guard","the gatehouse","knight",Vector3(44,0,44),Vector3(-4,0,4),Vector3(8,0,54)],
		["Ada","Farmer","the apiary","worker",Vector3(-34,0,44),Vector3(4,0,-8),Vector3(18,0,-22)],
		["Jory","Forester","the woodland hut","night_hunter",Vector3(-48,0,36),Vector3(-4,0,18),Vector3(-48,0,52)],
		["Pip","Merchant","the outer inn","worker",Vector3(6,0,-6),Vector3(20,0,0),Vector3(-48,0,-20)],
		["Greta","Stable keeper","Willow House","viking",Vector3(48,0,18),Vector3(4,0,8),Vector3(14,0,22)],
		["Alden","Town clerk","the town hall","medieval",Vector3(0,0,-10),Vector3(-4,0,-4),Vector3(-14,0,22)],
		["Eirik","Guard","the gatehouse","knight",Vector3(44,0,44),Vector3(8,0,54),Vector3(14,0,22)],
		["Corvin","Merchant","the outer inn","mercenary",Vector3(12,0,0),Vector3(4,0,18),Vector3(-14,0,22)],
		["Kael","Forester","the woodland hut","night_hunter",Vector3(-48,0,36),Vector3(-4,0,18),Vector3(-48,0,52)],
		["Astrid","Carpenter","Orchard Cottage","viking",Vector3(30,0,18),Vector3(6,0,-6),Vector3(18,0,-22)]
	]
	var extra_names := ["Oren","Lysa","Cedric","Freya","Torren","Ingrid","Elric","Mina","Wolfram","Tilda","Beren","Elsa","Hilda","Bodil","Rolf","Leif","Ida","Erna","Sven","Alva","Nils","Liv","Edda","Ivar","Runa","Bjorn","Una","Sten"]
	var styles := ["worker","knight","witch","viking","medieval","mercenary","adventurer","night_hunter"]
	var occupations := ["Carpenter","Herbalist","Guard","Merchant","Farmer","Forester"]
	for index in range(45-residents.size()):
		var west := index>=9 and index<17
		var outer := index>=17
		var work := Vector3(-48+(index%5)*22,0,-38+(index%4)*25)
		var square := Vector3(-6+(index%4)*4,0,4+(index%3)*5)
		var home := Vector3(-38+(index%5)*18,0,24)
		if west:
			work=[Vector3(-100,0,60),Vector3(-100,0,95),Vector3(-100,0,130),Vector3(-135,0,160),Vector3(-205,0,160),Vector3(-235,0,70),Vector3(-235,0,110),Vector3(-180,0,35)][index-9]
			square=Vector3(-100,0,95)
			home=[Vector3(-245,0,70),Vector3(-205,0,170),Vector3(-135,0,170),Vector3(-100,0,125)][index%4]
		elif outer:
			work=[Vector3(108,0,-64),Vector3(114,0,-64),Vector3(180,0,-81),Vector3(186,0,-81),Vector3(115,0,90),Vector3(121,0,90)][index-17]
			square=work+Vector3(-4,0,5)
			home=work+Vector3(4,0,5)
		residents.append([extra_names[index],occupations[index%occupations.size()],"the western village" if west else "the castle district" if outer else "Alderwick",styles[index%styles.size()],work,square,home])
	residents.append_array([
		["Gareth","Guard","Western Gate House","saxon",Vector3(-104,0,91),Vector3(-101,0,103),Vector3(-100,0,125)],
		["Duncan","Supply courier","the castle district","bruce",Vector3(130,0,105),Vector3(123,0,101),Vector3(121,0,90)],
		["Selene","Night guard","Hearth House","armoured_assassin",Vector3(22,0,-18),Vector3(4,0,8),Vector3(-14,0,22)],
		["Ivor","Archivist","the town hall","robed_scholar",Vector3(0,0,-19),Vector3(-4,0,-4),Vector3(14,0,22)],
		["Roslin","Herbalist","Orchard Cottage","medieval_woman",Vector3(-20,0,-10),Vector3(-5,0,5),Vector3(-94,0,74),Vector3(122,0,101)],
		["Fenn","Range keeper","the woodland hut","cult_archer",Vector3(42,0,43),Vector3(-48,0,36),Vector3(-100,0,95),Vector3(69,0,47)],
		["Ollie","Village child","Willow House","runner_child",Vector3(5,0,20),Vector3(-3,0,12),Vector3(10,0,20)],
		["Theo","Young apprentice","Hearth House","runner_youth",Vector3(27,0,20),Vector3(10,0,18),Vector3(-7,0,23)]
	])
	var wardrobe := {"Finn":"male_peasant","Wren":"female_peasant","Kael":"male_ranger","Elowen":"female_ranger"}
	for i in range(residents.size()):
		var data: Array = residents[i]
		var person := CharacterBody3D.new()
		person.set_script(load("res://villager.gd"))
		person.person_name=data[0]
		person.occupation=data[1]
		person.home=data[2]
		person.style=data[3]
		if person.person_name=="Mina":person.style="emlyn"
		if wardrobe.has(person.person_name):person.style=wardrobe[person.person_name]
		person.is_child=person.style in ["runner_child","runner_youth"]
		person.walking_policy="pavement" if person.person_name in ["Ollie","Theo","Wren","Pip","Alden","Ivor"] else "road" if posmod(hash(person.person_name),2)==0 else "open"
		if person.person_name in ["Duncan","Gareth"]:person.walking_policy="road"
		if person.person_name in ["Roslin","Fenn"]:person.walking_policy="open"
		person.set_meta("district","castle" if data[4].x>75 else "west" if data[4].x< -80 and data[4].z>30 else "city")
		person.life=self
		person.speed=1.1+(i%5)*0.09
		person.route.assign([data[4],data[5],data[6]])
		if data.size()>7:person.route.append(data[7])
		person.destination=i%3
		person.visits=int(visits.get(data[0],0))
		var start := free_cell(data[4])
		for offset: Vector3 in [Vector3.ZERO,Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1),Vector3(2,0,0),Vector3(-2,0,0)]:
			var candidate := free_cell(data[4]+offset)
			var clear := true
			for existing in people:
				if Vector2(existing.position.x-candidate.x,existing.position.z-candidate.y).length()<1.05:clear=false
			if clear:start=candidate;break
		person.position=Vector3(start.x*CELL,float(floor_heights.get(start,0))+0.1,start.y*CELL)
		town.add_child(person)
		people.append(person)
		person.plan()
		person.wait_time=person.decision_rng.randf_range(1,4)
	occupy_interiors()
	staff_stalls()
	town.jobs.bind(self)
	town.economy.bind()
	town.jobs.bind_night_watch()
	town.routines.bind()
	if town.families:town.families.bind()
	navigation_ready=true
	set_night_routine(false)
	print("VILLAGERS_READY count=",people.size())

func navigation_floor(point: Vector3,space: PhysicsDirectSpaceState3D) -> float:
	for bridge_z in [0.0,48.0]:
		if absf(point.x-64)<=5.0 and absf(point.z-bridge_z)<1.8:return 0.13
	if absf(point.x)<=74 and point.z>=-66 and point.z<=67:return -0.04
	var hint: float=town.expansion.floor_hint(point)
	if not is_nan(hint):return hint
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*4,point-Vector3.UP,1)
	ray.exclude=[town.player.get_rid()]
	var hit := space.intersect_ray(ray)
	return hit.position.y if not hit.is_empty() else 0.0

func house_capacity(house: Node3D) -> int:
	var count := 0
	for child in house.get_children():
		if child.is_in_group("beds"):count+=1
	return count

func staff_stalls() -> void:
	var assignments := {
		"Wren":[Vector3(-8.45,0.03,-5),PI/2,"cabbages and carrots"],
		"Pip":[Vector3(8.45,0.03,-5),-PI/2,"onions and turnips"],
		"Ada":[Vector3(-8.45,0.03,5),PI/2,"pumpkins and greens"],
		"Tomas":[Vector3(8.45,0.03,5),-PI/2,"fresh vegetables"]
	}
	for person in people:
		if not assignments.has(person.person_name):continue
		var data: Array=assignments[person.person_name]
		person.position=data[0]
		person.stall_anchor=data[0]
		person.stall_facing=data[1]
		person.stall_name=data[2]
		person.occupation="Merchant"
		person.activity="Selling "+person.stall_name
		person.path=PackedVector3Array()
		person.wait_time=0
		person.visual.rotation.y=data[1]
		person.work_stops+=1

func set_night_routine(value: bool) -> void:
	if town.families:
		if value:town.families.start_evening()
		else:town.families.groups.clear()
	for person in people:
		var should_sleep: bool=not value if person.guard_shift=="night" else value
		if not should_sleep:release_bed(person)
	# Reserve the beds of indoor workers before choosing homes for visitors.
	# Actual bed ownership is the capacity ledger for every assignment.
	for person in people:
		var should_sleep: bool=not value if person.guard_shift=="night" else value
		if should_sleep and person.indoor_house:reserve_bed(person,person.indoor_house)
	for person in people:
		var should_sleep: bool=not value if person.guard_shift=="night" else value
		if town.routines:town.routines.cancel(person)
		if person.indoor_house:
			if person.social_partner:person.end_social()
			person.wait_time=100000.0 if should_sleep else person.decision_rng.randf_range(2,5)
			person.activity="Resting indoors for the night" if should_sleep else person.work_description()
			if should_sleep:
				if person.assigned_bed:person.go_to_bed(person.assigned_bed)
			else:
				person.night_schedule=false
				person.resting_indoors=false
				person.stand_up()
				person.plan()
			continue
		if should_sleep:
			person.day_visit=false
			if person.visit_seat and person.visit_seat.get_meta("occupant","")==person.person_name:person.visit_seat.remove_meta("occupant")
			person.visit_seat=null
			if inside_current_home(person):
				var bed := reserve_bed(person,person.home_door.get_parent())
				if bed:person.go_to_bed(bed)
				else:
					person.resting_indoors=true
					person.night_schedule=true
					person.leave_home()
					person.sleep_after_exit=true
			else:assign_home(person)
		else:
			person.sleep_after_exit=false
			if inside_current_home(person):person.resting_indoors=true
			person.leave_home()

func inside_current_home(person: CharacterBody3D) -> bool:
	if not is_instance_valid(person.home_door):return false
	var room: Node3D=person.home_door.get_parent()
	var local: Vector3=room.to_local(person.position)
	var width: float=room.get_meta("width",8)
	var depth: float=room.get_meta("depth",10)
	var entrance: Vector3=person.home_transform.affine_inverse()*person.position
	return absf(local.x)<width/2+0.4 and absf(local.z)<depth/2+0.4 and entrance.z>0.25

func assign_home(person: CharacterBody3D) -> bool:
	if town.get("industrial_workforce") and town.industrial_workforce.intercept_home(person):return true
	if town.families and town.families.send_home(person):return true
	var best: Node3D=null
	var best_distance := INF
	var best_route := PackedVector3Array()
	for house: Node3D in get_tree().get_nodes_in_group("enterable_houses"):
		if house.get_meta("player_owned",false) or house.get_meta("family_excluded",false):continue
		var capacity := false
		for bed in house.get_children():
			if bed.is_in_group("beds") and bed.get_meta("resident_owner",person.person_name)==person.person_name and (not bed.has_meta("occupant") or bed.get_meta("occupant")==person.person_name):capacity=true;break
		if not capacity:continue
		for door: Node3D in house.get_children():
			if not door.is_in_group("doors"):continue
			var distance: float=person.position.distance_to(door.global_position)
			for neighbour in people:
				if neighbour!=person and neighbour.style==person.style and neighbour.assigned_bed and neighbour.assigned_bed.get_parent()==house:distance+=80;break
			if distance>=best_distance:continue
			var route := route_to_door(person,door)
			if route.is_empty():continue
			best=door
			best_distance=distance
			best_route=route
	if best:
		if person.assigned_bed and person.assigned_bed.get_parent()!=best.get_parent():release_bed(person)
		if reserve_bed(person,best.get_parent()):
			person.head_home(best,best_route)
			person.night_delay=person.decision_rng.randf_range(0.1,2.3)
			return true
	person.night_schedule=true
	person.night_stage="finding_home"
	person.night_delay=1
	return false

func put_to_bed(person: CharacterBody3D,house: Node3D) -> void:
	var bed: Node3D=person.assigned_bed if person.assigned_bed else reserve_bed(person,house)
	if bed:person.sleep_at(bed)

func occupy_interiors() -> void:
	# Keep shopkeepers and tavern regulars present inside, while the remaining
	# residents continue their outdoor work, errands and social routines.
	var assignments := {
		"Mara":["Bramble Bakery","the bakery",Vector3(0.7,0,-0.6)],
		"Bram":["Forge & Anvil","the forge",Vector3(1.6,0,-1.2)],
		"Rowan":["The Copper Stag","the tavern",Vector3(0.2,0,0.1)],
		"Hugh":["Brew House","the brew house",Vector3(0.3,0,1.8)],
		"Agnes":["Weaver's House","the weaver's house",Vector3(0.4,0,-0.3)],
		"Alden":["Alderwick Town Hall","the town hall",Vector3(0.5,0,-0.2)],
		"Ivor":["Alderwick Town Hall","the archive",Vector3(-1.0,0,1.2)],
		"Edda":["Feira Castle","the castle provisions room",Vector3(.8,0,-.6)],
		"Sven":["Castle XIX","the castle workshop",Vector3(1.2,0,.6)]
	}
	for person in people:
		if not assignments.has(person.person_name):continue
		var assignment: Array=assignments[person.person_name]
		var house: Node3D=null
		for candidate in get_tree().get_nodes_in_group("enterable_houses"):
			if String(candidate.name).replace(" ","").replace("'", "")==String(assignment[0]).replace(" ","").replace("'", ""):
				house=candidate
				break
		if house==null:
			push_error("Missing interior for "+person.person_name)
			continue
		person.indoor_house=house
		house.set_meta("display_name",assignment[0])
		if person.person_name=="Edda":person.occupation="Castle caretaker"
		person.indoor_role=assignment[1]
		var local: Vector3=assignment[2]
		if house.is_in_group("native_interiors"):
			var shape:=CapsuleShape3D.new();shape.height=1.7;shape.radius=.38
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
			for offset: Vector3 in [Vector3.ZERO,Vector3(1,0,0),Vector3(-1,0,0),Vector3(2,0,-1),Vector3(-2,0,1),Vector3(0,0,2)]:
				query.transform.origin=house.to_global(local+offset+Vector3.UP*.9)
				if town.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():local+=offset;break
		person.indoor_points.assign([house.to_global(local),house.to_global(local+Vector3(0,0,0.65)),house.to_global(local+Vector3(0,0,-0.65))])
		person.route.assign(person.indoor_points)
		person.position=person.indoor_points[0]+Vector3(0,0.03,0)
		person.destination=0
		person.path=PackedVector3Array()
		person.path_index=0
		person.wait_time=person.decision_rng.randf_range(10,20)
		person.activity=person.work_description()
		person.work_stops+=1
		person.visual.rotation.y=house.rotation.y+PI/2
		print("INTERIOR_RESIDENT ",person.person_name," in ",house.name)

func free_cell(point: Vector3) -> Vector2i:
	var id := Vector2i(roundi(point.x/CELL),roundi(point.z/CELL))
	for radius in range(14):
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				var candidate := id+Vector2i(dx,dz)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate) and (street_cells.is_empty() or street_cells.has(candidate)): return candidate
	return Vector2i(0,10)

func find_route(from: Vector3,to: Vector3,person: Node=null,avoid_people := false,physical_person: CharacterBody3D=null) -> PackedVector3Array:
	var result := PackedVector3Array()
	var ids: Array[Vector2i]=walking_routes.path(from,to,person,avoid_people) if walking_routes else grid.get_id_path(free_cell(from),free_cell(to),false)
	for id in ids: result.append(Vector3(id.x*CELL,float(floor_heights.get(id,0))+0.01,id.y*CELL))
	# A free grid cell may be across the corner of a stool or workbench.
	# Validate the short connection from the person's actual standing point.
	var mover: CharacterBody3D=physical_person if physical_person else person as CharacterBody3D
	if mover and not result.is_empty() and mover.position.distance_to(from)<.2:
		var mask: int=mover.collision_mask;mover.collision_mask=1
		var probe: Transform3D=mover.global_transform;probe.origin.y+=.16
		var join: Vector3=result[0]-from;join.y=0
		if mover.test_move(probe,join):
			var alternatives: Array[Vector2i]=[]
			var centre:=Vector2i(roundi(from.x),roundi(from.z))
			for dx in range(-2,3):
				for dz in range(-2,3):
					var cell:=centre+Vector2i(dx,dz)
					if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell) and street_cells.has(cell):alternatives.append(cell)
			alternatives.sort_custom(func(a: Vector2i,b: Vector2i):return Vector2(a.x-from.x,a.y-from.z).length_squared()<Vector2(b.x-from.x,b.y-from.z).length_squared())
			for cell in alternatives:
				var point:=Vector3(cell.x,float(floor_heights.get(cell,0))+.01,cell.y)
				var motion:=point-from;motion.y=0
				if mover.test_move(probe,motion):continue
				var alternative: Array[Vector2i]=walking_routes.path(point,to,person,avoid_people) if walking_routes else grid.get_id_path(cell,free_cell(to),false)
				if alternative.is_empty():continue
				result=PackedVector3Array([point])
				for id in alternative:result.append(Vector3(id.x,float(floor_heights.get(id,0))+.01,id.y))
				break
		mover.collision_mask=mask
	return result

func route_to_point(person: CharacterBody3D,target: Vector3,avoid_people := false) -> PackedVector3Array:
	var route := find_route(person.position,target,person,avoid_people)
	if route.is_empty():return route
	if Vector2(route[-1].x-target.x,route[-1].z-target.z).length()>1.4:return PackedVector3Array()
	var probe := person.global_transform
	probe.origin=route[-1]+Vector3.UP*0.30
	var mask: int=person.collision_mask
	person.collision_mask=1
	var blocked: bool=person.test_move(probe,target+Vector3.UP*0.30-probe.origin)
	person.collision_mask=mask
	if blocked:return PackedVector3Array()
	route.append(target)
	return route

func bedside_position(person: CharacterBody3D,bed: Node3D,avoid_people := false) -> Vector3:
	var room: Node3D=bed.get_parent()
	var toward := -signf(bed.position.x) if absf(bed.position.x)>0.1 else 1.0
	var center: Vector3=bed.position+bed.basis*Vector3(0,0,.75)
	center.y=.04
	var shape := CapsuleShape3D.new()
	shape.radius=0.3*person.appearance_build
	shape.height=1.7*person.appearance_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=3 if avoid_people else 1
	query.exclude=[person.get_rid(),town.player.get_rid()]
	for offset: Vector3 in [Vector3(toward*1.08,0,0),Vector3(toward*1.08,0,-0.55),Vector3(toward*1.08,0,0.55),Vector3(0,0,1.55),Vector3(toward*1.4,0,0)]:
		var point: Vector3=room.to_global(center+bed.basis*offset)
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*(shape.height/2+0.02))
		if town.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return point
	return room.global_position+Vector3.UP*0.05

func reserve_bed(person: CharacterBody3D,house: Node3D) -> Node3D:
	if house.get_meta("player_owned",false) or house.get_meta("family_excluded",false):return null
	for child in house.get_children():
		if child.get_meta("resident_owner",person.person_name)!=person.person_name:continue
		if child.is_in_group("beds") and (not child.has_meta("occupant") or child.get_meta("occupant")==person.person_name):
			child.set_meta("occupant",person.person_name)
			person.assigned_bed=child
			return child
	return null

func release_bed(person: CharacterBody3D) -> void:
	if person.assigned_bed and person.assigned_bed.get_meta("occupant","")==person.person_name:person.assigned_bed.remove_meta("occupant")
	person.assigned_bed=null

func indoor_route(person: CharacterBody3D,house: Node3D,from: Vector3,to: Vector3) -> PackedVector3Array:
	var cell_size := 0.25
	var nav: AStarGrid2D
	if interior_grids.has(house):nav=interior_grids[house]
	else:
		var width: float=house.get_meta("width",8)
		var depth: float=house.get_meta("depth",10)
		var low := Vector2(-width/2-1,-depth/2-1)
		var high := Vector2(width/2+1,depth/2+1)
		for child in house.get_children():
			if child.is_in_group("doors"):
				var point: Vector3=house.to_local(child.get_closed_transform()*Vector3(child.width/2,0.04,1.8))
				low=low.min(Vector2(point.x-1.5,point.z-1.5))
				high=high.max(Vector2(point.x+1.5,point.z+1.5))
		nav=AStarGrid2D.new()
		var first := Vector2i(floori(low.x/cell_size),floori(low.y/cell_size))
		var last := Vector2i(ceili(high.x/cell_size),ceili(high.y/cell_size))
		nav.region=Rect2i(first,last-first+Vector2i.ONE)
		nav.cell_size=Vector2.ONE*cell_size
		nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
		nav.update()
		var shape := CapsuleShape3D.new()
		shape.radius=0.38
		shape.height=1.85
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape=shape
		query.collision_mask=1
		query.exclude=[town.player.get_rid(),person.get_rid()]
		for x in range(first.x,last.x+1):
			for z in range(first.y,last.y+1):
				query.transform=Transform3D(Basis.IDENTITY,house.to_global(Vector3(x*cell_size,1.1,z*cell_size)))
				nav.set_point_solid(Vector2i(x,z),not town.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty())
		interior_grids[house]=nav
	var local_from: Vector3=house.to_local(from)
	var local_to: Vector3=house.to_local(to)
	var start := nearest_indoor_cell(nav,Vector2i(roundi(local_from.x/cell_size),roundi(local_from.z/cell_size)))
	var finish := nearest_indoor_cell(nav,Vector2i(roundi(local_to.x/cell_size),roundi(local_to.z/cell_size)))
	var result := PackedVector3Array()
	for cell in nav.get_id_path(start,finish,false):result.append(house.to_global(Vector3(cell.x*cell_size,0.04,cell.y*cell_size)))
	if not result.is_empty():result.append(to)
	elif String(house.name)=="CastleXIX" and not house.has_meta("nav_dumped"):
		house.set_meta("nav_dumped",true)
		var free: Array=[]
		for x in range(nav.region.position.x,nav.region.end.x):
			for z in range(nav.region.position.y,nav.region.end.y):
				if not nav.is_point_solid(Vector2i(x,z)):free.append([x,z])
		var file := FileAccess.open("res://../castle-indoor-navigation.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"origin":[house.position.x,house.position.y,house.position.z],"start":[start.x,start.y],"finish":[finish.x,finish.y],"free":free}))
		print("CASTLE_NAV_DIAGNOSTIC start=",start," finish=",finish," free_cells=",free.size()," from=",from," to=",to)
	return result

func nearest_indoor_cell(nav: AStarGrid2D,point: Vector2i) -> Vector2i:
	for radius in range(10):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var cell := point+Vector2i(x,z)
				if nav.is_in_boundsv(cell) and not nav.is_point_solid(cell):return cell
	return nav.region.position

func route_to_door(person: CharacterBody3D,door: Node3D) -> PackedVector3Array:
	var closed: Transform3D=door.get_closed_transform()
	var entrance: Vector3=closed*Vector3(door.width/2,0.04,-1.3)
	for distance: float in [1.3,2.1,3.0,4.0]:
		var approach: Vector3=closed*Vector3(door.width/2,0.04,-distance)
		var route := find_route(person.position,approach,null,false,person)
		if route.is_empty():continue
		var end: Vector3=route[-1]
		if Vector2(end.x-approach.x,end.z-approach.z).length()>1.2:continue
		# Test the final approach above a low threshold, which residents can
		# step over. A wall or tall obstruction still rejects this entrance.
		var probe := person.global_transform
		probe.origin=end+Vector3.UP*0.35
		var goal := entrance+Vector3.UP*0.35
		var mask: int=person.collision_mask
		person.collision_mask=1
		var blocked: bool=person.test_move(probe,goal-probe.origin)
		person.collision_mask=mask
		if blocked:continue
		route.append(entrance)
		return route
	return PackedVector3Array()

func _process(delta: float) -> void:
	if not navigation_ready: return
	social_clock+=delta
	if social_clock>1.1:
		social_clock=0
		consider_meetups()
	heartbeat+=delta
	if heartbeat<0.15: return
	heartbeat=0
	if active and not active.stall_name.is_empty():refresh_trade()
	if town.day_night and town.day_night.night:close_night_doors()
	nearest=null
	var distance := 5.0
	for person in people:
		var d: float = person.position.distance_to(town.player.position)
		if d<distance:
			var sight := PhysicsRayQueryParameters3D.create(town.player.position+Vector3.UP*1.5,person.position+Vector3.UP*1.4,1)
			if town.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():nearest=person;distance=d
	nearest_door=null
	var door_distance := 2.8
	for door in get_tree().get_nodes_in_group("doors"):
		var d: float=door.global_position.distance_to(town.player.position)
		if d<door_distance:nearest_door=door;door_distance=d
	nearest_furniture=null
	var furniture_distance := 2.3
	for group in ["seats","beds"]:
		for item in get_tree().get_nodes_in_group(group):
			if item.has_meta("occupant"):continue
			var d: float=item.global_position.distance_to(town.player.position)
			if d<furniture_distance:
				var sight := PhysicsRayQueryParameters3D.create(town.player.position+Vector3.UP*1.4,item.global_position+Vector3.UP*1.0,1)
				if not town.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():continue
				nearest_furniture=item
				furniture_distance=d
	hint.visible=active==null
	var target:=preload("res://interaction_target.gd").resolve(town)
	hint.text=("Use: " if preload("res://mobile_runtime.gd").enabled() else "[E] ")+target.label
	if town.view_mode==1:hint.text=str(people.size())+" villagers · Select a resident to talk"
	talk_button.visible=active==null and nearest!=null and town.view_mode!=1
	if nearest:
		if nearest.social_partner and nearest.has_conversation_partner():
			talk_button.text="Join "+nearest.person_name+" & "+nearest.social_partner.person_name+" [F]"
			if target.kind=="talk":hint.text="Join "+nearest.person_name+" & "+nearest.social_partner.person_name
		else:talk_button.text="Talk to "+nearest.person_name+" [F]"

func close_night_doors() -> void:
	for door in get_tree().get_nodes_in_group("doors"):
		if not door.is_open:continue
		var occupied := false
		var waiting := false
		for person in people:
			if person.indoor_house==door.get_parent():occupied=true
			if person.home_door==door and person.night_schedule:
				occupied=true
				if not person.resting_indoors:waiting=true
		if occupied and not waiting:door.toggle(town.player.position)

func can_meet(a: CharacterBody3D,b: CharacterBody3D) -> bool:
	if a.style==b.style:return false
	if not a.routine.is_empty() or not b.routine.is_empty():return false
	if a.posture!="standing" or b.posture!="standing":return false
	if not a.stall_name.is_empty() or not b.stall_name.is_empty():return false
	if a==b or a.talking or b.talking or a.social_partner or b.social_partner:return false
	if a.meeting_partner or b.meeting_partner or a.night_schedule or b.night_schedule:return false
	if a.social_cooldown>0 or b.social_cooldown>0:return false
	var gap: float=a.position.distance_to(b.position)
	if gap<1.05 or gap>1.9:return false
	# Check sight and room between the pair so nobody chats through a wall.
	var ray := PhysicsRayQueryParameters3D.create(a.position+Vector3.UP,b.position+Vector3.UP,1)
	return town.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func start_meetup(a: CharacterBody3D,b: CharacterBody3D,duration: float=0) -> bool:
	if not can_meet(a,b):return false
	if duration<=0:duration=150
	var no_lines: Array[String]=[]
	a.begin_social(b,duration,no_lines)
	b.begin_social(a,duration,no_lines)
	a.chat_id=next_chat_id
	b.chat_id=next_chat_id
	chats[next_chat_id]={"a":a,"b":b,"leader":a if a.get_index()<b.get_index() else b,"turns":[],"index":-1,"elapsed":0.0,"minimum":0.0,"speaker":null}
	next_chat_id+=1
	social_events+=1
	return true

func tick_chat(person: CharacterBody3D,delta: float) -> void:
	if not chats.has(person.chat_id):return
	var chat: Dictionary=chats[person.chat_id]
	if chat.leader!=person:return
	ai.tick_social(person,chat,delta)

func stop_chat(person: CharacterBody3D) -> void:
	if not chats.has(person.chat_id):return
	var chat: Dictionary=chats[person.chat_id]
	if chat.index>=1 and town.routines:town.routines.befriend(chat.a,chat.b)
	for participant in [chat.a,chat.b]:
		var other: CharacterBody3D=chat.b if participant==chat.a else chat.a
		if chat.index>=1:
			for turn in chat.turns:
				if turn.speaker!=other:continue
				participant.heard_events.append({"who":other.person_name,"kind":"conversation","text":turn.text})
				if participant.heard_events.size()>3:participant.heard_events.pop_front()
		participant.social_speaking=false
		if town.speech:town.speech.stop(participant)
	chats.erase(person.chat_id)

func consider_meetups() -> void:
	if town.day_night and town.day_night.night:return
	var chatting := 0
	for person in people:
		if person.social_partner or person.meeting_partner:chatting+=1
	if chatting>=social_limit*2:return
	var candidates := people.duplicate()
	candidates.shuffle()
	for a in candidates:
		if not available_for_meeting(a):continue
		if social_rng.randf()>a.sociability:continue
		var partners := candidates.duplicate()
		partners.sort_custom(func(first: CharacterBody3D,second: CharacterBody3D):return int(a.friendships.get(first.person_name,0))>int(a.friendships.get(second.person_name,0)))
		for b in partners:
			if not available_for_meeting(b) or a==b:continue
			if start_meetup(a,b) or invite_meetup(a,b):return

func available_for_meeting(person: CharacterBody3D) -> bool:
	if not person.routine.is_empty():return false
	if not person.job.is_empty() and person.job.get("stage","") in ["harvesting","crafting"]:return false
	if not person.guard_label.is_empty() and Vector2(person.position.x-person.guard_post.x,person.position.z-person.guard_post.z).length()>0.3:return false
	return person.posture=="standing" and person.getting_up<=0 and not person.talking and not person.social_partner and not person.meeting_partner and person.social_cooldown<=0 and not person.night_schedule and not person.indoor_house and person.stall_name.is_empty()

func invite_meetup(a: CharacterBody3D,b: CharacterBody3D) -> bool:
	if a.style==b.style:return false
	if not available_for_meeting(a) or not available_for_meeting(b):return false
	if not b.guard_label.is_empty():return false
	if a.position.distance_to(b.position)>12 or absf(a.position.y-b.position.y)>0.45:return false
	var shape := CapsuleShape3D.new()
	shape.radius=0.4
	shape.height=1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=1
	query.exclude=[town.player.get_rid()]
	var space := town.get_world_3d().direct_space_state
	var toward: Vector3=b.position-a.position
	var angle := atan2(toward.x,toward.z)
	for turn: float in [0.0,PI/4,-PI/4,PI/2,-PI/2,PI]:
		var target: Vector3=a.position+Vector3(sin(angle+turn),0,cos(angle+turn))*1.55
		var cell := Vector2i(roundi(target.x),roundi(target.z))
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):continue
		target.y=float(floor_heights.get(cell,0))+0.03
		query.transform=Transform3D(Basis.IDENTITY,target+Vector3.UP*0.91)
		if not space.intersect_shape(query,1).is_empty():continue
		var occupied := false
		for person in people:
			if person!=a and person!=b and person.position.distance_to(target)<0.95:occupied=true;break
		if occupied:continue
		var sight := PhysicsRayQueryParameters3D.create(a.position+Vector3.UP*1.3,target+Vector3.UP*1.3,1)
		if not space.intersect_ray(sight).is_empty():continue
		var approach := find_route(b.position,target)
		if approach.is_empty() or Vector2(approach[-1].x-target.x,approach[-1].z-target.z).length()>1.1:continue
		var probe := b.global_transform
		probe.origin=approach[-1]+Vector3.UP*0.03
		if b.test_move(probe,target-approach[-1]):continue
		var distance := 0.0
		var previous: Vector3=b.position
		for point in approach:
			distance+=previous.distance_to(point)
			previous=point
		if distance>18:continue
		approach.append(target)
		a.reserve_meeting(b,PackedVector3Array())
		b.reserve_meeting(a,approach)
		meeting_invitations+=1
		return true
	return false

func finish_meeting(a: CharacterBody3D,b: CharacterBody3D) -> bool:
	if a.meeting_partner!=b or b.meeting_partner!=a:return false
	a.meeting_partner=null
	b.meeting_partner=null
	if start_meetup(a,b):return true
	for person in [a,b]:
		person.social_cooldown=4
		person.plan()
	return false

func cancel_meeting(person: CharacterBody3D) -> void:
	var other: CharacterBody3D=person.meeting_partner
	person.meeting_partner=null
	person.meeting_path=PackedVector3Array()
	person.social_cooldown=maxf(person.social_cooldown,4)
	person.plan()
	if is_instance_valid(other) and other.meeting_partner==person:
		other.meeting_partner=null
		other.meeting_path=PackedVector3Array()
		other.social_cooldown=maxf(other.social_cooldown,4)
		other.plan()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE and active:
			close_dialog()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_F and not active and nearest and town.view_mode!=1:
			open_dialog(nearest)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_E and not active and town.view_mode!=1:
			preload("res://interaction_target.gd").perform(town,preload("res://interaction_target.gd").resolve(town))
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and town.view_mode==1 and not active:
		var camera := get_viewport().get_camera_3d()
		var origin := camera.project_ray_origin(event.position)
		var ray := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(event.position)*400,2)
		var hit := town.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit and hit.collider.is_in_group("villagers"): open_dialog(hit.collider)

func make_interface() -> void:
	preload("res://dialogue_panel.gd").build(self)

func open_dialog(person: CharacterBody3D,allow_join := true) -> void:
	if allow_join and person.social_partner and person.has_conversation_partner() and person.position.distance_to(town.player.position)<=5:
		join_conversation(person)
		return
	if person.posture=="sleeping":
		town.economy.announce(person.person_name+" is sleeping. Come back during their shift.")
		return
	if active:close_dialog()
	if not person.routine.is_empty():town.routines.cancel(person)
	if person.meeting_partner:cancel_meeting(person)
	if person.social_partner:person.end_social()
	person.stand_up()
	active=person
	active.talking=true
	active.work_timer=0
	active.visits+=1
	heading.text=active.person_name+" · "+active.occupation
	transcript.text=""
	entry.clear()
	dialog.show()
	refresh_trade()
	hint.hide()
	active.label.hide()
	var facing: Vector3 = town.player.position-active.position
	if Vector2(facing.x,facing.z).length()>0.01:active.visual.rotation.y=atan2(facing.x,facing.z)
	ai.layout()
	ai.open(person)
	town.player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	previous_music=town.music.volume_db
	if previous_music>-60:town.music.volume_db=-40
	entry.grab_focus()
	visits[active.person_name]=active.visits
	if not automated:
		var save := FileAccess.open("user://villager-visits.json",FileAccess.WRITE)
		save.store_string(JSON.stringify(visits))

func join_conversation(person: CharacterBody3D) -> void:
	var partner: CharacterBody3D=person.social_partner
	if not is_instance_valid(partner) or not person.has_conversation_partner():return
	var overheard: Array[Dictionary]=[]
	if chats.has(person.chat_id):
		for turn in chats[person.chat_id].turns:overheard.append({"name":turn.speaker.person_name,"text":turn.text})
	open_dialog(person,false)
	ai.begin_group(person,partner,overheard)

func refresh_trade() -> void:
	trade_row.visible=active!=null and not active.stall_name.is_empty()
	if not trade_row.visible:return
	var market: Dictionary=town.economy.market_for(active)
	trade_status.text="Stock: "+str(market.stock)+"  ·  Purse: "+str(town.economy.player_coins)+"  "
	var price: int=town.economy.player_food_price(active)
	var buttons: Array=trade_row.get_child(0).get_child(1).get_children()
	if not buttons.is_empty():buttons[0].text="Buy food · "+str(price)+" coins"

func send_entry() -> void:
	send(entry.text)

func send(message: String) -> void:
	ai.send(message)

func close_dialog() -> void:
	if active:
		if town.speech:town.speech.stop(active)
		active.talking=false
		active.work_timer=0
		if town.day_night.night:
			if active.indoor_house:put_to_bed(active,active.indoor_house)
			elif active.resting_indoors:put_to_bed(active,active.home_door.get_parent())
	active=null
	ai.close()
	dialog.hide()
	town.player.enabled=town.view_mode!=1
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if town.view_mode==1 else Input.MOUSE_MODE_CAPTURED
	town.music.volume_db=previous_music
