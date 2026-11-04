extends Node

var sim: Node
var panel: AcceptDialog
var tabs: TabContainer
var bars: Dictionary={}
var mood_label: Label
var skills_text: RichTextLabel
var people_choice: OptionButton
var person_text: RichTextLabel
var lesson_choice: OptionButton
var romance_button: Button
var recipe_choice: OptionButton
var cooking_text: RichTextLabel
var progress: ProgressBar
var notice: Label
var previous_enabled := false
var previous_mouse := Input.MOUSE_MODE_VISIBLE
var names: Array[String]=[]

func build(owner: Node) -> void:
	sim=owner
	panel=AcceptDialog.new();panel.title="Life in Alderwick";panel.min_size=Vector2i(630,600);sim.town.add_child(panel)
	panel.get_ok_button().text="Back to town"
	var body := VBoxContainer.new();panel.add_child(body)
	tabs=TabContainer.new();tabs.custom_minimum_size=Vector2(620,470);body.add_child(tabs)
	var needs := page("Needs")
	mood_label=Label.new();mood_label.add_theme_font_size_override("font_size",21);needs.add_child(mood_label)
	for id in sim.NEEDS:
		var row := HBoxContainer.new();needs.add_child(row)
		var label := Label.new();label.text={"hunger":"Food","energy":"Energy","hygiene":"Cleanliness","comfort":"Comfort","fun":"Fun","social":"Social"}[id];label.custom_minimum_size.x=100;row.add_child(label)
		var bar := ProgressBar.new();bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.custom_minimum_size.y=24;row.add_child(bar);bars[id]=bar
	action(needs,"Eat a vegetable portion",func():message(sim.town.economy.eat(),"You ate a portion of vegetables.","Buy food at the market first."))
	action(needs,"Wash at the town well",func():
		if sim.town.player.position.distance_to(Vector3.ZERO)>3.5:notice.text="Stand beside the town well to wash.";return
		message(sim.begin_activity("wash",4),"Washing…","Finish your current activity or get up first."))
	var rest := Label.new();rest.text="Use E beside a chair or bed to rest. Talking, meals and walks help your mood.";rest.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;needs.add_child(rest)
	var skills := page("Skills")
	skills_text=rich(skills)
	var skill_help := Label.new();skill_help.text="Practise through cooking, planting, harvesting and real work. Trusted, experienced residents can give a short lesson.";skill_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;skills.add_child(skill_help)
	var people := page("People")
	people_choice=OptionButton.new();people.add_child(people_choice);people_choice.item_selected.connect(func(_index: int):refresh())
	person_text=rich(people)
	action(people,"Give a portion of food",func():message(sim.give_food(selected_name()),"They accepted your food.","Stand near them with vegetables or a cooked meal."))
	romance_button=action(people,"Express romantic interest",func():notice.text=sim.romantic_interest(selected_name());refresh())
	action(people,"Invite to your home",func():message(sim.invite_home(selected_name()),"They are coming to visit your home.","You need a registered home, a friendly adult resident, and a free seat. Guards stay on duty."))
	action(people,"Argue",func():message(sim.argue(selected_name()),"The disagreement hurt your relationship.","Stand near them to speak in person."))
	action(people,"Apologize",func():message(sim.apologize(selected_name()),"Your apology is a start; trust takes time to rebuild.","An apology is available after a disagreement, once per day."))
	lesson_choice=OptionButton.new();people.add_child(lesson_choice)
	for skill in sim.SKILLS:lesson_choice.add_item(skill)
	action(people,"Ask for a short lesson",func():message(sim.lesson(selected_name(),lesson_choice.get_item_text(lesson_choice.selected)),"Practising together…","Stand near a trusted resident who is more experienced in that skill and free to teach."))
	var cooking := page("Cooking & garden")
	cooking_text=rich(cooking)
	recipe_choice=OptionButton.new();cooking.add_child(recipe_choice)
	for recipe in sim.town.cooking.RECIPES:recipe_choice.add_item(recipe)
	recipe_choice.item_selected.connect(func(_index: int):refresh())
	action(cooking,"Prepare this meal",func():message(sim.town.cooking.begin_recipe(recipe_name()),"Preparing your meal…","Stand by a cooking pot with the ingredients and required skill."))
	action(cooking,"Eat this meal",func():message(sim.town.cooking.eat_meal(recipe_name()),"You enjoyed your meal.","Prepare that meal first."))
	action(cooking,"Plant vegetables · uses 1 portion",func():message(sim.town.cooking.plant(),"Planting vegetables…","Visit the community garden with one vegetable portion and an empty plot."))
	action(cooking,"Harvest vegetables",func():message(sim.town.cooking.harvest(),"Harvest collected.","Stand beside the community garden when its vegetables are ready."))
	action(cooking,"Gather herbs",func():message(sim.town.cooking.gather_herbs(),"Collected herbs.","Stand beside the community garden; the herbs may need time to regrow."))
	progress=ProgressBar.new();progress.custom_minimum_size.y=20;body.add_child(progress);progress.hide()
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size.y=38;body.add_child(notice)
	panel.visibility_changed.connect(func():
		if not panel.visible:
			sim.cancel_activity();sim.town.player.enabled=previous_enabled;Input.mouse_mode=previous_mouse)
	var button := Button.new();button.text="Life, needs & skills [L]";button.pressed.connect(open);sim.town.menu_body.add_child(button)

