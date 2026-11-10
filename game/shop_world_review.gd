extends "res://desktop_gameplay_review.gd"

const Shop = preload("res://town_shop.gd")

func stand_near(person: CharacterBody3D) -> bool:
	var exclude: Array[RID] = [town.player.get_rid()]
	for offset in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		var point: Vector3 = town.session.safe_floor(person.global_position + offset * 1.5, exclude)
		if not point.is_finite():continue
		town.player.global_position = point
		town.player.velocity = Vector3.ZERO
		await ticks(3)
		if town.inventory_ui.shop.available_for(person):return true
	return false

func open_shop_with(person: CharacterBody3D, action: String) -> bool:
	if not await stand_near(person):return false
	town.life.open_dialog(person, false)
	var button: Button = town.life.dialog.find_child("ShopButton", true, false)
	if not button.visible or button.text != action:return false
	button.pressed.emit()
	return town.interface_ui.opened_page == "Belongings" and town.inventory_ui.source == "shop"

func place_at_home(item: String) -> bool:
	town.interface_ui.close()
	town.home_district.enter_home()
	var home: Node3D = town.home_district.interior
	for local: Vector3 in [Vector3(2.6,.1,3.8), Vector3(2,.1,1), Vector3(.8,.1,2.5), Vector3(4,.1,3.5), Vector3(0,.1,3)]:
		town.player.global_position = home.to_global(local)
		await ticks(2)
		if town.inventory_ui.use(item):return true
	return false

func play() -> void:
	town.day_night.set_enabled(false)
	town.home_district.leave_home()
	var shop: Node = town.inventory_ui.shop
	var merchant: CharacterBody3D = town.economy.seller_for("city")
	if not await open_shop_with(merchant, "Browse goods"):
		check(false, "Market resident opens the actual shop page");return
	check(true, "Market resident opens the actual shop page")
	var initial: int = town.economy.player_coins
	check(initial == 30 and town.physical_gameplay.work_seconds("chop") == 4.0, "Fresh town starts with 30 coins and ordinary timber tools")
	shop.controls[Shop.STOOL].pressed.emit()
	shop.controls[Shop.AXE].pressed.emit()
	check(town.economy.player_coins == 10 and town.inventory_ui.amount(Shop.STOOL) == 1 and town.inventory_ui.amount(Shop.AXE) == 1, "Stool and axe cost 8 and 12 coins and reach the bag")
	check(not shop.buy(Shop.AXE) and town.economy.player_coins == 10, "A duplicate axe purchase does not charge the player")
	check(town.physical_gameplay.work_seconds("chop") == 2.5 and town.physical_gameplay.work_seconds("repair") == 4.0, "Axe speeds up timber work and keeps other tasks at their usual pace")
	check(await place_at_home(Shop.STOOL) and town.inventory_ui.amount(Shop.STOOL) == 0, "Purchased stool places on the actual home floor")
	var seat: Node3D
	for child in town.home_district.interior.get_children():
		if child.has_meta("crafted_id"):
			for marker in child.get_children():
				if marker.is_in_group("seats"):seat = marker
	check(is_instance_valid(seat) and town.player.use_furniture(seat, "sitting"), "Purchased stool is a usable seat")
	town.player.stand_from_furniture(true)
	check(town.inventory_ui.transfer(Shop.AXE, 1, true) and town.physical_gameplay.work_seconds("chop") == 4.0, "Storing the axe removes its bonus")
	check(town.inventory_ui.transfer(Shop.AXE, 1, false), "Taking the axe back restores it to the bag")
	town.home_district.leave_home()
	var oren: CharacterBody3D = shop.carpenter()
	check(await stand_near(oren) and not shop.order_table() and town.economy.player_coins == 10, "Oren's table requires the player to earn more coins")
	town.challenges.start("wood")
	var block: Node3D = town.physical_gameplay.find_object("physical/timber_chopping_block")
	town.player.global_position = block.global_position + Vector3.BACK
	await ticks(5)
	for piece in range(3):
		town.physical_gameplay.start_work(block)
		check(is_equal_approx(town.physical_gameplay.busy, 2.5), "The real timber work uses the axe's faster timer")
		while town.physical_gameplay.busy > 0:await physics_frame
	check(town.inventory_ui.amount("Timber") == 3, "Three chopping actions produce three pieces of timber")
	town.player.global_position = town.challenges.DEFINITIONS.repair.point + Vector3.BACK
	await ticks(8)
	check(town.challenges.active.is_empty() and town.economy.player_coins == 25 and town.inventory_ui.amount("Timber") == 0, "Timber order pays 15 coins and uses the delivered timber")
	if not await open_shop_with(oren, "Furniture commissions"):
		check(false, "Oren opens the commission page");return
	check(true, "Oren opens the commission page")
	shop.controls[Shop.TABLE].pressed.emit()
	check(town.economy.player_coins == 1 and shop.remaining > 0 and not shop.order_table() and not shop.collect_table(), "One paid commission is pending with no early collection or duplicate charge")
	town.interface_ui.close()
	await tap(KEY_ESCAPE)
	check(press_button(town.interface_ui.pause_panel, "Save game") and town.session.last_error == OK, "Pause menu saves the pending commission")
	var saved: Dictionary = town.session.Store.load_valid(town.session.save_path)
	check(not saved.is_empty() and saved.extensions.shop.table_seconds > 0 and saved.economy.player_coins == 1, "Saved checkpoint contains the paid order and remaining work time")

func resume() -> void:
	var shop: Node = town.inventory_ui.shop
	check(town.economy.player_coins == 1 and town.inventory_ui.amount(Shop.AXE) == 1 and shop.remaining > 0, "Fresh process restores the purse, axe, and pending table")
	check(town.crafting.placed.size() == 1 and town.crafting.placed[0].item == Shop.STOOL, "Purchased stool survives reload as one placed item")
	var pending: float = shop.remaining
	town.day_night.night = true
	shop._process(10)
	check(is_equal_approx(shop.remaining, pending), "Oren's commission pauses at night")
	town.day_night.night = false
	shop._process(Shop.BUILD_SECONDS)
	check(shop.remaining == 0, "Daytime work finishes the table")
	town.player.global_position = Vector3(0, .1, 60)
	check(not shop.collect_table() and shop.remaining == 0, "The finished table waits for pickup with Oren")
	if not await open_shop_with(shop.carpenter(), "Furniture commissions"):
		check(false, "Oren opens the ready commission");return
	if DisplayServer.get_name() != "headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../review/town-shop.png")
	shop.controls.collect.pressed.emit()
	check(shop.remaining == -1 and town.inventory_ui.amount(Shop.TABLE) == 1 and town.economy.player_coins == 1 and not shop.collect_table(), "Collecting hands over one table with no second fee")
	check(await place_at_home(Shop.TABLE) and town.inventory_ui.amount(Shop.TABLE) == 0, "Commissioned dining table becomes real furniture in the home")
	check(town.session.flush_and_save() == OK, "Final purchase and placement save successfully")
