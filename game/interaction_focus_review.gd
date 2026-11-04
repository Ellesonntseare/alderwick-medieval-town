extends SceneTree
const Target=preload("res://interaction_target.gd")

class Person extends CharacterBody3D:
	var person_name:="Ada"
	var occupation:="Vegetable seller"
class Player extends CharacterBody3D:
	var resting:=""
class AI extends Node:
	var group_members: Array=[]
	var group_target:=OptionButton.new()
	var focused_person: CharacterBody3D
class Life extends Node:
	var town: Node3D
	var active: CharacterBody3D
	var nearest: CharacterBody3D
	var nearest_door: Node3D
	var nearest_furniture: Node3D
	var dialog:=PanelContainer.new()
	var ai:=AI.new()
class Town extends Node3D:
	var player:=Player.new()
	var life:=Life.new()
	var adventures: Node

func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	var town:=Town.new();root.add_child(town);town.add_child(town.player);town.add_child(town.life);town.life.town=town
	var life=town.life;life.add_child(life.ai);life.ai.add_child(life.ai.group_target)
	var ada:=Person.new();town.add_child(ada);life.nearest=ada
	assert(Target.resolve(town).label=="Talk to Ada · Vegetable seller")
	var door: Node3D=load("res://door.gd").new();town.add_child(door);door.door_name="Feira Castle door";door.position.x=1;life.nearest_door=door
	assert(Target.resolve(town).label=="Open Feira Castle door")
	var seat:=Marker3D.new();town.add_child(seat);seat.name="Oak stool";seat.position.x=.5;seat.add_to_group("seats");life.nearest_furniture=seat
	assert(Target.resolve(town).label=="Sit on Oak stool")
	seat.position.x=2
	assert(Target.resolve(town).kind=="door")
	town.player.resting="sitting";assert(Target.resolve(town).kind=="stand");town.player.resting=""
	var layer:=CanvasLayer.new();life.add_child(layer);layer.add_child(life.dialog)
	life.dialog.position=Vector2(690,40);life.dialog.size=Vector2(550,640)
	var column:=VBoxContainer.new();life.dialog.add_child(column)
	var heading:=Label.new();heading.text="Conversation";column.add_child(heading)
	var focus: Node=load("res://conversation_focus.gd").new();life.add_child(focus)
	life.active=ada;focus._process(0)
	assert(focus.banner.text.contains("Talking to Ada"))
	assert(focus.markers[0].visible and not focus.markers[1].visible)
	assert(focus.markers[0].global_position.distance_to(ada.global_position)<.1)
	var oren:=Person.new();oren.person_name="Oren";oren.occupation="Carpenter";town.add_child(oren)
	life.ai.group_members=[ada,oren]
	for name in ["Either person","Ada","Oren"]:life.ai.group_target.add_item(name)
	life.ai.group_target.select(2);focus._process(0)
	assert(focus.banner.text.contains("Your message goes to Oren") and focus.markers[1].visible)
	life.dialog.hide();focus._process(0)
	assert(not focus.markers[0].visible and not focus.markers[1].visible)
	print("INTERACTION_FOCUS_REVIEW_COMPLETE named_targets=true nearest_action_priority=true named_recipient=true group_selection=true close_cleanup=true")
	quit()
