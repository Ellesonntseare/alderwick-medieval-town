extends Node

var town: Node3D
var definitions: Array=[]
var progress: Dictionary={}
var relationships: Dictionary={}
var inventory: Dictionary={}
var memories: Array=[]
var markers: Dictionary={}
var visitor: CharacterBody3D
var journal: PanelContainer
var content: VBoxContainer
var prompt: Label
var conversation_action: Button
var previous_enabled:=false
var unit_test:=false
var save_path:="user://town-adventures.json"
var work_elapsed:=0.0
var active_work:=""
var repaired_cart: Node3D
var refresh_clock:=0.0
var connections: Dictionary={}
var work_player_enabled:=false

func _ready() -> void:
	town=get_parent()
	load_definitions()
	if town.economy.testing():save_path="user://review-adventures.json"
	load_state()
	make_interface()
	var button:=Button.new();button.text="Journal & relationships [J]"
	button.pressed.connect(toggle_journal);town.menu_body.add_child(button)
	setup_world.call_deferred()

func load_definitions() -> void:
	definitions=JSON.parse_string(FileAccess.get_file_as_string("res://story_missions.json")).missions
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://character_stories.json")).characters:connections[person.name]=person.connections
	for mission in definitions:
		if not progress.has(mission.id):progress[mission.id]={"status":"unmet","step":0}

func load_state() -> void:
	if not FileAccess.file_exists(save_path):return
	var saved=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not saved is Dictionary:return
	for id in saved.get("progress",{}):
		if progress.has(id):progress[id]=saved.progress[id]
	relationships=saved.get("relationships",{});inventory=saved.get("inventory",{})
	memories=saved.get("memories",[])

func save_state() -> void:
	if unit_test:return
	var trace := preload("res://frame_costs.gd").begin()
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"version":1,"progress":progress,"relationships":relationships,"inventory":inventory,"memories":memories}))
	if file:file.close()
	preload("res://frame_costs.gd").finish("adventures.save_state",trace)

func relationship(name: String) -> Dictionary:
	if not relationships.has(name):relationships[name]={"trust":0,"events":[],"promises":{},"trade_count":0}
	return relationships[name]

func remember(name: String,id: String,text: String,change: int) -> void:
	var data:=relationship(name)
	for event in data.events:
		if event.id==id:return
	data.trust=clampi(int(data.trust)+change,-25,25)
	data.events.append({"id":id,"text":text})
	if data.events.size()>35:data.events.pop_front()
	save_state()

func traded(name: String) -> void:
	var data:=relationship(name)
	data.trade_count+=1
	remember(name,"trade_"+str(mini(data.trade_count,3)),"The visitor bought food from my stall.",1)

func find_mission(id: String) -> Dictionary:
	for mission in definitions:
		if mission.id==id:return mission
	return {}

func meet(name: String) -> void:
	var changed:=false
	for mission in definitions:
		if mission.giver==name and progress[mission.id].status=="unmet" and unlocked(mission):progress[mission.id].status="offered";changed=true
	if changed:save_state()

func accept(id: String) -> bool:
	var mission:=find_mission(id)
	if mission.is_empty() or progress[id].status!="offered" or not unlocked(mission):return false
	progress[id].status="active";progress[id].step=0
	if not unit_test and town.events:
		var origin:=Vector3.ZERO
		for person in town.life.people:
			if person.person_name==mission.giver:origin=person.position;break
		town.events.publish("request_"+id,mission.summary,[mission.giver],origin)
	relationship(mission.giver).promises[id]="I offered to help: "+mission.title
	remember(mission.giver,"accepted_"+id,"The visitor promised to help with "+mission.title+".",0)
	if not unit_test:town.economy.announce("You offered to help "+mission.giver+". Your journal has the next lead.")
	update_markers();refresh_journal();return true

func unlocked(mission: Dictionary) -> bool:
	for id in mission.get("requires",[]):
		if not progress.has(id) or progress[id].status!="complete":return false
	return true

