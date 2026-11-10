extends Node

const STOOL := "Crafted stool"
const AXE := "Work axe"
const TABLE := "Crafted table"
const FOOD := "Food portions"
const FITTINGS := "Metal fittings"
const SEEDS := "Seed packet"
const LANTERN := "Travel lantern"
const BED := "Wooden bed"
const CARPENTER := "Oren"
const TABLE_PRICE := 24
const SECTIONS := ["Food & garden", "Tools & materials", "Home", "Orders"]
const GOODS := {
	FOOD: {"section":0,"title":"Fresh vegetables","price":2,"icon":"Carrot","detail":"Eat, cook, or feed an animal. Comes from this stall’s vegetable stock."},
	"Vegetable stew": {"section":0,"title":"Vegetable stew","price":5,"icon":"Carrot","detail":"A ready meal. Eat it from your bag to restore hunger and comfort."},
	"Herbs": {"section":0,"title":"Cooking herbs","price":2,"icon":"Carrot","detail":"An ingredient for garden broth and family stew."},
	SEEDS: {"section":0,"title":"Seed packet","price":2,"icon":"Bag","detail":"Plant one packet in the community garden to grow vegetables."},
	AXE: {"section":1,"title":"Work axe","price":12,"icon":"Axe_Bronze","detail":"Keep it in your bag to chop timber in 2.5 seconds instead of 4.","unique":true},
	LANTERN: {"section":1,"title":"Travel lantern","price":14,"icon":"Lantern_Wall","detail":"Use it from your bag to light your way at night or indoors.","unique":true},
	"Timber": {"section":1,"title":"Timber","price":3,"icon":"Timber","detail":"Build furniture or supply a timber order."},
	FITTINGS: {"section":1,"title":"Metal fittings","price":4,"icon":"MetalFittings","detail":"Use these at the workbench for tables, crates, and tools."},
	STOOL: {"section":2,"title":"Wooden stool","price":8,"icon":"Stool","detail":"Place it on a clear spot at home and sit on it."},
	BED: {"section":2,"title":"Wooden bed","price":22,"icon":"Bed_Twin1","detail":"Place it at home and use it to lie down and sleep."}
}
const BUILD_SECONDS := 30.0
const REACH := 4.0

var town: Node3D
var inventory: Node
var remaining := -1.0
var panel: VBoxContainer
var purse: Label
var order_status: Label
var feedback: Label
var controls: Dictionary = {}
var categories: TabContainer
var order_feedback: Label
var lantern: OmniLight3D
var lantern_on := false

func _ready() -> void:
	inventory = get_parent()
	town = inventory.get_parent()

func nearby(person: Node) -> bool:
	if not is_instance_valid(person) or not is_instance_valid(town.player):return false
	if person.global_position.distance_to(town.player.global_position) >= REACH:return false
	var physical: Node = town.physical_gameplay
	return not physical or not physical.has_method("clear_exchange_path") or physical.clear_exchange_path(person)

func open_seller() -> Node:
	var seller: Node = inventory.seller()
	return seller if nearby(seller) else null

func carpenter() -> Node:
	if not is_instance_valid(town.life) or not (&"people" in town.life):return null
	for person in town.life.people:
		if is_instance_valid(person) and person.person_name == CARPENTER:return person
	return null

func working(person: Node) -> bool:
	return is_instance_valid(person) and is_instance_valid(town.day_night) and not town.day_night.night and not person.night_schedule and person.posture == "standing"

func open_carpenter() -> Node:
	var person := carpenter()
	return person if working(person) and nearby(person) else null

func available_for(person: Node) -> bool:
	if not nearby(person):return false
	if person.person_name == CARPENTER:return working(person)
	return town.economy.open_for_trade(person)

func pay(person: Node, price: int, kind: String) -> void:
	town.economy.player_coins -= price
	person.coins += price
	if town.economy.has_method("record"):town.economy.record(kind, "You", person.person_name, price)

func can_change_order() -> bool:
	return not is_instance_valid(town.session) or (town.session.ready_for_use and town.session.restored)

func buy(item: String) -> bool:
	if not GOODS.has(item) or not can_change_order():return false
	var seller := open_seller()
	if not seller:return false
	if item == FOOD:
		if not town.economy.buy_food(seller):return false
		inventory.persist()
		return true
	if item == FITTINGS:return inventory.buy_fittings(1)
	var price: int = GOODS[item].price
	if town.economy.player_coins < price or (GOODS[item].get("unique", false) and owns(item)):return false
	inventory.change(item, 1)
	pay(seller, price, "shop purchase")
	inventory.persist()
	return true

func owns(item: String) -> bool:
	return inventory.amount(item) > 0 or int(town.player_home.storage.get(item, 0)) > 0

func order_table() -> bool:
	if not can_change_order():return false
	var maker := open_carpenter()
	if not maker or remaining >= 0 or town.economy.player_coins < TABLE_PRICE:return false
	remaining = BUILD_SECONDS
	pay(maker, TABLE_PRICE, "carpentry commission")
	inventory.persist()
	return true

func collect_table() -> bool:
	if not can_change_order() or remaining != 0 or not open_carpenter():return false
	remaining = -1
	inventory.change(TABLE, 1)
	inventory.persist()
	return true

