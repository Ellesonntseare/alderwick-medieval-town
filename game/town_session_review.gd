extends SceneTree

const Session = preload("res://town_session.gd")
const Store = preload("res://town_session_store.gd")

class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func set_view(mode: int) -> void:view_mode = mode
class Physical extends "res://physical_gameplay.gd":
	func _ready() -> void:town = get_parent()
	func _physics_process(_delta: float) -> void:pass
class Adventures extends "res://town_adventures.gd":
	func _ready() -> void:
		town = get_parent();load_definitions();unit_test = true
		repaired_cart = Node3D.new();add_child(repaired_cart)
	func _process(_delta: float) -> void:pass
	func refresh_journal() -> void:pass
class Economy extends "res://town_economy.gd":
	func _ready() -> void:town = get_parent();bound = true
	func _process(_delta: float) -> void:pass
	func testing() -> bool:return true
class Challenges extends "res://town_challenges.gd":
	func _ready() -> void:town = get_parent()
	func _process(_delta: float) -> void:pass
class Life extends Node:
	var navigation_ready := true
	var people: Array = []
	func set_night_routine(_enabled: bool) -> void:pass
class CharacterLife extends "res://character_life.gd":
	func _ready() -> void:town = get_parent();bound = true;states["You"] = defaults("You")
	func _process(_delta: float) -> void:pass
class DayNight extends "res://day_night.gd":
	func _ready() -> void:town = get_parent()
	func _process(_delta: float) -> void:pass
	func apply_time() -> void:set_night(phase >= .7 or phase < .24)
class Jobs extends "res://town_jobs.gd":
	func _ready() -> void:town = get_parent();markets.city = {"stock":12,"received":12,"sold":0,"returned":0}
	func update_market(_id: String) -> void:pass
class Home extends "res://player_home_district.gd":
	func _ready() -> void:
		town = get_parent();ready_for_spawn = true
		interior = Node3D.new();add_child(interior);interior.position = room_origin
		exterior = Node3D.new();add_child(exterior);exterior.position = porch
		town.box(interior, Vector3(12,.2,12), Vector3(2,-.1,0), Color.WHITE, true)
	func _process(_delta: float) -> void:pass
class Storage extends "res://player_home.gd":
	func _ready() -> void:pass
class Player extends "res://player.gd":
	func _ready() -> void:camera = Camera3D.new();add_child(camera)
	func _physics_process(_delta: float) -> void:pass
class Crafting extends Node:
	var job := {"item":"Crafted stool","remaining":4.5,"position":[4,.04,6]}
	var received: Dictionary = {}
	func snapshot() -> Dictionary:return {"job":job,"placed":[],"stock":{"Alec:1":1},"serial":2}
	func restore(data: Dictionary) -> void:received = data

var failures: Array[String] = []
func _initialize() -> void:run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:failures.append(message);push_error(message)

func build_town() -> Node3D:
	var town := Town.new();root.add_child(town)
	town.life = Life.new();town.add_child(town.life)
	town.character_life = CharacterLife.new();town.add_child(town.character_life)
	town.economy = Economy.new();town.add_child(town.economy)
	town.player = Player.new();town.add_child(town.player)
	town.player_home = Storage.new();town.add_child(town.player_home)
	town.home_district = Home.new();town.add_child(town.home_district)
	town.jobs = Jobs.new();town.add_child(town.jobs)
	town.day_night = DayNight.new();town.add_child(town.day_night)
	town.adventures = Adventures.new();town.add_child(town.adventures)
	town.challenges = Challenges.new();town.add_child(town.challenges)
	town.physical_gameplay = Physical.new();town.add_child(town.physical_gameplay)
	town.physical_gameplay.cart = CharacterBody3D.new();town.physical_gameplay.cart.name = "Supply cart";town.physical_gameplay.add_child(town.physical_gameplay.cart);town.physical_gameplay.objects.append(town.physical_gameplay.cart)
	town.physical_gameplay.prop("Test crate", "", Vector3(3,.04,6), "carry")
	town.crafting = Crafting.new();town.add_child(town.crafting)
	town.box(town, Vector3(300,1,300), Vector3(0,-.5,0), Color.WHITE, true)
	return town

func session_for(town: Node3D, path: String) -> Node:
	var session := Session.new();session.auto_restore = false;session.save_path = path;session.layout_key_override = "fixture-a"
	town.add_child(session);session.ready_for_use = true
	return session