func abandon(id: String) -> void:
	if progress[id].status!="active":return
	var mission:=find_mission(id)
	progress[id].status="offered";progress[id].step=0
	progress[id].erase("notes")
	for step in mission.steps:
		if step.has("item") and (step.kind in ["collect","work"] or step.item=="Repaired wagon fittings"):inventory.erase(step.item)
	relationship(mission.giver).promises.erase(id)
	remember(mission.giver,"abandoned_"+id,"The visitor told me they could not keep their offer to help.",-2)
	update_markers();save_state();refresh_journal()

func before_message(person: Node,message: String) -> void:
	meet(person.person_name)
	var text:=message.to_lower().replace("’","'")
	var offer:=false
	for phrase in ["i'll help","i will help","i can help","let me help","count me in","i'll look","i will look","i accept","i'll find","i will find","i'll track","i will track","leave it with me","i'll take care","happy to help"]:
		if text.contains(phrase):offer=true
	if not text.contains("not help") and not text.contains("won't help") and offer:
		for mission in definitions:
			if mission.giver==person.person_name and progress[mission.id].status=="offered":accept(mission.id);break
	for insult in ["you're useless","you are useless","you idiot","you are an idiot"]:
		if text.contains(insult):remember(person.person_name,"insult_"+str(memories.size()),"The visitor insulted me during our conversation.",-2);break
	for friend in connections.get(person.person_name,{}):
		if text.contains(String(friend).to_lower()) and (text.contains("idiot") or text.contains("useless")):
			remember(person.person_name,"friend_insult_"+str(memories.size()),"The visitor spoke cruelly about "+friend+" in front of me.",-1);break
	for phrase in ["i can no longer help","i cannot keep my promise","i'm giving up","i withdraw my offer"]:
		if text.contains(phrase):
			for mission in definitions:
				if mission.giver==person.person_name:abandon(mission.id)
	memories.append({"person":person.person_name,"message":message.left(180)})
	if memories.size()>100:memories.pop_front()
	save_state()

func dialogue_context(person: Node) -> Dictionary:
	var name: String=person.person_name
	var data:=relationship(name)
	var facts: Array=[]
	for mission in definitions:
		var state: Dictionary=progress[mission.id]
		if state.status=="offered" and mission.giver==name:
			facts.append({"request":mission.summary,"reward_coins":mission.reward,"status":"You may ask for help. The visitor must actually accept before any progress or rewards."})
		elif state.status=="active":
			var step: Dictionary=mission.steps[int(state.step)]
			if mission.giver==name and int(state.step)==0:facts.append({"request_in_progress":mission.summary,"your_first_lead":mission.get("first_lead","")})
			if step.get("person","")==name:facts.append({"mission":mission.title,"known_fact":step.get("fact",""),"objective":step.text})
		elif state.status=="complete" and mission.giver==name:facts.append({"completed":mission.title,"real_result":"The visitor completed this task and received its reward."})
	var result: Dictionary={"trust_score":data.trust,"remembered_actions":data.events.slice(maxi(0,data.events.size()-8)),"unfulfilled_promises":data.promises,"mission_facts_you_know":facts}
	if town.families:result["family"]=town.families.context(name)
	if town.events:result["surroundings_and_news"]=town.events.context(person)
	if town.discoveries:result["discoveries_shown_to_you"]=town.discoveries.context(person)
	result["instruction"]="Speak naturally. When asked about an active task, share its known facts. These gameplay records override invented claims. Do not claim an item was delivered, a mission accepted, or coins paid unless recorded here. Ordinary conversation is welcome."
	return result

func after_reply(person: Node,message: String) -> void:
	var text:=message.to_lower()
	var relevant:=false
	for word in ["delivery","crate","parcel","shipment","bundle","vegetable","ada","fitting","wagon","oren","ansel","surveyor","where","safe","check","found","brought","here","ready","finished","done","return","sorted","fixed"]:
		if text.contains(word):relevant=true;break
	if not relevant:return
	for mission in definitions:
		var state: Dictionary=progress[mission.id]
		if state.status!="active":continue
		var step: Dictionary=mission.steps[int(state.step)]
		if step.get("person","")!=person.person_name:continue
		if step.kind=="talk":advance(mission.id)
		elif step.kind=="handin":
			var returning:=false
			for word in ["here","brought","back","deliver","return","found","safe","finished","done","ready","got your","check-in","checked","sorted","fixed"]:
				if text.contains(word):returning=true;break
			if not returning:continue
			if step.has("item") and int(inventory.get(step.item,0))<1:continue
			if step.has("item"):inventory.erase(step.item)
			advance(mission.id)
	refresh_conversation_action()