func page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new();scroll.name=title;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var box := VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",8);scroll.add_child(box);return box

func rich(parent: Node) -> RichTextLabel:
	var text := RichTextLabel.new();text.custom_minimum_size.y=110;text.size_flags_vertical=Control.SIZE_EXPAND_FILL;text.add_theme_font_size_override("normal_font_size",16);parent.add_child(text);return text

func action(parent: Node,text: String,callback: Callable) -> Button:
	var button := Button.new();button.text=text;button.custom_minimum_size.y=44;button.pressed.connect(callback);parent.add_child(button);return button

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode==KEY_L and not sim.town.life.active and not sim.town.builder.active:
		if panel.visible:panel.hide()
		else:open()
		get_viewport().set_input_as_handled()

func visible() -> bool:return panel and panel.visible

func refresh_people() -> void:
	names.assign(sim.people.keys());names.sort()
	people_choice.clear()
	for name in names:people_choice.add_item(name)

func selected_name() -> String:return names[people_choice.selected] if people_choice.selected>=0 and people_choice.selected<names.size() else ""
func recipe_name() -> String:return recipe_choice.get_item_text(recipe_choice.selected)

func open() -> void:
	if not sim.bound:return
	if sim.town.life.active:
		var name: String=sim.town.life.active.person_name
		if names.has(name):people_choice.select(names.find(name));tabs.current_tab=2
		sim.town.life.close_dialog()
	previous_enabled=sim.town.player.enabled;previous_mouse=Input.mouse_mode
	sim.town.player.enabled=false;sim.town.player.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	refresh()
	var height := mini(650,int(get_viewport().get_visible_rect().size.y)-60)
	tabs.custom_minimum_size.y=maxi(320,height-170)
	panel.min_size=Vector2i(630,height);panel.popup_centered(Vector2i(650,height))

func message(ok: bool,success: String,failure: String) -> void:notice.text=success if ok else failure;refresh()

func refresh() -> void:
	if not sim.bound:return
	mood_label.text="You feel "+sim.mood("You").to_lower()+"."
	for id in bars:bars[id].value=sim.need("You",id)
	var skills := "Your traits: "+", ".join(sim.state("You").traits)+"\n\n"
	for skill in sim.SKILLS:
		var level: int=sim.skill_level("You",skill)
		skills+=skill+" · Level "+str(level)+" / 10\n"
	skills_text.text=skills+"\nTown reputation: "+str(sim.reputation())+"\nReputation follows actual relationships and deeds."
	var name := selected_name()
	if sim.people.has(name):
		var person: Node=sim.people[name]
		person_text.text=name+" · "+person.occupation+"\n"+", ".join(sim.state(name).traits)+"\nMood: "+sim.mood(name)+"\nYour relationship: "+sim.relationship_status(name)+"\nTrust: "+str(sim.town.adventures.relationship(name).trust)
		romance_button.disabled=person.is_child or sim.town.player.skin_id in ["runner_child","runner_youth"]
	var recipe := recipe_name()
	var data: Dictionary=sim.town.cooking.RECIPES[recipe]
	var inventory: Dictionary=sim.town.adventures.inventory
	cooking_text.text="Vegetables: "+str(sim.town.economy.player_food)+" · Herbs: "+str(inventory.get("Herbs",0))+"\nCooked portions of "+recipe.to_lower()+": "+str(inventory.get(recipe,0))+"\n\nNeeds "+str(data.food)+" vegetable portions and "+str(data.herbs)+" herbs. Cooking level "+str(data.level)+". Makes "+str(data.servings)+" portions.\n\nCook at the Copper Stag pot or your home's kitchen. Plant and gather at the community garden near the southern farm."
	progress.visible=not sim.activity.is_empty()
	if progress.visible:progress.value=100*(1-float(sim.activity.timer)/float(sim.activity.total))
