extends SceneTree

class Town extends Node3D:
	var expansion := Node3D.new()

class Life extends Node:
	var town: Node3D
	var grid := AStarGrid2D.new()
	var street_cells: Dictionary={}
	var people: Array[CharacterBody3D]=[]
	func free_cell(point: Vector3) -> Vector2i:return Vector2i(roundi(point.x),roundi(point.z))

class Person extends CharacterBody3D:
	var person_name := "walker"
	var walking_policy := "open"
	var night_schedule := false
	var indoor_house: Node3D
	var posture := "standing"

var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message)

func run() -> void:
	var town := Town.new()
	root.add_child(town)
	town.add_child(town.expansion)
	var lane := MeshInstance3D.new()
	town.expansion.add_child(lane)
	lane.set_meta("walking_lane",{"a":Vector3(2,0,2),"b":Vector3(2,0,12),"width":2.0})
	for spec in [[Vector3(2,0,12),Vector3(18,0,12)],[Vector3(18,0,12),Vector3(18,0,2)]]:
		var next := MeshInstance3D.new()
		town.expansion.add_child(next)
		next.set_meta("walking_lane",{"a":spec[0],"b":spec[1],"width":2.0})
	var life := Life.new()
	town.add_child(life)
	life.town=town
	life.grid.region=Rect2i(0,0,22,16)
	life.grid.update()
	for x in range(22):
		for z in range(16):life.street_cells[Vector2i(x,z)]=true
	var walker := Person.new()
	town.add_child(walker)
	life.people.append(walker)
	var routes=load("res://walking_routes.gd").new()
	routes.build(life)
	var start := Vector3(2,0,2)
	var end := Vector3(18,0,2)
	walker.walking_policy="open"
	var direct: Array[Vector2i]=routes.path(start,end,walker,false)
	check(direct.size()==17,"Open-area walker can take the clear direct route")
	walker.walking_policy="road"
	var road: Array[Vector2i]=routes.path(start,end,walker,false)
	check(road.size()>direct.size(),"Road follower uses the longer road instead of crossing the field")
	var on_road := 0
	for point in road:
		if routes.paved.has(point):on_road+=1
	check(on_road>=road.size()-2,"Road follower stays on the supplied road")
	walker.walking_policy="pavement"
	var pavement: Array[Vector2i]=routes.path(start,end,walker,false)
	check(not pavement.is_empty(),"Pavement route is connected")
	for point in pavement:check(routes.paved.has(point),"Pavement walker cannot cut across open ground")
	var obstacle := Person.new()
	obstacle.person_name="stationary resident"
	obstacle.position=Vector3(2,0,7)
	town.add_child(obstacle)
	life.people.append(obstacle)
	var passing: Array[Vector2i]=routes.path(start,end,walker,true)
	check(not passing.is_empty() and not passing.has(Vector2i(2,7)),"Walker finds a way around a stationary person")
	check(not routes.pavement_grid.is_point_solid(Vector2i(2,7)),"Temporary crowd avoidance must not corrupt navigation")
	routes.avoid(walker,Vector3(2,0,6))
	var recovered: Array[Vector2i]=routes.path(start,end,walker,false)
	check(not recovered.is_empty() and not recovered.has(Vector2i(2,6)),"Repeated obstacle recovery selects a different route")
	walker.night_schedule=true
	check(routes.path(start,end,walker,false).size()==direct.size(),"Home access remains available at night")
	print("WALKING_ROUTES_REVIEW_COMPLETE failures=",failures," direct=",direct.size()," road=",road.size()," pavement=",pavement.size())
	quit(0 if failures.is_empty() else 1)