func advance(id: String) -> void:
	var mission:=find_mission(id)
	var state: Dictionary=progress[id]
	if state.status!="active":return
	state.step+=1
	if state.step>=mission.steps.size():
		state.status="complete"
		relationship(mission.giver).promises.erase(id)
		remember(mission.giver,"completed_"+id,"The visitor kept their promise and completed "+mission.title+".",5)
		inventory[mission.item_reward]=1
		apply_result(mission)
		if not unit_test:town.economy.announce(mission.title+" complete · "+str(mission.reward)+" coins")
	save_state();update_markers();refresh_journal()

func apply_result(mission: Dictionary) -> void:
	if unit_test:return
	if town.events:
		var results: Dictionary={"missing_delivery":"The visitor returned Ada's misplaced greens. The square market received twelve vegetable portions.","wagon_fittings":"The visitor helped fit Oren's replacement wagon parts. His repaired wagon is ready in the workyard.","overdue_surveyor":"The visitor personally found Ansel safe at the western gatehouse and brought Greta his check-in."}
		var origin:=Vector3.ZERO
		for person in town.life.people:
			if person.person_name==mission.giver:origin=person.position;break
		town.events.publish("resolved_"+mission.id,String(mission.get("result_news",results.get(mission.id,mission.summary))),[mission.giver],origin)
	if town.economy.award_story(mission.id,mission.reward) and mission.id=="missing_delivery":
		town.jobs.markets.city.stock+=12;town.jobs.markets.city.received+=12
		town.jobs.update_market("city")
	if mission.id=="wagon_fittings" and repaired_cart:repaired_cart.show()

func step_position(step: Dictionary) -> Vector3:
	var p: Array=step.get("position",[0,0,0])
	return Vector3(p[0],p[1],p[2])

func setup_world() -> void:
	while not town.life.navigation_ready:await get_tree().process_frame
	for mission in definitions:
		for index in range(mission.steps.size()):
			var step: Dictionary=mission.steps[index]
			if step.kind not in ["collect","work"]:continue
			var marker:=Node3D.new();town.add_child(marker);marker.position=step_position(step)
			if step.kind=="collect":town.detailed_prop("Crate_Wooden",marker,Vector3.ZERO,Vector3(.65,.5,.55),false)
			var label:=Label3D.new();marker.add_child(label)
			label.text=step.get("item","Work here");label.position.y=1.05
			label.font_size=18;label.pixel_size=.005;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			markers[mission.id+":"+str(index)]=marker
	var before:=town.get_child_count()
	town.model(town,"Prop_Wagon",Vector3(38,0,20),PI/2,false)
	repaired_cart=town.get_child(before);repaired_cart.visible=progress.wagon_fittings.status=="complete"
	spawn_visitor()
	for mission in definitions:
		if progress[mission.id].status=="complete":apply_result(mission)
	update_markers()
	print("ADVENTURES_READY missions=",definitions.size()," visitor=Ansel")

