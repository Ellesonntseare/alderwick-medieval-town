extends SceneTree

class Person extends Node3D:
	var person_name := "Edric"
	var style := "knight"
	var posture := "standing"
	var talking := true
	var social_partner: Node
	func has_conversation_partner() -> bool:return false

class Life extends Node:
	var active: Node
	var ai: Node

class Town extends Node3D:
	var player: Node3D
	var life: Node
	var view_mode := 0
	var overview: Camera3D

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var town := Town.new()
	root.add_child(town)
	var camera := Camera3D.new()
	town.add_child(camera)
	camera.current=true
	town.player=Node3D.new()
	town.add_child(town.player)
	town.player.position.z=2
	town.life=Life.new()
	town.add_child(town.life)
	var person := Person.new()
	town.add_child(person)
	town.life.active=person
	var speech: Node=load("res://town_speech.gd").new()
	town.add_child(speech)
	var started := Time.get_ticks_msec()
	while not speech.available and Time.get_ticks_msec()-started<60000:await process_frame
	if not speech.available:print("LOCAL_GENERATED_VOICE_COMPLETE passed=false service_unavailable=true");quit(1);return
	var saved=JSON.parse_string(FileAccess.get_file_as_string("res://../tools/ai/state/review/Edric.json"))
	var text: String=saved.messages[-1].content
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus,"GeneratedVoiceReview")
	var capture := AudioEffectCapture.new()
	capture.buffer_length=10
	AudioServer.add_bus_effect(bus,capture)
	var voice: AudioStreamPlayer3D=speech.configure(person)
	voice.bus="GeneratedVoiceReview"
	speech.read_dialogue(person,text)
	started=Time.get_ticks_msec()
	while speech.played==0 and Time.get_ticks_msec()-started<55000:await process_frame
	var played: bool=speech.played>0
	if played:await create_timer(1.0).timeout
	var samples := capture.get_buffer(capture.get_frames_available())
	var power := 0.0
	for sample in samples:power+=sample.length_squared()
	var rms := sqrt(power/maxi(1,samples.size()*2))
	var passed := played and rms>0.001
	print("LOCAL_GENERATED_VOICE_COMPLETE passed=",passed," generated_text=",text," played=",speech.played," available=",speech.available," enabled=",speech.enabled," pending=",speech.pending," queued=",speech.next_lines," rms=",rms," frames=",samples.size())
	speech.stop(person)
	AudioServer.remove_bus(bus)
	voice.stream=null
	capture.clear_buffer()
	capture=null
	town.queue_free()
	for frame in range(2):await process_frame
	quit(0 if passed else 1)
