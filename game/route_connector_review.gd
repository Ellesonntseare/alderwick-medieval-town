extends SceneTree
class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass
	func _unhandled_input(_event: InputEvent) -> void:pass
class Life extends "res://village_life.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
var failed: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	Engine.max_fps=0
	var town:=Town.new();root.add_child(town);town.world()
	town.life=Life.new();town.life.town=town;town.add_child(town.life)
	var life: Node=town.life
	life.grid.region=Rect2i(-5,-5,11,11);life.grid.cell_size=Vector2.ONE;life.grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;life.grid.update()
	town.interior_stool(town,Vector3.ZERO)
	var person: CharacterBody3D=load("res://villager.gd").new();person.style="worker";person.person_name="Oren";person.life=life;town.add_child(person);person.set_physics_process(false)
	person.position=Vector3(.47913,.03,.45512)
	life.people.append(person);life.traffic=load("res://street_traffic.gd").new();life.traffic.life=life
	for frame in range(3):await physics_frame
	var shape:=CapsuleShape3D.new();shape.radius=.44;shape.height=1.7
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	for x in range(-5,6):
		for z in range(-5,6):
			var cell:=Vector2i(x,z);life.floor_heights[cell]=0.0;query.transform.origin=Vector3(x,.9,z)
			var blocked:=not town.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
			life.grid.set_point_solid(cell,blocked)
			if not blocked:life.street_cells[cell]=true
	var remote:=Vector3(0,0,272)
	if not life.find_route(remote,Vector3(0,0,4)).is_empty():failed.append("City routing must reject an out-of-district start")
	if not life.find_route(person.position,remote).is_empty():failed.append("City routing must reject an out-of-district destination")
	person.path=life.find_route(person.position,Vector3(0,0,4),null,false,person)
	print("ROUTE_CONNECTOR_PATH ",person.path)
	if person.path.is_empty():failed.append("A reachable start connector must exist beside the stool")
	for frame in range(600):
		if person.follow_path(1.0/60,1.45):break
		await physics_frame
	if person.position.distance_to(Vector3(0,0,4))>.6:failed.append("Actual resident must walk around the stool corner")
	print("ROUTE_CONNECTOR_REVIEW_COMPLETE failures=",failed," final=",person.position)
	quit(0 if failed.is_empty() else 1)