func spawn_visitor() -> void:
	visitor=load("res://mission_visitor.gd").new()
	visitor.person_name="Ansel";visitor.occupation="Visiting surveyor";visitor.home="Western survey camp"
	visitor.life=town.life;visitor.style="adventurer"
	visitor.set_meta("district","west")
	visitor.position=step_position(find_mission("overdue_surveyor").steps[2])+Vector3(0,.05,1.2)
	town.add_child(visitor)
	visitor.activity="Recording the old masonry"
	visitor.survey_origin=visitor.position;visitor.survey_target=visitor.position
	var camp:=Node3D.new();town.add_child(camp)
	camp.position=visitor.position+Vector3(3.2,0,1.8)
	var ray:=PhysicsRayQueryParameters3D.create(camp.position+Vector3.UP*1.2,camp.position-Vector3.UP*2,1)
	var floor_hit:=town.get_world_3d().direct_space_state.intersect_ray(ray)
	if not floor_hit.is_empty():camp.position.y=floor_hit.position.y
	town.detailed_prop("Bed_Twin1",camp,Vector3.ZERO,Vector3(1.25,.6,2.15),true)
	var bed:=Marker3D.new();camp.add_child(bed);bed.position=Vector3(0,.6,-.85)
	bed.add_to_group("beds");bed.set_meta("resident_owner","Ansel")
	visitor.assigned_bed=bed

func update_markers() -> void:
	if unit_test:return
	for key in markers:
		var parts: PackedStringArray=key.split(":")
		markers[key].visible=progress[parts[0]].status=="active" and int(progress[parts[0]].step)==int(parts[1])

func nearby_task() -> String:
	for mission in definitions:
		var state: Dictionary=progress[mission.id]
		if state.status!="active":continue
		var step: Dictionary=mission.steps[int(state.step)]
		if step.kind in ["collect","work"] and town.player.position.distance_to(step_position(step))<2.4:return mission.id
	return ""

func use_task(id: String) -> bool:
	var mission:=find_mission(id)
	if mission.is_empty() or progress[id].status!="active":return false
	var step: Dictionary=mission.steps[int(progress[id].step)]
	if town.player.position.distance_to(step_position(step))>2.4:return false
	if step.kind=="collect":inventory[step.item]=1;advance(id);return true
	return false

func _process(delta: float) -> void:
	if not prompt or not town.life:return
	refresh_clock+=delta
	if refresh_clock>.4:
		refresh_clock=0;refresh_conversation_action()
	if journal.visible or town.life.active or (town.builder and town.builder.active):prompt.hide();return
	var id:=nearby_task()
	var focused:=preload("res://interaction_target.gd").uses_focus(town)
	if focused:
		var target: Dictionary=town.life.hud_target
		if not preload("res://interaction_target.gd").gameplay_visible(town) or target.get("kind","")!="task" or target.get("id","")!=id:id=""
	prompt.visible=not focused and not id.is_empty()
	if id.is_empty():stop_work();return
	var step: Dictionary=find_mission(id).steps[int(progress[id].step)]
	if step.kind=="collect":prompt.text="E · Pick up "+step.item
	else:
		if active_work!=id:active_work=id;work_elapsed=0
		if Input.is_physical_key_pressed(KEY_E):
			if work_elapsed==0:
				work_player_enabled=town.player.enabled;town.player.enabled=false
				town.player.velocity=Vector3.ZERO
				if town.player.animator.has_animation("WorkTable"):town.player.animator.play("WorkTable",.2)
			work_elapsed+=delta
			if work_elapsed>=4:
				inventory.erase(step.item);inventory["Repaired wagon fittings"]=1;advance(id);stop_work()
		else:stop_work()
		prompt.text="Hold E · Fit wagon parts · %d%%"%int(work_elapsed/4*100)

func stop_work() -> void:
	if work_elapsed>0:town.player.enabled=work_player_enabled
	active_work="";work_elapsed=0

