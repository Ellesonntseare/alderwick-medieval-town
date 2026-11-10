extends RefCounted

static func uses_focus(town: Node) -> bool:
	var interface: Node=town.get("interface_ui") if &"interface_ui" in town else null
	return is_instance_valid(interface) and interface.ready_for_use

static func gameplay_visible(town: Node) -> bool:
	if not uses_focus(town):return false
	return town.view_mode!=1 and not town.interface_ui.active and not town.builder.active and not town.life.active and not town.character_directory.is_open()

static func resolve(town: Node) -> Dictionary:
	if not town.player.resting.is_empty():return {"kind":"stand","verb":"Stand up","label":"Stand up from your "+("seat" if town.player.resting=="sitting" else "bed")}
	if uses_focus(town):return resolve_focused(town)
	var home=town.get("home_district")
	if home and home.prompt and not home.prompt.text.is_empty():
		return {"kind":"home","verb":"Leave home" if home.inside else "Enter home","label":"Leave your home" if home.inside else "Enter your home"}
	if town.adventures:
		var id: String=town.adventures.nearby_task()
		if not id.is_empty():
			var mission: Dictionary=town.adventures.find_mission(id)
			var step: Dictionary=mission.steps[int(town.adventures.progress[id].step)]
			return {"kind":"task","id":id,"verb":"Work" if step.kind=="work" else "Pick up","label":("Hold Use to work: "+mission.title) if step.kind=="work" else "Pick up "+String(step.get("item",mission.title))}
	var life=town.life
	if town.get("physical_gameplay"):
		var physical: Dictionary=town.physical_gameplay.target()
		if not physical.is_empty():return physical
	var furniture=life.nearest_furniture
	var door=life.nearest_door
	if furniture and (not door or furniture.global_position.distance_to(town.player.position)<door.global_position.distance_to(town.player.position)):
		var seat: bool=furniture.is_in_group("seats")
		var title: String=String(furniture.name)
		if title.begins_with("@") or title.begins_with("Marker"):title="seat" if seat else "bed"
		return {"kind":"furniture","node":furniture,"verb":"Sit down" if seat else "Lie down","label":("Sit on " if seat else "Lie down in ")+title,"posture":"sitting" if seat else "sleeping"}
	if door:return {"kind":"door","node":door,"verb":"Close door" if door.is_open else "Open door","label":("Close " if door.is_open else "Open ")+door.door_name}
	if life.nearest:
		var inventory: Node = town.inventory_ui if &"inventory_ui" in town else null
		if is_instance_valid(inventory) and inventory.shop.available_for(life.nearest):
			var orders: bool = life.nearest.person_name == inventory.shop.CARPENTER
			return {"kind":"shop","orders":orders,"verb":"Browse","label":"Furniture commissions" if orders else "Browse the shop"}
		return {"kind":"talk","node":life.nearest,"verb":"Talk","label":"Talk to "+life.nearest.person_name+" · "+life.nearest.occupation}
	return {"kind":"none","verb":"Use","label":"Move closer to a door, person or usable item"}

