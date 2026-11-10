extends Node

signal status_changed(message: String, error: int)
const Store = preload("res://town_session_store.gd")
var town: Node3D
var save_path := "user://town-session.json"
var writer = Store.new()
var auto_restore := true
var autosave_seconds := 30.0
var ready_for_use := false
var restored := false
var status_text := "Preparing your session…"
var last_error: Error = OK
var used_backup := false
var layout_key_override := ""
var clock := 0.0
var saving := false
var status_label: Label
var notice_time := 0.0
var extensions: Dictionary = {}
var restore_notes: Array[String] = []

func _ready() -> void:
	town = get_parent();process_mode = Node.PROCESS_MODE_ALWAYS
	writer.report_failures = false
	if testing() and not save_path.get_file().begins_with("review-"):
		save_path = "user://review-town-session.json"
		# Existing world fixtures start fresh unless they explicitly exercise saves.
		if "--review-session-enabled" not in OS.get_cmdline_user_args():
			auto_restore = false
			ready_for_use = true
			restored = true
			autosave_seconds = INF
	var layer := CanvasLayer.new();layer.layer = 29;add_child(layer)
	status_label = Label.new();layer.add_child(status_label);status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.position = Vector2(24, get_viewport().get_visible_rect().size.y - 38);status_label.hide()
	if auto_restore:prepare.call_deferred()

func testing() -> bool:
	var economy: Node = town.get("economy")
	return is_instance_valid(economy) and economy.has_method("testing") and economy.testing()

func systems_ready() -> bool:
	for spec in [["life", "navigation_ready"], ["home_district", "ready_for_spawn"], ["economy", "bound"], ["character_life", "bound"]]:
		var node: Node = town.get(spec[0])
		if not is_instance_valid(node) or not node.get(spec[1]):return false
	for spec in [["industrial_workforce", "bound"], ["families", "bound"], ["interface_ui", "ready_for_use"]]:
		var node: Node = town.get(spec[0])
		if is_instance_valid(node) and not node.get(spec[1]):return false
	var physical: Node = town.get("physical_gameplay")
	var adventures: Node = town.get("adventures")
	return is_instance_valid(town.get("player")) and is_instance_valid(physical) and not physical.objects.is_empty() and is_instance_valid(physical.cart) and is_instance_valid(adventures) and is_instance_valid(adventures.repaired_cart)

func prepare() -> void:
	while is_inside_tree() and not systems_ready():await get_tree().process_frame
	if not is_inside_tree():return
	# Deferred individual loaders and physical setup finish before the snapshot.
	await get_tree().physics_frame;await get_tree().physics_frame
	ready_for_use = true
	restore_saved(town.join_started >= 0)

func register_extension(id: String, capture: Callable, apply: Callable) -> void:
	extensions[id] = {"capture":capture,"apply":apply}

func layout_key() -> String:
	if not layout_key_override.is_empty():return layout_key_override
	return FileAccess.get_file_as_string("user://town-layout.json").sha256_text() if FileAccess.file_exists("user://town-layout.json") else "original-layout"

func vec(point: Vector3) -> Array:return [point.x, point.y, point.z]
func point(value: Array) -> Vector3:return Vector3(float(value[0]), float(value[1]), float(value[2]))

