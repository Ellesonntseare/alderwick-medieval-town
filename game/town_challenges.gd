extends Node

const DEFINITIONS={
	"archery":{"title":"Archery contest","instruction":"Score 3 target hits within 60 seconds","seconds":60,"reward":10,"point":Vector3(33,.1,43)},
	"delivery":{"title":"Market express","instruction":"Collect the challenge crate, then bring it to the square within 120 seconds","seconds":120,"reward":12,"point":Vector3(-32,.1,37)},
	"wood":{"title":"Timber order","instruction":"Chop 3 pieces of timber, then deliver them to the repair bench","seconds":0,"reward":15,"point":Vector3(-27,.1,39)},
	"repair":{"title":"Furniture repair","instruction":"Repair the damaged stool at the work area","seconds":0,"reward":10,"point":Vector3(-24,.1,39)}}
var town: Node
var active:=""
var remaining:=0.0
var baseline:=0
var finished: Array=[]
var panel: AcceptDialog
var message: Label
var crate: Node3D
var repair_job: Node3D
var completions: Dictionary={}
var cooldowns: Dictionary={}
var active_spec: Dictionary={}
var buttons: Dictionary={}
var ui_clock:=0.0
var save_path:="user://town-challenges.json"
const REPEAT_DELAY:=60.0
var previous_enabled:=true
var previous_mouse:=Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	town=get_parent();panel=AcceptDialog.new();panel.title="Town challenges";town.add_child(panel)
	var column:=VBoxContainer.new();panel.add_child(column)
	message=Label.new();message.custom_minimum_size.x=480;message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(message)
	for id in DEFINITIONS:
		var button:=Button.new();button.text=DEFINITIONS[id].title+" · "+str(DEFINITIONS[id].reward)+" coins";button.custom_minimum_size.y=48;column.add_child(button);buttons[id]=button
		button.pressed.connect(func():start(id))
	var cancel:=Button.new();cancel.text="Abandon current challenge";column.add_child(cancel);cancel.pressed.connect(func():abandon();message.text="Challenge abandoned.")
	panel.visibility_changed.connect(func():
		if not panel.visible:town.player.enabled=previous_enabled;Input.mouse_mode=previous_mouse)
	var shortcut:=Button.new();shortcut.text="Town challenges";town.menu_body.add_child(shortcut);shortcut.pressed.connect(func():
		previous_enabled=town.player.enabled;previous_mouse=Input.mouse_mode;town.player.enabled=false;town.player.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		message.text="Choose a challenge. One can be active at a time.";panel.popup_centered())
	load_state()
	refresh_options()

func contract(id: String) -> Dictionary:
	if not DEFINITIONS.has(id):return {}
	var spec: Dictionary=DEFINITIONS[id].duplicate(true)
	var count:=maxi(0,int(completions.get(id,0)))
	var tier:=count%3
	spec["quantity"]=3+tier
	spec["round"]=count+1
	spec["requester"]={"archery":["Fenn","Theo","Fenn"],"delivery":["Ada","Nell","Duncan"],"wood":["Oren","Finn","Astrid"],"repair":["Bram","Oren","Bodil"]}[id][tier]
	spec["skill"]={"archery":"Archery","delivery":"Trading","wood":"Carpentry","repair":"Carpentry"}[id]
	spec.reward=int(spec.reward)+tier*3
	if id=="archery":spec.seconds=60-tier*5
	if id=="delivery":
		spec["destination"]=[Vector3(8,.1,4),Vector3(-97,.1,103),Vector3(122,.1,101)][tier]
		spec["destination_name"]=["square market","western market","castle provisions"][tier]
		spec["market"]=["city","west","castle"][tier]
		spec["stock"]=4+tier*2
		spec.seconds=[120,150,180][tier]
	if id=="repair":spec.point=DEFINITIONS.repair.point+Vector3(tier*2,0,0)
	spec.instruction=String(spec.instruction)
	if id=="archery":spec.instruction="Score %d target hits within %d seconds"%[spec.quantity,spec.seconds]
	if id=="wood":spec.instruction="Chop %d pieces of timber, then deliver them to the repair bench"%spec.quantity
	if id=="delivery":spec.instruction="Collect the express crate and deliver it to the "+spec.destination_name
	return spec

func load_state() -> void:
	if not town.economy.testing() and FileAccess.file_exists(save_path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if data is Array:
			finished=data
			for id in data:
				if DEFINITIONS.has(id):completions[id]=1
		elif data is Dictionary:
			if data.get("completions") is Dictionary:completions=data.completions
			if data.get("cooldowns") is Dictionary:cooldowns=data.cooldowns
	# The wallet is authoritative if a previous run ended between the two saves.
	for id in DEFINITIONS:
		if town.economy.story_rewards.has("challenge_"+id):completions[id]=maxi(1,int(completions.get(id,0)))
		var prefix: String="challenge_"+id+"_repeat_"
		for reward in town.economy.story_rewards:
			if String(reward).begins_with(prefix):completions[id]=maxi(int(completions.get(id,0)),String(reward).trim_prefix(prefix).to_int())

func save_state() -> void:
	if town.economy.testing():return
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"version":2,"completions":completions,"cooldowns":cooldowns}))

func refresh_options() -> void:
	for id in buttons:
		var spec:=contract(id)
		var wait:=float(cooldowns.get(id,0))
		buttons[id].text=spec.title+" · "+spec.requester+" · %d coins · order %d"%[spec.reward,spec.round]+(" · ready in %ds"%ceili(wait) if wait>0 else "")
		buttons[id].disabled=wait>0

