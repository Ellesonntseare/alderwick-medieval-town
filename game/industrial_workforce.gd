extends Node3D

var town: Node3D
var workers: Dictionary={}
var grid:=AStarGrid2D.new()
var heights: Dictionary={}
var bound:=false
var deliveries:=0
var completed_work:=0
var gate:=Vector3(0,.03,58)
var clock:=0.0

func _ready() -> void:
	town=get_parent();name="IndustrialWorkforce";setup.call_deferred()

func setup() -> void:
	while not town.life.navigation_ready:await get_tree().process_frame
	# A separate corridor graph extends past the city grid into the new town.
	grid.region=Rect2i(-20,28,41,135);grid.cell_size=Vector2(2,2)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	var shape:=CapsuleShape3D.new();shape.radius=.42;shape.height=1.8
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	var space:=get_world_3d().direct_space_state
	for x in range(-20,21):
		for z in range(28,163):
			var id:=Vector2i(x,z);var p:=Vector3(x*2,0,z*2)
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*5,p-Vector3.UP*2,1))
			var y: float=hit.position.y if not hit.is_empty() else -10
			heights[id]=y;query.transform.origin=Vector3(p.x,y+1.02,p.z)
			grid.set_point_solid(id,y< -1 or y>1.6 or not space.intersect_shape(query,1).is_empty())
		if x%4==0:await get_tree().process_frame
	# Prevent routes across narrow walls and abrupt edges between sampled floors.
	var blocked: Array[Vector2i]=[]
	for id in heights:
		if grid.is_point_solid(id):continue
		for offset: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
			var next: Vector2i=id+offset
			if not grid.is_in_boundsv(next) or grid.is_point_solid(next):continue
			query.transform.origin=Vector3((id.x+next.x),maxf(heights[id],heights[next])+1.02,(id.y+next.y))
			if absf(heights[id]-heights[next])>.45 or not space.intersect_shape(query,1).is_empty():blocked.append(id);blocked.append(next)
	for id in blocked:grid.set_point_solid(id,true)
	var candidates: Array=["Jory","Kael","Duncan","Finn","Corvin","Beren","Elric","Torren"]
	for name in candidates:
		for person in town.life.people:
			if person.person_name!=name or person.indoor_house or not person.guard_label.is_empty() or not person.stall_name.is_empty():continue
			if workers.size()>=6:break
			var index:=workers.size();var post:=nearest(Vector3(-12+index*5,0,280+(index%3)*10))
			if post.y<0:continue
			var route:=route_between(gate,post)
			if route.is_empty():continue
			var role: String=["Timber supplier","Tool carrier","Warehouse courier","Workshop carpenter","Goods clerk","Yard supplier"][index]
			person.occupation=role
			if person.get("label"):person.label.text=person.person_name+" · "+role
			person.job={"kind":"industrial","stage":"commuting","district":"industrial"}
			person.set_meta("industrial_worker",true)
			person.routine={};person.path=PackedVector3Array();person.path_index=0
			if person.social_partner:person.end_social()
			var state: Dictionary={"post":post,"phase":"work" if index<2 else "outbound" if index%2==0 else "inbound","timer":8.0+index*4,"route":PackedVector3Array(),"index":0,"stuck":0.0,"produced":0,"output":null,"has_goods":index>=2 and index%2==1}
			workers[person]=state
			if state.has_goods and person.has_method("set_carry"):person.set_carry("supplies")
			var point:=post if index<2 else nearest(Vector3(1 if index%2==0 else -1,0,85+(index-2)*48))
			person.position=point
			make_workplace(person,state,index)
			plan(person,state,post if state.phase=="outbound" else gate)
			person.recent_events.append({"kind":"employment","text":"I now take shifts at the industrial town and carry supplies along the southern road."})
	bound=true
	print("INDUSTRIAL_WORKFORCE_READY workers=",workers.size()," residents=",town.life.people.size()," road_routes=true")

func nearest(point: Vector3) -> Vector3:
	var best:=Vector3(0,-10,0);var distance:=INF
	for id in heights:
		if grid.is_point_solid(id):continue
		var p:=Vector3(id.x*2,heights[id]+.03,id.y*2)
		var gap:=p.distance_squared_to(point)
		if gap<distance:distance=gap;best=p
	return best

func route_between(a: Vector3,b: Vector3) -> PackedVector3Array:
	var from:=nearest(a);var to:=nearest(b);var result:=PackedVector3Array()
	if from.y< -1 or to.y< -1:return result
	var ids:=grid.get_id_path(Vector2i(roundi(from.x/2),roundi(from.z/2)),Vector2i(roundi(to.x/2),roundi(to.z/2)),false)
	for id in ids:result.append(Vector3(id.x*2,heights[id]+.03,id.y*2))
	return result

