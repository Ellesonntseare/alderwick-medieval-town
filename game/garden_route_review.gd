extends SceneTree
class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
class Life extends "res://village_life.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
class Cooking extends "res://town_cooking.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
class Day extends Node:
	var night:=false
class Jobs extends Node3D:
	var records:=0
	func record(_person: Node,_kind: String,_text: String) -> void:records+=1
class Routines extends Node:
	var town: Node3D
	var actions: Node3D
	func available(person: Node) -> bool:return person.routine.is_empty() and person.posture=="standing"
	func cancel(person: Node) -> void:actions.cleanup(person);person.routine={}
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	Engine.max_fps=0
	var town:=Town.new();root.add_child(town);town.world();town.town()
	town.life=Life.new();town.life.town=town;town.add_child(town.life)
	town.day_night=Day.new();town.add_child(town.day_night)
	town.jobs=Jobs.new();town.add_child(town.jobs)
	town.routines=Routines.new();town.routines.town=town;town.add_child(town.routines)
	town.routines.actions=load("res://resident_actions.gd").new();town.routines.add_child(town.routines.actions)
	town.cooking=Cooking.new();town.cooking.town=town;town.add_child(town.cooking);town.cooking.build_garden()
	var life: Node=town.life
	life.grid.region=Rect2i(-75,-65,151,131);life.grid.cell_size=Vector2.ONE;life.grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;life.grid.update()
	life.traffic=load("res://street_traffic.gd").new();life.traffic.life=life
	var person: CharacterBody3D=load("res://villager.gd").new();person.person_name="Roslin";person.style="medieval_woman";person.occupation="Herbalist";person.life=life
	person.position=Vector3(31.5,.06,38);person.walking_policy="open";person.set_meta("district","city")
	town.add_child(person);person.set_physics_process(false);life.people.append(person)
	for frame in range(3):await physics_frame
	var shape:=CapsuleShape3D.new();shape.radius=.44;shape.height=1.7
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	var space:=town.get_world_3d().direct_space_state
	for x in range(-75,76):
		for z in range(-65,66):
			var cell:=Vector2i(x,z)
			var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,.4,z),Vector3(x,-1,z),1))
			var y: float=floor_hit.position.y if not floor_hit.is_empty() else -10
			life.floor_heights[cell]=y;query.transform.origin=Vector3(x,y+.94,z)
			var blocked:=y< -1 or not space.intersect_shape(query,1).is_empty()
			life.grid.set_point_solid(cell,blocked)
			if not blocked:life.street_cells[cell]=true
	var began: bool=town.routines.actions.begin(person,"garden")
	if not began:failures.append("Roslin must have a route from her actual archery lane to the garden")
	print("GARDEN_ROUTE_START began=",began," nodes=",person.path.size()," target=",person.routine.get("target"))
	if began:
		for frame in range(6000):
			town.routines.actions.tick(person,1.0/60)
			if town.routines.actions.completed.garden>0:break
			await physics_frame
		if town.routines.actions.completed.garden!=1:failures.append("Herbalist must physically arrive and finish tending the garden")
	print("GARDEN_ROUTE_REVIEW_COMPLETE failures=",failures," position=",person.position," garden=",town.routines.actions.completed.garden)
	quit(0 if failures.is_empty() else 1)