func abandon() -> void:
	if active=="delivery" and is_instance_valid(crate) and town.physical_gameplay.carried==crate:
		crate.reparent(town.physical_gameplay);crate.global_position=town.player.global_position+Vector3(1,0,0)
		crate.collision_layer=1;town.physical_gameplay.carried=null
	active="";active_spec={}

func start(id: String) -> void:
	if not DEFINITIONS.has(id):return
	if not active.is_empty():message.text="Finish or abandon your current challenge first.";return
	if float(cooldowns.get(id,0))>0:message.text="The next order will be ready in %d seconds."%ceili(float(cooldowns[id]));return
	if not town.life.navigation_ready or town.physical_gameplay.objects.is_empty():message.text="The town is still preparing.";return
	active=id;active_spec=contract(id);remaining=active_spec.seconds
	if town.menu_panel and not town.menu_collapsed:town.toggle_menu()
	baseline=town.physical_gameplay.score if id=="archery" else int(town.adventures.inventory.get("Timber",0))
	if id=="delivery":
		if not is_instance_valid(crate):crate=town.physical_gameplay.prop("Express delivery crate","Crate_Wooden",active_spec.point,"carry")
		if town.physical_gameplay.carried!=crate:crate.global_position=active_spec.point
	if id=="repair":
		if not is_instance_valid(repair_job):repair_job=town.physical_gameplay.prop("Damaged stool repair","Stool",active_spec.point+Vector3(1.5,0,0),"furniture_repair")
		repair_job.global_position=active_spec.point+Vector3(1.5,0,0)
		repair_job.set_meta("stock",1)
		for child in repair_job.get_children():
			if child is Node3D and not child is CollisionShape3D:child.rotation.z=.18
	if id=="wood":
		for object in town.physical_gameplay.objects:
			if object.get_meta("activity","")=="chop":object.set_meta("stock",maxi(int(active_spec.quantity),int(object.get_meta("stock",0))))
	panel.hide();town.economy.announce(active_spec.instruction)
	if town.get("town_map"):town.town_map.tracked="challenge"

func objective() -> Dictionary:
	if active.is_empty():return {}
	var point: Vector3=active_spec.point
	var instruction: String=active_spec.instruction
	var quantity:=int(active_spec.quantity)
	if active=="delivery" and is_instance_valid(crate):point=crate.global_position
	if active=="archery":instruction="Archery contest · %d / %d hits"%[mini(quantity,maxi(0,town.physical_gameplay.score-baseline)),quantity]
	if active=="wood":instruction="Timber order · %d / %d pieces chopped"%[mini(quantity,maxi(0,int(town.adventures.inventory.get("Timber",0))-baseline)),quantity]
	if active=="delivery" and town.physical_gameplay.carried==crate:point=active_spec.destination;instruction="Carry the express crate to the "+active_spec.destination_name
	if active=="wood" and int(town.adventures.inventory.get("Timber",0))-baseline>=quantity:point=DEFINITIONS.repair.point;instruction="Deliver %d pieces of timber to the repair bench"%quantity
	return {"point":point,"text":instruction+(" · %d seconds"%ceili(remaining) if remaining>0 else "")}

func complete() -> void:
	if active.is_empty():return
	var id:=active
	var spec:=active_spec.duplicate(true)
	active="";active_spec={}
	var round_number:=int(spec.round)
	var reward_id: String="challenge_"+id if round_number==1 else "challenge_"+id+"_repeat_"+str(round_number)
	if town.economy.award_story(reward_id,int(spec.reward)):
		completions[id]=round_number
		cooldowns[id]=REPEAT_DELAY
		if not finished.has(id):finished.append(id)
		if town.adventures.has_method("remember"):town.adventures.remember(spec.requester,"order_"+reward_id,"The visitor finished my "+String(spec.title).to_lower()+" order.",1)
		var life=town.get("character_life")
		if life and life.bound:life.gain_skill("You",spec.skill,4+int(spec.quantity));life.change_need("You","fun",6)
		save_state();refresh_options()
		town.economy.announce("Completed "+spec.title+" · %d coins. Another order will be ready shortly."%spec.reward)

func _process(delta: float) -> void:
	if town.player.enabled and not town.life.active:
		var ready:=false
		for id in cooldowns:
			var before:=float(cooldowns[id]);cooldowns[id]=maxf(0,before-delta)
			if before>0 and float(cooldowns[id])==0:ready=true
		if ready:save_state()
	ui_clock+=delta
	if ui_clock>.5:ui_clock=0;refresh_options()
	if active.is_empty() or panel.visible:return
	if not town.player.enabled or town.life.active or (town.get("town_map") and town.town_map.opened):return
	if active_spec.seconds>0:
		remaining-=delta
		if remaining<=0:town.economy.announce("Time ran out. You can retry the challenge.");abandon();return
	match active:
		"archery":
			if town.physical_gameplay.score-baseline>=int(active_spec.quantity):complete()
		"delivery":
			if town.physical_gameplay.carried==crate and town.player.position.distance_to(active_spec.destination)<3:
				crate.reparent(town.physical_gameplay);crate.global_position=active_spec.destination+Vector3(1,0,0);crate.collision_layer=1;town.physical_gameplay.carried=null
				var market: Dictionary=town.jobs.markets[active_spec.market]
				market.stock+=int(active_spec.stock)
				if market.has("received"):market.received+=int(active_spec.stock)
				town.jobs.update_market(active_spec.market);complete()
		"wood":
			if int(town.adventures.inventory.get("Timber",0))-baseline>=int(active_spec.quantity) and town.player.position.distance_to(DEFINITIONS.repair.point)<2.5:
				town.adventures.inventory.Timber-=int(active_spec.quantity);town.adventures.save_state();complete()
		"repair":
			if repair_job.get_meta("stock",1)==0:complete()
