extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	stage.add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(80,1,20)
	floor_shape.shape=box
	floor_shape.position.y=-0.5
	floor_body.add_child(floor_shape)
	var people: Array[CharacterBody3D]=[]
	for style in ["medieval","worker","witch","adventurer","knight","viking","mercenary","night_hunter","emlyn"]:
		var person: CharacterBody3D=load("res://villager.gd").new()
		person.style=style
		person.person_name=style
		person.position=Vector3(people.size()*3,0.01,0)
		stage.add_child(person)
		person.set_physics_process(false)
		people.append(person)
	var failures: Array[String]=[]
	for clip in ["Idle","Walk","Run"]:
		for person in people:person.animate(clip)
		for frame in range(120):await physics_frame
		for person in people:
			var grounding: SkeletonModifier3D=person.visual.find_child("GroundedFeet",true,false)
			print("GROUND_CONTACT style=",person.style," clip=",clip," feet=",grounding.feet.size()," error=",grounding.contact_error," visual_offset=",grounding.offset)
			if grounding.feet.size()!=2 or absf(grounding.contact_error)>0.08:failures.append(person.style+" "+clip+" feet gap")
	print("GROUNDING_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
