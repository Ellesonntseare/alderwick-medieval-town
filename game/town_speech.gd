extends Node

const Phone=preload("res://mobile_runtime.gd")
const Features=preload("res://dialogue_features.gd")

var URL := "http://127.0.0.1:34319"
const VOICES_M := ["bm_george","bm_daniel","bm_fable","bm_lewis"]
const VOICES_F := ["bf_emma","bf_alice","bf_isabella","bf_lily"]
var town: Node3D
var enabled := true
var available := false
var starting := false
var backend_pid := 0
var health_clock := 0.0
var health: HTTPRequest
var listener: AudioListener3D
var players: Dictionary={}
var tokens: Dictionary={}
var pending: Dictionary={}
var next_lines: Dictionary={}
var cache: Dictionary={}
var warming: Dictionary={}
var volume := -13.0
var direct_volume := -9.0
var gain := 0.7
var ambient_enabled := true
var listening := false
var recognition_available := false
var health_pending := false
var voice_profiles: Dictionary={}
var generated := 0
var played := 0

func _ready() -> void:
	if not Features.ENABLED:
		town=get_parent()
		enabled=false
		ambient_enabled=false
		set_process(false)
		return
	URL=Phone.backend_url(34319)
	town=get_parent()
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://voice_profiles.json"))
	if data is Dictionary:voice_profiles=data.get("profiles",{})
	var settings := ConfigFile.new()
	if settings.load("user://voice-settings.cfg")==OK:
		enabled=bool(settings.get_value("voices","enabled",true))
		ambient_enabled=bool(settings.get_value("voices","ambient",true))
		gain=clampf(float(settings.get_value("voices","volume",0.7)),0,1)
	build_controls.call_deferred()
	listener=AudioListener3D.new()
	add_child(listener)
	get_viewport().audio_listener_enable_3d=true
	listener.make_current()
	health=HTTPRequest.new()
	add_child(health)
	health.timeout=2
	health.request_completed.connect(health_result)
	if "--no-voices" not in OS.get_cmdline_user_args():check_health()
	else:enabled=false

func check_health() -> void:
	if not Features.ENABLED:return
	if health_pending:return
	health_pending=true
	if health.request(URL+"/health?pid="+str(OS.get_process_id()))!=OK:health_pending=false

