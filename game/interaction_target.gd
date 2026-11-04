extends RefCounted

static func resolve(town: Node) -> Dictionary:
	if not town.player.resting.is_empty():return {"kind":"stand","verb":"Stand up","label":"Stand up from your "+("seat" if town.player.resting=="sitting" else "bed")}
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
	if life.nearest:return {"kind":"talk","node":life.nearest,"verb":"Talk","label":"Talk to "+life.nearest.person_name+" · "+life.nearest.occupation}
	return {"kind":"none","verb":"Use","label":"Move closer to a door, person or usable item"}

static func perform(town: Node,target: Dictionary) -> void:
	match target.kind:
		"physical":town.physical_gameplay.interact(target)
		"stand":town.player.stand_from_furniture()
		"home":
			if Time.get_ticks_msec()-town.home_district.transferred_at>700:
				if town.home_district.inside:town.home_district.leave_home()
				else:town.home_district.enter_home()
		"task":town.adventures.use_task(target.id)
		"furniture":town.player.use_furniture(target.node,target.posture)
		"door":
			if not target.node.toggle(town.player.position):town.life.hint.text="Step clear of the doorway before closing it"
		"talk":town.life.open_dialog(target.node)
