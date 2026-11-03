extends Node

var town: Node3D
var failures: Array[String]=[]

func _ready() -> void:
	town=get_parent()
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	if ok:return
	failures.append(message)
	push_error(message)

func capture(file: String) -> void:
	if "--review-character-chat" not in OS.get_cmdline_user_args():return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../"+file)

func run() -> void:
	while not town.life.navigation_ready or get_tree().get_nodes_in_group("animals").size()<9:await get_tree().physics_frame
	var life: Node=town.life
	check(life.people.size()==45,"45 residents retained")
	while not town.character_directory.bound:await get_tree().process_frame
	var bases: Dictionary={}
	for skin in town.character_directory.entries:
		check(not bases.has(skin.base),"Player appearance menu must not repeat a base model")
		bases[skin.base]=true
	check(bases.size()>=9,"Available player base models appear in the selector")
	check(not town.music.playing,"Music starts off")
	var guard: CharacterBody3D
	for person in life.people:
		check(person.label.font_size==18 and person.label.pixel_size<0.005,"Smaller labels for "+person.person_name)
		if person.person_name=="Edric":guard=person
	check(guard!=null,"Edric exists")
	var cast=JSON.parse_string(FileAccess.get_file_as_string("res://character_stories.json"))
	check(cast.characters.size()==45,"45 individual backgrounds")
	var names: Dictionary={}
	for story in cast.characters:names[story.name]=true
	for person in life.people:check(names.has(person.person_name),"Background for "+person.person_name)
	town.player.position=guard.position+Vector3(0,0.2,4)
	life.open_dialog(guard)
	for frame in range(6):await get_tree().process_frame
	check(life.dialog.position.x>get_viewport().get_visible_rect().size.x*0.5,"Conversation panel remains on the side")
	check(life.transcript.scroll_following,"Conversation history scrolls")
	check(life.ai.camera.current,"Character stays in the conversation view")
	check(life.ai.submit.get_global_rect().end.y<get_viewport().get_visible_rect().size.y,"Send button fits on the screen")
	await capture("town-chat-loading.png")
	print("CHARACTER_CHAT_PANEL_BOUNDS panel=",life.dialog.get_rect()," send_button=",life.ai.submit.get_global_rect()," viewport=",get_viewport().get_visible_rect())
	print("CHARACTER_CHAT_VIEW_READY cast=45 labels=18 side_panel=true waiting_for_local_model=true")
	var started := Time.get_ticks_msec()
	while not life.ai.available and Time.get_ticks_msec()-started<1500000:await get_tree().process_frame
	check(life.ai.available,"Local conversation AI becomes ready")
	if not life.ai.available:
		print("CHARACTER_CHAT_REVIEW_COMPLETE failures=",failures)
		if "--review-character-chat" not in OS.get_cmdline_user_args() or "--capture-character-chat" in OS.get_cmdline_user_args():get_tree().quit(1)
		return
	print("CHARACTER_CHAT_MODEL_READY")
	var played_before: int=town.speech.played
	life.send("Hello Edric. I'm Cedar. I mend fishing nets, and I really dislike turnips. How have you been?")
	started=Time.get_ticks_msec()
	while life.ai.waiting and Time.get_ticks_msec()-started<170000:await get_tree().process_frame
	check(life.ai.histories.get("Edric",[]).size()>=2,"Actual generated character reply arrives")
	print("CHARACTER_CHAT_FIRST_REPLY ",life.transcript.text)
	var voice: AudioStreamPlayer3D=town.speech.configure(guard)
	started=Time.get_ticks_msec()
	while town.speech.played<=played_before and Time.get_ticks_msec()-started<60000:await get_tree().process_frame
	check(town.speech.played>played_before,"Generated reply plays through the local character voice")
	if town.speech.played>played_before:print("GENERATED_REPLY_VOICE_OK profile=",town.speech.profile(guard)," seconds=",voice.stream.get_length())
	await capture("town-character-chat.png")
	life.close_dialog()
	life.open_dialog(guard)
	await get_tree().create_timer(1.0).timeout
	check(life.transcript.text.contains("Cedar"),"Reopening conversation restores saved history")
	life.send("What is my name, what work do I do, and which vegetable did I say I dislike?")
	started=Time.get_ticks_msec()
	while life.ai.waiting and Time.get_ticks_msec()-started<170000:await get_tree().process_frame
	var history: Array=life.ai.histories.get("Edric",[])
	var answer: String=history[-1].content if not history.is_empty() else ""
	print("CHARACTER_CHAT_MEMORY_REPLY ",answer)
	check(answer.to_lower().contains("cedar") and answer.to_lower().contains("net") and answer.to_lower().contains("turnip"),"Character recalls specific freely typed player facts")
	await capture("town-character-chat-memory.png")
	life.close_dialog()
	life.ai.scope="player"
	life.ai.histories.clear()
	town.set_view(1)
	town.update_camera()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	print("CHARACTER_CHAT_REVIEW_COMPLETE failures=",failures)
	if "--review-character-chat" not in OS.get_cmdline_user_args() or "--capture-character-chat" in OS.get_cmdline_user_args():get_tree().quit(0 if failures.is_empty() else 1)
