extends Node

const FOOD="Food portions"
const Shop = preload("res://town_shop.gd")
const CATALOG={"Timber":{"asset":"Timber","sell":1},"Metal fittings":{"asset":"MetalFittings","sell":2},"Herbs":{"asset":"Carrot","sell":1},"Repaired furniture":{"asset":"Stool","sell":5},"Crafted stool":{"asset":"Stool","sell":6},"Crafted table":{"asset":"Table_Large","sell":16},"Supply crate":{"asset":"Crate_Wooden","sell":8},"Repaired tools":{"asset":"Axe_Bronze","sell":12},"Work axe":{"asset":"Axe_Bronze","sell":5},"Food portions":{"asset":"Carrot","sell":1},"Seed packet":{"asset":"Bag","sell":1},"Travel lantern":{"asset":"Lantern_Wall","sell":6},"Wooden bed":{"asset":"Bed_Twin1","sell":11},"Vegetable stew":{"asset":"Carrot","sell":2}}
var town: Node3D
var body: VBoxContainer
var grid: GridContainer
var detail: Label
var selection:=""
var source:="bag"
var number: SpinBox
var clock:=0.0
var last_signature:=""
var controls: Dictionary={}
var shop := Shop.new()
var bag_panel: VBoxContainer

func _ready() -> void:
	town = get_parent()
	add_child(shop)

func open_shop(orders := false) -> void:
	set_source("shop")
	shop.show_category(orders)
	town.interface_ui.open_page("Belongings")

func set_source(mode: String) -> void:
	source = mode
	selection = ""
	if bag_panel:bag_panel.visible = source != "shop"
	if shop.panel:shop.panel.visible = source == "shop"
	refresh()
func amount(item: String) -> int:return maxi(0,int(town.economy.player_food if item==FOOD else town.adventures.inventory.get(item,0)))
func change(item: String,delta: int) -> bool:
	var count:=amount(item)+delta
	if count<0:return false
	if item==FOOD:town.economy.player_food=count
	else:
		if count==0:town.adventures.inventory.erase(item)
		else:town.adventures.inventory[item]=count
	if item == Shop.LANTERN:shop.sync_lantern()
	return true
func protected(item: String) -> bool:
	for mission in town.adventures.definitions:
		for step in mission.steps:
			if step.get("item","")==item and (step.kind=="collect" or town.adventures.progress[mission.id].status=="active"):return true
	return item in ["Market favour","Craftsman's favour","Surveyor's map"]
func near_home() -> bool:
	return town.home_district.inside or town.player.global_position.distance_to(town.home_district.porch)<5
func seller() -> Node:
	var person=town.life.active if town.life.active else town.life.nearest
	if is_instance_valid(person) and not person.stall_name.is_empty() and person.posture!="sleeping" and person.global_position.distance_to(town.player.global_position)<5 and town.economy.open_for_trade(person):return person
	var stalls: Variant=town.economy.get("sellers")
	if not stalls is Dictionary:return null
	var best: Node
	var distance:=4.0
	for stall in stalls.values():
		var merchant: CharacterBody3D=stall.person
		if not is_instance_valid(merchant) or not town.economy.open_for_trade(merchant):continue
		var gap: float=merchant.global_position.distance_to(town.player.global_position)
		if gap<distance:best=merchant;distance=gap
	return best
func transfer(item: String,count: int,deposit: bool) -> bool:
	if count<=0 or not near_home():return false
	if deposit:
		if amount(item)<count:return false
		change(item,-count);town.player_home.storage[item]=int(town.player_home.storage.get(item,0))+count
	else:
		if int(town.player_home.storage.get(item,0))<count:return false
		town.player_home.storage[item]=int(town.player_home.storage[item])-count;change(item,count)
		if int(town.player_home.storage[item])==0:town.player_home.storage.erase(item)
	persist();return true
func sell(item: String,count: int) -> bool:
	if count<=0 or protected(item) or amount(item)<count or not CATALOG.has(item) or not seller():return false
	var person=seller();var price:=int(CATALOG[item].sell)*count
	if int(person.coins)<price:return false
	change(item,-count);person.coins-=price;town.economy.player_coins+=price
	town.adventures.traded(person.person_name);persist();return true
func fittings_key(person: Node) -> String:
	return person.person_name + ":" + str(int(town.character_life.day))

func fittings_stock(person: Node) -> int:
	return int(town.crafting.stock.get(fittings_key(person), 8))

func buy_fittings(count: int) -> bool:
	var person=seller()
	if not person or count<=0:return false
	var key := fittings_key(person)
	var stock := fittings_stock(person)
	if count>stock or town.economy.player_coins<count*4:return false
	town.economy.player_coins-=count*4;person.coins+=count*4;town.crafting.stock[key]=stock-count;change("Metal fittings",count);persist();return true
func use(item: String) -> bool:
	if item==FOOD:return town.economy.eat()
	if town.cooking.RECIPES.has(item):return town.cooking.eat_meal(item)
	if item=="Market favour":return town.adventures.redeem_market_favour()
	if item == Shop.LANTERN:return shop.toggle_lantern()
	if item == Shop.SEEDS:return amount(item) > 0 and town.cooking.plant()
	if town.crafting.PLACEABLES.has(item):return town.crafting.place(item)
	return false
func persist() -> void:
	town.adventures.save_state();town.economy.refresh()
	var file:=FileAccess.open(town.player_home.save_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"storage":town.player_home.storage}))
	var session=town.get("session")
	if session and session.has_method("save_now"):session.save_now(true)
