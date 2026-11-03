extends RefCounted

var life: Node
var paved: Dictionary={}
var road_grid := AStarGrid2D.new()
var pavement_grid := AStarGrid2D.new()
var detours: Dictionary={}
var pavement_components: Dictionary={}

func build(owner: Node) -> void:
	life=owner
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
	var result: Dictionary={}
	for radius in range(11):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				if abs(x)!=radius and abs(z)!=radius:continue
				var point := cell+Vector2i(x,z)
				if not pavement_components.has(point):continue
				var component: int=pavement_components[point]
				if result.has(component):continue
				var approach: Array[Vector2i]=life.grid.get_id_path(cell,point,false)
				if not approach.is_empty() and approach.size()<=35:result[component]={"point":point,"length":approach.size()}
	return result

func path(from: Vector3,to: Vector3,person: Node,avoid_people: bool) -> Array[Vector2i]:
	var start: Vector2i=life.free_cell(from)
	var finish: Vector2i=life.free_cell(to)
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