func handle_input(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:return false
	if journal and journal.visible:
		if event.physical_keycode in [KEY_J,KEY_ESCAPE]:toggle_journal()
		return true
	if town.life.active:return false
	if event.physical_keycode==KEY_J:toggle_journal();return true
	if town.view_mode==1:return false
	if preload("res://interaction_target.gd").uses_focus(town):return false
	if event.physical_keycode==KEY_E:
		var id:=nearby_task()
		if not id.is_empty():use_task(id);return true
	if event.physical_keycode==KEY_F and is_instance_valid(visitor) and visitor.position.distance_to(town.player.position)<3.2:
		town.life.open_dialog(visitor);return true
	return false

func make_interface() -> void:
	var layer:=CanvasLayer.new();layer.layer=18;add_child(layer)
	prompt=Label.new();prompt.position=Vector2(30,510);layer.add_child(prompt)
	prompt.add_theme_color_override("font_shadow_color",Color.BLACK)
	journal=PanelContainer.new();layer.add_child(journal);journal.hide()
	var style:=StyleBoxFlat.new();style.bg_color=Color(.035,.055,.045,.98)
	style.content_margin_left=20;style.content_margin_right=20;style.content_margin_top=18;style.content_margin_bottom=18
	style.set_corner_radius_all(10);journal.add_theme_stylebox_override("panel",style)
	journal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	journal.position=Vector2(350,45);journal.size=Vector2(650,650)
	var outer:=VBoxContainer.new();journal.add_child(outer)
	var header:=HBoxContainer.new();outer.add_child(header)
	var title:=Label.new();title.text="Your journal · people, promises & belongings";title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	var close:=Button.new();close.text="Close [J]";close.pressed.connect(toggle_journal);header.add_child(close)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;outer.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
	conversation_action=Button.new()
	var conversation_column: VBoxContainer=town.life.dialog.get_child(0)
	conversation_column.add_child(conversation_action)
	conversation_column.move_child(conversation_action,mini(4,conversation_column.get_child_count()-1))
	conversation_action.hide()
	conversation_action.pressed.connect(func():
		if not town.life.active:return
		var person: CharacterBody3D=town.life.active
		var action:=resident_action(person)
		if action.is_empty():return
		var step_index:=int(action.step)
		if step_index>=0 and not String(action.get("item","")).is_empty() and town.get("physical_gameplay"):
			var commit:=func() -> bool:
				var completed:=perform_resident_action(person,action.id,step_index)
				refresh_conversation_action()
				return completed
			if not town.physical_gameplay.animate_inventory_handover(person,action.item,commit):
				town.economy.announce("Stand close to the resident with your hands free to deliver the item.")
		else:perform_resident_action(person,action.id,step_index)
		refresh_conversation_action())

func resident_action(person: Node) -> Dictionary:
	# Physical mission interactions work independently of dialogue generation.
	if not is_instance_valid(person):return {}
	for mission in definitions:
		var state: Dictionary=progress[mission.id]
		if state.status!="active":continue
		var step: Dictionary=mission.steps[int(state.step)]
		if step.get("person","")!=person.person_name or step.kind not in ["talk","handin"]:continue
		var missing: bool=step.has("item") and int(inventory.get(step.item,0))<1
		return {"id":mission.id,"step":int(state.step),"text":String(step.get("action","Check the lead" if step.kind=="talk" else "Finish the delivery")),"missing":missing,"item":step.get("item","")}
	for mission in definitions:
		if mission.giver==person.person_name and progress[mission.id].status=="offered":return {"id":mission.id,"step":-1,"text":"Offer to help · "+mission.title,"missing":false}
	return {}

func perform_resident_action(person: Node,id: String,expected_step: int) -> bool:
	if not is_instance_valid(person) or not progress.has(id):return false
	if not unit_test:
		if person!=town.life.active or town.player.global_position.distance_to(person.global_position)>5:return false
		if person.posture=="sleeping":return false
	var mission:=find_mission(id)
	var state: Dictionary=progress[id]
	if expected_step==-1:
		if mission.giver!=person.person_name or state.status!="offered" or not accept(id):return false
		if not unit_test:town.life.transcript.text=mission.summary+"\n\n"+String(mission.get("first_lead",""))
		return true
	if state.status!="active" or int(state.step)!=expected_step:return false
	var step: Dictionary=mission.steps[expected_step]
	if step.get("person","")!=person.person_name or step.kind not in ["talk","handin"]:return false
	if step.has("item"):
		if int(inventory.get(step.item,0))<1:return false
		inventory[step.item]=int(inventory[step.item])-1
		if inventory[step.item]<=0:inventory.erase(step.item)
	if not state.has("notes"):state["notes"]=[]
	var note: String=String(step.get("journal_note",step.text))
	state.notes.append({"person":person.person_name,"text":note})
	advance(id)
	if not unit_test:
		town.life.transcript.text="Journal updated\n\n"+note
		town.economy.announce("Updated · "+mission.title)
	return true

func refresh_conversation_action() -> void:
	if not conversation_action:return
	conversation_action.hide()
	if not town.life.active:return
	meet(town.life.active.person_name)
	var action:=resident_action(town.life.active)
	if not action.is_empty():
		conversation_action.text="Bring "+String(action.item) if action.missing else action.text
		conversation_action.disabled=action.missing
		conversation_action.show()

func toggle_journal() -> void:
	var book_ui: Node=town.get("interface_ui")
	if book_ui and book_ui.ready_for_use:
		if book_ui.active and book_ui.opened_page=="Journal":book_ui.close()
		else:book_ui.open_page("Journal")
		return
	stop_work()
	if journal.visible:
		journal.hide();town.player.enabled=previous_enabled
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if previous_enabled else Input.MOUSE_MODE_VISIBLE
	else:
		if town.life.active:town.life.close_dialog()
		previous_enabled=town.player.enabled;town.player.enabled=false
		town.player.velocity=Vector3.ZERO
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		refresh_journal();journal.show()

func text_line(text: String) -> void:
	var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x=570;content.add_child(label)

func refresh_journal() -> void:
	if unit_test or not content:return
	for child in content.get_children():content.remove_child(child);child.queue_free()
	for mission in definitions:
		var state: Dictionary=progress[mission.id]
		if not unlocked(mission):
			text_line(mission.title+" · Complete "+String(find_mission(mission.requires[0]).get("title","the preceding request"))+" first.")
			continue
		var status: String={"unmet":"Ask "+mission.giver,"offered":"Available","active":"In progress","complete":"Completed"}.get(state.status,"Available")
		text_line(mission.title+" · "+status+" · %d coins"%int(mission.reward))
		text_line(mission.summary)
		if state.status=="unmet":text_line("Speak with "+mission.giver+" to learn more.")
		elif state.status=="active":
			text_line("Next: "+mission.steps[int(state.step)].text)
			var button:=Button.new();button.text="Tell "+mission.giver+" I can no longer help"
			button.pressed.connect(abandon.bind(mission.id));content.add_child(button)
		for note in state.get("notes",[]):text_line(String(note.person)+" · "+String(note.text))
		content.add_child(HSeparator.new())
	var belongings: Array[String]=[]
	for item in inventory:belongings.append(str(inventory[item])+" × "+item)
	text_line("Belongings: "+(", ".join(belongings) if not belongings.is_empty() else "Nothing carried yet"))
	if int(inventory.get("Market favour",0))>0:
		var redeem:=Button.new();redeem.text="Trade Ada's market favour for two meals · visit Ada's open stall"
		redeem.pressed.connect(redeem_market_favour);content.add_child(redeem)
	text_line("Relationships")
	for name in relationships:
		var data: Dictionary=relationships[name]
		var feeling: String="Trusted" if data.trust>=5 else "Wary" if data.trust<0 else "Getting to know you"
		text_line(name+" · "+feeling+" · %d open promises"%data.promises.size())
		if not data.events.is_empty():text_line(data.events[-1].text)
	text_line("Households")
	if town.families:
		for family in town.families.households:
			text_line(family.title+": "+", ".join(family.members.keys())+(" — "+String(family.house.name) if family.has("house") else ""))

func redeem_market_favour() -> bool:
	if int(inventory.get("Market favour",0))<1:return false
	for person in town.life.people:
		if person.person_name!="Ada":continue
		if person.position.distance_to(town.player.position)>3:break
		if not town.economy.open_for_trade(person):return false
		inventory.erase("Market favour");town.economy.player_food+=2
		town.economy.refresh();remember("Ada","market_favour_redeemed","The visitor traded my favour for a meal parcel.",1)
		refresh_journal();return true
	town.economy.announce("Visit Ada's stall during the day to trade the favour.")
	return false
