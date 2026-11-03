extends SceneTree

class TestTown extends "res://town.gd":
	func _ready() -> void:pass
class Day extends Node:
	var night := false
class Builder extends Node:
	var active := false
class Families extends Node:
	var households: Array=[]
	func context(_name: String) -> Dictionary:return {}
class Life extends Node:
	var town: Node
	var people: Array[CharacterBody3D]=[]
	var navigation_ready := true
	var active: Node
	var traffic: Node
	var ai: Node
	var floor_heights: Dictionary={}
	func close_dialog() -> void:active=null
	func assign_home(person: Node) -> void:person.set_meta("review_home_requested",true)
	func find_route(from: Vector3,to: Vector3,_person: Node=null) -> PackedVector3Array:return PackedVector3Array([from,to])
	func route_to_point(person: Node,to: Vector3,_avoid := false) -> PackedVector3Array:return PackedVector3Array([person.position,to])
	func cancel_meeting(_person: Node) -> void:pass
class Home extends Node:
	var house: Node3D

var failures: Array[String]=[]
var town: Node3D
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
	else:print("LIFE_FEATURE_PASS ",message)

func run() -> void:
	root.size=Vector2i(1280,800)
	town=TestTown.new();root.add_child(town)
	var ground: MeshInstance3D=town.box(town,Vector3(300,1,300),Vector3(0,-.5,0),Color("708057"),true)
	ground.name="FixtureFloor"
	town.menu_body=VBoxContainer.new();town.add_child(town.menu_body);town.menu_body.hide()
	town.player=load("res://player.gd").new();town.add_child(town.player);town.player.enabled=false;town.player.set_physics_process(false)
	town.day_night=Day.new();town.add_child(town.day_night)
	town.builder=Builder.new();town.add_child(town.builder)
	town.families=Families.new();town.add_child(town.families)
	town.player_home=Home.new();town.add_child(town.player_home)
	town.life=Life.new();town.life.town=town;town.add_child(town.life)
	town.economy=load("res://town_economy.gd").new();town.add_child(town.economy)
	town.jobs=Node3D.new();town.add_child(town.jobs)
	town.routines=load("res://town_routines.gd").new();town.add_child(town.routines)
	town.adventures=load("res://town_adventures.gd").new();town.adventures.town=town;town.adventures.unit_test=true
	for spec in [["Finn","Carpenter","worker"],["Roslin","Herbalist","medieval_woman"],["Ollie","Village child","runner_child"]]:
		var person: CharacterBody3D=load("res://villager.gd").new()
		person.person_name=spec[0];person.occupation=spec[1];person.style=spec[2];person.is_child=spec[0]=="Ollie";person.route.assign([Vector3(3,0,0),Vector3(6,0,0),Vector3(9,0,0)])
		town.add_child(person);person.life=town.life;person.set_physics_process(false);person.position=Vector3(3+town.life.people.size()*2,0,0);town.life.people.append(person)
	town.cooking=load("res://town_cooking.gd").new();town.add_child(town.cooking)
	town.character_life=load("res://character_life.gd").new();town.add_child(town.character_life)
	var sim: Node=town.character_life
	while not sim.bound:await process_frame
	sim.set_process(false);town.routines.set_process(false);town.cooking.set_process(false)
	var finn: Node=sim.people.Finn;var roslin: Node=sim.people.Roslin;var child: Node=sim.people.Ollie
	check(sim.states.size()==4,"Player and residents receive separate needs and traits")
	check(sim.state("Roslin").traits==["Generous","Patient"],"Named personalities are stable")
	sim.state("You").needs.energy=10
	check(sim.mood("You")=="Exhausted","Low energy affects mood")
	town.player.resting="sleeping";sim.update_player(20)
	check(sim.need("You","energy")>60,"Sleeping restores energy over time")
	town.player.resting=""
	sim.state("You").needs.hunger=10;town.economy.player_food=1
	check(town.economy.eat() and town.economy.player_food==0 and sim.need("You","hunger")==42,"Eating consumes actual food and improves hunger")
	var hunger: float=sim.need("You","hunger")
	check(not town.economy.eat() and sim.need("You","hunger")==hunger,"Empty inventory cannot restore hunger")
	town.player.position=Vector3(-40,0,16);town.economy.player_food=3
	check(town.cooking.begin_recipe("Vegetable stew"),"A nearby cooking station starts a timed recipe")
	check(town.economy.player_food==3 and int(town.adventures.inventory.get("Vegetable stew",0))==0,"Starting a recipe cannot give an instant meal")
	sim.cancel_activity()
	check(town.economy.player_food==3,"Cancelling preparation preserves unused ingredients")
	check(town.cooking.begin_recipe("Vegetable stew"),"Cooking can restart after cancel")
	sim.update_activity(8)
	check(town.economy.player_food==1 and int(town.adventures.inventory.get("Vegetable stew",0))==2,"Completed cooking consumes ingredients exactly once")
	check(not town.cooking.finish_recipe("Vegetable stew"),"Insufficient ingredients cannot duplicate meals")
	check(town.cooking.eat_meal("Vegetable stew") and town.adventures.inventory["Vegetable stew"]==1,"Eating a cooked serving removes that serving")
	town.player.position=Vector3(30,0,30)
	check(not town.cooking.begin_recipe("Roasted vegetables"),"Recipes require an actual nearby cooking station")
	town.player.position=town.cooking.garden.position
	check(town.cooking.plant(),"Planting uses the real community plot")
	sim.update_activity(5)
	check(town.economy.player_food==0 and town.cooking.crop_state=="growing","Planting consumes one vegetable portion")
	check(not town.cooking.harvest(),"Crops cannot be harvested before growing")
	town.cooking.clock=town.cooking.growth_ready;town.cooking._process(0)
	check(town.cooking.harvest() and town.economy.player_food>=3,"Grown crops produce food")
	var crop: int=town.economy.player_food
	check(not town.cooking.harvest() and town.economy.player_food==crop,"The same crop cannot be harvested twice")
	check(town.cooking.gather_herbs() and town.adventures.inventory.Herbs==1,"Herbs enter the shared carried inventory")
	var xp: float=sim.state("You").skills.Cooking
	sim.gain_skill("You","Cooking",12)
	check(sim.state("You").skills.Cooking>xp and sim.skill_level("You","Cooking")>=1,"Practice increases a real skill level")
	sim.state("You").skills.Carpentry=0;town.player.position=finn.position+Vector3(0,0,1)
	town.adventures.remember("Finn","review_help","The visitor helped me.",8)
	check(sim.lesson("Finn","Carpentry"),"A trusted expert can start a nearby lesson")
	sim.update_activity(9)
	check(sim.state("You").skills.Carpentry==10 and not finn.talking,"The completed lesson grants practice and releases the teacher")
	var before: float=sim.state("Finn").skills.Carpentry
	sim.worked(finn,"crafted")
	check(sim.state("Finn").skills.Carpentry>before and sim.work_duration(finn,"Carpentry")<1,"Resident experience improves work speed")
	town.player.position=roslin.position+Vector3(0,0,1)
	var trust: int=town.adventures.relationship("Roslin").trust
	check(sim.give_food("Roslin") and town.adventures.relationship("Roslin").trust>trust,"Giving an actual meal builds trust")
	check(int(town.adventures.inventory.get("Vegetable stew",0))==0,"Cooked gifts are removed from carried inventory")
	var rep: int=sim.reputation()
	check(sim.argue("Roslin") and sim.reputation()<=rep,"An argument has a relationship and reputation consequence")
	check(sim.apologize("Roslin"),"An apology begins rebuilding damaged trust")
	check(not sim.apologize("Roslin"),"Repeated apologies cannot be farmed in one day")
	check(sim.romantic_interest("Ollie").contains("Friendship") and not town.adventures.relationship("Ollie").has("romance"),"Child characters retain friendship-only relationships")
	town.adventures.relationship("Roslin").trust=16
	sim.state("Roslin").romance_day=0
	check(sim.romantic_interest("Roslin").contains("mutual") and sim.relationship_status("Roslin")=="Mutual romantic interest","Trusted uncommitted adults can express mutual interest")
	town.player.skin_id="runner_child"
	check(sim.romantic_interest("Roslin").contains("Friendship"),"A child player appearance has friendship-only interactions")
	town.player.skin_id="medieval"
	var friendship: int=int(finn.friendships.get("Roslin",0))
	sim.shared_meal(finn,roslin)
	check(int(finn.friendships.Roslin)>friendship and roslin.friendships.has("Finn"),"Shared household time improves mutual relationships")
	finn.hunger=0;sim.state("Finn").needs.hygiene=5;sim.state("Finn").next_action=0
	check(sim.start_washing(finn),"A dirty resident can route to the well")
	finn.path.clear();finn.path_index=0
	sim.tick_routine(finn,5)
	check(sim.need("Finn","hygiene")==100 and finn.routine.is_empty(),"A completed wash restores hygiene and resumes work")
	finn.job={};sim.state("Finn").needs.energy=5;sim.state("Finn").next_action=0;sim.update_person(finn,1)
	check(finn.get_meta("review_home_requested",false),"An exhausted off-duty resident chooses to go home")
	finn.set_meta("mood_label","Exhausted")
	sim.set_needs_enabled(false)
	check(sim.mood("Finn")=="Content" and not finn.has_meta("mood_label"),"Disabling needs clears need-driven mood indicators")
	sim.set_needs_enabled(true)
	check(sim.walking_pace(finn)<1.0,"An exhausted resident walks more slowly")
	sim.testing=false;sim.save_path="user://life-functional-review.json";sim.save_state();sim.testing=true
	var saved=JSON.parse_string(FileAccess.get_file_as_string("user://life-functional-review.json"))
	check(saved.states.You.skills.Cooking>0 and saved.states.Finn.friendships.has("Roslin"),"Skills, needs and resident friendships are saved")
	sim.view.open()
	for frame in range(5):await process_frame
	check(sim.view.panel.size.y<=root.size.y and sim.view.people_choice.item_count==3,"Life panel lists actual residents and fits the window")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../life-needs-preview.png")
	print("CHARACTER_LIFE_REVIEW_COMPLETE failures=",failures)
	sim.view.panel.hide()
	town.adventures.free()
	quit(0 if failures.is_empty() else 1)
