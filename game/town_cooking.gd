extends Node3D

const RECIPES := {
	"Roasted vegetables":{"food":1,"herbs":0,"level":0,"servings":1,"seconds":5.0,"hunger":38.0,"xp":8.0},
	"Vegetable stew":{"food":2,"herbs":0,"level":0,"servings":2,"seconds":7.0,"hunger":42.0,"xp":10.0},
	"Garden broth":{"food":1,"herbs":1,"level":1,"servings":1,"seconds":6.0,"hunger":45.0,"xp":12.0},
	"Family stew":{"food":3,"herbs":1,"level":2,"servings":4,"seconds":9.0,"hunger":46.0,"xp":14.0}
}
var town: Node3D
var stations: Array[Node3D]=[]
var garden: Node3D
var crop_visual: Node3D
var herb_visual: Node3D
var clock := 0.0
var growth_ready := 0.0
var crop_state := "empty"
var herb_stock := 3
var herb_regrow := 0.0
var garden_label: Label3D
var save_clock := 0.0
var testing := false
var save_path := "user://town-cooking.json"
var garden_clock := 0.0

func _ready() -> void:
	town=get_parent();testing=town.economy.testing()
	if testing:save_path="user://review-town-cooking.json"
	if not testing and FileAccess.file_exists(save_path):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if saved is Dictionary:
			clock=float(saved.get("clock",0));growth_ready=float(saved.get("growth_ready",0));crop_state=String(saved.get("crop_state","empty"));herb_stock=clampi(int(saved.get("herb_stock",3)),0,3);herb_regrow=float(saved.get("herb_regrow",0))
	add_station(Vector3(-40,.03,16),"Copper Stag cooking pot")
	build_garden()

func add_station(point: Vector3,title: String) -> Node3D:
	var station := Node3D.new();add_child(station);station.position=point;station.name=title
	station.add_to_group("cooking_stations")
	town.box(station,Vector3(1.1,.15,1.1),Vector3(0,.075,0),Color("777365"),true)
	town.detailed_prop("Cauldron",station,Vector3(0,.15,0),Vector3(.75,.7,.75),true)
	stations.append(station)
	return station

func register_home(house: Node3D) -> void:
	if house.has_meta("cooking_station_ready"):return
	for station in get_tree().get_nodes_in_group("cooking_stations"):
		if house.is_ancestor_of(station):stations.append(station);house.set_meta("cooking_station_ready",true);return
	# A reviewed interior may supply its own kitchen marker without extra props.
	var marker := house.find_child("CookingAnchor",true,false) as Node3D
	if not marker:
		for candidate in get_tree().get_nodes_in_group("cooking_anchors"):
			if house.is_ancestor_of(candidate):marker=candidate;break
	if marker:marker.add_to_group("cooking_stations");stations.append(marker);house.set_meta("cooking_station_ready",true)

func build_garden() -> void:
	garden=Node3D.new();add_child(garden);garden.position=Vector3(-29,.025,38)
	town.box(garden,Vector3(3,.045,2.4),Vector3.ZERO,Color("65503b"),false)
	crop_visual=Node3D.new();garden.add_child(crop_visual)
	herb_visual=Node3D.new();garden.add_child(herb_visual);herb_visual.position.x=2.2
	for x in range(3):
		for z in range(3):town.detailed_prop("Carrot",crop_visual,Vector3((x-1)*.65,0,(z-1)*.6),Vector3(.2,.4,.2),false)
	for x in range(3):town.detailed_prop("Carrot",herb_visual,Vector3((x-1)*.28,-.16,0),Vector3(.17,.32,.17),false)
	garden_label=Label3D.new();garden.add_child(garden_label);garden_label.position=Vector3(0,1.2,0)
	garden_label.font_size=19;garden_label.pixel_size=.006;garden_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	update_garden()

func update_garden() -> void:
	if not crop_visual:return
	crop_visual.visible=crop_state!="empty"
	var progress := clampf(1-(growth_ready-clock)/45.0,.08,1)
	crop_visual.scale=Vector3.ONE*(progress if crop_state=="growing" else 1.0)
	herb_visual.visible=herb_stock>0
	garden_label.text="Community garden · "+("ready to harvest" if crop_state=="ready" else "growing" if crop_state=="growing" else "ready to plant")

