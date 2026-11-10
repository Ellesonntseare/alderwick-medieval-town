extends RefCounted

var life: Node
var paved: Dictionary={}
var road_grid := AStarGrid2D.new()
var pavement_grid := AStarGrid2D.new()
var detours: Dictionary={}
var pavement_components: Dictionary={}
var route_cache: Dictionary={}
var connector_cache: Dictionary={}
var options_cache: Dictionary={}
var cache_hits:=0
var searches:=0
var replan_frame:=-1
var replans_this_frame:=0
var deferred_replans:=0
var search_frame:=-1
var search_usec_this_frame:=0
const CACHE_LIMIT:=256
const CACHE_MSEC:=3000
const RECOVERY_USEC:=1500

func build(owner: Node) -> void:
	life=owner
	paved.clear()
	pavement_components.clear()
	detours.clear()
	route_cache.clear();connector_cache.clear();options_cache.clear()
	# Read the floor tiles that are actually rendered, including batched tiles.
	var square: Node3D=life.town.get_node_or_null("CobblestoneSquareAndLanes")
	if square:
		for instance: MultiMeshInstance3D in square.find_children("*","MultiMeshInstance3D",true,false):
			for index in range(instance.multimesh.instance_count):
				var point: Vector3=(instance.global_transform*instance.multimesh.get_instance_transform(index)).origin
				paint(point,1.0)
	for mesh: MeshInstance3D in life.town.find_children("*","MeshInstance3D",true,false):
		if not mesh.has_meta("walking_lane"):continue
		var lane: Dictionary=mesh.get_meta("walking_lane")
		var count := ceili(lane.a.distance_to(lane.b)*2)
		for step in range(count+1):paint(lane.a.lerp(lane.b,float(step)/maxi(count,1)),lane.width/2.0)
	for nav in [road_grid,pavement_grid]:
		nav.region=life.grid.region
		nav.cell_size=life.grid.cell_size
		nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
		nav.update()
		nav.fill_solid_region(nav.region)
	for cell: Vector2i in life.street_cells:
		road_grid.set_point_solid(cell,false)
		road_grid.set_point_weight_scale(cell,1.0 if paved.has(cell) else 7.0)
		if paved.has(cell):pavement_grid.set_point_solid(cell,false)
	var component := 0
	for cell: Vector2i in paved:
		if pavement_components.has(cell) or not pavement_grid.is_in_boundsv(cell) or pavement_grid.is_point_solid(cell):continue
		component+=1
		var queue: Array[Vector2i]=[cell]
		pavement_components[cell]=component
		var cursor := 0
		while cursor<queue.size():
			var current := queue[cursor]
			cursor+=1
			for step: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next := current+step
				if pavement_components.has(next) or not pavement_grid.is_in_boundsv(next) or pavement_grid.is_point_solid(next):continue
				pavement_components[next]=component
				queue.append(next)
	print("WALKING_ROUTES_READY paved_cells=",paved.size()," policies=road,pavement,open")

func paint(point: Vector3,radius: float) -> void:
	for x in range(ceili(point.x-radius),floori(point.x+radius)+1):
		for z in range(ceili(point.z-radius),floori(point.z+radius)+1):paved[Vector2i(x,z)]=true

func policy(person: Node) -> String:
	if not person or person.night_schedule or person.indoor_house:return "open"
	return person.walking_policy

func connector(cell: Vector2i) -> Vector2i:
	if connector_cache.has(cell):return connector_cache[cell]
	var result:=find_connector(cell)
	if connector_cache.size()>=1024:connector_cache.erase(connector_cache.keys()[0])
	connector_cache[cell]=result
	return result

func find_connector(cell: Vector2i) -> Vector2i:
	if pavement_grid.is_in_boundsv(cell) and not pavement_grid.is_point_solid(cell):return cell
	# Access to a doorway or a work stop may require a short approach from the
	# paving; the middle of the journey remains on the paved network.
	for radius in range(1,11):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				if abs(x)!=radius and abs(z)!=radius:continue
				var next := cell+Vector2i(x,z)
				if not pavement_grid.is_in_boundsv(next) or pavement_grid.is_point_solid(next):continue
				if not life.grid.get_id_path(cell,next,false).is_empty():return next
	return Vector2i(99999,99999)

func connector_options(cell: Vector2i) -> Dictionary:
	if options_cache.has(cell):return options_cache[cell]
	var options:=find_connector_options(cell)
	if options_cache.size()>=256:options_cache.erase(options_cache.keys()[0])
	options_cache[cell]=options
	return options

func find_connector_options(cell: Vector2i) -> Dictionary:
	var result: Dictionary={}
	# All candidates share one short breadth-first traversal. Previously each
	# paved candidate could start another A* search across the whole city.
	# A 35-cell approach contains at most 34 edges, so this bound preserves
	# the existing approach limit, including detours outside the ten-cell ring.
	var distances: Dictionary={}
	if not life.grid.is_in_boundsv(cell) or life.grid.is_point_solid(cell):return result
	var queue: Array[Vector2i]=[cell]
	distances[cell]=0
	var cursor:=0
	while cursor<queue.size():
		var current:=queue[cursor];cursor+=1
		var length: int=distances[current]
		if length>=34:continue
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:=current+offset
			if distances.has(next) or not life.grid.is_in_boundsv(next) or life.grid.is_point_solid(next):continue
			distances[next]=length+1;queue.append(next)
	for radius in range(11):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				if abs(x)!=radius and abs(z)!=radius:continue
				var point := cell+Vector2i(x,z)
				if not pavement_components.has(point):continue
				var component: int=pavement_components[point]
				if result.has(component):continue
				if distances.has(point):result[component]={"point":point,"length":int(distances[point])+1}
	return result

