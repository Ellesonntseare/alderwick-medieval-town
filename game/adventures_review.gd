extends SceneTree

class Person extends Node:
	var person_name:="Ada"
class Player extends Node3D:
	var enabled:=true
class Town extends Node3D:
	var player=Player.new()
	var families: Node
	var economy: Node
var failures: Array[String]=[]

func _initialize() -> void:run.call_deferred()
func check(ok: bool,text: String) -> void:
	if not ok:failures.append(text);push_error(text)

func run() -> void:
	var story=load("res://town_adventures.gd").new()
	story.unit_test=true;story.load_definitions()
	var town:=Town.new();story.town=town
	var person:=Person.new()
	check(not story.accept("missing_delivery"),"An undiscovered request cannot be accepted")
	story.meet("Ada");check(story.accept("missing_delivery"),"Ada's offered request can be accepted")
	check(not story.accept("missing_delivery"),"Accepting twice cannot reset progress")
	person.person_name="Corvin"
	story.after_reply(person,"Hello");check(story.progress.missing_delivery.step==0,"An unrelated hello must not reveal a clue")
	story.after_reply(person,"Where did Ada's delivery go?")
	check(story.progress.missing_delivery.step==1,"Free-form investigation advances the relevant clue")
	town.player.position=Vector3.ZERO
	check(not story.use_task("missing_delivery"),"A remote pickup must be rejected")
	town.player.position=story.step_position(story.find_mission("missing_delivery").steps[1])
	check(story.use_task("missing_delivery"),"An actual nearby crate can be recovered")
	person.person_name="Ada";story.after_reply(person,"I brought your crate back")
	check(story.progress.missing_delivery.status=="complete","Returning the actual crate completes delivery")
	check(story.relationship("Ada").trust==5,"Keeping the promise improves Ada's trust")
	story.after_reply(person,"Here is the crate again")
	check(story.relationship("Ada").trust==5,"Repeated conversation must not duplicate trust rewards")
	story.meet("Oren");story.accept("wagon_fittings")
	person.person_name="Bram";story.after_reply(person,"Are Oren's fittings ready?")
	town.player.position=Vector3(42,.05,-41.5);story.use_task("wagon_fittings")
	person.person_name="Oren";story.after_reply(person,"Done")
	check(story.progress.wagon_fittings.step==2,"Unfinished fittings cannot skip the work stage")
	story.abandon("wagon_fittings")
	check(story.relationship("Oren").trust==-2 and not story.inventory.has("Wagon fittings"),"Withdrawing clears task items and records a broken promise")
	story.meet("Greta");story.accept("overdue_surveyor")
	for name in ["Rowan","Nils","Ansel","Greta"]:
		person.person_name=name;story.after_reply(person,"I am checking whether Ansel is safe")
	check(story.progress.overdue_surveyor.status=="complete","The surveyor story follows all four actual contacts")
	person.person_name="Jory";story.before_message(person,"Ada is useless")
	check(story.relationship("Jory").trust==-1,"Insulting a friend in front of a listener changes that listener's trust")
	check(story.relationship("Ada").trust==5,"A resident does not magically know an insult said elsewhere")
	story.traded("Ada");story.traded("Ada");story.traded("Ada");story.traded("Ada")
	check(story.relationship("Ada").trust==8,"Repeated purchases have a bounded relationship benefit")
	story.unit_test=false;story.save_path="user://story-unit-review.json";story.save_state()
	var restored=load("res://town_adventures.gd").new();restored.unit_test=true;restored.save_path=story.save_path
	restored.load_definitions();restored.load_state()
	check(restored.progress.missing_delivery.status=="complete" and restored.relationship("Ada").trust==8,"Mission and relationship state survives reload")
	var economy=load("res://town_economy.gd").new()
	check(economy.award_story("test_contract",12) and economy.player_coins==42,"A contract pays its real coin reward")
	check(not economy.award_story("test_contract",12) and economy.player_coins==42,"A contract cannot pay twice")
	economy.free();restored.free();story.free();person.free();town.player.free();town.free()
	print("ADVENTURES_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
