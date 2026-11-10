extends "res://shop_world_review.gd"

const Interaction = preload("res://interaction_target.gd")

func enter_at_stall(merchant: CharacterBody3D) -> bool:
	var exclude: Array[RID] = [town.player.get_rid()]
	for offset in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		var point: Vector3 = town.session.safe_floor(merchant.global_position + offset * 1.5, exclude)
		if not point.is_finite():continue
		town.player.global_position = point
		town.player.velocity = Vector3.ZERO
		await ticks(8)
		if Interaction.resolve(town).kind != "shop":continue
		await tap(KEY_E)
		return town.interface_ui.opened_page == "Belongings" and town.inventory_ui.source == "shop"
	return false

func play() -> void:
	town.day_night.set_enabled(false)
	town.home_district.leave_home()
	var shop: Node = town.inventory_ui.shop
	var merchant: CharacterBody3D = town.economy.seller_for("city")
	# A test allowance lets this review exercise every catalog category.
	town.economy.award_story("expanded_shop_review_allowance", 90)
	if not await enter_at_stall(merchant):check(false, "E opens the marked stall shop");return
	check(true, "E opens the marked stall shop")
	check(shop.categories.get_tab_count() == 4 and shop.categories.get_tab_title(0) == "Food & garden", "Shop shows four categories and starts with provisions")
	var market: Dictionary = town.economy.market_for(merchant)
	var stock: int = market.stock
	var price: int = town.economy.player_food_price(merchant)
	var coins: int = town.economy.player_coins
	shop.controls[Shop.FOOD].pressed.emit()
	check(town.inventory_ui.amount(Shop.FOOD) == 1 and market.stock == stock - 1 and town.economy.player_coins == coins - price, "Vegetables use the seller’s real price and stock")
	coins = town.economy.player_coins
	for item in ["Vegetable stew", "Herbs", Shop.SEEDS, "Timber", Shop.FITTINGS, Shop.AXE, Shop.LANTERN, Shop.STOOL, Shop.BED]:
		shop.categories.current_tab = Shop.GOODS[item].section
		check(not shop.controls[item].disabled, "%s is available from the catalog" % item)
		shop.controls[item].pressed.emit()
		check(town.inventory_ui.amount(item) == 1, "%s reaches the bag" % item)
		coins -= int(Shop.GOODS[item].price)
	check(town.economy.player_coins == coins and town.inventory_ui.fittings_stock(merchant) == 7, "Catalog charges exact prices and preserves shared fittings stock")
	check(not shop.buy(Shop.LANTERN) and town.economy.player_coins == coins, "Owning a lantern blocks a duplicate purchase")
	town.day_night.night = true
	check(not shop.buy("Timber") and town.economy.player_coins == coins, "A closed stall cannot charge for goods")
	town.day_night.night = false
	if DisplayServer.get_name() != "headless":
		shop.categories.current_tab = 1
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../review/expanded-town-shop.png")
	town.interface_ui.close()
	town.character_life.change_need("You", "hunger", -70)
	var hunger: float = town.character_life.need("You", "hunger")
	check(town.inventory_ui.use("Vegetable stew") and town.inventory_ui.amount("Vegetable stew") == 0 and town.character_life.need("You", "hunger") > hunger, "A purchased meal is edible and restores hunger")
	check(town.inventory_ui.use(Shop.LANTERN) and shop.lantern.visible and shop.lantern.get_parent() == town.player, "Lantern lights up and follows the player")
	town.player.global_position = town.cooking.garden.global_position + Vector3.BACK * 1.5
	await ticks(3)
	check(town.inventory_ui.use(Shop.SEEDS), "Purchased seeds start the real planting action")
	await create_timer(4.4).timeout
	check(town.inventory_ui.amount(Shop.SEEDS) == 0 and town.inventory_ui.amount(Shop.FOOD) == 1 and town.cooking.crop_state == "growing", "Planting uses a packet and leaves bought food in the bag")
	check(await place_at_home(Shop.BED), "Purchased bed fits on the actual home floor")
	var bed: Node3D = bought_bed()
	check(is_instance_valid(bed) and town.player.use_furniture(bed, "sleeping"), "Purchased bed supports the real sleep action")
	town.player.stand_from_furniture(true)
	check(town.inventory_ui.transfer(Shop.LANTERN, 1, true) and not shop.lantern.visible, "Putting the lantern in storage turns off its light")
	check(town.inventory_ui.transfer(Shop.LANTERN, 1, false) and town.inventory_ui.use(Shop.LANTERN), "The lantern can be taken back and relit")
	town.home_district.leave_home()
	if not await open_shop_with(shop.carpenter(), "Furniture commissions"):
		check(false, "Oren opens the orders tab");return
	check(shop.categories.current_tab == 3 and shop.order_table(), "Oren opens the orders tab and accepts a table commission")
	town.interface_ui.close()
	check(town.session.flush_and_save() == OK, "Expanded shop state saves")

func bought_bed() -> Node3D:
	for child in town.home_district.interior.get_children():
		if child.has_meta("crafted_id"):
			var marker := child.get_node_or_null("Wooden bed") as Node3D
			if marker:return marker
	return null

func resume() -> void:
	var shop: Node = town.inventory_ui.shop
	check(town.inventory_ui.amount(Shop.LANTERN) == 1 and shop.lantern_on and shop.lantern.visible, "Continue restores the bought lantern and its light state")
	check(is_instance_valid(bought_bed()) and town.crafting.placed.size() == 1, "Continue restores the purchased bed exactly once")
	check(town.inventory_ui.amount("Herbs") == 1 and town.inventory_ui.amount("Timber") == 1 and town.inventory_ui.amount(Shop.FITTINGS) == 1, "Continue restores the purchased materials")
	check(town.cooking.crop_state == "growing" and town.inventory_ui.amount(Shop.SEEDS) == 0, "Continue restores the garden without refunding planted seeds")
	check(shop.remaining > 0, "Continue restores the pending commission")
	shop._process(Shop.BUILD_SECONDS)
	if not await open_shop_with(shop.carpenter(), "Furniture commissions"):
		check(false, "Oren reopens the orders tab to collect");return
	check(shop.categories.current_tab == 3 and shop.collect_table() and town.inventory_ui.amount(Shop.TABLE) == 1 and not shop.collect_table(), "Restored commission hands over one table")