func _process(delta: float) -> void:
	clock+=delta;save_clock+=delta
	if town.player_home and is_instance_valid(town.player_home.house):register_home(town.player_home.house)
	if crop_state=="growing" and clock>=growth_ready:crop_state="ready";update_garden()
	if herb_stock<3 and clock>=herb_regrow:herb_stock+=1;herb_regrow=clock+60;update_garden()
	garden_clock+=delta
	if garden_clock>=1: garden_clock=0;update_garden()
	if save_clock>15:save_clock=0;save_state()

func save_state() -> void:
	if testing:return
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"clock":clock,"growth_ready":growth_ready,"crop_state":crop_state,"herb_stock":herb_stock,"herb_regrow":herb_regrow}))

func near_station() -> bool:
	for station in stations:
		if is_instance_valid(station) and station.global_position.distance_to(town.player.position)<3.3:return true
	return false

func near_garden() -> bool:return is_instance_valid(garden) and garden.global_position.distance_to(town.player.position)<4.0

func can_cook(recipe: String) -> bool:
	if not RECIPES.has(recipe) or not near_station():return false
	var data: Dictionary=RECIPES[recipe]
	return town.economy.player_food>=data.food and int(town.adventures.inventory.get("Herbs",0))>=data.herbs and town.character_life.skill_level("You","Cooking")>=data.level

func begin_recipe(recipe: String) -> bool:
	if not can_cook(recipe):return false
	return town.character_life.begin_activity("cook",RECIPES[recipe].seconds,{"recipe":recipe})

func finish_recipe(recipe: String) -> bool:
	if not can_cook(recipe):return false
	var data: Dictionary=RECIPES[recipe]
	town.economy.player_food-=data.food
	if data.herbs>0:town.adventures.inventory["Herbs"]=int(town.adventures.inventory.get("Herbs",0))-data.herbs
	town.adventures.inventory[recipe]=int(town.adventures.inventory.get(recipe,0))+data.servings
	town.character_life.gain_skill("You","Cooking",data.xp)
	town.character_life.feel("You","Proud",30)
	town.economy.refresh();town.adventures.save_state();save_state()
	town.economy.announce("Prepared "+str(data.servings)+" portions of "+recipe.to_lower()+".")
	return true

func eat_meal(recipe: String) -> bool:
	if not RECIPES.has(recipe) or int(town.adventures.inventory.get(recipe,0))<1:return false
	town.adventures.inventory[recipe]=int(town.adventures.inventory[recipe])-1
	town.character_life.change_need("You","hunger",RECIPES[recipe].hunger)
	town.character_life.change_need("You","comfort",10);town.character_life.change_need("You","fun",6)
	town.economy.meals_eaten+=1;town.economy.refresh();town.adventures.save_state()
	return true

func take_gift() -> String:
	for recipe in RECIPES:
		if int(town.adventures.inventory.get(recipe,0))>0:
			town.adventures.inventory[recipe]=int(town.adventures.inventory[recipe])-1;town.adventures.save_state();return recipe
	if town.economy.player_food>0:town.economy.player_food-=1;town.economy.refresh();return "fresh vegetables"
	return ""

func gather_herbs() -> bool:
	if not near_garden() or herb_stock<1:return false
	herb_stock-=1;herb_regrow=clock+60
	town.adventures.inventory["Herbs"]=int(town.adventures.inventory.get("Herbs",0))+1
	town.character_life.gain_skill("You","Farming",3)
	town.adventures.save_state();update_garden();save_state()
	return true

func plant() -> bool:
	if not near_garden() or crop_state!="empty" or town.economy.player_food<1:return false
	return town.character_life.begin_activity("plant",4)

func finish_planting() -> bool:
	if not near_garden() or crop_state!="empty" or town.economy.player_food<1:return false
	town.economy.player_food-=1;town.economy.refresh()
	crop_state="growing";growth_ready=clock+45/(1+.08*town.character_life.skill_level("You","Farming"))
	town.character_life.gain_skill("You","Farming",4)
	update_garden();save_state();return true

func harvest() -> bool:
	if not near_garden() or crop_state!="ready":return false
	var portions := 3+mini(2,town.character_life.skill_level("You","Farming")/3)
	town.economy.player_food+=portions;town.economy.refresh()
	crop_state="empty";town.character_life.gain_skill("You","Farming",8)
	town.character_life.feel("You","Proud",30);update_garden();save_state()
	town.economy.announce("Harvested "+str(portions)+" vegetable portions.")
	return true