func snapshot() -> Dictionary:
	var player: Node3D = town.player
	var position: Vector3 = player.stand_transform.origin if not String(player.get("resting")).is_empty() else player.global_position
	var physical: Node = town.physical_gameplay
	var objects: Dictionary = {}
	for object: Node3D in physical.objects:
		if not is_instance_valid(object):continue
		var id: String = physical.object_id(object)
		var held: bool = object == physical.carried or object.has_meta("held_by")
		var location: Vector3 = object.get_meta("pickup_position", object.global_position) if held else object.global_position
		var stock: Dictionary = {}
		for field in ["stock", "cargo", "vegetables"]:
			if object.has_meta(field):stock[field] = maxi(0, int(object.get_meta(field)))
		objects[id] = {"position":vec(location),"rotation":vec(object.global_rotation),"stock":stock,"holder":String(object.get_meta("held_by", ""))}
	var adventure: Node = town.adventures
	var challenge: Node = town.challenges
	var progress: Dictionary = {}
	if challenge.active == "archery":progress["hits"] = maxi(0, physical.score - challenge.baseline)
	if challenge.active == "wood":progress["timber"] = maxi(0, int(adventure.inventory.get("Timber", 0)) - challenge.baseline)
	var markets: Dictionary = {}
	for id in town.jobs.markets:
		var market: Dictionary = town.jobs.markets[id];var record: Dictionary = {}
		for field in ["stock", "received", "sold", "returned"]:record[field] = maxi(0, int(market.get(field, 0)))
		markets[id] = record
	var data := {"version":Store.VERSION,"saved_at":Time.get_unix_time_from_system(),"layout":layout_key(),
		"player":{"position":vec(position),"rotation":vec(player.global_rotation),"inside":town.home_district.inside,"view":town.view_mode,"camera":vec(player.camera.rotation),"overview_focus":vec(town.overview_focus),"distance":town.distance,"orbit":town.orbit},
		"adventures":{"inventory":adventure.inventory.duplicate(true),"progress":adventure.progress.duplicate(true),"relationships":adventure.relationships.duplicate(true),"memories":adventure.memories.duplicate(true)},
		"economy":{"player_coins":town.economy.player_coins,"player_food":town.economy.player_food,"treasury":town.economy.treasury,"story_rewards":town.economy.story_rewards.duplicate(true)},
		"home":{"storage":town.player_home.storage.duplicate(true)},
		"challenge":{"active":challenge.active,"remaining":maxf(0, challenge.remaining),"round":int(challenge.active_spec.get("round", 0)),"progress":progress,"completions":challenge.completions.duplicate(true),"cooldowns":challenge.cooldowns.duplicate(true),"finished":challenge.finished.duplicate(),"crate":physical.object_id(challenge.crate),"repair":physical.object_id(challenge.repair_job)},
		"world":{"enabled":town.day_night.enabled,"phase":town.day_night.phase,"cycle_seconds":town.day_night.cycle_seconds,"home_wait_seconds":town.day_night.home_wait_seconds,"settled_seconds":town.day_night.settled_seconds},
		"physical":{"objects":objects,"carried":physical.object_id(physical.carried),"score":physical.score},"markets":markets,"extensions":{}}
	var life: Node = town.get("character_life")
	if is_instance_valid(life):
		var states: Dictionary = life.states.duplicate(true)
		for name in life.people:
			if states.has(name):states[name]["friendships"] = life.people[name].friendships.duplicate(true)
		data.extensions.life = {"states":states,"day":life.day,"elapsed":life.elapsed,"enabled":life.enabled}
	var cooking: Node = town.get("cooking")
	if is_instance_valid(cooking):
		var garden: Dictionary = {}
		for field in ["clock", "growth_ready", "crop_state", "herb_stock", "herb_regrow"]:garden[field] = cooking.get(field)
		garden.watered = cooking.garden.get_meta("watered", false) if is_instance_valid(cooking.garden) else false
		data.extensions.cooking = garden
	var events: Node = town.get("events")
	if is_instance_valid(events):data.extensions.events = {"records":events.records.duplicate(true),"knowledge":events.knowledge.duplicate(true),"elapsed":events.elapsed}
	var crafting: Node = town.get("crafting")
	if is_instance_valid(crafting) and crafting.has_method("snapshot"):data.extensions.crafting = crafting.snapshot()
	for id in extensions:data.extensions[id] = extensions[id].capture.call()
	return data

func save_now(background := false) -> Error:
	if not ready_for_use or not systems_ready():
		set_status("The town is still getting ready. Try saving again shortly.", ERR_BUSY)
		return ERR_BUSY
	var data := snapshot()
	set_status("Saving…");saving = background
	var result: Error = writer.save(save_path, data, background)
	if result != OK:set_status("Could not save your session. Please try again.", result);saving = false
	elif not background:set_status("Session saved.")
	clock = 0
	return result

func flush_and_save() -> Error:
	var result := save_now(false)
	var flushed: Error = writer.flush()
	return result if result != OK else flushed

func restore_saved(start_at_home := false) -> bool:
	if restored:return false
	var data := Store.load_valid(save_path)
	used_backup = false
	if data.is_empty():
		data = Store.load_valid(save_path + ".backup");used_backup = not data.is_empty()
	if data.is_empty():
		restored = true
		set_status("No saved session yet." if not FileAccess.file_exists(save_path) else "Saved session could not be read. Your existing individual saves remain available.")
		return false
	if not apply_snapshot(data, start_at_home):
		# Leave both copies intact until the player explicitly saves again.
		return false
	restored = true
	set_status(("Recovered previous session." if used_backup else "Session restored.") + (" " + " ".join(restore_notes) if not restore_notes.is_empty() else ""))
	return true

