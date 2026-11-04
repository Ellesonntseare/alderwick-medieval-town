extends Node

const Phone=preload("res://mobile_runtime.gd")

var URL := "http://127.0.0.1:34320"
var life: Node
var town: Node3D
var available := false
var backend_pid := 0
var clock := 0.0
var health: HTTPRequest
var health_pending:=false
var request: HTTPRequest
var generation := 0
var waiting := false
var status: Label
var submit: Button
var retry: Button
var camera: Camera3D
var histories: Dictionary={}
var social_busy := false
var social_clock := 0.0
var scope := "player"
var voice_input: Node
var group_members: Array[CharacterBody3D]=[]
var group_turns: Array[Dictionary]=[]
var group_target: OptionButton
var focused_person: CharacterBody3D
var group_index := 0

func _ready() -> void:
	URL=Phone.backend_url(34320)
	life=get_parent()
	town=life.town
	if "--review-character-chat" in OS.get_cmdline_user_args() or "--validate-character-chat" in OS.get_cmdline_user_args():scope="review"
	health=HTTPRequest.new()
	add_child(health)
	health.timeout=2
	health.request_completed.connect(health_result)
	camera=Camera3D.new()
	camera.name="ConversationCamera"
	camera.fov=54
	camera.near=0.06
	town.add_child(camera)
	if "--no-ai" not in OS.get_cmdline_user_args():check_health()

func check_health() -> void:
	if health_pending:return
	health_pending=true
	var error:=health.request(URL+"/health?pid="+str(OS.get_process_id()))
	if error!=OK:health_pending=false

