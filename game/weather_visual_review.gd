extends SceneTree
class FixtureTown extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass
	func _unhandled_input(_event: InputEvent) -> void:pass
class Life extends Node:
	var navigation_ready:=false
	var people: Array=[]
class Events extends Node:
	func publish(_id: String,_text: String,_witnesses: Array,_point: Vector3) -> void:pass
var failed: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800)
	var town:=FixtureTown.new();root.add_child(town);town.world()
	town.player=CharacterBody3D.new();town.add_child(town.player)
	town.menu_body=VBoxContainer.new();town.add_child(town.menu_body)
	town.life=Life.new();town.add_child(town.life)
	town.events=Events.new();town.add_child(town.events)
	town.day_night=load("res://day_night.gd").new();town.add_child(town.day_night)
	var camera:=Camera3D.new();town.add_child(camera);camera.position=Vector3(10,3,14);camera.look_at(Vector3(0,1,0));camera.current=true
	town.building("Weather review cottage",Vector3.ZERO,6,6,1,0)
	var weather: Node3D=load("res://town_weather.gd").new();town.weather=weather;town.add_child(weather)
	for frame in range(3):await physics_frame
	town.day_night.set_night(true)
	for frame in range(5):await process_frame
	if not town.day_night.night:failed.append("Weather resets paused night")
	town.day_night.set_night(false);weather.set_weather("Rain")
	for frame in range(100):await process_frame
	if not weather.rain.emitting:failed.append("Rain must emit outdoors")
	if not weather.covered(Vector3(0,.05,0)):failed.append("House interior must have a physical roof")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://../town-weather-rain.png")
	camera.position=Vector3(0,1.65,0)
	for frame in range(3):await process_frame
	if weather.rain.emitting:failed.append("Rain must stop under a roof")
	camera.position=Vector3(10,3,14);camera.look_at(Vector3(0,1,0));weather.set_weather("Mist")
	for frame in range(120):await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://../town-weather-mist.png")
	weather.set_weather("Clear")
	for frame in range(4):await process_frame
	if town.day_night.sun.light_energy<.6:failed.append("Clear weather must restore daylight")
	print("WEATHER_VISUAL_REVIEW_COMPLETE failures=",failed)
	quit(0 if failed.is_empty() else 1)