func health_result(_result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	if not Features.ENABLED:return
	health_pending=false
	available=code==200
	var data=JSON.parse_string(body.get_string_from_utf8()) if available else null
	recognition_available=data is Dictionary and data.get("recognition_ready",false)
	if available:starting=false;return
	if Phone.enabled():return
	if starting and OS.is_process_running(backend_pid):return
	var folder := ProjectSettings.globalize_path("res://../tools/speech/")
	var executable := folder+"python/pythonw.exe"
	if not FileAccess.file_exists(executable):executable=folder+"python/python.exe"
	if FileAccess.file_exists(executable):
		backend_pid=OS.create_process(executable,PackedStringArray([folder+"server.py"]),false)
		starting=true

func _process(delta: float) -> void:
	if not town.player:return
	listener.global_position=town.player.global_position+Vector3.UP*1.6
	listener.global_rotation=Vector3(0,town.player.global_rotation.y,0)
	if town.view_mode==1:
		listener.global_rotation.y=town.overview.global_rotation.y
	if town.life and town.life.active:
		listener.global_position=town.life.active.global_position+Vector3(0,1.6,2)
		if town.life.ai and town.life.ai.camera:listener.global_rotation.y=town.life.ai.camera.global_rotation.y
	health_clock+=delta
	var microphone_requested: bool=town.life and town.life.active and town.life.ai and town.life.ai.get("voice_input")!=null and town.life.ai.voice_input.selector.selected==1
	if (enabled or microphone_requested) and health_clock>5:
		health_clock=0
		check_health()
	for person in players:
		var voice: AudioStreamPlayer3D=players[person]
		if not is_instance_valid(person):continue
		if voice.playing and not allowed(person):stop(person)
		voice.volume_db=(direct_volume if direct_conversation(person) else volume)+linear_to_db(maxf(gain,0.0001))
		if available and allowed(person) and not voice.playing and next_lines.has(person) and not pending.get(person,false):
			var lines: Array=next_lines[person]
			if not lines.is_empty():
				say(person,lines.pop_front(),true)
				if not lines.is_empty():precache(person,lines[0])
			else:next_lines.erase(person)

func allowed(person: Node) -> bool:
	if not Features.ENABLED:return false
	if not enabled or listening or gain<=0 or not is_instance_valid(person) or person.posture=="sleeping":return false
	if direct_conversation(person):return true
	if town.life.active or not ambient_enabled:return false
	return person.social_partner!=null and person.has_conversation_partner()

func direct_conversation(person: Node) -> bool:
	if town.life.active==person and person.talking:return true
	return town.life.ai!=null and town.life.ai.has_method("is_group_member") and town.life.ai.is_group_member(person)

func configure(person: Node3D) -> AudioStreamPlayer3D:
	if players.has(person):return players[person]
	var voice := AudioStreamPlayer3D.new()
	voice.name="Voice"
	person.add_child(voice)
	var height: float=float(person.get("appearance_height")) if person.get("appearance_height")!=null else 1.0
	voice.position=Vector3(0,1.55*height,0)
	voice.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.unit_size=2.2
	voice.max_distance=24.0
	voice.volume_db=volume
	voice.pitch_scale=float(voice_settings(person).get("pitch",1.0))
	voice.max_db=0
	voice.attenuation_filter_cutoff_hz=5500
	players[person]=voice
	return voice

func profile(person: Node) -> String:
	if voice_profiles.has(person.person_name):return voice_profiles[person.person_name].voice
	var female: bool= person.style in ["witch","viking"] or person.person_name in ["Mara","Nell","Sera","Ada","Greta","Lysa","Ingrid","Mina","Tilda","Hilda","Bodil","Ida","Erna","Alva","Liv","Edda"]
	var list: Array=VOICES_F if female else VOICES_M
	return list[posmod(person.person_name.hash(),list.size())]

func voice_settings(person: Node) -> Dictionary:
	return voice_profiles.get(person.person_name,{"voice":profile(person),"speed":1.0,"pitch":1.0})

func speech_key(person: Node,text: String) -> String:
	return JSON.stringify(voice_settings(person))+":"+text

func say(person: Node3D,text: String,direct := false) -> void:
	if not available or not allowed(person):return
	if not direct and listener.global_position.distance_to(person.global_position)>27:return
	var voice := configure(person)
	voice.stop()
	var token: int=int(tokens.get(person,0))+1
	tokens[person]=token
	var speed: float=float(voice_settings(person).get("speed",1.0))
	var key := speech_key(person,text)
	voice.volume_db=(direct_volume if direct_conversation(person) else volume)+linear_to_db(maxf(gain,0.0001))
	if cache.has(key):
		voice.stream=cache[key]
		voice.play()
		played+=1
		print("CHARACTER_VOICE_PLAYING name=",person.person_name," cached=true length=",voice.stream.get_length())
		return
	pending[person]=true
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout=40
	request.body_size_limit=4000000
	request.request_completed.connect(func(_result: int,code: int,_headers: PackedStringArray,body: PackedByteArray):
		request.queue_free()
		if not is_instance_valid(person) or int(tokens.get(person,0))!=token:return
		pending[person]=false
		if code!=200 or body.size()<44:return
		var stream := AudioStreamWAV.load_from_buffer(body)
		if not stream:return
		cache[key]=stream
		generated+=1
		if not allowed(person):return
		voice.stream=stream
		voice.play()
		played+=1)
	request.request(URL+"/speak",PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify({"text":text,"character":person.person_name,"voice":profile(person),"speed":speed,"pid":OS.get_process_id()}))

func read_dialogue(person: Node3D,text: String) -> void:
	if not Features.ENABLED:return
	stop(person)
	var pieces: Array[String]=[]
	var current := ""
	for word in text.replace("\n"," ").split(" ",false):
		if current.length()+word.length()>220 and not current.is_empty():pieces.append(current.strip_edges());current=""
		current+=word+" "
		if current.length()>100 and word.ends_with("."):pieces.append(current.strip_edges());current=""
	if not current.is_empty():pieces.append(current)
	if pieces.is_empty():return
	configure(person)
	next_lines[person]=pieces

func precache(person: Node3D,text: String) -> void:
	if not Features.ENABLED:return
	if not available or not enabled or listener.global_position.distance_to(person.global_position)>27:return
	var speed: float=float(voice_settings(person).get("speed",1.0))
	var key := speech_key(person,text)
	if cache.has(key) or warming.has(key):return
	warming[key]=true
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout=40
	request.request_completed.connect(func(_result: int,code: int,_headers: PackedStringArray,body: PackedByteArray):
		request.queue_free()
		warming.erase(key)
		if code==200 and body.size()>44:
			var stream := AudioStreamWAV.load_from_buffer(body)
			if stream:cache[key]=stream)
	request.request(URL+"/speak",PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify({"text":text,"character":person.person_name,"voice":profile(person),"speed":speed,"pid":OS.get_process_id()}))

func busy(person: Node) -> bool:
	return bool(pending.get(person,false)) or (players.has(person) and players[person].playing)

func stop(person: Node) -> void:
	tokens[person]=int(tokens.get(person,0))+1
	pending[person]=false
	next_lines.erase(person)
	if players.has(person):players[person].stop()

func set_enabled(value: bool) -> void:
	if not Features.ENABLED:
		enabled=false
		return
	enabled=value
	if not value:
		for person in players:stop(person)
	else:check_health()

func set_listening(value: bool) -> void:
	listening=value
	if value:
		for person in players:stop(person)

func save_settings() -> void:
	var settings := ConfigFile.new()
	settings.set_value("voices","enabled",enabled)
	settings.set_value("voices","ambient",ambient_enabled)
	settings.set_value("voices","volume",gain)
	settings.save("user://voice-settings.cfg")

func build_controls() -> void:
	if not town.get("menu_body") is Container:return
	var column: Container=town.get("menu_body")
	var voices := CheckBox.new()
	voices.text="Character voices"
	voices.button_pressed=enabled
	voices.toggled.connect(func(value: bool):set_enabled(value);save_settings())
	column.add_child(voices)
	var ambient := CheckBox.new()
	ambient.text="Hear nearby conversations"
	ambient.button_pressed=ambient_enabled
	ambient.toggled.connect(func(value: bool):ambient_enabled=value;save_settings())
	column.add_child(ambient)
	var row := HBoxContainer.new()
	column.add_child(row)
	var label := Label.new()
	label.text="Voice volume"
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value=0
	slider.max_value=1
	slider.step=.05
	slider.value=gain
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x=100
	slider.value_changed.connect(func(value: float):gain=value;save_settings())
	row.add_child(slider)

