extends SceneTree

class Person extends "res://villager.gd":
	func _ready() -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func rest(_delta: float) -> void:pass
	func follow_path(_delta: float,_pace: float) -> bool:return true
class ReviewTown extends Node3D:
	var life: Node
	var day_night: Node
	var routines: Node
	var player: Node3D
	var character_life: Node
	var jobs: Node
	var festival: Node3D
	var locations: Array=[]
	var view_mode:=0
	var overview_focus:=Vector3.ZERO
	func box(parent: Node3D,size: Vector3,point: Vector3,color: Color,_collision:=false) -> MeshInstance3D:
		var part:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;part.mesh=mesh;parent.add_child(part);part.position=point
		var material:=StandardMaterial3D.new();material.albedo_color=color;part.material_override=material;return part
class ReviewLife extends Node:
	var people: Array=[]
	var town: Node3D
	var navigation_ready:=false
	var active: Node
	var traffic: RefCounted
	func route_to_point(_person: Node,destination: Vector3) -> PackedVector3Array:return PackedVector3Array([destination])
class ReviewDay extends Node:
	var night:=false
	var enabled:=false
	var phase:=.5
class ReviewActions extends Node:
	func clear_work(_person: Node) -> void:pass
class ReviewRoutines extends Node:
	var paused:=false
	var actions: Node
	var festival: Node
	func available(person: Node) -> bool:return person.routine.is_empty() and not person.talking and not person.night_schedule
	func cancel(person: Node) -> void:festival.cleanup(person);person.routine={}
class ReviewJobs extends Node:
	var memories:=0
	func record(_person: Node,_kind: String,_text: String) -> void:memories+=1
class ReviewNeeds extends Node:
	var bound:=false
	func feel(_name: String,_mood: String,_seconds: float) -> void:pass

func _initialize() -> void:run.call_deferred()
func run() -> void:
	var town:=ReviewTown.new();root.add_child(town)
	town.life=ReviewLife.new();town.add_child(town.life);town.life.town=town
	town.day_night=ReviewDay.new();town.add_child(town.day_night)
	town.routines=ReviewRoutines.new();town.add_child(town.routines);town.routines.actions=ReviewActions.new();town.routines.add_child(town.routines.actions)
	town.jobs=ReviewJobs.new();town.add_child(town.jobs);town.character_life=ReviewNeeds.new();town.add_child(town.character_life)
	town.player=Node3D.new();town.add_child(town.player);town.player.position=Vector3(-29,0,24)
	var styles: Array=["worker","female_peasant","male_ranger","medieval_woman","emlyn","witch"]
	for index in range(6):
		var person:=Person.new();town.add_child(person);person.person_name="Dancer"+str(index);person.life=town.life
		person.style=styles[index];person.position=town.player.position+Vector3(index,0,0)
		person.visual=load("res://characters/"+styles[index]+".glb").instantiate();person.add_child(person.visual)
		person.animator=person.find_animator(person.visual);preload("res://motion_library.gd").attach(person.visual,person.animator)
		person.equipment_nodes=[]
		town.life.people.append(person)
	town.festival=preload("res://town_festival.gd").new();town.routines.festival=town.festival;town.add_child(town.festival)
	town.life.navigation_ready=true
	await process_frame;await process_frame
	var festival: Node=town.festival
	assert(festival.members.size()==6 and festival.slots.size()==6)
	assert(festival.music.stream!=null and festival.music.stream.loop and festival.music.stream.get_length()>10)
	assert(is_equal_approx(festival.audible_gain(Vector3(-29,0,24)),1.0))
	assert(festival.audible_gain(Vector3(-9,0,24))<.5 and festival.audible_gain(Vector3(5,0,24))==0)
	for person in town.life.people:
		person.position=person.routine.target;person.path_index=person.path.size()
		festival.tick(person,.1)
		assert(person.routine.stage=="dancing" and person.animator.current_animation==festival.dance_clip(person))
	festival.update_music(1)
	assert(festival.music.playing and festival.music.volume_db> -25)
	var loud: float=festival.music.volume_db
	town.life.active=town.player;festival.update_music(1)
	assert(festival.music.volume_db<loud-5)
	town.life.active=null;town.view_mode=1;town.overview_focus=Vector3(-29,100,24)
	assert(festival.audible_gain(festival.listening_point())==1)
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1280,800)
		var light:=DirectionalLight3D.new();town.add_child(light);light.rotation_degrees=Vector3(-45,-25,0)
		var environment:=WorldEnvironment.new();town.add_child(environment);environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.6
		var camera:=Camera3D.new();town.add_child(camera);camera.position=Vector3(-19,7,12);camera.look_at(Vector3(-29,1,24));camera.fov=52
		town.box(town,Vector3(20,.1,20),Vector3(-29,-.12,24),Color("69784d"))
		for frame in range(40):
			await process_frame
			for person in town.life.people:festival.tick(person,1.0/60)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../review/village-dance-preview.png")
	var completed: Node=town.life.people[0]
	completed.routine.timer=completed.routine.dance_seconds
	festival.tick(completed,.1)
	assert(festival.completed==1 and town.jobs.memories==1 and not festival.members.has(completed))
	town.day_night.night=true
	for person in festival.members.keys():festival.tick(person,.1)
	assert(festival.members.is_empty() and festival.slots.is_empty())
	festival.update_music(10)
	assert(not festival.music.playing)
	town.day_night.night=false
	for person in town.life.people:person.set_meta("next_village_dance",0)
	festival.invite(true)
	assert(festival.members.size()==6)
	var worker: Node=town.life.people[0]
	worker.routine={"kind":"resident_action"}
	festival._process(.1)
	assert(not festival.members.has(worker) and worker.routine.kind=="resident_action")
	print("FESTIVAL_REVIEW_COMPLETE dancers=6 actual_fitted_clips=true positional_fade=true overview_audio=true dialogue_duck=true night_cleanup=true completion_memory=true")
	quit()