func safe_floor(candidate: Vector3, exclude: Array[RID] = []) -> Vector3:
	if not candidate.is_finite() or absf(candidate.x) > 2000 or absf(candidate.z) > 2000:return Vector3.INF
	var ray := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * .6, candidate - Vector3.UP * 4, 1)
	ray.exclude = exclude
	var floor_hit: Dictionary = town.get_world_3d().direct_space_state.intersect_ray(ray)
	if floor_hit.is_empty() or floor_hit.normal.y < .7 or absf(floor_hit.position.y - candidate.y) > .5:return Vector3.INF
	var location: Vector3 = floor_hit.position + Vector3.UP * .04
	var shape := CapsuleShape3D.new();shape.radius = .34;shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new();query.shape = shape;query.collision_mask = 1;query.exclude = exclude
	query.transform.origin = location + Vector3.UP * .94
	return location if town.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty() else Vector3.INF

func safe_player(saved: Dictionary) -> Vector3:
	var home: Node3D = town.home_district
	var candidate := point(saved.position)
	var inside: bool = saved.inside
	if (inside and candidate.distance_to(home.room_origin) < 40) or (not inside and candidate.y > -20):
		var exact := safe_floor(candidate, [town.player.get_rid()])
		if exact.is_finite():return exact
	restore_notes.append("Moved to a clear floor.")
	var origin: Vector3 = home.spawn if inside else home.porch
	for offset in [Vector3.ZERO, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3(2, 0, 2), Vector3(-2, 0, -2)]:
		var fallback := safe_floor(origin + offset, [town.player.get_rid()])
		if fallback.is_finite():return fallback
	return Vector3.INF

