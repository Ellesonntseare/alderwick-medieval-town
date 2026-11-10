extends SceneTree
const World=preload("res://town_map_review.gd")
class Player extends CharacterBody3D:
	var enabled:=true
	var animator:=AnimationPlayer.new()
class Economy extends Node:
	var player_coins:=100
	var player_food:=3
	func open_for_trade(_p: Node) -> bool:return true
	func refresh() -> void:pass
	func eat() -> bool:
		if player_food<1:return false
		player_food-=1;return true
	func announce(_text: String) -> void:pass
class Adventures extends Node:
	var inventory: Dictionary={"Timber":12,"Metal fittings":4,"Quest parcel":1}
	var definitions: Array=[{"id":"quest","steps":[{"kind":"collect","item":"Quest parcel"}]}]
	var progress: Dictionary={"quest":{"status":"active"}}
	func save_state() -> void:pass
	func traded(_name: String) -> void:pass
class Home extends Node:
	var storage: Dictionary={}
	var save_path:="user://inventory-crafting-review-home.json"
class District extends Node3D:
	var inside:=true
	var porch:=Vector3.ZERO
	var interior:=Node3D.new()
class Person extends Node3D:
	var person_name:="Ada"
	var stall_name:="food"
	var posture:="standing"
	var coins:=100
class Life extends Node:
	var active: Node
	var nearest: Node
class CharacterLife extends Node:
	var day:=1
	var bound:=true
	var xp:=0
	func skill_level(_name: String,_skill: String) -> int:return 2
	func gain_skill(_name: String,_skill: String,amount: int) -> void:xp+=amount
class Interface extends CanvasLayer:
	var active:=false
class Physical extends Node3D:
	var objects: Array=[]
class Cooking extends Node3D:
	const RECIPES={}
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var town:=World.Town.new();root.add_child(town)
	town.player=Player.new();town.add_child(town.player)
	town.economy=Economy.new();town.add_child(town.economy)
	town.adventures=Adventures.new();town.add_child(town.adventures)
	town.player_home=Home.new();town.add_child(town.player_home)
	town.home_district=District.new();town.add_child(town.home_district);town.home_district.add_child(town.home_district.interior)
	town.life=Life.new();town.add_child(town.life)
	var seller:=Person.new();town.add_child(seller);town.life.nearest=seller
	town.character_life=CharacterLife.new();town.add_child(town.character_life)
	town.interface_ui=Interface.new();town.add_child(town.interface_ui)
	town.physical_gameplay=Physical.new();town.add_child(town.physical_gameplay)
	var bench:=Node3D.new();town.physical_gameplay.add_child(bench);bench.set_meta("activity","repair");town.physical_gameplay.objects.append(bench)
	town.cooking=Cooking.new();town.add_child(town.cooking)
	town.crafting=load("res://town_crafting.gd").new();town.add_child(town.crafting);town.crafting.set_process(false)
	town.inventory_ui=load("res://town_inventory.gd").new();town.add_child(town.inventory_ui)
	var column:=VBoxContainer.new();root.add_child(column);town.inventory_ui.build(column)
	assert(town.inventory_ui.transfer("Timber",3,true) and town.inventory_ui.amount("Timber")==9)
	assert(town.inventory_ui.transfer("Timber",3,false) and town.inventory_ui.amount("Timber")==12)
	assert(not town.inventory_ui.transfer("Timber",99,true))
	assert(not town.inventory_ui.sell("Quest parcel",1))
	assert(town.inventory_ui.buy_fittings(2) and town.economy.player_coins==92)
	assert(not town.inventory_ui.buy_fittings(99))
	assert(town.crafting.begin("Crafted stool") and town.inventory_ui.amount("Timber")==9)
	assert(not town.crafting.begin("Crafted stool"))
	town.crafting.cancel();assert(town.inventory_ui.amount("Timber")==12 and town.player.enabled)
	town.crafting.cancel();assert(town.inventory_ui.amount("Timber")==12)
	assert(town.crafting.begin("Crafted stool"));town.crafting._process(6)
	assert(town.inventory_ui.amount("Timber")==9 and town.inventory_ui.amount("Crafted stool")==1)
	town.crafting._process(6);assert(town.inventory_ui.amount("Crafted stool")==1)
	assert(town.inventory_ui.sell("Crafted stool",1) and town.economy.player_coins==98)
	town.player.position.x=20;assert(not town.crafting.begin("Supply crate"));town.player.position.x=0
	assert(town.crafting.begin("Supply crate"));town.crafting._process(2)
	var state: Dictionary=town.crafting.snapshot();town.crafting.restore(state)
	assert(town.inventory_ui.amount("Timber")==5)
	town.crafting._process(5);assert(town.inventory_ui.amount("Supply crate")==1 and town.inventory_ui.amount("Timber")==5)
	assert(town.inventory_ui.use("Food portions") and town.economy.player_food==2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(town.player_home.save_path))
	town.player.animator.free()
	print("INVENTORY_CRAFTING_REVIEW_COMPLETE item_panel=true storage=true quest_sale_blocked=true stock_currency=true reserve_refund=true one_output=true nearby_bench=true resume_without_double_charge=true food=true")
	quit()