func run() -> void:
	var path := "user://review-session-" + str(OS.get_process_id()) + ".json"
	var town := build_town()
	var session := session_for(town, path)
	await physics_frame;await physics_frame
	town.player.global_position = Vector3(4,.04,6);town.player.rotation.y = 1.2;town.view_mode = 2
	town.adventures.inventory = {"Timber":7};town.adventures.relationships = {"Ada":{"trust":6,"events":[],"promises":{},"trade_count":0}}
	town.economy.player_coins = 71;town.economy.player_food = 9;town.economy.story_rewards = {"challenge_wood":15}
	town.player_home.storage = {"Apple":3};town.jobs.markets.city.stock = 21
	town.day_night.enabled = true;town.day_night.phase = .8;town.day_night.cycle_seconds = 240
	town.challenges.active = "archery";town.challenges.active_spec = town.challenges.contract("archery");town.challenges.remaining = 42.5
	town.physical_gameplay.score = 8;town.challenges.baseline = 6
	var crate: Node3D = town.physical_gameplay.objects[1];crate.set_meta("stock", 2);crate.global_position = Vector3(4,.04,8)
	check(town.physical_gameplay.restore_carried(crate), "Real physical carry restore API accepts fixture crate")
	var result: Error = session.save_now(false)
	check(result == OK, "Manual save succeeds: " + error_string(result))
	if result != OK:quit(1);return
	check(Store.load_valid(path).economy.player_coins == 71, "Manual snapshot readable")
	town.economy.player_coins = 72
	check(session.save_now(true) == OK, "Background save enqueued")
	town.economy.player_coins = 73
	check(session.flush_and_save() == OK, "Quit flush preserves newest complete snapshot")
	check(Store.load_valid(path).economy.player_coins == 73 and Store.load_valid(path + ".backup").economy.player_coins == 72, "Atomic primary and previous backup ordering")
	town.free()
	# Fresh object IDs verify that the carry restore relies on stable identity.
	town = build_town();session = session_for(town, path)
	await physics_frame;await physics_frame
	check(session.restore_saved(), "Fresh town restores durable session")
	check(town.player.global_position.is_equal_approx(Vector3(4,.04,6)) and is_equal_approx(town.player.rotation.y, 1.2) and town.view_mode == 2, "Position rotation and camera view round trip")
	check(town.economy.player_coins == 73 and town.economy.player_food == 9 and not town.economy.award_story("challenge_wood", 15), "Coins food and duplicate reward prevention")
	check(town.adventures.inventory.Timber == 7 and town.adventures.relationships.Ada.trust == 6 and town.player_home.storage.Apple == 3, "Belongings relationships and storage round trip")
	check(town.jobs.markets.city.stock == 21 and town.day_night.night and is_equal_approx(town.day_night.phase, .8), "Stock and world time round trip")
	check(town.challenges.active == "archery" and is_equal_approx(town.challenges.remaining, 42.5) and town.physical_gameplay.score - town.challenges.baseline == 2, "Active challenge timer and hits round trip")
	crate = town.physical_gameplay.carried
	check(is_instance_valid(crate) and crate.get_parent() == town.player and crate.get_meta("stock") == 2 and crate.get_meta("pickup_position").is_equal_approx(Vector3(4,.04,8)), "Carried object and its safe drop position round trip")
	check(town.crafting.received.job.remaining == 4.5 and town.adventures.inventory.Timber == 7, "Crafting resumes without taking reserved materials twice")
	var broken := FileAccess.open(path, FileAccess.WRITE);broken.store_string("{truncated");broken.close()
	session.restored = false
	check(session.restore_saved() and session.used_backup and town.economy.player_coins == 72, "Corrupt primary falls back to last complete backup")
	var data: Dictionary = session.snapshot()
	data.player.position = [6,8,6]
	session.layout_key_override = "fixture-changed"
	check(session.apply_snapshot(data), "Invalid floor fallback restores other state")
	check(town.player.global_position.distance_to(town.home_district.porch) < 1 and not session.restore_notes.is_empty(), "Missing floor uses a clear outdoor fallback")
	data.player.inside = true;data.player.position = [3,-79.96,2]
	check(session.apply_snapshot(data) and town.home_district.inside and town.home_district.interior.visible and not town.home_district.exterior.visible, "Home interior state restores independently of camera")
	data.challenge.active = "wood";data.challenge.round = 2;data.challenge.progress = {"timber":2};data.challenge.completions = {"wood":1}
	check(session.apply_snapshot(data) and town.challenges.active == "wood" and int(town.adventures.inventory.Timber) - town.challenges.baseline == 2, "Repeat timber order restores per-attempt progress")
	data.challenge.round = 1;data.challenge.completions = {}
	check(session.apply_snapshot(data) and town.challenges.active.is_empty(), "Already rewarded attempt cannot restore as active")
	check(not Store.valid_snapshot({"version":Store.VERSION,"player":{"position":[NAN,0,0]}}), "Malformed snapshot rejected")
	for suffix in ["", ".backup"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("TOWN_SESSION_REVIEW_COMPLETE failures=", failures, " background=true backup=true camera=true challenge=true carry=true safe_floor=true")
	quit(0 if failures.is_empty() else 1)