func build(parent: VBoxContainer) -> void:
	body=parent
	var title:=Label.new();title.text="Belongings & workshop";title.add_theme_font_size_override("font_size",25);body.add_child(title)
	var modes:=HBoxContainer.new();body.add_child(modes)
	for mode in ["bag","storage","shop"]:
		var b:=Button.new();b.text={"bag":"Your bag","storage":"Home storage","shop":"Shop"}[mode]
		modes.add_child(b);b.pressed.connect(set_source.bind(mode))
	bag_panel=VBoxContainer.new();bag_panel.add_theme_constant_override("separation",8);body.add_child(bag_panel)
	grid=GridContainer.new();grid.columns=3;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bag_panel.add_child(grid)
	detail=Label.new();detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;bag_panel.add_child(detail)
	number=SpinBox.new();number.min_value=1;number.max_value=99;bag_panel.add_child(number)
	var actions:=HBoxContainer.new();bag_panel.add_child(actions)
	for id in ["Use / place","Store","Take","Sell","Deliver","Buy fittings"]:
		var b:=Button.new();b.text=id;b.custom_minimum_size.y=46;actions.add_child(b);controls[id]=b
		b.pressed.connect(func():perform(id))
	var header:=Label.new();header.text="Craft at the repair workbench. Metal fittings cost 4 coins at open stalls.";header.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;bag_panel.add_child(header)
	for item in town.crafting.RECIPES:
		var recipe: Dictionary=town.crafting.RECIPES[item]
		var costs: PackedStringArray=[]
		for material in recipe.cost:costs.append(str(recipe.cost[material])+" "+String(material).to_lower())
		var b:=Button.new();b.text=item+" · "+", ".join(costs)+" · Carpentry "+str(recipe.level);b.custom_minimum_size.y=48;b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;bag_panel.add_child(b)
		b.pressed.connect(func():
			if not town.crafting.begin(item):detail.text="Visit the repair workbench with the materials and required carpentry skill.")
	shop.build(body)
	set_source(source)
func perform(id: String) -> void:
	var count:=int(number.value);var ok:=false
	match id:
		"Store":ok=transfer(selection,count,true)
		"Take":ok=transfer(selection,count,false)
		"Sell":ok=sell(selection,count)
		"Use / place":ok=use(selection)
		"Deliver":ok=deliver(selection)
		"Buy fittings":ok=buy_fittings(count)
	if ok and id=="Use / place":persist()
	refresh()
	if not ok:detail.text="Move closer to the right place, check the quantity and supplies, or choose another item. Mission items cannot be sold."
func recipient(item: String) -> CharacterBody3D:
	if item.is_empty() or not town.adventures.has_method("resident_action"):return null
	for person: CharacterBody3D in town.life.people:
		if person.posture!="standing" or person.global_position.distance_to(town.player.global_position)>2.5:continue
		var action: Dictionary=town.adventures.resident_action(person)
		if action.get("item","")==item and not action.get("missing",true):return person
	return null
func deliver(item: String) -> bool:
	var person:=recipient(item)
	if not person:return false
	town.interface_ui.close()
	town.life.open_dialog(person,false)
	town.adventures.refresh_conversation_action()
	if town.life.active!=person or not town.adventures.conversation_action.visible:return false
	town.adventures.conversation_action.pressed.emit()
	return true
func refresh() -> void:
	if not grid:return
	if source == "shop":shop.refresh();return
	var items: Dictionary=town.adventures.inventory.duplicate()
	if town.economy.player_food>0:items[FOOD]=town.economy.player_food
	if source=="storage":items=town.player_home.storage
	var receiver: CharacterBody3D=recipient(selection) if source=="bag" else null
	var signature:=str([items,town.economy.player_coins,source,selection,near_home(),seller(),receiver,shop.lantern_on])
	if signature==last_signature:return
	last_signature=signature
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	var names:=items.keys();names.sort()
	for item in names:
		if int(items[item])<=0:continue
		var b:=Button.new();b.text=item+" × "+str(items[item]);b.custom_minimum_size=Vector2(170,100);b.expand_icon=true;b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
		var fallback: String="Carrot" if town.cooking.RECIPES.has(item) else "Book_Stack_1" if item.contains("map") or item.contains("pass") else "Anvil_Log" if item.to_lower().contains("fittings") else "Crate_Wooden"
		var icon_path: String="res://ui/items/"+String(CATALOG.get(item,{}).get("asset",fallback))+".png"
		if ResourceLoader.exists(icon_path):b.icon=load(icon_path)
		b.toggle_mode=true;b.button_pressed=selection==item;grid.add_child(b);b.pressed.connect(func():selection=item;refresh())
	detail.text="%d coins · %s"%[town.economy.player_coins,"Visit home to store or take items. Open stalls buy ordinary goods." if selection.is_empty() else selection+(" · mission item" if protected(selection) else "")]
	if selection == Shop.AXE:detail.text += " · Chops timber faster while in your bag."
	if selection == Shop.LANTERN:detail.text += " · Lit" if shop.lantern_on else " · Unlit"
	controls["Store"].disabled=source!="bag" or selection.is_empty() or not near_home()
	controls["Take"].disabled=source!="storage" or selection.is_empty() or not near_home()
	controls["Sell"].disabled=source!="bag" or selection.is_empty() or protected(selection) or not seller() or not CATALOG.has(selection)
	controls["Use / place"].disabled=source!="bag" or selection.is_empty() or selection==Shop.AXE
	controls["Buy fittings"].disabled=not seller()
	controls["Deliver"].disabled=not receiver
func _process(delta: float) -> void:
	if not body or not body.is_visible_in_tree():return
	clock+=delta
	if clock>1:clock=0;refresh()
