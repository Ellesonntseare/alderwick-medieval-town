extends SceneTree

class Agent extends CharacterBody3D:
	var appearance_build := 1.0
	var posture := "standing"
	var style := ""
	var night_schedule := false
	var home_door: Node3D
	var night_stage := ""
	var queue_target := Vector3.INF

class Fixture extends Node:
	var people: Array=[]
	var town: Node
	var player: Node3D

var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(value: bool,message: String) -> void:
	if value:return
	failures.append(message)
	push_error(message)

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	stage.add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape=BoxShape3D.new()
	floor_shape.shape.size=Vector3(30,0.2,30)
	floor_shape.position.y= -0.1
	floor_body.add_child(floor_shape)
	var fixture := Fixture.new()
	stage.add_child(fixture)
	fixture.town=fixture
	fixture.player=Node3D.new()
	stage.add_child(fixture.player)
	fixture.player.position=Vector3(10,0,10)
	var agents: Array[Agent]=[]
	for index in range(2):
		var agent := Agent.new()
		stage.add_child(agent)
		agent.collision_layer=2
		agent.collision_mask=3
		var collider := CollisionShape3D.new()
		collider.shape=CapsuleShape3D.new()
		collider.shape.radius=0.3
		collider.shape.height=1.7
		collider.position.y=0.85
		agent.add_child(collider)
		agent.position=Vector3(-3 if index==0 else 3,0.02,0)
		agents.append(agent)
	fixture.people.assign(agents)
	var traffic := preload("res://street_traffic.gd").new()
	traffic.life=fixture
	for index in range(100):
		var distant:=Agent.new()
		stage.add_child(distant)
		distant.position=Vector3(100+index*5,0,100)
		fixture.people.append(distant)
	check(traffic.nearby_people(agents[0],1.5).size()==2,"Distant districts must not participate in a local crowd check")
	check(traffic.people_near(agents[0].position,12.0).size()==2,"Conversation searches reuse nearby cells and exclude distant districts")
	var minimum := INF
	var done := false
	for frame in range(900):
		await physics_frame
		done=true
		for index in range(2):
			var goal := Vector3(3 if index==0 else -3,0,0)
			var difference := goal-agents[index].position
			difference.y=0
			var velocity := Vector3.ZERO
			if difference.length()>0.15:
				done=false
				velocity=traffic.steer(agents[index],difference.normalized(),minf(1.5,difference.length()*60),1.0/60)
			agents[index].velocity=Vector3(velocity.x,-2,velocity.z)
			agents[index].move_and_slide()
		minimum=minf(minimum,agents[0].position.distance_to(agents[1].position))
		if done:break
	check(done and minimum>=0.65,"Opposing pedestrians must pass each other with body clearance")
	print("CROWD_PASS_CHECK done=",done," minimum_gap=",minimum," positions=",agents[0].position," ",agents[1].position)
	for index in range(2):
		agents[index].style="same_model"
		agents[index].position=Vector3(-4 if index==0 else 4,0.02,0)
	minimum=INF
	done=false
	for frame in range(1200):
		await physics_frame
		done=true
		for index in range(2):
			var goal := Vector3(4 if index==0 else -4,0,0)
			var difference := goal-agents[index].position
			difference.y=0
			var velocity := Vector3.ZERO
			if difference.length()>0.15:
				done=false
				velocity=traffic.steer(agents[index],difference.normalized(),minf(1.5,difference.length()*60),1.0/60)
			agents[index].velocity=Vector3(velocity.x,-2,velocity.z)
			agents[index].move_and_slide()
		minimum=minf(minimum,agents[0].position.distance_to(agents[1].position))
		if done:break
	check(done and minimum>=1.3,"Residents sharing a model must pass with extra separation")
	print("MATCHING_MODEL_PASS done=",done," minimum_gap=",minimum)
	agents[0].style="one"
	agents[1].style="two"
	agents[0].position=Vector3(-3,0.02,5)
	agents[1].position=Vector3(0,0.02,5)
	var stationary: Vector3=agents[1].position
	done=false
	for frame in range(900):
		await physics_frame
		var difference := Vector3(3,0,5)-agents[0].position
		difference.y=0
		if difference.length()<0.15:done=true;break
		var velocity := traffic.steer(agents[0],difference.normalized(),minf(1.5,difference.length()*60),1.0/60)
		agents[0].velocity=Vector3(velocity.x,-2,velocity.z)
		agents[0].move_and_slide()
	check(done and agents[1].position.distance_to(stationary)<0.001,"Passers-by must go around a stationary guard without moving the guard")
	var door := Node3D.new()
	door.set_script(load("res://door.gd"))
	stage.add_child(door)
	check(traffic.request_door(agents[0],door)== -1,"First resident must own the doorway")
	check(traffic.request_door(agents[1],door)>=1,"Second resident must wait in line")
	traffic.release_door(agents[0])
	check(traffic.request_door(agents[1],door)== -1,"Door ownership must pass to the next queued resident")
	traffic.release_door(agents[1])
	print("TRAFFIC_REVIEW_COMPLETE failures=",failures," max_queue=",traffic.max_queue)
	quit(0 if failures.is_empty() else 1)
