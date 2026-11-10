extends Node

const FOOD_PRICE := 2
const CRATE_PORTIONS := 6
var town: Node3D
var treasury := 3000
var player_coins := 30
var player_food := 0
var receipts: Array[Dictionary]=[]
var purchases := 0
var meals_eaten := 0
var wages_paid := 0
var sellers: Dictionary={}
var wallet_label: Label
var eat_button: Button
var notification: Label
var notice_time := 0.0
var bound := false
var story_rewards: Dictionary={}

func _ready() -> void:
	town=get_parent()
	if not testing() and FileAccess.file_exists("user://town-economy.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string("user://town-economy.json"))
		if saved is Dictionary:
			player_coins=maxi(0,int(saved.get("coins",30)))
			player_food=maxi(0,int(saved.get("food",0)))
			story_rewards=saved.get("story_rewards",{})
	make_interface()

func testing() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--validate") or argument.begins_with("--review"):return true
	return false

func bind() -> void:
	for person in town.life.people:
		person.coins=16+posmod(person.person_name.hash(),13)
		person.food=2 if not person.guard_label.is_empty() else 0
		person.hunger=0.1+posmod(person.person_name.hash(),60)/100.0
		if not person.stall_name.is_empty():person.coins=45
		if person.person_name in ["Bodil","Liv"]:
			var district: String=person.get_meta("district")
			person.job.clear()
			person.set_carry("")
			person.stall_name="fresh vegetables"
			person.occupation="Merchant"
			person.stall_anchor=Vector3(-102.45,0.03,103) if district=="west" else Vector3(116.55,0.03,101)
			person.stall_facing=PI/2
			person.position=person.stall_anchor
			person.path=PackedVector3Array()
			person.visual.rotation.y=person.stall_facing
			person.coins=45
		if not person.stall_name.is_empty():
			sellers[person.person_name]={"person":person,"district":String(person.get_meta("district"))}
	bound=true
	refresh()

func seller_for(district: String,choice := 0) -> CharacterBody3D:
	var candidates: Array[CharacterBody3D]=[]
	for data in sellers.values():
		if data.district==district:candidates.append(data.person)
	return candidates[posmod(choice,candidates.size())] if not candidates.is_empty() else null

func market_for(seller: CharacterBody3D) -> Dictionary:
	return town.jobs.markets[String(seller.get_meta("district"))]

func open_for_trade(seller: CharacterBody3D) -> bool:
	return seller!=null and not seller.stall_name.is_empty() and not town.day_night.night and not seller.night_schedule and seller.posture=="standing"

func player_food_price(seller: CharacterBody3D) -> int:
	if not seller or not town.adventures:return FOOD_PRICE
	var trust: int=int(town.adventures.relationship(seller.person_name).trust)
	return 1 if trust>=8 else 3 if trust<=-8 else FOOD_PRICE

func buy_food(seller: CharacterBody3D,buyer: CharacterBody3D=null) -> bool:
	if not open_for_trade(seller):return false
	var market := market_for(seller)
	var money: int=buyer.coins if buyer else player_coins
	var price := FOOD_PRICE if buyer else player_food_price(seller)
	if int(market.stock)<1 or money<price:return false
	if buyer:
		buyer.coins-=price
		buyer.food+=1
	else:
		player_coins-=price
		player_food+=1
		if town.adventures:town.adventures.traded(seller.person_name)
	seller.coins+=price
	market.stock-=1
	market.sold+=1
	purchases+=1
	record("food",buyer.person_name if buyer else "You",seller.person_name,price)
	town.jobs.update_market(String(seller.get_meta("district")))
	refresh()
	return true

func player_buy() -> void:
	var seller: CharacterBody3D=town.life.active
	var price := player_food_price(seller)
	if buy_food(seller):announce("Bought vegetables for "+str(price)+" coins.")
	elif seller and open_for_trade(seller):announce("Not enough coins." if player_coins<price else "The stall is waiting for a fresh delivery.")
	else:announce("The market is closed for the night.")
	town.life.refresh_trade()

func player_sell() -> void:
	var seller: CharacterBody3D=town.life.active
	if not seller or not open_for_trade(seller) or player_food<1 or seller.coins<1:
		announce("You need a meal to sell, and an open stall.")
		return
	player_food-=1
	player_coins+=1
	seller.coins-=1
	var market := market_for(seller)
	market.stock+=1
	market.returned+=1
	record("resale",seller.person_name,"You",1)
	town.jobs.update_market(String(seller.get_meta("district")))
	refresh()
	town.life.refresh_trade()
	announce("Sold one portion for 1 coin.")

func eat(buyer: CharacterBody3D=null) -> bool:
	if buyer:
		if buyer.food<1:return false
		buyer.food-=1
		buyer.hunger=0
	else:
		if player_food<1:return false
		player_food-=1
	meals_eaten+=1
	if town.character_life:town.character_life.ate(buyer)
	refresh()
	return true

func pay(person: CharacterBody3D,kind: String) -> void:
	if not bound:return
	var amount: int={"delivery":4,"crafted":3,"supply":2,"watch":4}.get(kind,0)
	if amount<1 or treasury<amount:return
	treasury-=amount
	person.coins+=amount
	wages_paid+=amount
	record("wage","Town treasury",person.person_name,amount)

func record(kind: String,from_name: String,to_name: String,amount: int) -> void:
	receipts.append({"kind":kind,"from":from_name,"to":to_name,"coins":amount,"time":Time.get_ticks_msec()})
	if receipts.size()>150:receipts.pop_front()

func refresh() -> void:
	if wallet_label:wallet_label.text="Your purse: %d coins\nFood: %d portions"%[player_coins,player_food]
	if eat_button:eat_button.disabled=player_food<1
	if not testing():
		var trace := preload("res://frame_costs.gd").begin()
		var file := FileAccess.open("user://town-economy.json",FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify({"version":2,"coins":player_coins,"food":player_food,"story_rewards":story_rewards}))
			file.close()
		preload("res://frame_costs.gd").finish("economy.save_state",trace)

func award_story(id: String,amount: int) -> bool:
	if story_rewards.has(id):return false
	story_rewards[id]=amount
	treasury=maxi(0,treasury-maxi(0,amount))
	player_coins+=maxi(0,amount)
	record("mission","Town contract","You",amount)
	refresh()
	return true

func announce(message: String) -> void:
	notification.text=message
	notice_time=5

func make_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(root_control)
	wallet_label=Label.new()
	root_control.add_child(wallet_label)
	wallet_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	wallet_label.offset_left=-255
	wallet_label.offset_right=-25
	wallet_label.offset_top=26
	wallet_label.offset_bottom=76
	wallet_label.add_theme_color_override("font_color",Color("ffe2a0"))
	wallet_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	wallet_label.add_theme_constant_override("shadow_offset_x",2)
	wallet_label.add_theme_constant_override("shadow_offset_y",2)
	eat_button=Button.new()
	root_control.add_child(eat_button)
	eat_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	eat_button.offset_left=-255
	eat_button.offset_right=-100
	eat_button.offset_top=80
	eat_button.offset_bottom=112
	eat_button.text="Eat a portion"
	eat_button.pressed.connect(func():
		if eat():announce("You ate a portion of vegetables."))
	notification=Label.new()
	root_control.add_child(notification)
	notification.position=Vector2(28,465)
	notification.add_theme_color_override("font_shadow_color",Color.BLACK)
	refresh()

func _process(delta: float) -> void:
	if notice_time>0:
		notice_time-=delta
		if notice_time<=0:notification.text=""
