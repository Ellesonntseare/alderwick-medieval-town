extends SceneTree

class Resident extends "res://villager.gd":
	func _ready() -> void:pass
	func _physics_process(_delta: float) -> void:pass

var failures: Array[String]=[]
var stage: Node3D

func _initialize() -> void:run.call_deferred()

func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func box(size: Vector3,point: Vector3) -> void:
	var body:=StaticBody3D.new();stage.add_child(body);body.position=point
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size
	collision.shape=shape;body.add_child(collision)

func resident(point: Vector3) -> Resident:
	var person:=Resident.new();stage.add_child(person)
	person.position=point;person.collision_layer=2;person.collision_mask=3
	var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
	capsule.radius=.3;capsule.height=1.7;collision.shape=capsule;collision.position.y=.85;person.add_child(collision)
	person.visual=Node3D.new();person.add_child(person.visual)
	person.animator=AnimationPlayer.new();person.add_child(person.animator)
	var library:=AnimationLibrary.new()
	for name in ["Idle","Walk","Run"]:
		var animation:=Animation.new();animation.length=1;animation.loop_mode=Animation.LOOP_LINEAR;library.add_animation(name,animation)
	person.animator.add_animation_library("",library)
	return person

func run() -> void:
	Engine.max_fps=0
	stage=Node3D.new();root.add_child(stage)
	box(Vector3(60,.2,60),Vector3(0,-.1,0))
	var person:=resident(Vector3(-10,.03,-12))
	for frame in range(120):
		await physics_frame;person.rest(1.0/60)
	var standing:=person.position
	for frame in range(120):
		await physics_frame;person.rest(1.0/60)
	check(person.position.distance_to(standing)<.01,"Resting on flat ground must remain stable")
	for frame in range(180):
		await physics_frame;person.move_direction(Vector3.RIGHT,1.5,1.0/60)
	check(absf(person.position.x-standing.x-4.5)<.25,"Flat-ground walking must preserve requested distance")
	check(absf(person.position.y)<.08,"Flat-ground walking must remain grounded")
	print("MOVEMENT_FLAT position=",person.position)
	person.free()
	for index in range(3):
		var height: float=(index+1)*.2
		box(Vector3(1,height,2),Vector3(-8+index,height/2,-4))
	box(Vector3(3,.6,2),Vector3(-4,.3,-4))
	person=resident(Vector3(-10,.03,-4))
	var highest:=0.0
	for frame in range(330):
		await physics_frame
		if person.position.x< -4.8:person.move_direction(Vector3.RIGHT,1.5,1.0/60)
		else:person.rest(1.0/60)
		highest=maxf(highest,person.position.y)
	check(person.position.x> -5.1 and person.position.y>.5,"Residents must climb ordinary 20 cm stairs")
	print("MOVEMENT_STAIRS position=",person.position," highest=",highest)
	person.free()
	box(Vector3(.5,3,3),Vector3(0,1.5,4))
	person=resident(Vector3(-3,.03,4))
	for frame in range(180):
		await physics_frame;person.move_direction(Vector3.RIGHT,2.0,1.0/60)
	check(person.position.x< -.5 and person.position.x> -1,"A solid wall must stop the resident capsule")
	check(person.position.y<.1,"Wall contact must not lift a resident onto the wall")
	print("MOVEMENT_WALL position=",person.position)
	person.free()
	person=resident(Vector3(-10,.03,12))
	for frame in range(12):await physics_frame;person.rest(1.0/60)
	var start:=person.position
	for frame in range(360):
		await physics_frame
		if frame%6==5:person.move_direction(Vector3.RIGHT,1.5,.1)
	check(absf(person.position.x-start.x-9)<.35,"Budgeted 10 Hz movement must preserve walking distance")
	check(absf(person.position.y)<.12,"Budgeted movement must remain on the floor")
	print("MOVEMENT_BUDGETED position=",person.position," distance=",person.position.x-start.x)
	person.free()
	# A skipped resting tick must not cache support after the platform disappears.
	var platform:=StaticBody3D.new();stage.add_child(platform);platform.position=Vector3(18,1.9,18)
	var platform_collision:=CollisionShape3D.new();var platform_shape:=BoxShape3D.new()
	platform_shape.size=Vector3(3,.2,3);platform_collision.shape=platform_shape;platform.add_child(platform_collision)
	person=resident(Vector3(18,2.03,18))
	for frame in range(120):await physics_frame;person.rest(1.0/60)
	var platform_height:=person.position.y
	check(platform_height>1.9,"Resident must first settle on the raised platform")
	platform.queue_free()
	for frame in range(40):await physics_frame;person.rest(1.0/60)
	check(person.position.y<platform_height-.5,"A resting resident must notice removed support and fall")
	print("MOVEMENT_REMOVED_SUPPORT before=",platform_height," after=",person.position.y)
	person.free()
	# Fast/slow simulation must change elapsed game time, not multiply velocity
	# again inside CharacterBody3D's own time-scaled physics integration.
	for scale_value: float in [.5,3.0]:
		Engine.time_scale=scale_value
		for budgeted: bool in [false,true]:
			person=resident(Vector3(-10,.03,20))
			for frame in range(12):await physics_frame;person.rest(scale_value/60)
			var origin:=person.position
			for frame in range(60):
				await physics_frame
				if not budgeted or frame%6==5:person.move_direction(Vector3.RIGHT,1.5,scale_value*(.1 if budgeted else 1.0/60))
			var actual:=person.position.x-origin.x
			var expected:=1.5*scale_value
			check(absf(actual-expected)<.15,"Time scaling must preserve normal and budgeted travel per game second")
			print("MOVEMENT_TIME_SCALE scale=",scale_value," budgeted=",budgeted," expected=",expected," actual=",actual)
			person.free()
	Engine.time_scale=1.0
	print("MOVEMENT_REGRESSION_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
