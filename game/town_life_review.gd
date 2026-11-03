extends Node

var town: Node3D
var failures: Array[String]=[]

func _ready() -> void:
	town=get_parent()
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func total_coins() -> int:
	var total: int=town.economy.player_coins+town.economy.treasury
	for person in town.life.people:total+=person.coins
	return total

func run() -> void:
	while not town.life.navigation_ready or get_tree().get_nodes_in_group("animals").size()<9:await get_tree().physics_frame
	town.speech.set_enabled(false)
	town.day_night.set_enabled(false)
	town.player.position=Vector3(0,0.1,23)
	check(town.life.people.size()==town.life.RESIDENT_COUNT,"Keep the full approved population")
	check(not town.music.playing and town.music.volume_db<=-80,"Music must start off")
	town.toggle_menu()
	check(not town.menu_body.visible,"Menu must collapse")
	town.toggle_menu()
	check(town.menu_body.visible,"Menu must expand")
	var total := total_coins()
	var seller: CharacterBody3D=town.economy.seller_for("city")
	var coins_before: int=town.economy.player_coins
	var stock_before: int=town.economy.market_for(seller).stock
	check(town.economy.buy_food(seller),"Player can buy food")
	check(town.economy.player_coins==coins_before-2 and town.economy.market_for(seller).stock==stock_before-1,"Purchases transfer coins and consume stock")
	town.economy.player_coins=0
	var food_before: int=town.economy.player_food
	check(not town.economy.buy_food(seller),"No purchase without coins")
	check(town.economy.player_food==food_before,"Failed purchase must be atomic")
	town.economy.player_coins=coins_before-2
	check(total_coins()==total,"Purchases conserve currency")
	var dog: CharacterBody3D
	for animal in get_tree().get_nodes_in_group("animals"):
		if animal.species=="Pug":dog=animal
	var minimum_foot := 0.0
	var maximum_foot := 0.0
	var grounded_samples := 0
	for frame in range(9000):
		await get_tree().physics_frame
		if frame%600!=0:continue
		for person in town.life.people:
			if person.posture!="standing" or person.getting_up>0:continue
			var grounding: SkeletonModifier3D=person.visual.find_child("GroundedFeet",true,false)
			if grounding and grounding.corrections>5:
				grounded_samples+=1
				if absf(grounding.contact_error)>0.12:print("FOOT_CONTACT_PENDING ",person.person_name," style=",person.style," stage=",person.night_stage," posture=",person.posture," error=",grounding.contact_error," at=",person.position," offset=",grounding.offset)
				minimum_foot=minf(minimum_foot,grounding.contact_error)
				maximum_foot=maxf(maximum_foot,grounding.contact_error)
		print("TOWN_LIFE_PROGRESS seconds=",frame/60," purchases=",town.economy.purchases," meals=",town.routines.meals," tavern=",town.routines.tavern_visits," breaks=",town.routines.breaks_taken," friendships=",town.routines.friendships_made," dog_distance=",dog.travelled)
	check(town.economy.purchases>=4,"Residents must buy food autonomously")
	check(town.routines.meals>=3,"Residents must eat")
	check(town.routines.breaks_taken>=2,"Residents must take seated breaks")
	check(town.routines.tavern_visits>=1,"Residents must enter and visit the tavern")
	# Actual generated conversations are checked by the character-chat suite.
	# Exercise the mutual relationship ledger without requiring a loaded model.
	var first: CharacterBody3D=town.life.people[0]
	var second: CharacterBody3D=town.life.people[1]
	town.routines.befriend(first,second)
	check(first.friendships.has(second.person_name) and second.friendships.has(first.person_name),"Friendships must be mutual")
	check(town.economy.wages_paid>0,"Completed work must pay wages")
	check(total_coins()==total,"Autonomous transactions and wages must conserve currency")
	for market in town.jobs.markets.values():check(market.received+market.returned==market.stock+market.sold,"Market deliveries, purchases and stock must balance")
	check(dog.travelled>5,"Small dog must roam around the town")
	check(grounded_samples>50 and maximum_foot<0.16 and minimum_foot> -0.16,"Resident feet must stay close to the real floor while walking")
	print("GROUNDING_TOWN_RESULTS min=",minimum_foot," max=",maximum_foot," samples=",grounded_samples)
	for person in town.life.people:
		if person.day_visit:print("TAVERN_VISITOR ",person.person_name," stage=",person.night_stage," at=",person.position," index=",person.night_index,"/",person.night_path.size())
	town.day_night.set_enabled(true)
	town.day_night.phase=0.85
	town.day_night.apply_time()
	town.day_night.enabled=false
	var sleeping := 0
	var watching := 0
	for frame in range(5400):
		await get_tree().physics_frame
		if frame%300!=0:continue
		sleeping=0
		watching=0
		for person in town.life.people:
			if person.posture=="sleeping":sleeping+=1
		for guard in town.jobs.night_guards:
			if not guard.night_schedule and guard.position.distance_to(guard.guard_post)<0.3:watching+=1
		print("TOWN_NIGHT_PROGRESS seconds=",frame/60," sleeping=",sleeping," watch=",watching,"/",town.jobs.night_guards.size())
		if sleeping==town.life.people.size()-town.jobs.night_guards.size() and watching==town.jobs.night_guards.size():break
	check(sleeping==town.life.people.size()-town.jobs.night_guards.size() and watching==town.jobs.night_guards.size(),"Residents sleep while the separate night watch covers its posts")
	for person in town.life.people:
		if person.posture!="sleeping" and person.guard_shift!="night":print("NIGHT_PENDING ",person.person_name," stage=",person.night_stage," pos=",person.position," goal=",person.night_path[person.night_index] if person.night_index<person.night_path.size() else Vector3.ZERO)
	for guard in town.jobs.night_guards:print("NIGHT_GUARD_STATE ",guard.person_name," stage=",guard.night_stage," schedule=",guard.night_schedule," posture=",guard.posture," at=",guard.position," post=",guard.guard_post," path=",guard.path_index,"/",guard.path.size())
	town.day_night.set_enabled(false)
	var posted := 0
	var off_duty := 0
	for frame in range(5400):
		await get_tree().physics_frame
		if frame%300!=0:continue
		posted=0
		off_duty=0
		for guard in town.jobs.guards:
			if not guard.night_schedule and Vector2(guard.position.x-guard.guard_post.x,guard.position.z-guard.guard_post.z).length()<0.25:posted+=1
		for guard in town.jobs.night_guards:
			if guard.posture=="sleeping":off_duty+=1
		print("TOWN_MORNING_PROGRESS seconds=",frame/60," day_watch=",posted,"/",town.jobs.guards.size()," night_guards_asleep=",off_duty,"/",town.jobs.night_guards.size())
		if posted==town.jobs.guards.size() and off_duty==town.jobs.night_guards.size():break
	check(posted==town.jobs.guards.size() and off_duty==town.jobs.night_guards.size(),"Day watch resumes while night guards sleep")
	for person in town.life.people:
		if person.night_schedule and person.posture!="sleeping":print("MORNING_PENDING ",person.person_name," stage=",person.night_stage," pos=",person.position)
	print("TOWN_LIFE_REVIEW_COMPLETE failures=",failures," coin_total=",total_coins()," wages=",town.economy.wages_paid)
	get_tree().quit(0 if failures.is_empty() else 1)
