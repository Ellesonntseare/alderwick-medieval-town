extends SceneTree

class ReviewTown extends Node3D:
	var life: Node
	var day_night: Node
	var routines: Node
	func box(parent: Node3D,size: Vector3,point: Vector3,color: Color,_collision: bool) -> MeshInstance3D:
		var part:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;part.mesh=mesh;parent.add_child(part);part.position=point
		var material:=StandardMaterial3D.new();material.albedo_color=color;part.material_override=material;return part
class ReviewLife extends Node:
	var people: Array[CharacterBody3D]=[]
	func route_to_point(_person: CharacterBody3D,point: Vector3) -> PackedVector3Array:return PackedVector3Array([point])
class ReviewDay extends Node:
	var night:=false
class ReviewRoutines extends Node:
	var elapsed:=0.0
	func available(person: CharacterBody3D) -> bool:return person.routine.is_empty()
class ReviewActions extends Node3D:
	var town: Node3D
	var reservations: Dictionary={}
	func clear_work(_person: CharacterBody3D) -> void:pass

func _initialize() -> void:run.call_deferred()
func run() -> void:
	var town:=ReviewTown.new();root.add_child(town)
	town.life=ReviewLife.new();town.add_child(town.life)
	town.day_night=ReviewDay.new();town.add_child(town.day_night)
	town.routines=ReviewRoutines.new();town.add_child(town.routines)
	var actions:=ReviewActions.new();actions.town=town;town.add_child(actions)
	var school:=preload("res://archery_school.gd").new();actions.add_child(school)
	var styles: Array=["cult_archer","runner_youth","runner_child","medieval_woman","female_ranger","witch","medieval","robed_scholar","female_peasant","emlyn"]
	var names: Array=["Fenn","Theo","Ollie","Roslin","Elowen","Agnes","Alden","Ivor","Lysa","Mina"]
	var failures: Array[String]=[]
	for index in range(10):
		var person: CharacterBody3D=preload("res://villager.gd").new()
		person.person_name=names[index];person.style=styles[index];person.appearance_height=.75 if index==2 else 1.0
		var model: Node3D=load("res://characters/"+styles[index]+".glb").instantiate();town.add_child(model)
		person.visual=model;person.animator=person.find_animator(model)
		preload("res://motion_library.gd").attach(model,person.animator)
		town.life.people.append(person)
	school.bind()
	await process_frame
	if school.pupils.size()!=10:failures.append("Expected ten actual residents")
	if actions.reservations.size()!=10:failures.append("Each trainee needs a unique lane reservation")
	for person in school.pupils:
		person.visual.position=person.position
		person.routine.stage="working"
	for frame in range(370):
		for person in school.pupils:
			person.routine.timer=float(frame)/60
			school.tick(person,1.0/60)
			person.animator.advance(1.0/60)
		if frame%60==0:await process_frame
	if school.shots<10:failures.append("All ten trainees must release arrows")
	if school.bows.size()!=10:failures.append("All ten trainees need hand-fitted bows")
	for person in school.pupils:
		var state: Dictionary=school.bows[person]
		var hand: Vector3=state.rig.global_transform*state.rig.get_bone_global_pose(state.left).origin
		var bow_centre: Vector3=(state.parts[0].global_position+state.parts[7].global_position)*.5
		if hand.distance_to(bow_centre)>.12:failures.append(person.person_name+" bow lost left hand")
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1440,700)
		var light:=DirectionalLight3D.new();town.add_child(light);light.rotation_degrees=Vector3(-45,-30,0)
		var world:=WorldEnvironment.new();town.add_child(world);world.environment=Environment.new();world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.7
		var camera:=Camera3D.new();town.add_child(camera);camera.position=Vector3(35,12,27);camera.look_at(Vector3(35,0,43));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=29
		town.box(town,Vector3(31,.08,21),Vector3(35,-.1,43),Color("68784b"),false)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../review/archery-ten-trainees.png")
	town.day_night.night=true
	for person in school.pupils:
		school.cleanup(person);person.routine={}
		if school.begin(person):failures.append("Night must prevent archery class")
	if not school.bows.is_empty():failures.append("Practice bows must be removed at night")
	print("ARCHERY_SCHOOL_REVIEW pupils=",school.pupils.size()," shots=",school.shots," failures=",failures)
	for person in town.life.people:person.free()
	quit(0 if failures.is_empty() else 1)
