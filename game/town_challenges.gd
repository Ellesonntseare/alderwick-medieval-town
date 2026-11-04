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
var previous_enabled:=true
var previous_mouse:=Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	town=get_parent();panel=AcceptDialog.new();panel.title="Town challenges";town.add_child(panel)
	var column:=VBoxContainer.new();panel.add_child(column)
	message=Label.new();message.custom_minimum_size.x=480;message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(message)
	for id in DEFINITIONS:
		var button:=Button.new();button.text=DEFINITIONS[id].title+" · "+str(DEFINITIONS[id].reward)+" coins";button.custom_minimum_size.y=48;column.add_child(button)
		button.pressed.connect(func():start(id))
	var cancel:=Button.new();cancel.text="Abandon current challenge";column.add_child(cancel);cancel.pressed.connect(func():active="";message.text="Challenge abandoned.")
	panel.visibility_changed.connect(func():
		if not panel.visible:town.player.enabled=previous_enabled;Input.mouse_mode=previous_mouse)
	var shortcut:=Button.new();shortcut.text="Town challenges";town.menu_body.add_child(shortcut);shortcut.pressed.connect(func():
		previous_enabled=town.player.enabled;previous_mouse=Input.mouse_mode;town.player.enabled=false;town.player.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		message.text="Choose a challenge. One can be active at a time.";panel.popup_centered())
	if FileAccess.file_exists("user://town-challenges.json") and not town.economy.testing():
		var data=JSON.parse_string(FileAccess.get_file_as_string("user://town-challenges.json"))
		if data is Array:finished=data

func start(id: String) -> void:
	if not active.is_empty():message.text="Finish or abandon your current challenge first.";return
	if finished.has(id) or town.economy.story_rewards.has("challenge_"+id):message.text="You have already completed this challenge.";return
	if not town.life.navigation_ready or town.physical_gameplay.objects.is_empty():message.text="The town is still preparing.";return
	active=id;remaining=DEFINITIONS[id].seconds
	if town.menu_panel and not town.menu_collapsed:town.toggle_menu()
	baseline=town.physical_gameplay.score if id=="archery" else int(town.adventures.inventory.get("Timber",0))
	if id=="delivery":
		if not is_instance_valid(crate):crate=town.physical_gameplay.prop("Express delivery crate","Crate_Wooden",DEFINITIONS.delivery.point,"carry")
		if town.physical_gameplay.carried!=crate:crate.global_position=DEFINITIONS.delivery.point
	if id=="repair":
		if not is_instance_valid(repair_job):repair_job=town.physical_gameplay.prop("Damaged stool repair","Stool",DEFINITIONS.repair.point+Vector3(1.5,0,0),"furniture_repair")
		repair_job.set_meta("stock",1)
		for child in repair_job.get_children():
			if child is Node3D and not child is CollisionShape3D:child.rotation.z=.18
	if id=="wood":
		for object in town.physical_gameplay.objects:
			if object.get_meta("activity","")=="chop":object.set_meta("stock",maxi(3,int(object.get_meta("stock",0))))
	panel.hide();town.economy.announce(DEFINITIONS[id].instruction)
	if town.get("town_map"):town.town_map.tracked="challenge"

func objective() -> Dictionary:
	if active.is_empty():return {}
	var point: Vector3=DEFINITIONS[active].point
	var instruction: String=DEFINITIONS[active].instruction
	if active=="delivery" and is_instance_valid(crate):point=crate.global_position
	if active=="archery":instruction="Archery contest · %d / 3 hits"%mini(3,maxi(0,town.physical_gameplay.score-baseline))
	if active=="wood":instruction="Timber order · %d / 3 pieces chopped"%mini(3,maxi(0,int(town.adventures.inventory.get("Timber",0))-baseline))
	if active=="delivery" and town.physical_gameplay.carried==crate:point=Vector3(8,.1,4);instruction="Carry the express crate to the square market"
	if active=="wood" and int(town.adventures.inventory.get("Timber",0))-baseline>=3:point=DEFINITIONS.repair.point;instruction="Deliver 3 pieces of timber to the repair bench"
	return {"point":point,"text":instruction+(" · %d seconds"%ceili(remaining) if remaining>0 else "")}

func complete() -> void:
	var id:=active
	if town.economy.award_story("challenge_"+id,DEFINITIONS[id].reward):
		finished.append(id)
		if not town.economy.testing():
			var file:=FileAccess.open("user://town-challenges.json",FileAccess.WRITE);file.store_string(JSON.stringify(finished))
		town.economy.announce("Completed "+DEFINITIONS[id].title+" · "+str(DEFINITIONS[id].reward)+" coins")
	active=""

func _process(delta: float) -> void:
	if active.is_empty() or panel.visible:return
	if not town.player.enabled or town.life.active or (town.get("town_map") and town.town_map.opened):return
	if DEFINITIONS[active].seconds>0:
		remaining-=delta
		if remaining<=0:town.economy.announce("Time ran out. You can retry the challenge.");active="";return
	match active:
		"archery":
			if town.physical_gameplay.score-baseline>=3:complete()
		"delivery":
			if town.physical_gameplay.carried==crate and town.player.position.distance_to(Vector3(8,.1,4))<3:
				crate.reparent(town.physical_gameplay);crate.global_position=Vector3(9,.1,4);crate.collision_layer=1;town.physical_gameplay.carried=null
				town.jobs.markets.city.stock+=4;town.jobs.update_market("city");complete()
		"wood":
			if int(town.adventures.inventory.get("Timber",0))-baseline>=3 and town.player.position.distance_to(DEFINITIONS.repair.point)<2.5:
				town.adventures.inventory.Timber-=3;town.adventures.save_state();complete()
		"repair":
			if repair_job.get_meta("stock",1)==0:complete()
