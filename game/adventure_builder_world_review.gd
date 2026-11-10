extends SceneTree

var town: Node3D
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func person_named(name: String) -> CharacterBody3D:
	for person in town.life.people:
		if person.person_name==name:return person
	return town.adventures.visitor if name=="Ansel" else null

func talk(name: String,message: String) -> String:
	var person:=person_named(name)
	town.player.position=person.position+Vector3(0,.1,2.2)
	town.life.open_dialog(person)
	Engine.max_fps=60
	for frame in range(3):await process_frame
	town.life.send(message)
	var started:=Time.get_ticks_msec()
	while town.life.ai.waiting and Time.get_ticks_msec()-started<160000:await process_frame
	var turns: Array=town.life.ai.histories.get(name,[])
	var reply: String=turns[-1].content if not turns.is_empty() and turns[-1].role=="assistant" else ""
	check(not reply.is_empty(),name+" returns an actual local AI reply")
	print("MISSION_ACTUAL_DIALOGUE person=",name," message=",message," reply=",reply)
	town.life.close_dialog();Engine.max_fps=0
	return reply

func run() -> void:
	town=load("res://town.tscn").instantiate();root.add_child(town)
	town.life.ai.scope="review"
	while not town.life.navigation_ready or not town.adventures.visitor:await physics_frame
	town.speech.set_enabled(false);town.day_night.set_enabled(false)
	for person in town.life.people:person.set_physics_process(false)
	town.adventures.visitor.set_physics_process(false)
	town.life.set_process(false);town.routines.set_process(false)
	town.life.ai.set_process(true)
	for animal in get_nodes_in_group("animals"):animal.set_physics_process(false)
	var story: Node=town.adventures
	story.progress.clear();story.relationships.clear();story.inventory.clear();story.load_definitions()
	town.economy.story_rewards.clear()
	Engine.max_fps=60
	var started:=Time.get_ticks_msec()
	while not town.life.ai.available and Time.get_ticks_msec()-started<90000:await process_frame
	check(town.life.ai.available,"Local AI becomes ready for free-form mission conversations")
	print("MISSION_AI_HEALTH available=",town.life.ai.available," polling=",town.life.ai.is_processing()," pending=",town.life.ai.health_pending," clock=",town.life.ai.clock)
	if town.life.ai.available:
		var first:=await talk("Ada","I can help find your missing vegetable delivery. Who handled its delivery slip?")
		check(story.progress.missing_delivery.status=="active","A natural offer accepts Ada's mission")
		check(first.to_lower().contains("corvin"),"Ada gives the actual first lead")
		var clue:=await talk("Corvin","Ada asked me to check her missing greens. Where did the destination label send the crate?")
		check(story.progress.missing_delivery.step==1,"Asking Corvin unlocks the physical recovery step")
		check(clue.to_lower().contains("western") and clue.to_lower().contains("market"),"The generated clue names the western market")
		town.player.enabled=false
		town.player.position=story.step_position(story.find_mission("missing_delivery").steps[1])
		check(story.use_task("missing_delivery"),"The real world crate can be picked up only nearby")
		var coins: int=town.economy.player_coins
		var stock: int=town.jobs.markets.city.stock
		await talk("Ada","I found your labelled vegetable crate at the western market and brought it back. Here it is.")
		check(story.progress.missing_delivery.status=="complete","Free-form return dialogue completes the real delivery")
		check(town.economy.player_coins==coins+12,"The real purse receives twelve coins")
		check(town.jobs.markets.city.stock==stock+12,"The actual market receives twelve vegetable portions")
		check(not story.inventory.has("Ada's vegetable crate"),"The returned crate leaves the player's inventory")
		await talk("Ansel","Greta was worried when you missed your check-in. Are you safe here at the western gatehouse?")
	# The other mission paths use the same reply hook already exercised above.
	story.meet("Oren");story.accept("wagon_fittings")
	story.after_reply(person_named("Bram"),"Are Oren's wagon fittings ready?")
	town.player.enabled=false;town.player.position=Vector3(42,.05,-41.5)
	check(story.use_task("wagon_fittings"),"The physical fitting bundle is recoverable")
	town.player.position=Vector3(35,.05,17.4)
	var press:=InputEventKey.new();press.physical_keycode=KEY_E;press.pressed=true;Input.parse_input_event(press)
	for frame in range(265):await physics_frame
	press=InputEventKey.new();press.physical_keycode=KEY_E;press.pressed=false;Input.parse_input_event(press)
	check(story.inventory.has("Repaired wagon fittings"),"Holding E at the workbench actually finishes the fittings")
	story.after_reply(person_named("Oren"),"The wagon fittings are finished. Here they are.")
	check(story.progress.wagon_fittings.status=="complete" and story.repaired_cart.visible,"The repair produces a visible completed wagon")
	story.meet("Greta");story.accept("overdue_surveyor")
	for name in ["Rowan","Nils","Ansel","Greta"]:story.after_reply(person_named(name),"I checked that Ansel is safe.")
	check(story.progress.overdue_surveyor.status=="complete","The surveyor's complete contact chain resolves")
	check(story.inventory.has("Surveyor's map"),"The investigation grants its inventory reward")
	var restored=load("res://town_adventures.gd").new();restored.unit_test=true;restored.save_path=story.save_path;restored.load_definitions();restored.load_state()
	check(restored.progress.wagon_fittings.status=="complete" and restored.relationship("Ada").trust>=5,"Actual play progress and trust survive loading the save")
	restored.free()
	# Exercise editing against the full physical town, keeping its live cast.
	var editor: Node=town.builder
	editor.toggle()
	var candidate:=Vector3.ZERO;var placed:=false
	for x in [-45,-35,-25,25,35,45]:
		if placed:break
		for z in [-50,-40,-30,30,40,50]:
			var cell:=Vector2i(x,z)
			if town.life.walking_routes.paved.has(cell) or town.life.grid.is_point_solid(cell):continue
			candidate=Vector3(x,0,z)
			if await editor.place("path",candidate):placed=true;break
	check(placed,"The real town accepts a new path on clear ground")
	if placed:check(await editor.place("crate",candidate),"A movable physical crate can be placed in the town")
	await editor.finish()
	if placed:
		var cell:=Vector2i(roundi(candidate.x),roundi(candidate.z))
		check(town.life.walking_routes.paved.has(cell),"User paths are included in road and pavement policies")
		check(town.life.grid.is_point_solid(cell),"The new crate blocks NPC navigation instead of trapping a walker")
	check(town.life.people.size()==53 and town.families.membership.size()==53,"Editing preserves the complete resident and family cast")
	editor.toggle();editor.apply_records({});await editor.finish()
	if placed:check(not town.life.grid.is_point_solid(Vector2i(roundi(candidate.x),roundi(candidate.z))),"Removing an obstacle restores the walking space")
	print("ADVENTURE_BUILDER_WORLD_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)
