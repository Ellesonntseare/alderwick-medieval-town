extends Node

var town: Node3D
var panel: AcceptDialog
var choices: VBoxContainer
var previous_enabled := true
var previous_mouse := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	town=get_parent()
	panel=AcceptDialog.new();panel.title="Nearby activities";town.add_child(panel)
	choices=VBoxContainer.new();choices.add_theme_constant_override("separation",10);panel.add_child(choices)
	panel.visibility_changed.connect(func():
		if not panel.visible:town.player.enabled=previous_enabled;Input.mouse_mode=previous_mouse)
	var shortcut:=Button.new();shortcut.text="Nearby activities · G";town.menu_body.add_child(shortcut);shortcut.pressed.connect(open)

func available() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not town.player.resting.is_empty():result.append({"label":"Stand up","action":town.player.stand_from_furniture})
	else:
		for group in ["seats","beds"]:
			var best: Node3D
			var distance:=2.5
			for item: Node3D in get_tree().get_nodes_in_group(group):
				if item.has_meta("occupant"):continue
				var d:=item.global_position.distance_to(town.player.global_position)
				if d<distance:distance=d;best=item
			if best:
				var anchor:=best
				var kind: String="sitting" if group=="seats" else "sleeping"
				result.append({"label":"Sit and rest" if group=="seats" else "Lie down / sleep","action":func():town.player.use_furniture(anchor,kind)})
	if town.cooking.near_station():result.append({"label":"Cook a meal","action":open_cooking})
	if town.economy.player_food>0:result.append({"label":"Eat a vegetable portion","action":town.economy.eat})
	for recipe: String in town.cooking.RECIPES:
		if int(town.adventures.inventory.get(recipe,0))>0:
			var meal:=recipe
			result.append({"label":"Eat "+meal.to_lower(),"action":func():town.cooking.eat_meal(meal)})
	if is_instance_valid(town.player_home.house) and town.player.global_position.distance_to(town.player_home.house.global_position)<8:
		result.append({"label":"Store or take belongings","action":town.player_home.show_home})
	result.append({"label":"People, visits and skills","action":open_people})
	return result

func open_cooking() -> void:
	town.character_life.view.tabs.current_tab=3;town.character_life.view.open()

func open_people() -> void:
	town.character_life.view.tabs.current_tab=2;town.character_life.view.open()

func open() -> void:
	if panel.visible or not town.character_life.bound or town.life.active or town.builder.active:return
	for child in choices.get_children():choices.remove_child(child);child.queue_free()
	var help:=Label.new();help.text="Activities use nearby furniture and your own supplies.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.custom_minimum_size.x=420;choices.add_child(help)
	for option in available():
		var button:=Button.new();button.text=option.label;button.custom_minimum_size.y=48;choices.add_child(button)
		var callback: Callable=option.action
		button.pressed.connect(func():panel.hide();callback.call())
	previous_enabled=town.player.enabled;previous_mouse=Input.mouse_mode
	town.player.enabled=false;town.player.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	panel.popup_centered()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_G:
		open();get_viewport().set_input_as_handled()
