extends SceneTree
class FixtureTown extends Node3D:
	var player: CharacterBody3D
	var economy: Node
	var families: Node
	var adventures: Node
	var menu_body: VBoxContainer
class Economy extends Node:
	func testing() -> bool:return true
class Families extends Node:
	var households: Array=[]
class Adventures extends Node:
	var inventory: Dictionary={"Letter":2}
	func save_state() -> void:pass
var failed: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
	if not value:failed.append(message)
func run() -> void:
	var town:=FixtureTown.new();root.add_child(town)
	town.player=CharacterBody3D.new()
	# Home expects only enabled and velocity; a small fixture script supplies it.
	town.player.set_script(load("res://player_home_review_player.gd"));town.add_child(town.player)
	town.economy=Economy.new();town.add_child(town.economy)
	town.families=Families.new();town.add_child(town.families)
	town.adventures=Adventures.new();town.add_child(town.adventures)
	town.menu_body=VBoxContainer.new();town.add_child(town.menu_body)
	var home: Node=load("res://player_home.gd").new();town.add_child(home);home.storage.clear()
	check(town.menu_body.get_child_count()==1,"Home menu initializes successfully")
	home.show_home();await process_frame
	check(not town.player.enabled,"Home menu pauses player movement")
	home.panel.hide();await process_frame
	check(town.player.enabled,"Closing the home menu restores movement")
	var house:=Node3D.new();town.add_child(house);house.add_to_group("enterable_houses")
	check(home.register_house(house),"Register reviewed home")
	check(home.transfer("Letter",1,true),"Deposit")
	check(home.transfer("Letter",1,false) and town.adventures.inventory.Letter==2,"Withdraw without duplication")
	check(not home.transfer("Letter",3,true),"Reject unavailable items")
	print("PLAYER_HOME_REVIEW_COMPLETE failures=",failed)
	quit(0 if failed.is_empty() else 1)
