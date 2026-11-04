extends SceneTree
const Fixture=preload("res://town_map_review.gd")
class Economy extends Node:
	var story_rewards: Dictionary={}
	var coins:=0
	func testing() -> bool:return true
	func announce(_text: String) -> void:pass
	func award_story(id: String,amount: int) -> bool:
		if story_rewards.has(id):return false
		story_rewards[id]=true;coins+=amount;return true
class Adventures extends Node:
	var inventory: Dictionary={"Timber":2}
	func save_state() -> void:pass
class Physical extends Node3D:
	var score:=0
	var carried: Node3D
	var objects: Array=[]
	func prop(title: String,_asset: String,point: Vector3,kind: String) -> Node3D:
		var item:=StaticBody3D.new();item.name=title;add_child(item);item.position=point;item.set_meta("activity",kind);objects.append(item);return item
class Jobs extends Node3D:
	var markets: Dictionary={"city":{"stock":0}}
	func update_market(_id: String) -> void:pass
class Map extends CanvasLayer:
	var tracked:=""
	var opened:=false
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var town=Fixture.Town.new();root.add_child(town)
	town.player=Fixture.Player.new();town.add_child(town.player)
	town.life=Fixture.Life.new();town.add_child(town.life)
	town.economy=Economy.new();town.add_child(town.economy)
	town.adventures=Adventures.new();town.add_child(town.adventures)
	town.physical_gameplay=Physical.new();town.add_child(town.physical_gameplay)
	town.physical_gameplay.prop("Block","",Vector3.ZERO,"chop")
	town.jobs=Jobs.new();town.add_child(town.jobs)
	town.town_map=Map.new();town.add_child(town.town_map)
	town.menu_body=VBoxContainer.new();town.add_child(town.menu_body)
	var challenges: Node=load("res://town_challenges.gd").new();town.challenges=challenges;town.add_child(challenges)
	challenges.start("archery");town.physical_gameplay.score=2;challenges._process(.1);assert(challenges.active=="archery")
	town.physical_gameplay.score=3;challenges._process(.1);assert(challenges.active.is_empty() and town.economy.coins==10)
	challenges.start("archery");assert(challenges.active.is_empty() and town.economy.coins==10)
	challenges.start("delivery");challenges.remaining=.1;challenges._process(1);assert(challenges.active.is_empty())
	challenges.start("delivery");challenges.crate.reparent(town.player);town.physical_gameplay.carried=challenges.crate
	assert(challenges.objective().point==Vector3(8,.1,4))
	town.player.position=Vector3(8,.1,4);challenges._process(.1);assert(challenges.active.is_empty() and town.jobs.markets.city.stock==4)
	challenges.start("wood");town.adventures.inventory.Timber=5;town.player.position=Vector3(-24,.1,39);challenges._process(.1)
	assert(challenges.active.is_empty() and town.adventures.inventory.Timber==2)
	challenges.start("repair");challenges.repair_job.set_meta("stock",0);challenges._process(.1);assert(challenges.active.is_empty())
	assert(town.economy.coins==47)
	print("TOWN_CHALLENGES_REVIEW_COMPLETE archery=true timeout_retry=true delivery_stock=true timber_consumed=true repair=true duplicate_rewards_blocked=true")
	quit()
