extends SceneTree

class Walker extends "res://villager.gd":
	var stride:=1
	var ticks:=0
	var test_pace:=1.0
	func _ready() -> void:pass
	func _physics_process(delta: float) -> void:
		ticks+=1
		if ticks%stride!=0:return
		velocity=Vector3(test_pace,-2,0)
		move_with_steps(delta*stride)

func _initialize() -> void:run.call_deferred()

func run() -> void:
	Engine.physics_ticks_per_second=30
	var stage:=Node3D.new();root.add_child(stage)
	var floor_body:=StaticBody3D.new();stage.add_child(floor_body)
	var floor_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new()
	floor_box.size=Vector3(20,.2,20);floor_shape.shape=floor_box;floor_shape.position.y=-.1;floor_body.add_child(floor_shape)
	var walkers: Array[CharacterBody3D]=[]
	for index in range(2):
		var walker:=Walker.new();stage.add_child(walker)
		walker.stride=1 if index==0 else 3
		walker.position=Vector3(0,.02,index*2)
		var collider:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
		capsule.radius=.3;capsule.height=1.7;collider.shape=capsule;collider.position.y=.85;walker.add_child(collider)
		walkers.append(walker)
	for frame in range(30):await physics_frame
	for index in range(2):
		walkers[index].position=Vector3(0,.02,index*2)
		walkers[index].ticks=0
	for frame in range(90):
		await physics_frame
	print("MOVEMENT_BUDGET_DISTANCES ",walkers[0].position," ",walkers[1].position)
	assert(absf(walkers[0].position.x-walkers[1].position.x)<.11)
	assert(absf(walkers[1].position.x-3.0)<.20)
	var wall:=StaticBody3D.new();stage.add_child(wall)
	var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new()
	wall_box.size=Vector3(.1,3,8);wall_shape.shape=wall_box;wall_shape.position=Vector3(4,1.5,0);wall.add_child(wall_shape)
	walkers[1].test_pace=2.0
	for frame in range(60):
		await physics_frame
	assert(walkers[1].position.x<3.8)
	print("MOVEMENT_BUDGET_REVIEW_COMPLETE distance_preserved=true swept_wall_collision=true x=",walkers[1].position.x)
	quit()
