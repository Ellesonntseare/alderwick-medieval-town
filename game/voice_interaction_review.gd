extends SceneTree

class Economy extends Node:
	func player_buy() -> void:pass
	func player_sell() -> void:pass
class Day extends Node:
	var night := false
class Town extends Node3D:
	var economy: Node
	var day_night: Node
	var adventures: Node
	var families: Node
	var player: Node3D
	var life: Node
	var speech: Node
	var view_mode := 0
	var overview: Camera3D
	var menu_body: VBoxContainer
	func set_view(_mode: int) -> void:pass
class Life extends Node:
	var town: Node
	var ai: Node
	var active: CharacterBody3D
	var hint: Label
	var talk_button: Button
	var dialog: PanelContainer
	var heading: Label
	var transcript: RichTextLabel
	var entry: TextEdit
	var trade_row: HBoxContainer
	var trade_status: Label
	var nearest: Node
	func close_dialog() -> void:active=null;ai.close();dialog.hide()
	func send_entry() -> void:ai.send(entry.text)
	func open_dialog(_person: Node) -> void:pass
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func run() -> void:
	root.size=Vector2i(1280,800)
	var town := Town.new()
	root.add_child(town)
	town.economy=Economy.new();town.add_child(town.economy)
	town.day_night=Day.new();town.add_child(town.day_night)
	town.player=CharacterBody3D.new();town.add_child(town.player);town.player.position.z=2
	town.menu_body=VBoxContainer.new();town.add_child(town.menu_body);town.menu_body.hide()
	town.life=Life.new();town.life.town=town;town.add_child(town.life)
	var life: Node=town.life
	life.ai=load("res://town_dialogue.gd").new();life.add_child(life.ai)
	preload("res://dialogue_panel.gd").build(life)
	town.speech=load("res://town_speech.gd").new();town.add_child(town.speech)
	var a: CharacterBody3D=load("res://villager.gd").new()
	var b: CharacterBody3D=load("res://villager.gd").new()
	a.person_name="Roslin";b.person_name="Fenn"
	a.set_meta("district","city");b.set_meta("district","city")
	town.add_child(a);town.add_child(b)
	a.set_physics_process(false);b.set_physics_process(false);b.position.x=1.5
	life.active=a;a.talking=true
	life.ai.open(a)
	var overheard: Array[Dictionary]=[{"name":"Roslin","text":"The herb garden needs a clear path for deliveries."},{"name":"Fenn","text":"We could use the woodland entrance instead."}]
	life.ai.begin_group(a,b,overheard)
	life.dialog.show()
	life.trade_row.hide()
	check(life.ai.group_members.size()==2 and b.talking,"Joining retains both residents")
	check(life.transcript.text.contains("woodland entrance"),"Joining preserves the actual overheard discussion")
	check(life.ai.group_target.item_count==3,"Player can address either participant")
	check(town.speech.allowed(a) and town.speech.allowed(b),"Both joined residents can speak")
	var input: Node=life.ai.voice_input
	input.selector.select(1);input.controls.show();input.auto_send.button_pressed=false
	for frame in range(5):await process_frame
	life.ai.layout()
	check(life.ai.submit.get_global_rect().end.y<=800,"Voice controls and Send fit the screen")
	root.size=Vector2i(1280,720)
	for frame in range(6):await process_frame
	life.ai.layout()
	check(life.ai.submit.get_global_rect().end.y<=720,"Voice controls fit a 720p window")
	root.size=Vector2i(1280,800)
	var started := Time.get_ticks_msec()
	while not town.speech.recognition_available and Time.get_ticks_msec()-started<30000:await process_frame
	check(town.speech.recognition_available,"Local microphone recognizer is available")
	if town.speech.recognition_available:
		var clip := AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes("res://../review/characters/Duncan-voice.wav"))
		input.begin(clip)
		check(input.recording and town.speech.listening,"Recording visibly starts and silences NPC output")
		await create_timer(clip.get_length()+.2).timeout
		input.finish()
		started=Time.get_ticks_msec()
		while input.recognizing and Time.get_ticks_msec()-started<60000:await process_frame
		check(life.entry.text.to_lower().contains("market"),"Captured audio is transcribed into the editable message")
		check(not life.ai.waiting,"Review mode waits for Send")
		check(not input.recording and not town.speech.listening,"Recording stops after speech")
		input.begin(clip)
		input.cancel()
		check(not input.recording and input.samples.is_empty(),"Cancel clears unsent microphone samples")
	if "--generated" in OS.get_cmdline_user_args():
		started=Time.get_ticks_msec()
		while not life.ai.available and Time.get_ticks_msec()-started<90000:await process_frame
		check(life.ai.available,"Dialogue service becomes ready in the actual UI")
		if life.ai.available:
			var before: int=town.speech.played
			life.ai.send("Roslin, may I join you? What were you saying about the garden path?")
			started=Time.get_ticks_msec()
			while life.ai.waiting and Time.get_ticks_msec()-started<170000:await process_frame
			check(life.ai.group_turns[-1].name=="Roslin" and life.ai.group_turns.size()>=4,"The named participant answers the joined conversation")
			started=Time.get_ticks_msec()
			while town.speech.played<=before and Time.get_ticks_msec()-started<60000:await process_frame
			check(town.speech.played>before,"Actual joined AI reply plays through the assigned character voice")
			print("JOINED_UI_GENERATED_REPLY ",life.ai.group_turns[-1]," speech_played=",town.speech.played)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../voice-conversation-preview.png")
	life.close_dialog()
	check(not a.talking and not b.talking and life.ai.group_members.is_empty(),"Leaving releases both residents")
	print("VOICE_INTERACTION_REVIEW_COMPLETE failures=",failures," real_microphone_opened=false")
	quit(0 if failures.is_empty() else 1)