func plan(person: Node,state: Dictionary,goal: Vector3) -> void:
	state.route=route_between(person.position,goal);state.index=0;state.stuck=0.0

func make_workplace(person: Node,state: Dictionary,index: int) -> void:
	var root:=Node3D.new();add_child(root);root.position=state.post+Vector3(1.5,0,0)
	town.detailed_prop("Workbench_Drawers" if index==3 else "Crate_Wooden",root,Vector3.ZERO,Vector3(1.3,.85,.7),false)
	var output:=Node3D.new();add_child(output);output.position=state.post+Vector3(-1.5,0,0);state.output=output
	var label:=Label3D.new();root.add_child(label);label.text=person.person_name+" · "+person.occupation
	label.position.y=1.65;label.font_size=19;label.pixel_size=.004;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED

func intercept_home(person: CharacterBody3D) -> bool:
	if not bound or not workers.has(person) or person.position.z<66:return false
	var state: Dictionary=workers[person]
	state.phase="inbound";person.night_schedule=false
	plan(person,state,gate);return true

func tick(person: CharacterBody3D,delta: float) -> bool:
	if not bound or not workers.has(person):return false
	var state: Dictionary=workers[person]
	if state.phase=="home":
		if town.day_night.night or person.night_schedule:return false
		if not person.routine.is_empty():return false
		state.timer-=delta
		if state.timer>0:return false
		# Leave existing family homes through their actual doorway first.
		var approach: PackedVector3Array=town.life.route_to_point(person,gate)
		if approach.is_empty():return false
		state.phase="outbound";state.route=approach;state.index=0;state["joining"]=true
		person.job.stage="commuting"
	if not person.routine.is_empty():return false
	if town.day_night.night and state.phase!="inbound":
		state.phase="inbound";person.night_schedule=false;plan(person,state,gate)
	if state.phase=="work":
		person.rest(delta);person.animate("WorkTable" if person.occupation=="Workshop carpenter" else "Interact")
		person.activity="Working in the industrial town · "+person.occupation
		state.timer-=delta
		if state.timer<=0:
			completed_work+=1;state.produced+=1
			if state.produced<=3:town.detailed_prop("Crate_Wooden",state.output,Vector3(0,(state.produced-1)*.35,0),Vector3(.6,.35,.5),false)
			town.economy.pay(person,"supply");state.has_goods=true
			if person.has_method("set_carry"):person.set_carry("supplies")
			if town.character_life and town.character_life.bound:town.character_life.worked(person,"crafted" if person.occupation=="Workshop carpenter" else "supply")
			state.phase="inbound";plan(person,state,gate)
		return true
	person.activity="Returning to Alderwick with workshop supplies" if state.phase=="inbound" else "Walking to work in the industrial town"
	var route: PackedVector3Array=state.route
	while int(state.index)<route.size() and Vector2(person.position.x-route[state.index].x,person.position.z-route[state.index].z).length()<.4:state.index+=1
	if int(state.index)>=route.size():
		if state.get("joining",false):state.joining=false;plan(person,state,state.post);return true
		var goal: Vector3=state.post if state.phase=="outbound" else gate
		if Vector2(person.position.x-goal.x,person.position.z-goal.z).length()>3:
			person.rest(delta);state.stuck+=delta
			if state.stuck>2:plan(person,state,goal)
			return true
		if state.phase=="outbound":state.phase="work";state.timer=24+posmod(person.person_name.hash(),25)
		else:
			if state.has_goods:deliveries+=1;town.jobs.supply_stock.city+=1
			state.has_goods=false
			if person.has_method("set_carry"):person.set_carry("")
			person.recent_events.append({"kind":"delivery","text":"I brought supplies back from the industrial workshops."})
			if person.recent_events.size()>12:person.recent_events.pop_front()
			state.phase="home";state.timer=18+posmod(person.person_name.hash(),25)
			person.job.stage="break"
			if town.day_night.night:town.life.assign_home(person)
			else:person.plan()
		return true
	var direction: Vector3=route[state.index]-person.position;direction.y=0
	var before: Vector3=person.position
	person.move_direction(direction.normalized(),minf(2.0,direction.length()/delta),delta)
	person.travelled+=person.position.distance_to(before)
	state.stuck=state.stuck+delta if person.position.distance_to(before)<.005 else 0.0
	if state.stuck>2:
		var blocked:=Vector2i(roundi(route[state.index].x/2),roundi(route[state.index].z/2))
		if grid.is_in_boundsv(blocked):grid.set_point_solid(blocked,true)
		plan(person,state,gate if state.phase=="inbound" else state.post)
	return true