func health_result(_result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	health_pending=false
	var data=JSON.parse_string(body.get_string_from_utf8()) if code==200 else null
	available=data is Dictionary and data.get("ready",false)==true
	if not Phone.enabled() and code!=200 and (backend_pid==0 or not OS.is_process_running(backend_pid)):
		var executable := ProjectSettings.globalize_path("res://../tools/speech/python/pythonw.exe")
		var script := ProjectSettings.globalize_path("res://../tools/ai/chat_server.py")
		if FileAccess.file_exists(executable):backend_pid=OS.create_process(executable,PackedStringArray([script]),false)
	if life.active and not waiting and status:status.text="Write a message to "+life.active.person_name+"." if available else "Conversations are loading…"
	if submit:submit.disabled=not available or waiting

func _process(delta: float) -> void:
	clock+=delta
	social_clock=maxf(0,social_clock-delta)
	if clock>4 and "--no-ai" not in OS.get_cmdline_user_args():clock=0;check_health()

func context(person: Node) -> Dictionary:
	var result := {"name":person.person_name,"occupation":person.occupation,"home":person.home,
		"current_activity":person.activity,"district":person.get_meta("district"),
		"time":"night" if town.day_night.night else "day","recent_personal_events":person.recent_events,
		"news_actually_heard":person.heard_events,"guard_post":person.guard_label}
	if person.get("friendships") is Dictionary:result["familiar_neighbours"]=person.friendships
	if person.get("coins")!=null:result["own_coins"]=person.coins
	if not person.stall_name.is_empty() and town.economy:
		result["stall_goods"]=person.stall_name
		result["food_price_coins"]=town.economy.player_food_price(person)
		result["food_in_stock"]=town.economy.market_for(person).stock
	if town.adventures:result["player_story_state"]=town.adventures.dialogue_context(person)
	elif town.families:result["family"]=town.families.context(person.person_name)
	if town.get("character_life")!=null and town.character_life.bound:result["personal_life"]=town.character_life.context(person)
	if not group_members.is_empty():
		var participants: Array=[]
		for member in group_members:participants.append({"name":member.person_name,"occupation":member.occupation})
		result["joined_conversation"]={"participants":participants,"recent_turns":group_turns.slice(-12),"player_has_joined":true}
	return result

func open(person: CharacterBody3D) -> void:
	generation+=1
	waiting=false
	if voice_input:voice_input.cancel()
	life.transcript.text=""
	status.text="Write a message to "+person.person_name+"." if available else "Conversations are loading…"
	submit.disabled=not available
	retry.hide()
	focus_character(person)
	settle_layout.call_deferred()
	var ticket := generation
	var load_history := HTTPRequest.new()
	add_child(load_history)
	load_history.timeout=5
	load_history.request_completed.connect(func(_result: int,code: int,_headers: PackedStringArray,body: PackedByteArray):
		load_history.queue_free()
		if ticket!=generation or life.active!=person or not group_members.is_empty():return
		var data=JSON.parse_string(body.get_string_from_utf8()) if code==200 else null
		if data is Dictionary and not waiting:
			var saved: Array=data.get("messages",[])
			if saved.size()>=histories.get(person.person_name,[]).size():histories[person.person_name]=saved
			render_history(person.person_name)
		elif histories.has(person.person_name):render_history(person.person_name))
	load_history.request(URL+"/history?name="+person.person_name.uri_encode()+"&scope="+scope+"&pid="+str(OS.get_process_id()))

func render_history(name: String) -> void:
	var text := ""
	for turn in histories.get(name,[]):
		text+=("You" if turn.role=="user" else name)+":\n"+String(turn.content)+"\n\n"
	life.transcript.text=text

func send(text: String) -> void:
	if not life.active or waiting or text.strip_edges().is_empty():return
	if voice_input and (voice_input.recording or voice_input.recognizing):voice_input.cancel()
	if not group_members.is_empty():send_group(text);return
	if not available:
		status.text="Conversations are still loading. Please try again in a moment."
		check_health()
		return
	var person: CharacterBody3D=life.active
	var message := text.strip_edges().left(1000)
	if town.adventures:town.adventures.before_message(person,message)
	var ticket := generation
	waiting=true
	submit.disabled=true
	retry.hide()
	status.text=person.person_name+" is thinking…"
	life.entry.clear()
	if town.speech:town.speech.stop(person)
	life.transcript.append_text("You:\n"+message+"\n\n")
	var call := HTTPRequest.new()
	request=call
	add_child(call)
	call.timeout=160
	call.body_size_limit=64000
	call.request_completed.connect(func(_result: int,code: int,_headers: PackedStringArray,body: PackedByteArray):
		call.queue_free()
		if ticket!=generation or life.active!=person:return
		waiting=false
		submit.disabled=not available
		var data=JSON.parse_string(body.get_string_from_utf8()) if code==200 else null
		if not (data is Dictionary and data.get("generated",false)==true and data.get("reply","")!=""):
			status.text="The reply could not finish. Your message is still here; you can try again."
			life.entry.text=message
			retry.show()
			return
		var answer: String=data.reply
		if town.adventures:town.adventures.after_reply(person,message)
		if town.get("character_life")!=null:town.character_life.conversed(person)
		if not histories.has(person.person_name):histories[person.person_name]=[]
		histories[person.person_name].append({"role":"user","content":message})
		histories[person.person_name].append({"role":"assistant","content":answer})
		render_history(person.person_name)
		status.text=""
		if town.speech:town.speech.read_dialogue(person,answer)
		life.entry.grab_focus())
	call.request(URL+"/chat",PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify({"name":person.person_name,"message":message,"context":context(person),"pid":OS.get_process_id(),"scope":scope}))

func close() -> void:
	focused_person=null
	generation+=1
	waiting=false
	if voice_input:voice_input.cancel()
	for person in group_members:
		if not is_instance_valid(person):continue
		person.talking=false
		if town.speech:town.speech.stop(person)
		if town.day_night.night and person.guard_shift!="night" and not person.night_schedule:life.assign_home(person)
	group_members.clear()
	group_turns.clear()
	if group_target:group_target.hide()
	if is_instance_valid(request):request.cancel_request();request.queue_free()
	camera.current=false
	if life.active==null:town.set_view(town.view_mode)

func focus_character(person: CharacterBody3D) -> void:
	var target := person.global_position+Vector3.UP*1.25
	var forward := Vector3(sin(person.visual.global_rotation.y),0,cos(person.visual.global_rotation.y))
	var chosen := target+forward*2.6+Vector3.UP*0.5
	var space := town.get_world_3d().direct_space_state
	var best := -INF
	for angle in [0.0,0.5,-0.5,1.0,-1.0,PI]:
		var desired := target+forward.rotated(Vector3.UP,angle)*3.1+Vector3.UP*0.45
		var ray := PhysicsRayQueryParameters3D.create(target,desired,1)
		ray.exclude=[town.player.get_rid(),person.get_rid()]
		var hit := space.intersect_ray(ray)
		if hit:desired=hit.position+(target-hit.position).normalized()*0.2
		var score := target.distance_to(desired)-absf(angle)*0.35
		if score>best:best=score;chosen=desired
	camera.global_position=chosen
	camera.look_at(target)
	camera.look_at(target+camera.global_basis.x*0.62)
	camera.current=true

func layout() -> void:
	if not life.dialog:return
	var size := get_viewport().get_visible_rect().size
	var width := clampf(size.x*0.37,350,470)
	var phone: bool=Phone.enabled()
	if phone:width=minf(size.x-24,maxf(460,size.x*.48))
	life.dialog.custom_minimum_size=Vector2(width,0)
	life.dialog.position=Vector2(size.x-width-(12 if phone else 20),12 if phone else 24)
	life.dialog.size=Vector2(width,size.y-(24 if phone else 48))
	if life.dialog.visible:print("CHAT_PANEL_LAYOUT viewport=",size," panel=",life.dialog.get_rect())

func settle_layout() -> void:
	# Wrapping labels report their true minimum after container layout.
	for frame in range(3):await get_tree().process_frame
	if life.dialog.visible:layout()

func tick_social(person: CharacterBody3D,chat: Dictionary,delta: float) -> void:
	chat.elapsed+=delta
	# Keep the pair together while inference/audio is pending; an old short
	# social timer must not make them leave before the generated voice arrives.
	if chat.get("pending",false) or (chat.index>=0 and town.speech and town.speech.busy(chat.speaker)):
		if chat.elapsed>65:person.end_social();return
		chat.a.social_time=maxf(chat.a.social_time,4.0)
		chat.b.social_time=maxf(chat.b.social_time,4.0)
		return
	if chat.index>=0:
		if chat.elapsed<chat.minimum or (town.speech and town.speech.busy(chat.speaker) and chat.elapsed<25):return
		if town.speech:town.speech.stop(chat.speaker)
	if chat.index>=3:person.end_social();return
	if not available or life.active or social_busy or social_clock>0:
		if chat.elapsed>8:person.end_social()
		return
	if town.player.global_position.distance_to(person.global_position)>24:
		if chat.elapsed>7:person.end_social()
		return
	var next: int=int(chat.index)+1
	var speaker: CharacterBody3D=chat.a if next%2==0 else chat.b
	var partner: CharacterBody3D=chat.b if speaker==chat.a else chat.a
	chat.pending=true
	social_busy=true
	var exchange: Array=[]
	for turn in chat.turns:exchange.append({"name":turn.speaker.person_name,"text":turn.text})
	var call := HTTPRequest.new()
	add_child(call)
	call.timeout=65
	call.request_completed.connect(func(_result: int,code: int,_headers: PackedStringArray,body: PackedByteArray):
		call.queue_free()
		social_busy=false
		if not life.chats.has(person.chat_id) or life.chats[person.chat_id]!=chat or not speaker.has_conversation_partner():return
		chat.pending=false
		var data=JSON.parse_string(body.get_string_from_utf8()) if code==200 else null
		if not (data is Dictionary and data.get("reply","")!=""):
			person.end_social()
			return
		chat.index=next
		social_clock=1.0
		chat.speaker=speaker
		chat.turns.append({"speaker":speaker,"text":String(data.reply)})
		chat.elapsed=0.0
		chat.minimum=clampf(String(data.reply).length()/18.0,3.0,11.0)
		chat.a.social_speaking=speaker==chat.a
		chat.b.social_speaking=speaker==chat.b
		speaker.bubble.text=data.reply
		if town.speech:town.speech.say(speaker,data.reply))
	call.request(URL+"/social",PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify({"name":speaker.person_name,"partner":partner.person_name,"exchange":exchange,"context":context(speaker),"pid":OS.get_process_id()}))

func is_group_member(person: Node) -> bool:
	return group_members.has(person) and person.talking and life.active!=null

func begin_group(first: CharacterBody3D,second: CharacterBody3D,overheard: Array[Dictionary]) -> void:
	focused_person=first
	group_members.assign([first,second])
	group_turns=overheard.duplicate(true)
	group_index=0
	for person in group_members:
		person.stand_up()
		person.talking=true
		person.label.hide()
		if town.speech:town.speech.stop(person)
	life.heading.text=first.person_name+" & "+second.person_name
	group_target.clear()
	group_target.add_item("Speak to either person")
	group_target.add_item(first.person_name)
	group_target.add_item(second.person_name)
	group_target.show()
	status.text="You joined their conversation. Type or use your microphone."
	render_group()

func render_group() -> void:
	var text := "You joined the conversation.\n\n"
	for turn in group_turns:text+=String(turn.name)+":\n"+String(turn.text)+"\n\n"
	life.transcript.text=text

func send_group(text: String) -> void:
	if not available:status.text="Conversations are still loading. Please try again shortly.";check_health();return
	var index := group_index%group_members.size() if group_target.selected==0 else group_target.selected-1
	if group_target.selected==0:
		for candidate in range(group_members.size()):
			var name: String=group_members[candidate].person_name.to_lower()
			if text.strip_edges().to_lower().begins_with(name+",") or text.strip_edges().to_lower().begins_with(name+" "):index=candidate;break
	var person: CharacterBody3D=group_members[index]
	focused_person=person
	var message := text.strip_edges().left(1000)
	var ticket := generation
	if town.adventures:town.adventures.before_message(person,message)
	group_turns.append({"name":"You","text":message})
	render_group()
	life.entry.clear()
	waiting=true
	submit.disabled=true
	retry.hide()
	status.text=person.person_name+" is thinking…"
	if town.speech:
		for member in group_members:town.speech.stop(member)
	var call := HTTPRequest.new()
	request=call
	add_child(call)
	call.timeout=160
	call.body_size_limit=64000
	call.request_completed.connect(func(_result: int,code: int,_headers: PackedStringArray,body: PackedByteArray):
		call.queue_free()
		if ticket!=generation or not group_members.has(person):return
		waiting=false
		submit.disabled=not available
		var data=JSON.parse_string(body.get_string_from_utf8()) if code==200 else null
		if not (data is Dictionary and data.get("generated",false) and not String(data.get("reply","")).is_empty()):
			group_turns.pop_back()
			render_group()
			life.entry.text=message
			status.text="The reply could not finish. Please try again."
			retry.show()
			return
		var answer: String=data.reply
		group_turns.append({"name":person.person_name,"text":answer})
		group_index=index+1
		render_group()
		status.text=""
		if town.adventures:town.adventures.after_reply(person,message)
		if town.get("character_life")!=null:town.character_life.conversed(person)
		if town.speech:town.speech.read_dialogue(person,answer)
		life.entry.grab_focus())
	call.request(URL+"/chat",PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify({"name":person.person_name,"message":message,"context":context(person),"scope":scope,"pid":OS.get_process_id()}))

