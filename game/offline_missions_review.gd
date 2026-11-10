extends SceneTree
class Person extends Node3D:
	var person_name:="Ada"
	var posture:="standing"
class Player extends Node3D:
	var enabled:=true
class Life extends Node:
	var active: Node3D
	var transcript:=RichTextLabel.new()
class Economy extends Node:
	var notices: Array=[]
	func announce(text: String) -> void:notices.append(text)
class Town extends Node3D:
	var player: Node3D
	var life: Node
	var economy: Node
	var events: Node
class Story extends "res://town_adventures.gd":
	var results:=0
	func apply_result(_mission: Dictionary) -> void:results+=1
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var town:=Town.new();root.add_child(town)
	town.player=Player.new();town.add_child(town.player)
	town.life=Life.new();town.add_child(town.life)
	town.economy=Economy.new();town.add_child(town.economy)
	var person:=Person.new();town.add_child(person);town.life.active=person
	var story:=Story.new();story.town=town;story.save_path="user://offline-mission-review.json";story.load_definitions()
	story.meet("Ada");assert(story.perform_resident_action(person,"missing_delivery",-1))
	assert(not story.perform_resident_action(person,"missing_delivery",-1))
	person.person_name="Corvin";person.position.x=10
	assert(not story.perform_resident_action(person,"missing_delivery",0))
	person.position.x=0;assert(story.perform_resident_action(person,"missing_delivery",0))
	assert(story.progress.missing_delivery.notes.size()==1 and not story.perform_resident_action(person,"missing_delivery",0))
	person.person_name="Ada";assert(not story.perform_resident_action(person,"missing_delivery",1))
	town.player.position=story.step_position(story.find_mission("missing_delivery").steps[1]);assert(story.use_task("missing_delivery"))
	person.position=town.player.position
	story.inventory.erase("Ada's vegetable crate");assert(not story.perform_resident_action(person,"missing_delivery",2))
	story.inventory["Ada's vegetable crate"]=1;assert(story.perform_resident_action(person,"missing_delivery",2))
	assert(story.results==1 and not story.inventory.has("Ada's vegetable crate"))
	assert(not story.perform_resident_action(person,"missing_delivery",2) and story.results==1)
	person.person_name="Greta";story.meet("Greta");assert(story.perform_resident_action(person,"overdue_surveyor",-1))
	var step:=0
	for name in ["Rowan","Nils","Ansel","Greta"]:
		person.person_name=name;assert(story.perform_resident_action(person,"overdue_surveyor",step));step+=1
	assert(story.progress.overdue_surveyor.status=="complete" and story.progress.overdue_surveyor.notes.size()==4)
	person.person_name="Sven";story.meet("Sven")
	assert(story.progress.castle_tools.status=="unmet" and story.perform_resident_action(person,"castle_store",-1))
	person.person_name="Gareth";assert(story.perform_resident_action(person,"castle_store",0))
	person.person_name="Sven";assert(not story.perform_resident_action(person,"castle_store",1))
	story.inventory["Supply crate"]=2
	assert(story.perform_resident_action(person,"castle_store",1) and story.inventory["Supply crate"]==1)
	story.meet("Sven");assert(story.perform_resident_action(person,"castle_tools",-1))
	person.person_name="Bram";assert(story.perform_resident_action(person,"castle_tools",0))
	story.inventory["Repaired tools"]=1
	story.abandon("castle_tools");assert(story.inventory["Repaired tools"]==1)
	var restored:=Story.new();restored.town=town;restored.save_path=story.save_path;restored.load_definitions();restored.load_state()
	assert(restored.progress.missing_delivery.status=="complete" and restored.progress.overdue_surveyor.notes.size()==4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(story.save_path))
	story.free();restored.free();town.life.transcript.free()
	print("OFFLINE_MISSIONS_REVIEW_COMPLETE accept=true physical_distance=true stale_click_rejected=true clues=true item_required=true item_consumed=true single_completion=true surveyor_chain=true notes_persist=true castle_prerequisite=true crafted_items_preserved_on_abandon=true")
	quit()
