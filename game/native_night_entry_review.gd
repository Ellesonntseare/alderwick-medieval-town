extends SceneTree

class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass
	func _unhandled_input(_event: InputEvent) -> void:pass
class District extends "res://native_districts.gd":
	func _ready() -> void:
		town=get_parent();layout=JSON.parse_string(FileAccess.get_file_as_string("res://downloaded/native-interiors.json"))
class Jobs extends Node3D:
	func suspend(_person: Node) -> void:pass
class Life extends "res://village_life.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func route_to_door(_person: CharacterBody3D,door: Node3D) -> PackedVector3Array:
		return PackedVector3Array([door.get_closed_transform()*Vector3(door.width/2,.04,-1.3)])
var failures: Array[String]=[]

func _initialize() -> void:run.call_deferred()

func run() -> void:
	Engine.max_fps=0
	var town:=Town.new();root.add_child(town);town.world()
	town.jobs=Jobs.new();town.add_child(town.jobs)
	town.life=Life.new();town.life.town=town;town.add_child(town.life)
	town.life.traffic=load("res://street_traffic.gd").new();town.life.traffic.life=town.life
	town.player=CharacterBody3D.new();town.add_child(town.player);town.player.position=Vector3(0,0,500)
	var district:=District.new();town.add_child(district)
	for spec in [["viking_hall","Viking Great Hall",Vector3(-99,0,-15),"hall",Vector3(-98.7461,-.051631,-22.60056)],
		["viking_house","Viking Residence",Vector3(-100,0,15),"home",Vector3(-99.76295,-.058016,7.492792)],
		["boathouse","Veya Boathouse",Vector3(53,0,85),"workshop",Vector3(52.75492,-.05466,76.49892)],
		["medieval_house","Northern Longhouse",Vector3(-33,0,-89),"home",Vector3(-32.73888,-.052641,-95.20054)]]:
		if "--first" in OS.get_cmdline_user_args() and spec[0]!="viking_hall":continue
		district.make_native_building(spec[0],spec[1],spec[2],spec[3])
		var door: Node3D=district.entrances[-1].door
		var person: CharacterBody3D=load("res://villager.gd").new()
		person.life=town.life;person.style="worker";person.person_name="Entry review"
		town.add_child(person);person.set_physics_process(false);town.life.people.append(person)
		person.position=spec[4]
		for frame in range(12):await physics_frame;person.rest(1.0/60)
		person.assigned_bed=town.life.reserve_bed(person,door.get_parent())
		person.head_home(door,PackedVector3Array([door.get_closed_transform()*Vector3(door.width/2,.04,-1.3)]))
		for frame in range(600 if "--first" in OS.get_cmdline_user_args() else 1500):
			await physics_frame;person.process_night(1.0/60)
			if "--first" in OS.get_cmdline_user_args() and frame in [1,60,180]:
				var probes: Array=[]
				var desired: Vector3=person.night_path[person.night_index]-person.position if person.night_index<person.night_path.size() else Vector3.ZERO
				desired.y=0
				for lift in [.03,.32,.4]:
					var pose: Transform3D=person.global_transform;pose.origin.y+=lift
					probes.append({"lift":lift,"blocked":person.test_move(pose,desired.normalized()*.04)})
				print("NATIVE_NIGHT_PROBE grounded=",person.is_on_floor()," velocity=",person.velocity," step_probes=",person.movement_step_probes," at=",person.position," probes=",probes)
			if person.posture=="sleeping":break
		print("NATIVE_NIGHT_ENTRY title=",spec[1]," sleeping=",person.posture=="sleeping"," stage=",person.night_stage," position=",person.position," target=",person.night_path[person.night_index] if person.night_index<person.night_path.size() else Vector3.INF)
		if person.posture!="sleeping":
			failures.append(spec[1]+" failed night entry")
			for index in range(person.get_slide_collision_count()):
				var hit: KinematicCollision3D=person.get_slide_collision(index)
				print("NATIVE_NIGHT_CONTACT collider=",hit.get_collider().get_path()," point=",hit.get_position()," normal=",hit.get_normal())
		town.life.traffic.release_door(person);town.life.people.erase(person);person.free()
	print("NATIVE_NIGHT_ENTRY_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