static func resolve_focused(town: Node) -> Dictionary:
	var none: Dictionary={"kind":"none","verb":"Use","label":""}
	if not gameplay_visible(town):return none
	var camera:=town.get_viewport().get_camera_3d()
	if not is_instance_valid(camera):return none
	var physical: Node=town.physical_gameplay
	if physical and (physical.carried or physical.climbing or physical.mounted or physical.pushing or physical.object_action.active):return physical.target()
	var player: CharacterBody3D=town.player
	var position:=player.global_position
	var eye: Vector3=player.camera.global_position
	var candidates: Array[Dictionary]=[]
	var home: Node=town.home_district
	if home:
		var point: Vector3=home.exit_point if home.inside else home.porch
		if position.distance_to(point)<2.5:
			candidates.append({"kind":"home","verb":"Leave home" if home.inside else "Enter home","label":"Leave your home" if home.inside else "Enter your home","point":point+Vector3.UP*.85})
	var adventures: Node=town.adventures
	if adventures:
		var id: String=adventures.nearby_task()
		if not id.is_empty():
			var mission: Dictionary=adventures.find_mission(id)
			var step: Dictionary=mission.steps[int(adventures.progress[id].step)]
			candidates.append({"kind":"task","id":id,"verb":"Work" if step.kind=="work" else "Pick up","label":"Fit wagon parts" if step.kind=="work" else "Pick up "+String(step.get("item",mission.title)),"hold":step.kind=="work","point":adventures.step_position(step)+Vector3.UP*.75})
	if physical:
		for object in physical.objects+town.get_tree().get_nodes_in_group("animals"):
			if not is_instance_valid(object) or not object.is_visible_in_tree() or position.distance_to(object.global_position)>=2.3:continue
			var animal: bool=object.is_in_group("animals")
			var pickup: bool=object.get_meta("activity","")=="carry" and (not object.has_meta("seat") or not object.get_meta("seat").has_meta("occupant"))
			var title:=String(object.species) if animal else String(object.name)
			candidates.append({"kind":"physical","object":object,"node":object,"verb":"Pick up" if pickup else "Activities","label":("Pick up " if pickup else "Use ")+title,"pickup":pickup,"point":object.global_position+Vector3.UP*(.85 if animal else .45)})
	for door: Node3D in town.get_tree().get_nodes_in_group("doors"):
		if not door.is_visible_in_tree() or position.distance_to(door.global_position)>=2.8:continue
		var verb: String="Close" if door.is_open else "Open"
		var point: Vector3=door.get_closed_transform()*Vector3(door.width/2,door.height*.5,0)
		candidates.append({"kind":"door","node":door,"verb":verb,"label":verb+" "+door.door_name,"point":point})
	for group in ["seats","beds"]:
		for item: Node3D in town.get_tree().get_nodes_in_group(group):
			if not item.is_visible_in_tree() or item.has_meta("occupant") or position.distance_to(item.global_position)>=2.3:continue
			var seat: bool=group=="seats"
			var title:=String(item.name)
			if title.begins_with("@") or title.begins_with("Marker"):title="seat" if seat else "bed"
			candidates.append({"kind":"furniture","node":item,"verb":"Sit down" if seat else "Lie down","label":("Sit on " if seat else "Lie down in ")+title,"posture":"sitting" if seat else "sleeping","point":item.global_position+Vector3.UP*.38})
	var people: Array=town.life.traffic.people_near(position,5.0) if town.life.traffic else town.life.people.duplicate()
	if adventures and is_instance_valid(adventures.visitor) and not people.has(adventures.visitor):people.append(adventures.visitor)
	for person in people:
		if not is_instance_valid(person) or person.posture=="sleeping" or not person.is_visible_in_tree() or position.distance_to(person.global_position)>=5:continue
		var point: Vector3=person.global_position+Vector3.UP*1.25*person.appearance_height
		var activity: String=person.occupation
		if not person.activity.is_empty() and person.activity!=person.occupation:activity+=" · "+person.activity
		var inventory: Node=town.inventory_ui
		if is_instance_valid(inventory) and inventory.shop.available_for(person):
			var orders: bool=person.person_name==inventory.shop.CARPENTER
			candidates.append({"kind":"shop","node":person,"orders":orders,"verb":"Browse","label":"Furniture commissions" if orders else "Browse "+person.person_name+"’s stall","detail":activity,"point":point})
		else:candidates.append({"kind":"talk","node":person,"verb":"Talk","label":"Talk to "+person.person_name,"detail":activity,"point":point})
	return best_visible(camera,player,eye,candidates,none)

static func best_visible(camera: Camera3D,player: CharacterBody3D,eye: Vector3,candidates: Array[Dictionary],fallback: Dictionary) -> Dictionary:
	var center:=camera.get_viewport().get_visible_rect().size/2
	var maximum:=maxf(30,center.y*.42)
	var world:=camera.get_world_3d().direct_space_state
	var best:=maximum
	var result:=fallback
	for candidate in candidates:
		var point: Vector3=candidate.point
		if camera.is_position_behind(point):continue
		var score:=camera.unproject_position(point).distance_to(center)+player.global_position.distance_to(point)*3
		if score>=best:continue
		var query:=PhysicsRayQueryParameters3D.create(eye,point,1)
		query.exclude=[player.get_rid()]
		var hit:=world.intersect_ray(query)
		var object: Node=candidate.get("node")
		if not hit.is_empty() and hit.position.distance_to(point)>.2 and (not is_instance_valid(object) or (hit.collider!=object and not object.is_ancestor_of(hit.collider))):continue
		best=score;result=candidate
	return result

static func perform(town: Node,target: Dictionary) -> void:
	match target.kind:
		"physical":
			if target.get("pickup",false):town.physical_gameplay.pickup(target.object)
			else:town.physical_gameplay.interact(target)
		"stand":town.player.stand_from_furniture()
		"shop":
			if target.has("node"):town.life.nearest=target.node
			town.inventory_ui.open_shop(target.orders)
		"home":
			if Time.get_ticks_msec()-town.home_district.transferred_at>700:
				if town.home_district.inside:town.home_district.leave_home()
				else:town.home_district.enter_home()
		"task":town.adventures.use_task(target.id)
		"furniture":town.player.use_furniture(target.node,target.posture)
		"door":
			if not target.node.toggle(town.player.position):
				if uses_focus(town):town.economy.announce("Step clear of the doorway before closing it.")
				else:town.life.hint.text="Step clear of the doorway before closing it"
		"talk":town.life.open_dialog(target.node)
