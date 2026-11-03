extends SceneTree

var town: Node3D
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
	else:print("WORLD_LIFE_PASS ",message)

func run() -> void:
	town=load("res://town.tscn").instantiate();root.add_child(town)
	while not town.life.navigation_ready or not town.character_life.bound or not town.home_district.ready_for_spawn:await physics_frame
	town.day_night.set_enabled(false);town.speech.set_enabled(false)
	town.player.enabled=false;town.player.set_physics_process(false)
	var sim: Node=town.character_life
	check(sim.people.size()==53 and sim.states.size()==54,"All 53 residents and the player have individual life state")
	check(town.families.membership.size()==53,"Needs preserve assigned family homes")
	check(town.player_home.house==town.home_district.interior,"Cooking and visits use the supplied home interior")
	town.home_district.enter_home();town.player.enabled=false
	town.cooking.register_home(town.player_home.house)
	town.player.position=town.home_district.cooking_anchor.global_position+Vector3(.8,.1,0)
	town.economy.player_food=3
	check(town.cooking.near_station(),"The actual home kitchen is a usable cooking station")
	check(town.cooking.begin_recipe("Vegetable stew"),"Cooking starts in the supplied interior")
	for frame in range(500):await physics_frame
	check(town.economy.player_food==1 and int(town.adventures.inventory.get("Vegetable stew",0))==2,"The timed home recipe completes with correct inventory")
	var hunger: float=sim.need("You","hunger")
	check(town.cooking.eat_meal("Vegetable stew") and sim.need("You","hunger")>hunger,"Cooked food improves actual player hunger")
	town.home_district.leave_home();town.player.enabled=false
	var seller: CharacterBody3D=town.economy.seller_for("city")
	var prior_trust: int=town.adventures.relationship(seller.person_name).trust
	town.adventures.relationship(seller.person_name).trust=8
	check(town.economy.player_food_price(seller)==1,"A trusted stallholder gives a friendly price")
	var before: int=town.economy.player_coins+seller.coins
	var stock: int=town.economy.market_for(seller).stock
	check(town.economy.buy_food(seller),"Friendly prices still use the real market transaction")
	check(town.economy.player_coins+seller.coins==before and town.economy.market_for(seller).stock==stock-1,"Discounts conserve coins and consume stock")
	town.adventures.relationship(seller.person_name).trust=prior_trust
	var finn: CharacterBody3D=sim.people.Finn
	if finn.social_partner:finn.end_social()
	if finn.meeting_partner:town.life.cancel_meeting(finn)
	town.routines.cancel(finn);town.jobs.suspend(finn);finn.job={};finn.indoor_house=null
	finn.position=town.home_district.porch+Vector3(0,0,3.0);finn.velocity=Vector3.ZERO;finn.wait_time=0
	town.adventures.relationship("Finn").trust=12
	check(sim.invite_home("Finn"),"A friendly resident can accept an invitation to the actual player home")
	for frame in range(1200):
		await physics_frame
		if town.home_district.visitors.has(finn):break
	check(town.home_district.visitors.has(finn) and finn.indoor_house==town.home_district.interior,"The invited resident arrives outside and enters the supplied interior")
	if sim.home_visits.has(finn):
		check(sim.home_visits[finn].stage=="inside","A home visit begins only after arrival at the porch")
		sim.home_visits[finn].time=46
		await physics_frame;await physics_frame
	check(not town.home_district.visitors.has(finn) and finn.position.y> -1,"A completed visitor returns outside and resumes town life")
	sim.state("You").needs.energy=10;town.player.resting="sleeping"
	var energy: float=sim.need("You","energy")
	sim.update_player(10);town.player.resting=""
	check(sim.need("You","energy")>energy,"Home sleep restores the same player energy system")
	var old: float=sim.state("Fenn").skills.Archery
	sim.worked(sim.people.Fenn,"lesson")
	check(sim.state("Fenn").skills.Archery>old,"Resident work contributes to their actual skill")
	for frame in range(1200):await physics_frame
	var grounded := 0
	for person in town.life.people:
		if person.posture!="standing":continue
		var modifier: Node=person.visual.find_child("GroundedFeet",true,false)
		if modifier and modifier.corrections>5 and absf(modifier.contact_error)<.16:grounded+=1
	check(grounded>=30,"New routines preserve grounded resident movement")
	print("CHARACTER_LIFE_WORLD_REVIEW_COMPLETE failures=",failures," grounded=",grounded," homes=",town.families.membership.size())
	quit(0 if failures.is_empty() else 1)
