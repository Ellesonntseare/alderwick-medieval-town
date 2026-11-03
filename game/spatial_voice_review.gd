extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	root.audio_listener_enable_3d=true
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	var listener := AudioListener3D.new()
	stage.add_child(listener)
	listener.position.y=1.6
	listener.make_current()
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus,"VoiceCheck")
	var capture := AudioEffectCapture.new()
	capture.buffer_length=1.0
	AudioServer.add_bus_effect(bus,capture)
	var voice := AudioStreamPlayer3D.new()
	stage.add_child(voice)
	voice.stream=AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes("res://../tools/speech/bm_george-sample.wav"))
	voice.bus="VoiceCheck"
	voice.unit_size=3
	voice.max_distance=26
	voice.volume_db= -5
	print("VOICE_BUFFER_CHECK length=",voice.stream.get_length()," listener=",root.audio_listener_enable_3d)
	var levels: Array[float]=[]
	for distance in [2.0,12.0,40.0]:
		voice.stop()
		voice.position=Vector3(0,1.6,distance)
		await create_timer(0.12).timeout
		capture.clear_buffer()
		voice.play()
		await create_timer(0.65).timeout
		var samples := capture.get_buffer(capture.get_frames_available())
		var energy := 0.0
		for sample in samples:energy+=sample.length_squared()
		var rms := sqrt(energy/maxi(1,samples.size()*2))
		levels.append(rms)
		print("SPATIAL_VOICE_LEVEL distance=",distance," rms=",rms," frames=",samples.size())
	var passed: bool=levels[0]>0.001 and levels[1]<levels[0]*0.5 and levels[1]>0 and levels[2]<0.00001
	print("SPATIAL_VOICE_REVIEW_COMPLETE passed=",passed," levels=",levels)
	voice.stop()
	AudioServer.remove_bus(bus)
	quit(0 if passed else 1)
