extends SceneTree

class FixtureTown extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass
	func _unhandled_input(_event: InputEvent) -> void:pass
class Life extends Node:
	var people: Array=[]
	func find_route(from: Vector3,to: Vector3,_person: Node=null,_avoid:=false) -> PackedVector3Array:return PackedVector3Array([from,to])
class Cycle extends Node:
	var night:=false
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func run() -> void:
	root.size=Vector2i(1280,800)
	var town:=FixtureTown.new();root.add_child(town)
	town.life=Life.new();town.add_child(town.life)
	town.day_night=Cycle.new();town.add_child(town.day_night)
	town.box(town,Vector3(100,1,100),Vector3(0,-.5,0),Color("778554"),true)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-30,0);light.light_energy=.9;town.add_child(light)
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("94b1c5")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5;town.add_child(env)
	var camera:=Camera3D.new();town.add_child(camera);camera.position=Vector3(4.5,3.8,12);camera.look_at(Vector3(4.5,.9,0));camera.current=true
	var animals: Array=[]
	for spec in [["Cow","cow_idle.glb",1.4],["Horse","horse_basemesh.glb",1.65],["Sheep","sheep.glb",.85],["Sheep","",.82]]:
		var animal=load("res://animal.gd").new();animal.species=spec[0];animal.asset_path="res://animals/new/"+spec[1] if not String(spec[1]).is_empty() else "res://animals/Sheep.glb"
		animal.desired_height=spec[2];animal.home=Vector3(animals.size()*3,0,0);animal.position=animal.home
		town.add_child(animal);animals.append(animal)
		animal.pause=0;animal.route_to(animal.home+Vector3(0,0,4));animal.pace=.65
		check(animal.animator.has_animation("Idle") and animal.animator.has_animation("Walk"),animal.asset_path+" keeps both idle and walk clips")
	var bird=load("res://sky_birds.gd").new();bird.centre=Vector3(4,0,-4);bird.radius=8;bird.height=5;bird.span=3;town.add_child(bird)
	for frame in range(180):await physics_frame
	for animal in animals:
		check(animal.travelled>.5,animal.asset_path+" physically walks")
		print("WILDLIFE_GAIT asset=",animal.asset_path," travelled=",animal.travelled," clip=",animal.animator.current_animation," bounds=",animal.animated_bounds())
	if DisplayServer.get_name()!="headless":
		for frame in range(20):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../town-new-farm-animals.png")
		camera.position=Vector3(13,1.5,4);camera.look_at(Vector3(7.5,.5,1.8))
		for frame in range(8):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../town-sheep-walk-detail.png")
	check(bird.travelled>1,"The sky flock moves continuously")
	print("WILDLIFE_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
