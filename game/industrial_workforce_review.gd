extends SceneTree
class FixtureTown extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass
	func _unhandled_input(_event: InputEvent) -> void:pass
class Expansion extends Node3D:
	func road(_points: Array,_width: float) -> void:pass
class Chateaux extends Node3D:
	var sites: Array=[]
class Economy extends Node:
	func pay(person: Node,_kind: String) -> void:person.coins+=2
class Jobs extends Node3D:
	var supply_stock: Dictionary={"city":0}
	func plan(person: Node) -> void:person.path=PackedVector3Array();person.path_index=0
class Day extends Node:
	var night:=false
class Life extends Node:
	var town: Node3D
	var traffic: RefCounted
	var navigation_ready:=true
	var people: Array=[]
	var homes:=0
	func route_to_point(person: Node,point: Vector3) -> PackedVector3Array:return PackedVector3Array([person.position,point])
	func assign_home(person: Node) -> bool:
		homes+=1;person.night_schedule=true
		# This fixture omits town houses: remove arrivals from the roadway,
		# representing handoff to the separately tested family-home system.
		person.position=Vector3(100+homes*2,0,50)
		return true
class Worker extends CharacterBody3D:
	var person_name: String
	var occupation:="Supplier"
	var indoor_house: Node3D
	var guard_label:=""
	var stall_name:=""
	var social_partner: Node
	var job: Dictionary={}
	var routine: Dictionary={}
	var path:=PackedVector3Array()
	var path_index:=0
	var recent_events: Array=[]
	var night_schedule:=false
	var travelled:=0.0
	var coins:=0
	var activity:=""
	func _ready() -> void:
		var collider:=CollisionShape3D.new();var shape:=CapsuleShape3D.new();shape.height=1.8;shape.radius=.35;collider.shape=shape;collider.position.y=.9;add_child(collider);collision_layer=2;collision_mask=1
	func move_direction(direction: Vector3,pace: float,delta: float) -> void:
		velocity=direction*pace;velocity.y=-2
		var motion:=direction*pace*delta
		if is_on_floor() and test_move(global_transform,motion):
			var probe:=global_transform;probe.origin.y+=.38
			if not test_move(global_transform,Vector3.UP*.38) and not test_move(probe,motion):position.y+=.38
		move_and_slide()
	func rest(_delta: float) -> void:velocity=Vector3(0,-2,0);move_and_slide()
	func animate(_clip: String) -> void:pass
	func plan() -> void:pass
	func end_social() -> void:pass
var failed: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	Engine.max_fps=0;Engine.time_scale=10
	var town:=FixtureTown.new();root.add_child(town);town.world()
	town.expansion=Expansion.new();town.add_child(town.expansion)
	town.chateaux=Chateaux.new();town.add_child(town.chateaux)
	var district: Node3D=load("res://neighbouring_town.gd").new();town.add_child(district)
	var forest: Node3D=load("res://forest_districts.gd").new();town.add_child(forest)
	town.life=Life.new();town.life.town=town;town.add_child(town.life)
	town.life.traffic=load("res://street_traffic.gd").new();town.life.traffic.life=town.life
	town.economy=Economy.new();town.add_child(town.economy)
	town.jobs=Jobs.new();town.add_child(town.jobs)
	town.day_night=Day.new();town.add_child(town.day_night)
	for name in ["Jory","Kael","Duncan","Finn","Corvin","Beren"]:
		var worker: CharacterBody3D
		if "--rigged" in OS.get_cmdline_user_args():
			worker=load("res://villager.gd").new()
			worker.style=["night_hunter","male_ranger","bruce","male_peasant","mercenary","witch"][town.life.people.size()]
			worker.life=town.life
		else:worker=Worker.new()
		worker.person_name=name;town.add_child(worker);worker.set_physics_process(false);town.life.people.append(worker)
	var manager: Node3D=load("res://industrial_workforce.gd").new();town.industrial_workforce=manager;town.add_child(manager)
	while not manager.bound:await physics_frame
	if manager.workers.size()!=6:failed.append("Six workers need a connected road to industrial work sites")
	var distance: Dictionary={}
	for worker in manager.workers:distance[worker.person_name]=worker.position.z
	for frame in range(2400):
		for worker in manager.workers:manager.tick(worker,1.0/6)
		await physics_frame
	for worker in manager.workers:
		print("INDUSTRIAL_WORKER_REVIEW ",worker.person_name," travelled=",worker.travelled," phase=",manager.workers[worker].phase," pos=",worker.position)
		if worker.travelled<15:failed.append(worker.person_name+" did not physically travel")
		if manager.workers[worker].produced<1:failed.append(worker.person_name+" did not reach and complete industrial work")
	if manager.completed_work<2:failed.append("Industrial work must complete")
	if manager.deliveries<2:failed.append("Supplies must return to town")
	town.day_night.night=true
	for worker in manager.workers:
		if not manager.intercept_home(worker):town.life.assign_home(worker)
	for frame in range(1500):
		for worker in manager.workers:manager.tick(worker,1.0/6)
		await physics_frame
	if town.life.homes<6:failed.append("All commuters must return to the city home system at night")
	for worker in manager.workers:print("INDUSTRIAL_NIGHT_END ",worker.person_name," ",manager.workers[worker].phase," ",worker.position)
	print("INDUSTRIAL_WORKFORCE_REVIEW_COMPLETE failures=",failed," jobs=",manager.completed_work," deliveries=",manager.deliveries," home_returns=",town.life.homes)
	quit(0 if failed.is_empty() else 1)