func snapshot() -> Dictionary:
	return {"table_seconds": remaining,"lantern_on":lantern_on}

func restore(data: Variant) -> void:
	remaining = -1
	lantern_on = false
	if not data is Dictionary:return
	var seconds: Variant = data.get("table_seconds", -1)
	if (seconds is int or seconds is float) and is_finite(float(seconds)) and float(seconds) >= 0:
		remaining = clampf(float(seconds), 0, BUILD_SECONDS)
	lantern_on = data.get("lantern_on", false) == true
	sync_lantern()

func toggle_lantern() -> bool:
	if inventory.amount(LANTERN) == 0:return false
	lantern_on = not lantern_on
	sync_lantern()
	return true

func sync_lantern() -> void:
	if inventory.amount(LANTERN) == 0:lantern_on = false
	if lantern_on and not is_instance_valid(lantern):
		lantern = OmniLight3D.new()
		lantern.name = "TravelLanternLight"
		lantern.light_color = Color("ffc987")
		lantern.light_energy = 1.3
		lantern.omni_range = 9.0
		lantern.position = Vector3(.24, town.player.appearance_height * 1.25, -.28)
		town.player.add_child(lantern)
	if is_instance_valid(lantern):lantern.visible = lantern_on

func _process(delta: float) -> void:
	if remaining > 0 and is_instance_valid(town.session) and town.session.restored and working(carpenter()):
		remaining = maxf(0, remaining - delta)
		if remaining == 0:
			town.economy.announce("Your table is ready. Collect it from Oren.")
			town.session.save_now(true)

func build(parent: VBoxContainer) -> void:
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 10)
	parent.add_child(panel)
	purse = label(panel)
	categories = TabContainer.new()
	panel.add_child(categories)
	for section in SECTIONS:
		var page := VBoxContainer.new()
		page.name = section
		page.add_theme_constant_override("separation", 10)
		categories.add_child(page)
	for item in GOODS:
		var good: Dictionary = GOODS[item]
		var page := categories.get_tab_control(good.section)
		var button := add_button(page, item, good.title, purchase_pressed.bind(item))
		var icon_path := "res://ui/items/" + String(good.icon) + ".png"
		if ResourceLoader.exists(icon_path):
			button.icon = load(icon_path)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 42)
		label(page).text = good.detail
	var orders := categories.get_tab_control(SECTIONS.size() - 1)
	order_status = label(orders)
	add_button(orders, TABLE, "Commission a dining table · %d coins" % TABLE_PRICE, func():
		order_feedback.text = "Oren took your order. Come back when the table is ready." if order_table() else "Speak to Oren during the day with enough coins for the order."
		refresh())
	add_button(orders, "collect", "Collect your table", func():
		order_feedback.text = "Table added to your bag. Use / place it at home." if collect_table() else "Collect it from Oren when the order is ready."
		refresh())
	order_feedback = label(orders)
	feedback = label(panel)
	panel.hide()

func label(parent: Control) -> Label:
	var control := Label.new()
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(control)
	return control

func add_button(parent: Control, id: String, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 46
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_color_override("font_disabled_color", Color("594e3e"))
	button.pressed.connect(action)
	parent.add_child(button)
	controls[id] = button
	return button

func purchase_pressed(item: String) -> void:
	feedback.text = "%s added to your bag." % GOODS[item].title if buy(item) else "Check your purse, the stall’s stock, and whether the seller is nearby."
	refresh()

func show_category(orders: bool) -> void:
	if categories:categories.current_tab = SECTIONS.size() - 1 if orders else 0

func refresh() -> void:
	if not panel or not panel.visible:return
	var seller := open_seller()
	var maker := open_carpenter()
	var coins: int = town.economy.player_coins
	var location := "Visit an open market stall to shop."
	if seller:location = seller.person_name + "’s stall"
	elif maker:location = "Oren’s commissions"
	purse.text = "%d %s · %s" % [coins, "coin" if coins == 1 else "coins", location]
	for item in GOODS:
		var good: Dictionary = GOODS[item]
		var owned: bool = good.get("unique", false) and owns(item)
		var price: int = good.price
		var stock := -1
		if seller and item == FOOD:
			price = town.economy.player_food_price(seller)
			stock = town.economy.market_for(seller).stock
		elif seller and item == FITTINGS:stock = inventory.fittings_stock(seller)
		var button: Button = controls[item]
		button.disabled = not seller or coins < price or owned or stock == 0
		button.text = "%s · %d %s" % [good.title, price, "coin" if price == 1 else "coins"]
		if owned:button.text += " · Owned"
		if stock >= 0:button.text += " · %d in stock" % stock
	controls[TABLE].visible = remaining < 0
	controls[TABLE].disabled = not maker or coins < TABLE_PRICE
	controls["collect"].visible = remaining == 0
	controls["collect"].disabled = not maker
	if remaining < 0:order_status.text = "Order a dining table from Oren. Pay when you order, then collect it after about 30 seconds during his daytime shift."
	elif remaining == 0:order_status.text = "Your dining table is ready to collect." if maker else "Your dining table is ready. Find Oren to collect it."
	else:order_status.text = "Oren’s table order · %d seconds of work left" % ceili(remaining)
