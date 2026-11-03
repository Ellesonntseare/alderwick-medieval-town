extends Node3D

var town: Node3D
var found: Dictionary={}
var sites: Array=[]
var prompt: Label
var save_path:="user://town-discoveries.json"

func _ready() -> void:
	town=get_parent()
	if town.economy.testing():save_path="user://review-town-discoveries.json"
	if FileAccess.file_exists(save_path):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if saved is Dictionary:found=saved
	setup.call_deferred()
	var layer:=CanvasLayer.new();add_child(layer)
	prompt=Label.new();layer.add_child(prompt);prompt.position=Vector2(24,690);prompt.add_theme_font_size_override("font_size",19)

func setup() -> void:
	while not town.life.navigation_ready:await get_tree().process_frame
	add_site("delivery_slip","A mud-stained delivery slip",Vector3(39,.04,-40),"The delivery slip says Ada's greens were sent to Fère-en-Tardenois by mistake. Corvin checked the destination label.",["Corvin","Ada"],"missing_delivery",1)
	add_site("workshop_note","A carpenter's work note",Vector3(35,.08,19.5),"Oren's note says Bram was making replacement wagon fittings. The eastern supply store was their collection point.",["Oren","Bram"],"wagon_fittings",1)
	for site in town.chateaux.sites:
		if site.id=="montfaucon_chateau":add_site("survey_sketch","A charcoal masonry sketch",site.inside+Vector3(3,.05,1),"Ansel's dated masonry sketch belongs to his current survey. A margin asks Nils to compare the western entrance. Greta is waiting for a check-in; the sketch alone does not prove Ansel is safe.",["Nils","Greta","Ansel"],"overdue_surveyor",2)

func add_site(id: String,title: String,point: Vector3,text: String,people: Array,mission: String,lead_step: int) -> void:
	var paper:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(.3,.015,.23);paper.mesh=mesh
	var material:=StandardMaterial3D.new();material.albedo_color=Color("c7b68c");paper.material_override=material
	add_child(paper);paper.position=point
	sites.append({"id":id,"title":title,"point":point,"text":text,"people":people,"mission":mission,"lead_step":lead_step})

func discover(site: Dictionary) -> bool:
	if town.player.position.distance_to(site.point)>2.4 or not town.events.visible_between(town.player.position,site.point):return false
	if found.has(site.id):town.economy.announce(site.text);return true
	found[site.id]=site.text
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(found))
	# Investigating a genuine clue can reveal its lead; finding a sketch never completes a rescue.
	var state: Dictionary=town.adventures.progress[site.mission]
	if state.status=="unmet":state.status="offered"
	if state.status=="active" and int(state.step)<int(site.lead_step):state.step=site.lead_step
	town.adventures.save_state();town.adventures.update_markers();town.adventures.refresh_journal()
	town.adventures.inventory[site.title]=1;town.adventures.save_state()
	town.economy.announce(site.text)
	return true

func context(person: Node) -> Array:
	var result: Array=[]
	for site in sites:
		if found.has(site.id) and site.people.has(person.person_name):result.append({"visitor_carries":site.title,"verified_text":site.text,"instruction":"Discuss this if the visitor mentions the clue. Do not pretend you already saw them find it."})
	return result

func _process(_delta: float) -> void:
	prompt.text=""
	if not town.player.enabled or town.life.active:return
	for site in sites:
		if town.player.position.distance_to(site.point)<2.4:prompt.text="[G] Examine · "+site.title;break

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_G and town.player.enabled and not town.life.active:
		for site in sites:
			if discover(site):get_viewport().set_input_as_handled();break
