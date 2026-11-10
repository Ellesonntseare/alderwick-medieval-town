extends SceneTree
const World=preload("res://town_map_review.gd")
const Fixture=preload("res://town_challenges_review.gd")
class Economy extends Fixture.Economy:
	var test_mode:=true
	func testing() -> bool:return test_mode
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var town:=World.Town.new();root.add_child(town)
	town.player=World.Player.new();town.add_child(town.player)
	town.life=World.Life.new();town.add_child(town.life)
	town.economy=Economy.new();town.add_child(town.economy)
	town.adventures=Fixture.Adventures.new();town.add_child(town.adventures)
	town.physical_gameplay=Fixture.Physical.new();town.add_child(town.physical_gameplay)
	town.physical_gameplay.prop("Block","",Vector3.ZERO,"chop")
	town.jobs=Fixture.Jobs.new();town.add_child(town.jobs)
	town.jobs.markets["west"]={"stock":0};town.jobs.markets["castle"]={"stock":0}
	town.town_map=Fixture.Map.new();town.add_child(town.town_map)
	town.menu_body=VBoxContainer.new();town.add_child(town.menu_body)
	var orders: Node=load("res://town_challenges.gd").new();orders.save_path="user://repeatable-orders-review.json";town.challenges=orders;town.add_child(orders)
	orders.start("invalid");assert(orders.active.is_empty())
	for round_number in [1,2,3]:
		orders.start("archery")
		assert(orders.active_spec.quantity==2+round_number)
		var baseline: int=orders.baseline
		town.physical_gameplay.score=baseline+int(orders.active_spec.quantity)-1;orders._process(.1);assert(orders.active=="archery")
		town.physical_gameplay.score+=1;orders._process(.1)
		assert(orders.active.is_empty() and orders.completions.archery==round_number)
		var earned: int=town.economy.coins;orders.complete();assert(town.economy.coins==earned)
		orders.start("archery");assert(orders.active.is_empty())
		orders._process(61)
	assert(town.economy.coins==39)
	orders.completions.clear();orders.load_state();assert(orders.completions.archery==3)
	for market in ["city","west","castle"]:
		orders.start("delivery");assert(orders.active_spec.market==market)
		orders.crate.reparent(town.player);town.physical_gameplay.carried=orders.crate
		var target: Vector3=orders.active_spec.destination
		assert(orders.objective().point==target)
		town.player.position=target;orders._process(.1);orders._process(61)
	assert(town.jobs.markets.city.stock==4 and town.jobs.markets.west.stock==6 and town.jobs.markets.castle.stock==8)
	orders.start("delivery");orders.crate.reparent(town.player);town.physical_gameplay.carried=orders.crate;orders.abandon()
	assert(town.physical_gameplay.carried==null and orders.crate.collision_layer==1 and orders.active.is_empty())
	town.economy.test_mode=false;orders.save_state()
	orders.completions.clear();orders.cooldowns.clear();orders.load_state();assert(orders.completions.delivery==3 and orders.completions.archery==3)
	var file:=FileAccess.open(orders.save_path,FileAccess.WRITE);file.store_string(JSON.stringify(["wood","repair"]));file.close()
	orders.completions.clear();orders.load_state();assert(orders.completions.wood==1 and orders.contract("repair").round==2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(orders.save_path));town.economy.test_mode=true
	print("REPEATABLE_ORDERS_REVIEW_COMPLETE three_rounds=true higher_targets=true rewards_once=true cooldown=true three_markets_restock=true release_carried_crate=true reload=true legacy_save_migration=true wallet_reconciliation=true")
	quit()
