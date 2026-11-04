extends SceneTree
class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass
	func _unhandled_input(_event: InputEvent) -> void:pass
class Player extends CharacterBody3D:
	var enabled:=true
	var resting:=""
	var animator:=AnimationPlayer.new()
class Home extends Node3D:
	var ready_for_spawn:=true
	var interior:=Node3D.new()
class Sim extends Node:
	var bound:=true
	func gain_skill(_name: String,_skill: String,_amount: float) -> void:pass
class Economy extends Node:
	func testing() -> bool:return true
	func announce(_message: String) -> void:pass
class Adventures extends Node:
	var inventory: Dictionary={}
	func save_state() -> void:pass
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	var town:=Town.new();root.add_child(town)
	town.player=Player.new();town.add_child(town.player);town.player.add_child(town.player.animator)
	town.home_district=Home.new();town.add_child(town.home_district);town.home_district.add_child(town.home_district.interior)
	town.character_life=Sim.new();town.add_child(town.character_life)
	town.economy=Economy.new();town.add_child(town.economy)
	town.adventures=Adventures.new();town.add_child(town.adventures)
	town.box(town,Vector3(150,.2,150),Vector3(0,-.1,0),Color.WHITE,true)
	var physical: Node3D=load("res://physical_gameplay.gd").new();town.physical_gameplay=physical;town.add_child(physical)
	await process_frame;await physics_frame
	assert(physical.objects.size()>=12)
	var crate: Node3D=physical.objects[0];town.player.position=crate.position+Vector3(0,0,1)
	physical.interact({"object":crate})
	for button in physical.choices.get_children():
		if button.text=="Pick up":button.pressed.emit();break
	assert(physical.carried==crate and crate.get_parent()==town.player and crate.collision_layer==0)
	town.player.position=Vector3(0,.1,0);await physics_frame;physical.place()
	assert(physical.carried==null and crate.collision_layer==1)
	var station: Node3D=physical.objects[1];physical.start_work(station)
	physical._physics_process(4.1)
	assert(town.adventures.inventory.get("Timber",0)==1 and station.get_meta("stock")==2)
	var previous_player: Node=town.player
	town.player=load("res://player.gd").new();town.add_child(town.player);town.player.set_physics_process(false);town.player.position=Vector3(20,.1,0);previous_player.queue_free()
	for index in range(12):
		var height: float=(index+1)*.2
		town.box(town,Vector3(1.1,height,.35),Vector3(20,height/2,-index*.35),Color.WHITE,true)
	physical.climb_goal=Vector3(20,2.45,-3.85);physical.climbing=true;physical.climb_previous=town.player.position
	for frame in range(240):
		await physics_frame
		physical.move_climber(1.0/60)
		if not physical.climbing:break
	assert(town.player.position.distance_to(physical.climb_goal)<.3)
	print("PHYSICAL_GAMEPLAY_REVIEW_COMPLETE carry_place=true tool_output=true station_stock=true")
	quit()
