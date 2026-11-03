extends Node

# The supplied house will be registered here after its entrances and scale are reviewed.
var town: Node3D
var house: Node3D
var storage: Dictionary={}
var panel: AcceptDialog
var details: Label
var save_path:="user://player-home.json"
var previous_enabled:=false
var previous_mouse:=Input.MOUSE_MODE_VISIBLE
var item_field: LineEdit
var quantity: SpinBox

func _ready() -> void:
	town=get_parent()
	if town.economy.testing():save_path="user://review-player-home.json"
	if FileAccess.file_exists(save_path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if data is Dictionary:storage=data.get("storage",{})
	panel=AcceptDialog.new();panel.title="Your home";town.add_child(panel)
	var body:=VBoxContainer.new();panel.add_child(body)
	details=Label.new();details.custom_minimum_size=Vector2(450,90);details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(details)
	item_field=LineEdit.new();item_field.placeholder_text="Belonging name";body.add_child(item_field)
	quantity=SpinBox.new();quantity.min_value=1;quantity.max_value=99;body.add_child(quantity)
	for deposit in [true,false]:
		var transfer_button:=Button.new();transfer_button.text="Store in your home" if deposit else "Take from home"
		body.add_child(transfer_button);transfer_button.pressed.connect(func():
			if transfer(item_field.text,int(quantity.value),deposit):update_details()
			else:details.text="Visit your registered home with the belongings you want to store, or choose an item already stored there."
		)
	panel.visibility_changed.connect(func():
		if not panel.visible:town.player.enabled=previous_enabled;Input.mouse_mode=previous_mouse
	)
	var button:=Button.new();button.text="Your home";town.menu_body.add_child(button);button.pressed.connect(show_home)

func show_home() -> void:
	previous_enabled=town.player.enabled;previous_mouse=Input.mouse_mode
	town.player.enabled=false;town.player.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	update_details()
	panel.popup_centered()

func update_details() -> void:
	details.text="Your potter's house and spacious loft interior are selected. Indoor fitting and the safe starting position are being prepared. You will start inside, with only your chosen interior visible."
	if is_instance_valid(house):details.text="Your home: "+String(house.name)+"\nUse nearby furniture to sit or sleep. Stored belongings: "+str(storage)

func register_house(model: Node3D) -> bool:
	if not is_instance_valid(model) or not model.is_in_group("enterable_houses"):return false
	# Never take an occupied family home for the player.
	for family in town.families.households:
		if family.get("house")==model:return false
	house=model;house.set_meta("player_owned",true);return true

func transfer(item: String,amount: int,deposit: bool) -> bool:
	if not is_instance_valid(house) or amount<=0 or town.player.position.distance_to(house.global_position)>8:return false
	var source: Dictionary=town.adventures.inventory if deposit else storage
	var target: Dictionary=storage if deposit else town.adventures.inventory
	if int(source.get(item,0))<amount:return false
	source[item]=int(source[item])-amount;target[item]=int(target.get(item,0))+amount
	town.adventures.save_state()
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"storage":storage}))
	return true