func path(from: Vector3,to: Vector3,person: Node,avoid_people: bool) -> Array[Vector2i]:
	var trace:=preload("res://frame_costs.gd").begin()
	var result:=path_impl(from,to,person,avoid_people)
	preload("res://frame_costs.gd").finish("walking_route",trace,[person.get("person_name") if person else "",from,to,policy(person),avoid_people])
	return result

func path_impl(from: Vector3,to: Vector3,person: Node,avoid_people: bool) -> Array[Vector2i]:
	var now:=Time.get_ticks_msec()
	var avoided: Dictionary=detours.get(person.person_name,{}) if person else {}
	for cell in avoided.keys():
		if int(avoided[cell])<now:avoided.erase(cell)
	# Crowd avoidance and personal obstacle recovery always get a fresh search.
	var reusable:=not avoid_people and avoided.is_empty()
	var start: Vector2i=life.free_cell(from);var finish: Vector2i=life.free_cell(to)
	var key:=str([start,finish,policy(person)])
	if reusable and route_cache.has(key) and now-int(route_cache[key].at)<CACHE_MSEC:
		cache_hits+=1
		return route_cache[key].path.duplicate()
	searches+=1
	var frame:=Engine.get_physics_frames()
	if search_frame!=frame:search_frame=frame;search_usec_this_frame=0
	var started:=Time.get_ticks_usec()
	var result:=uncached_path(start,finish,person,avoid_people)
	search_usec_this_frame+=Time.get_ticks_usec()-started
	if reusable and not result.is_empty():
		if route_cache.size()>=CACHE_LIMIT:route_cache.erase(route_cache.keys()[0])
		route_cache[key]={"path":result.duplicate(),"at":now}
	return result

func uncached_path(start: Vector2i,finish: Vector2i,person: Node,avoid_people: bool) -> Array[Vector2i]:
	var mode := policy(person)
	var nav: AStarGrid2D=road_grid if mode=="road" else pavement_grid if mode=="pavement" else life.grid
	var first := connector(start) if mode=="pavement" else start
	var last := connector(finish) if mode=="pavement" else finish
	if mode=="pavement" and pavement_components.get(first,-1)!=pavement_components.get(last,-2):
		var starts := connector_options(start)
		var finishes := connector_options(finish)
		var cost := INF
		for component in starts:
			if not finishes.has(component):continue
			var candidate: float=starts[component].length+finishes[component].length
			if candidate<cost:
				cost=candidate
				first=starts[component].point
				last=finishes[component].point
		if not is_finite(cost):return []
	if not nav.is_in_boundsv(first) or not nav.is_in_boundsv(last):return []
	var changed: Array[Vector2i]=[]
	if person:
		var avoided: Dictionary=detours.get(person.person_name,{})
		for cell: Vector2i in avoided:
			if int(avoided[cell])<Time.get_ticks_msec():continue
			if cell in [first,last] or not nav.is_in_boundsv(cell) or nav.is_point_solid(cell):continue
			nav.set_point_solid(cell,true)
			changed.append(cell)
	if avoid_people:
		for other in life.people:
			if other==person or other.posture=="sleeping" or other.velocity.length()>0.2:continue
			var cell := Vector2i(roundi(other.position.x),roundi(other.position.z))
			if cell in [first,last] or not nav.is_in_boundsv(cell) or nav.is_point_solid(cell):continue
			nav.set_point_solid(cell,true)
			changed.append(cell)
	var middle := nav.get_id_path(first,last,false)
	for cell in changed:nav.set_point_solid(cell,false)
	if middle.is_empty() or mode!="pavement":return middle
	var result: Array[Vector2i]=life.grid.get_id_path(start,first,false)
	result.append_array(middle.slice(1))
	result.append_array(life.grid.get_id_path(last,finish,false).slice(1))
	return result

func avoid(person: CharacterBody3D,point: Vector3) -> void:
	if not detours.has(person.person_name):detours[person.person_name]={}
	detours[person.person_name][Vector2i(roundi(point.x),roundi(point.z))]=Time.get_ticks_msec()+15000

func claim_replan() -> bool:
	# Recovery can wait a few ticks; initial routes and door approaches stay
	# immediate. This prevents a blocked crowd from recalculating all at once.
	var frame:=Engine.get_physics_frames()
	if replan_frame!=frame:replan_frame=frame;replans_this_frame=0
	if replans_this_frame>=3 or (replans_this_frame>0 and search_frame==frame and search_usec_this_frame>=RECOVERY_USEC):
		deferred_replans+=1;return false
	replans_this_frame+=1
	return true
