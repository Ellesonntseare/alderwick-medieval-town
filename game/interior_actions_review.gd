extends SceneTree

class Player extends CharacterBody3D:
	var enabled:=true
	var resting:=""
	func stand_from_furniture() -> void:resting=""
	func use_furniture(_anchor: Node3D,kind: String) -> void:resting=kind
class Economy extends Node:
	var player_food:=0
	func eat() -> void:pass
class Adventures extends Node:
	var inventory: Dictionary={}
class Home extends Node:
	var house: Node3D
	func show_home() -> void:pass
class View extends Node:
	var tabs:=TabContainer.new()
	func open() -> void:pass
class Sim extends Node:
	var bound:=true
	var view:=View.new()
class Life extends Node:
	var active: Node
class Builder extends Node:
	var active:=false
class Town extends Node3D:
	var player:=Player.new()
	var economy:=Economy.new()
	var adventures:=Adventures.new()
	var player_home:=Home.new()
	var character_life:=Sim.new()
	var life:=Life.new()
	var builder:=Builder.new()
	var menu_body:=VBoxContainer.new()
	var cooking: Node3D

func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	var town:=Town.new();root.add_child(town)
	for item: Node in [town.player,town.economy,town.adventures,town.player_home,town.character_life,town.life,town.builder,town.menu_body]:town.add_child(item)
	town.character_life.add_child(town.character_life.view);town.character_life.view.add_child(town.character_life.view.tabs)
	# Use the production cooking proximity method without loading district assets.
	town.cooking=load("res://town_cooking.gd").new();town.cooking.town=town
	var kitchen:=Node3D.new();town.add_child(kitchen);town.cooking.stations.append(kitchen)
	var house:=Node3D.new();town.add_child(house);town.player_home.house=house
	var seat:=Marker3D.new();town.add_child(seat);seat.add_to_group("seats")
	var actions: Node=load("res://interior_activities.gd").new();town.add_child(actions)
	var labels: Array=[]
	for option in actions.available():labels.append(option.label)
	assert(labels.has("Cook a meal") and labels.has("Store or take belongings") and labels.has("Sit and rest"))
	actions.open();assert(actions.panel.visible and not town.player.enabled)
	actions.panel.hide();assert(town.player.enabled)
	for option in actions.available():
		if option.label=="Sit and rest":option.action.call()
	assert(town.player.resting=="sitting")
	for option in actions.available():
		if option.label=="Stand up":option.action.call()
	assert(town.player.resting.is_empty())
	seat.set_meta("occupant","resident")
	for option in actions.available():assert(option.label!="Sit and rest")
	town.player.position=Vector3(0,0,25)
	for option in actions.available():assert(option.label!="Store or take belongings" and option.label!="Cook a meal")
	print("INTERIOR_ACTIONS_REVIEW_COMPLETE proximity=true occupied_seat_excluded=true callbacks=true modal_restore=true")
	town.cooking.free();quit()