func apply_snapshot(data: Dictionary, start_at_home := false) -> bool:
	if not Store.valid_snapshot(data) or not systems_ready():return false
	restore_notes.clear()
	var home: Node3D = town.home_district
	var position: Vector3 = home.safe_spawn() if start_at_home else safe_player(data.player)
	if not position.is_finite():set_status("Session could not restore: no clear floor was found.", ERR_UNAVAILABLE);return false
	var physical: Node = town.physical_gameplay
	physical.cancel_object_action();physical.restore_carried(null)
	if is_instance_valid(physical.mounted):
		var mount: CharacterBody3D = physical.mounted
		town.player.remove_collision_exception_with(mount);mount.remove_collision_exception_with(town.player);mount.set_physics_process(true);physical.mounted = null
	physical.pushing = false;physical.leading = null;physical.climbing = false;physical.busy = 0;physical.work = null
	if not String(town.player.resting).is_empty():town.player.stand_from_furniture(true)
	if physical.crouching and physical.has_method("toggle_crouch"):physical.toggle_crouch()
	town.adventures.stop_work()
	home.set_inside(start_at_home or data.player.inside)
	town.player.global_position = position
	town.player.global_rotation = Vector3.ZERO if start_at_home else point(data.player.rotation)
	town.player.velocity = Vector3.ZERO
	town.player.reset_physics_interpolation()
	if start_at_home:town.player.camera.rotation = Vector3.ZERO
	elif Store.vector(data.player.get("camera")):town.player.camera.rotation = point(data.player.camera)
	town.set_view(0 if start_at_home else int(data.player.view))
	if Store.vector(data.player.get("overview_focus")):town.overview_focus = point(data.player.overview_focus)
	town.distance = clampf(float(data.player.get("distance", 75)), 9, 450);town.orbit = float(data.player.get("orbit", .72))
	if town.view_mode == 1:town.update_camera()
	# Assign a consistent checkpoint; never call reward-bearing accept/advance,
	# complete/start methods while reconstructing it.
	var adventure: Node = town.adventures
	adventure.inventory = data.adventures.inventory.duplicate(true);adventure.relationships = data.adventures.relationships.duplicate(true)
	adventure.memories = data.adventures.get("memories", []).duplicate(true)
	for id in data.adventures.progress:
		if not adventure.progress.has(id):continue
		var record: Dictionary = data.adventures.progress[id]
		var definition: Dictionary = adventure.find_mission(id)
		var steps: int = definition.get("steps", []).size()
		if int(record.step) < steps or (record.status == "complete" and int(record.step) == steps):adventure.progress[id] = record.duplicate(true)
	for field in ["player_coins", "player_food", "treasury"]:town.economy.set(field, int(data.economy[field]))
	town.economy.story_rewards = data.economy.story_rewards.duplicate(true)
	town.player_home.storage = data.home.storage.duplicate(true)
	if is_instance_valid(adventure.repaired_cart) and adventure.progress.has("wagon_fittings"):adventure.repaired_cart.visible = adventure.progress.wagon_fittings.status == "complete"
	for id in data.markets:
		if not town.jobs.markets.has(id):continue
		for field in ["stock", "received", "sold", "returned"]:
			if data.markets[id].has(field):town.jobs.markets[id][field] = int(data.markets[id][field])
		town.jobs.update_market(id)
	restore_challenge(data.challenge)
	physical.score = maxi(0, int(data.physical.get("score", 0)))
	if town.challenges.active == "archery":town.challenges.baseline = physical.score - int(data.challenge.progress.get("hits", 0))
	if town.challenges.active == "wood":town.challenges.baseline = int(adventure.inventory.get("Timber", 0)) - int(data.challenge.progress.get("timber", 0))
	for id in data.physical.objects:
		var object: Node3D = physical.find_object(id)
		if not is_instance_valid(object):continue
		physical.clear_holder(object)
		if object.get_parent() != physical:object.reparent(physical)
		var record: Dictionary = data.physical.objects[id]
		var location := point(record.position)
		if data.get("layout", "") != layout_key() and String(object.get_meta("activity", "")) in ["carry", "cart"]:
			var exclude: Array[RID] = []
			if object is CollisionObject3D:exclude.append(object.get_rid())
			var validated := safe_floor(location, exclude)
			if validated.is_finite():location = validated
			else:location = object.global_position;restore_notes.append("A moved item kept its safe starting place.")
		object.global_position = location;object.global_rotation = point(record.rotation)
		if object is CollisionObject3D:object.collision_layer = 0 if object.get_meta("activity", "") == "ladder" else 1
		for field in ["stock", "cargo", "vegetables"]:
			if record.stock.has(field):object.set_meta(field, int(record.stock[field]))
		if object.has_meta("vegetables") and not record.stock.has("vegetables"):object.remove_meta("vegetables")
		if not String(record.get("holder", "")).is_empty():restore_notes.append("A resident's item was placed down.")
	if town.challenges.active == "repair" and is_instance_valid(town.challenges.repair_job):
		var repair: Node3D = town.challenges.repair_job
		for child in repair.get_children():
			if child is Node3D and not child is CollisionShape3D:child.rotation.z = .18 if int(repair.get_meta("stock", 1)) > 0 else 0.0
	if not String(data.physical.carried).is_empty():
		var carried: Node3D = physical.find_object(data.physical.carried)
		if carried and not physical.restore_carried(carried):restore_notes.append("The carried item was placed down.")
	physical.update_cargo()
	restore_extensions(data.extensions)
	var day: Node = town.day_night
	day.enabled = data.world.enabled;day.phase = float(data.world.phase);day.cycle_seconds = float(data.world.cycle_seconds)
	day.apply_time()
	var life: Node = town.get("character_life")
	if is_instance_valid(life):life.was_night = day.night
	day.home_wait_seconds = maxf(0, float(data.world.get("home_wait_seconds", 0)));day.settled_seconds = maxf(0, float(data.world.get("settled_seconds", 0)))
	if day.toggle:day.toggle.set_pressed_no_signal(day.enabled)
	adventure.update_markers();adventure.refresh_journal()
	# refresh() would write a separate wallet here; update only the existing UI.
	if town.economy.wallet_label:town.economy.wallet_label.text = "Your purse: %d coins\nFood: %d portions" % [town.economy.player_coins, town.economy.player_food]
	if town.economy.eat_button:town.economy.eat_button.disabled = town.economy.player_food < 1
	var map: Node = town.get("town_map")
	if is_instance_valid(map) and not town.challenges.active.is_empty():map.tracked = "challenge"
	return true

