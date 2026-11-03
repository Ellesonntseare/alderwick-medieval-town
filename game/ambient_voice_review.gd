extends SceneTree

class Person extends Node3D:
	var person_name := "Duncan"
	var style := "bruce"
	var posture := "standing"
	var talking := false
	var social_partner: Node
	func has_conversation_partner() -> bool:return social_partner!=null
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
	var town := Town.new();root.add_child(town)
	town.player=Node3D.new();town.add_child(town.player)
	town.life=Life.new();town.add_child(town.life)
	var camera := Camera3D.new();town.add_child(camera);camera.current=true
	var person := Person.new();town.add_child(person)
	person.social_partner=Node.new();town.add_child(person.social_partner)
	var speech: Node=load("res://town_speech.gd").new();town.add_child(speech)
	speech.enabled=true;speech.gain=.7;speech.available=false
	var voice: AudioStreamPlayer3D=speech.configure(person)
	voice.stream=AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes("res://../review/characters/Duncan-voice.wav"))
	var bus := AudioServer.bus_count
	AudioServer.add_bus();AudioServer.set_bus_name(bus,"AmbientVoiceReview")
	var capture := AudioEffectCapture.new();capture.buffer_length=2
	AudioServer.add_bus_effect(bus,capture);voice.bus="AmbientVoiceReview"
	var levels: Array[float]=[]
	for distance in [2.0,8.0,18.0,30.0]:
		voice.stop();person.position.z=distance
		await create_timer(.1).timeout
		capture.clear_buffer();voice.play()
		await create_timer(.8).timeout
		var samples := capture.get_buffer(capture.get_frames_available())
		var energy := 0.0
		for sample in samples:energy+=sample.length_squared()
		var rms := sqrt(energy/maxi(1,samples.size()*2));levels.append(rms)
		print("QUIET_AMBIENT_LEVEL distance=",distance," rms=",rms," db=",voice.volume_db)
	var passed: bool=levels[0]>.0001 and levels[0]<.08 and levels[1]<levels[0]*.55 and levels[2]<levels[1] and levels[3]<.00001
	voice.stop();AudioServer.remove_bus(bus)
	print("AMBIENT_VOICE_REVIEW_COMPLETE passed=",passed," levels=",levels)
	quit(0 if passed else 1)
