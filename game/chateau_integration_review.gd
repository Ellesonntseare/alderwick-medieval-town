extends SceneTree

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var town=load("res://town.tscn").instantiate()
	root.add_child(town)
	for frame in range(1200):
		await process_frame
		if town.life.navigation_ready:break
	var failures: Array[String]=[]
	if town.chateaux.sites.size()!=2:failures.append("Two new districts must load in the town")
	if town.life.people.size()!=45:failures.append("Resident count must remain 45")
	var visit_labels: Array[String]=[]
	for menu in town.find_children("*","OptionButton",true,false):
		for index in range(menu.item_count):visit_labels.append(menu.get_item_text(index))
	for site in town.chateaux.sites:
		if not visit_labels.has(site.title+" ruins"):failures.append(site.id+" missing from Visit menu")
	print("CHATEAU_INTEGRATION_REVIEW locations=",town.locations.size()," residents=",town.life.people.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