func restore_challenge(saved: Dictionary) -> void:
	var challenge: Node = town.challenges;var physical: Node = town.physical_gameplay
	challenge.active = "";challenge.active_spec = {}
	challenge.completions = saved.completions.duplicate(true);challenge.cooldowns = saved.get("cooldowns", {}).duplicate(true);challenge.finished = saved.get("finished", []).duplicate()
	var id: String = saved.active
	challenge.refresh_options()
	if not String(saved.get("crate", "")).is_empty():
		challenge.crate = physical.find_object(saved.crate)
		if not is_instance_valid(challenge.crate):challenge.crate = physical.prop("Express delivery crate", "Crate_Wooden", challenge.DEFINITIONS.delivery.point, "carry")
	if not String(saved.get("repair", "")).is_empty():
		challenge.repair_job = physical.find_object(saved.repair)
		if not is_instance_valid(challenge.repair_job):challenge.repair_job = physical.prop("Damaged stool repair", "Stool", challenge.DEFINITIONS.repair.point + Vector3(1.5, 0, 0), "furniture_repair")
	if not challenge.DEFINITIONS.has(id):return
	var spec: Dictionary = challenge.contract(id)
	var round_number := int(saved.get("round", spec.round))
	var reward_id := "challenge_" + id + ("_repeat_" + str(round_number) if round_number > 1 else "")
	if town.economy.story_rewards.has(reward_id) or round_number != int(spec.round):return
	challenge.active = id;challenge.active_spec = spec;challenge.remaining = clampf(float(saved.remaining), 0, float(spec.seconds))
	if id == "delivery":
		challenge.crate = physical.find_object(saved.get("crate", ""))
		if not is_instance_valid(challenge.crate):challenge.crate = physical.prop("Express delivery crate", "Crate_Wooden", spec.point, "carry")
	if id == "repair":
		challenge.repair_job = physical.find_object(saved.get("repair", ""))
		if not is_instance_valid(challenge.repair_job):
			challenge.repair_job = physical.prop("Damaged stool repair", "Stool", spec.point + Vector3(1.5, 0, 0), "furniture_repair")
			challenge.repair_job.set_meta("stock", 1)

func restore_extensions(data: Dictionary) -> void:
	var life: Node = town.get("character_life")
	if is_instance_valid(life) and data.get("life") is Dictionary:
		var saved: Dictionary = data.life
		for name in saved.get("states", {}):
			if not life.states.has(name):continue
			life.states[name] = saved.states[name].duplicate(true)
			if life.people.has(name):life.people[name].friendships = saved.states[name].get("friendships", {}).duplicate(true)
		life.day = maxi(1, int(saved.get("day", 1)));life.elapsed = maxf(0, float(saved.get("elapsed", 0)));life.enabled = bool(saved.get("enabled", true))
		if life.enabled_toggle:life.enabled_toggle.set_pressed_no_signal(life.enabled)
	var cooking: Node = town.get("cooking")
	if is_instance_valid(cooking) and data.get("cooking") is Dictionary:
		for field in ["clock", "growth_ready", "crop_state", "herb_stock", "herb_regrow"]:
			if data.cooking.has(field):cooking.set(field, data.cooking[field])
		if is_instance_valid(cooking.garden):cooking.garden.set_meta("watered", bool(data.cooking.get("watered", false)))
		cooking.update_garden()
	var events: Node = town.get("events")
	if is_instance_valid(events) and data.get("events") is Dictionary:
		events.records = data.events.get("records", {}).duplicate(true);events.knowledge = data.events.get("knowledge", {}).duplicate(true);events.elapsed = float(data.events.get("elapsed", 0))
	var crafting: Node = town.get("crafting")
	if is_instance_valid(crafting) and crafting.has_method("restore") and data.get("crafting") is Dictionary:crafting.restore(data.crafting.duplicate(true))
	for id in extensions:
		if data.has(id):extensions[id].apply.call(data[id])

func set_status(message: String, error: Error = OK) -> void:
	status_text = message;last_error = error;notice_time = 6
	if status_label:status_label.text = message;status_label.show()
	status_changed.emit(message, error)

func _process(delta: float) -> void:
	if saving:
		writer.mutex.lock();var busy: bool = writer.active or not writer.pending.is_empty();var error: Error = OK if writer.failures.is_empty() else writer.failures.values()[0];writer.mutex.unlock()
		if not busy:saving = false;set_status("Session saved." if error == OK else "Could not save your session. Please try again.", error)
	if notice_time > 0:
		notice_time -= delta
		if notice_time <= 0 and last_error == OK and status_label:status_label.hide()
	if not ready_for_use or not restored:return
	clock += delta
	if clock >= autosave_seconds and not saving:save_now(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and ready_for_use:flush_and_save()

func _exit_tree() -> void:writer.shutdown()
