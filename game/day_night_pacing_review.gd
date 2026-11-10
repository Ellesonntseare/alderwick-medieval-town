extends SceneTree
class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
class Life extends Node:
	var navigation_ready:=true
	var people: Array=[]
	var changes: Array=[]
	func set_night_routine(value: bool) -> void:changes.append(value)
class Person extends Node:
	var guard_shift:="day"
	var posture:="standing"
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var town:=Town.new();root.add_child(town);town.world()
	town.life=Life.new();town.add_child(town.life)
	var worker:=Person.new();town.add_child(worker);town.life.people.append(worker)
	var watch:=Person.new();watch.guard_shift="night";town.add_child(watch);town.life.people.append(watch)
	var day=load("res://day_night.gd").new();town.day_night=day;town.add_child(day);day.set_process(false)
	day.set_enabled(true);assert(day.night and town.life.changes==[true])
	day.phase=.239
	for step in range(90):day._process(1)
	assert(day.night and day.waiting_for_homes and day.phase<.24)
	assert(town.life.changes==[true])
	worker.posture="sleeping"
	assert(day.residents_heading_home()==0)
	for step in range(7):day._process(1)
	assert(day.night)
	day._process(1);assert(not day.night and town.life.changes==[true,false])
	day.phase=.70;day.apply_time();day.phase=.239;worker.posture="standing"
	for step in range(302):day._process(1)
	assert(not day.waiting_for_homes)
	day.set_enabled(false);assert(not day.night and day.phase==.5)
	print("NIGHT_PACING_REVIEW_COMPLETE normal_walks=true dawn_waits=true night_watch_excluded=true sleep_pause=8 bounded_wait=300 toggle_restores_day=true")
	quit()
